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

# Determine target directory: cd target or cwd
TARGET_DIR=""
if echo "$COMMAND" | grep -qE '^\s*cd\s+'; then
  # Extract cd target (first argument after cd)
  TARGET_DIR=$(echo "$COMMAND" | sed -E 's/^\s*cd\s+([^ &;|]+).*/\1/')
  # Expand ~ if present
  TARGET_DIR="${TARGET_DIR/#\~/$HOME}"
elif [ -n "$CWD" ]; then
  TARGET_DIR="$CWD"
fi

[ -z "$TARGET_DIR" ] && { echo '{"suppressOutput": true}'; exit 0; }

# Check if target is a git repo
if [ -d "$TARGET_DIR/.git" ]; then
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
