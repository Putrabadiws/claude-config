#!/bin/bash
# Blocks bulk overwrites (cp, rsync, tee, redirect) targeting any *-claude-config repo.
# Forces use of the Edit tool for surgical changes — preserves per-repo customizations.
# Exit 2 = block command, Exit 0 = allow command
source "$(dirname "$0")/path-bootstrap.sh"

if ! command -v jq &> /dev/null; then
  exit 0
fi

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

if [ -z "$COMMAND" ]; then
  exit 0
fi

# Two-stage detection to avoid false positives on incidental text in arguments:
#   1. Command-verbs (cp/rsync/tee/mv) anchored to sub-command start
#      (start-of-string or after &&, ;, ||, or newline).
#   2. Redirect (>) followed by a path-shaped destination (starts with ~/ or /).
# Both must target a path containing -claude-config.
if echo "$COMMAND" | grep -qE '(^|&&|;|\|\||\n)\s*(cp|rsync|tee|mv)\s+[^|]*-claude-config' \
   || echo "$COMMAND" | grep -qE '>\s+[~/][^|]*-claude-config'; then
  echo "BLOCKED: bulk overwrite to *-claude-config repo detected." >&2
  echo "Use the Edit tool for surgical changes — never cp/rsync/redirect to claude-config files." >&2
  exit 2
fi

exit 0
