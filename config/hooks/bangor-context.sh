#!/bin/bash
# SYNC:LOCAL-ONLY  — Bangor-team-specific hook; do not sync to ib or other repos.
# Inject Burger Bangor business context when working in any repo under the
# Bangor-Group-Indonesia GitHub org. Detection is via `git remote` on the cd
# target (or current cwd if no cd), so any checkout location works.
# Mirrors gitlab-context.sh: PreToolUse on Bash, session-scoped flag avoids
# re-injection. Coordinates with session-context.sh which sets the same flag
# when the session already starts inside a Bangor repo.

INPUT=$(cat)

SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty')
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')
CWD=$(echo "$INPUT" | jq -r '.cwd // empty')

FLAG="/tmp/bangor-context-injected-${SESSION_ID}"

# Already injected this session? Skip silently.
[ -f "$FLAG" ] && { echo '{"suppressOutput": true}'; exit 0; }

# Determine target directory: cd target wins (user is moving INTO it), else cwd.
TARGET_DIR=""
# BSD sed/grep on macOS don't support \s — use [[:space:]] (POSIX) so this
# works on both macOS and Linux without needing GNU coreutils.
if echo "$COMMAND" | grep -qE '^[[:space:]]*cd[[:space:]]+'; then
  TARGET_DIR=$(echo "$COMMAND" | sed -E 's/^[[:space:]]*cd[[:space:]]+([^ &;|]+).*/\1/')
  TARGET_DIR="${TARGET_DIR/#\~/$HOME}"
elif [ -n "$CWD" ]; then
  TARGET_DIR="$CWD"
fi

[ -z "$TARGET_DIR" ] && { echo '{"suppressOutput": true}'; exit 0; }

# Match if either: (a) path is under ~/bangor (the user's local workspace for
# Bangor repos), or (b) the target dir's git remote points to the Bangor org.
# Path check is cheap and handles cases like cd'ing to ~/bangor itself (not yet
# inside a repo). Git-remote check generalizes to any checkout location.
MATCHED=false
case "$TARGET_DIR" in
  "$HOME/bangor"|"$HOME/bangor"/*) MATCHED=true ;;
esac

if ! $MATCHED && [ -d "$TARGET_DIR" ]; then
  REMOTE=$(git -C "$TARGET_DIR" remote get-url origin 2>/dev/null || echo "")
  if echo "$REMOTE" | grep -qiE 'bangor-group-indonesia'; then
    MATCHED=true
  fi
fi

if $MATCHED; then
  touch "$FLAG"
  CTX=$(cat ~/.claude/hooks/bangor-context.md 2>/dev/null || echo "")
  if [ -n "$CTX" ]; then
    CTX_JSON=$(echo "$CTX" | jq -Rs .)
    echo "{\"hookSpecificOutput\":{\"hookEventName\":\"PreToolUse\",\"additionalContext\":$CTX_JSON}}"
    exit 0
  fi
fi

echo '{"suppressOutput": true}'
