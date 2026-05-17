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

# Match: cp / rsync / tee / shell-redirect targeting a path containing -claude-config
if echo "$COMMAND" | grep -qE '(cp\s+|rsync\s+|tee\s+|>\s+)[^|]*-claude-config'; then
  echo "BLOCKED: bulk overwrite to *-claude-config repo detected." >&2
  echo "Use the Edit tool for surgical changes — never cp/rsync/redirect to claude-config files." >&2
  exit 2
fi

exit 0
