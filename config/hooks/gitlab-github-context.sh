#!/bin/bash
# Unified context-injection hook: detects whether the current/cd-target git
# repo's remote is GitLab or GitHub, and injects the matching rules file
# (`gitlab-rules.md` or `github-rules.md`) once per session.
#
# Replaces the prior split `gitlab-context.sh` + `github-context.sh`.
# Both detection paths share the same boilerplate (read input, resolve target
# dir, check session flag); only the URL-pattern match and rules file differ.

INPUT=$(cat)

SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty')
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')
CWD=$(echo "$INPUT" | jq -r '.cwd // empty')

# Determine target directory: cd target wins (user is moving INTO it), else cwd.
# BSD sed/grep on macOS don't support \s — use [[:space:]] (POSIX) so this
# works on both macOS and Linux without needing GNU coreutils.
TARGET_DIR=""
if echo "$COMMAND" | grep -qE '^[[:space:]]*cd[[:space:]]+'; then
  TARGET_DIR=$(echo "$COMMAND" | sed -E 's/^[[:space:]]*cd[[:space:]]+([^ &;|]+).*/\1/')
  TARGET_DIR="${TARGET_DIR/#\~/$HOME}"
elif [ -n "$CWD" ]; then
  TARGET_DIR="$CWD"
fi

[ -z "$TARGET_DIR" ] && { echo '{"suppressOutput": true}'; exit 0; }
[ ! -d "$TARGET_DIR/.git" ] && { echo '{"suppressOutput": true}'; exit 0; }

REMOTE_URL=$(git -C "$TARGET_DIR" remote get-url origin 2>/dev/null || echo "")
[ -z "$REMOTE_URL" ] && { echo '{"suppressOutput": true}'; exit 0; }

# Detect platform from raw remote URL — stripping to owner/repo loses the host,
# which would inject GitLab rules for GitHub repos and vice versa.
case "$REMOTE_URL" in
  *gitlab*) PLATFORM="gitlab" ;;
  *github*) PLATFORM="github" ;;
  *)        echo '{"suppressOutput": true}'; exit 0 ;;
esac

# Session-scoped flag prevents re-injection within the same session.
FLAG="/tmp/${PLATFORM}-rules-injected-${SESSION_ID}"
[ -f "$FLAG" ] && { echo '{"suppressOutput": true}'; exit 0; }

RULES_FILE="$HOME/.claude/hooks/${PLATFORM}-rules.md"
[ ! -f "$RULES_FILE" ] && { echo '{"suppressOutput": true}'; exit 0; }

RULES=$(cat "$RULES_FILE")
[ -z "$RULES" ] && { echo '{"suppressOutput": true}'; exit 0; }

touch "$FLAG"
RULES_JSON=$(echo "$RULES" | jq -Rs .)
echo "{\"hookSpecificOutput\":{\"hookEventName\":\"PreToolUse\",\"additionalContext\":$RULES_JSON}}"
