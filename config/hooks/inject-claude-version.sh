#!/bin/bash
# inject-claude-version.sh — Two-layer version injection for git commits and MR descriptions.
#
# Layer 1 (updatedInput): If the command contains literal {{claude-code-version}} or {{claude-model}}
#   placeholders, the hook rewrites the command deterministically via updatedInput.
# Layer 2 (additionalContext): If the LLM already resolved the tokens (common path — Claude reads
#   the version from session context and substitutes before the hook fires), provide the correct
#   version as additionalContext so future commands also use the right values.
#
# Both layers always emit additionalContext with the correct version+model for consistency.
source "$(dirname "$0")/path-bootstrap.sh"

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

# Only intercept commit/MR/PR creation commands.
# Anchor verbs to sub-command start to avoid false positives on substrings
# inside argument text (e.g. `grep "glab mr create" file.txt`).
if ! echo "$COMMAND" | grep -qE '(^|&&|;|[|]+|\n)\s*(git\s+commit|glab\s+mr\s+(create|update)|gh\s+pr\s+(create|edit|comment))'; then
  exit 0
fi

# Load from session-env file (written by session-context.sh)
SESSION_ENV="$HOME/.claude/.session-env"
if [ -f "$SESSION_ENV" ]; then
  source "$SESSION_ENV"
fi

# Resolve version: session-env > env var > CLI fallback
VERSION="${CLAUDE_CODE_VERSION:-}"
if [ -z "$VERSION" ]; then
  VERSION=$(claude --version 2>/dev/null | head -1)
fi
# Strip " (Claude Code)" suffix if present — it's already in the attribution text
VERSION=$(echo "$VERSION" | sed 's/ (Claude Code)$//')

# Resolve model from transcript_path (PreToolUse payload doesn't carry .model).
# JSONL: extract .model from each assistant entry, take the last (most recent).
# Use raw ID (e.g. claude-opus-4-7) — no display-name mapping to maintain.
# Fallback to "Claude" only if transcript is missing or has no assistant entries yet
# (e.g. very first command in a brand-new session).
MODEL=""
TRANSCRIPT=$(echo "$INPUT" | jq -r '.transcript_path // empty')
if [ -n "$TRANSCRIPT" ] && [ -f "$TRANSCRIPT" ]; then
  MODEL=$(jq -r 'select(.type=="assistant") | .message.model // .model // empty' "$TRANSCRIPT" 2>/dev/null | tail -1)
fi
[ -z "$MODEL" ] && MODEL="${CLAUDE_MODEL:-Claude}"

if [ -z "$VERSION" ]; then
  exit 0
fi

# Check if command contains placeholders to replace
# Handles both forms: {{claude-code-version}}/{{claude-model}} (canonical) and {version}/{model}
# (legacy form still present in attribution.commit/pr settings). Substitution is gated to
# commit/MR/PR commands above, so it's safe to rewrite {version}/{model} without false positives.
if echo "$COMMAND" | grep -qE '\{\{claude-code-version\}\}|\{\{claude-model\}\}|\{version\}|\{model\}'; then
  # Branch A — placeholders present: replace via updatedInput
  MODIFIED=$(echo "$COMMAND" \
    | sed "s/{{claude-code-version}}/$VERSION/g" \
    | sed "s/{{claude-model}}/$MODEL/g" \
    | sed "s/{version}/$VERSION/g" \
    | sed "s/{model}/$MODEL/g")

  jq -n --arg cmd "$MODIFIED" --arg v "$VERSION" --arg m "$MODEL" '{
    "hookSpecificOutput": {
      "hookEventName": "PreToolUse",
      "updatedInput": { "command": $cmd },
      "additionalContext": ("Claude Code version: " + $v + " | Model: " + $m)
    }
  }'

elif echo "$COMMAND" | grep -q '✨ Generated with Claude Code'; then
  # Branch B — attribution line present (manual substitution); verify version+model match
  ATTR_LINE=$(echo "$COMMAND" | grep -oE '✨ Generated with Claude Code \(claude\.ai/claude-code\) [^ ]+ \([^)]+\)' | head -1)
  ATTR_VER=$(echo "$ATTR_LINE" | sed -E 's|.*\(claude\.ai/claude-code\) ([^ ]+) \(.*|\1|')
  ATTR_MODEL=$(echo "$ATTR_LINE" | sed -E 's|.*\(([^)]+)\)$|\1|')

  if [ -n "$ATTR_VER" ] && [ -n "$ATTR_MODEL" ] && [ "$ATTR_VER" = "$VERSION" ] && [ "$ATTR_MODEL" = "$MODEL" ]; then
    # Correct manual substitution — no scolding, just emit context
    jq -n --arg v "$VERSION" --arg m "$MODEL" '{
      "hookSpecificOutput": {
        "hookEventName": "PreToolUse",
        "additionalContext": ("Claude Code version: " + $v + " | Model: " + $m)
      }
    }'
  else
    # Wrong values or parse failure (treated as mismatch — safer)
    jq -n --arg v "$VERSION" --arg m "$MODEL" --arg av "${ATTR_VER:-?}" --arg am "${ATTR_MODEL:-?}" '{
      "hookSpecificOutput": {
        "hookEventName": "PreToolUse",
        "additionalContext": ("ATTRIBUTION MISMATCH: commit has version=" + $av + ", model=" + $am + " — real values are version=" + $v + ", model=" + $m + ". You MUST amend (or follow-up commit if already pushed) with the correct line: ✨ Generated with Claude Code (claude.ai/claude-code) " + $v + " (" + $m + ")")
      }
    }'
  fi

else
  # Branch C — no attribution at all; emit IMPORTANT note with resolved content
  jq -n --arg v "$VERSION" --arg m "$MODEL" '{
    "hookSpecificOutput": {
      "hookEventName": "PreToolUse",
      "additionalContext": ("IMPORTANT: attribution line missing. Add to commit body: ✨ Generated with Claude Code (claude.ai/claude-code) " + $v + " (" + $m + ")")
    }
  }'
fi
