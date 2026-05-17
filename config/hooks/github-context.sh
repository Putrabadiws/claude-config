#!/bin/bash
# Detect git repo from cwd or cd target, inject github rules once
# Uses a session-scoped flag file to avoid re-injecting

INPUT=$(cat)

# Extract fields
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty')
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')
CWD=$(echo "$INPUT" | jq -r '.cwd // empty')

# Flag file: one per session, prevents re-injection
FLAG="/tmp/github-rules-injected-${SESSION_ID}"

# Already injected this session? Skip
[ -f "$FLAG" ] && { echo '{"suppressOutput": true}'; exit 0; }

# Determine target directory: cd target or cwd.
# BSD sed/grep on macOS don't support \s — use [[:space:]] (POSIX) so this
# works on both macOS and Linux.
TARGET_DIR=""
if echo "$COMMAND" | grep -qE '^[[:space:]]*cd[[:space:]]+'; then
  # Extract cd target (first argument after cd)
  TARGET_DIR=$(echo "$COMMAND" | sed -E 's/^[[:space:]]*cd[[:space:]]+([^ &;|]+).*/\1/')
  # Expand ~ if present
  TARGET_DIR="${TARGET_DIR/#\~/$HOME}"
elif [ -n "$CWD" ]; then
  TARGET_DIR="$CWD"
fi

[ -z "$TARGET_DIR" ] && { echo '{"suppressOutput": true}'; exit 0; }

# Only inject when target is a git repo whose remote points to GitHub.
# Match on raw remote URL — stripping to owner/repo loses the host.
if [ -d "$TARGET_DIR/.git" ]; then
  REMOTE_URL=$(git -C "$TARGET_DIR" remote get-url origin 2>/dev/null || echo "")
  case "$REMOTE_URL" in
    *github*) ;;
    *) echo '{"suppressOutput": true}'; exit 0 ;;
  esac
  touch "$FLAG"
  RULES=$(cat ~/.claude/hooks/github-rules.md 2>/dev/null || echo "")
  if [ -n "$RULES" ]; then
    # Escape for JSON
    RULES_JSON=$(echo "$RULES" | jq -Rs .)
    echo "{\"hookSpecificOutput\":{\"hookEventName\":\"PreToolUse\",\"additionalContext\":$RULES_JSON}}"
    exit 0
  fi
fi

echo '{"suppressOutput": true}'
