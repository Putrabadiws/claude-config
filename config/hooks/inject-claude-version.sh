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

# Only intercept commit/PR creation commands
if ! echo "$COMMAND" | grep -qE '(git\s+commit|gh\s+pr\s+(create|edit|comment))'; then
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
  # Deterministic replacement via updatedInput — handle both placeholder dialects
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
else
  # No placeholders — just provide context so Claude uses correct values next time
  jq -n --arg v "$VERSION" --arg m "$MODEL" '{
    "hookSpecificOutput": {
      "hookEventName": "PreToolUse",
      "additionalContext": ("IMPORTANT: The correct attribution line is: ✨ Generated with Claude Code (claude.ai/claude-code) " + $v + " (" + $m + ") — Use {{claude-code-version}} and {{claude-model}} placeholders (or legacy {version}/{model}); both are replaced automatically in git commit and gh pr commands.")
    }
  }'
fi
