#!/bin/bash
# Validates Bash commands for destructive operations
# Blocks dangerous commands that could cause data loss
# Exit 2 = block command, Exit 0 = allow command
source "$(dirname "$0")/path-bootstrap.sh"

# Check if jq is available
if ! command -v jq &> /dev/null; then
  echo "Warning: jq not found, skipping validation" >&2
  exit 0
fi

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

if [ -z "$COMMAND" ]; then
  exit 0
fi

# Block destructive git commands (allow --force-with-lease as it's safe)
if echo "$COMMAND" | grep -qE 'git\s+(reset\s+--hard|clean\s+-fd?|branch\s+-D)'; then
  echo "Destructive git command detected. Requires approval." >&2
  exit 1
fi
# Block git push --force/-f but allow --force-with-lease
# Match -f or --force as standalone flags (word boundaries), not as part of branch names
if echo "$COMMAND" | grep -qE 'git\s+push\b' && echo "$COMMAND" | grep -qE '(^|\s)(-f|--force)(\s|$)' && ! echo "$COMMAND" | grep -q '\-\-force-with-lease'; then
  echo "git push --force detected. Use --force-with-lease or approve." >&2
  exit 1
fi

# Only block truly catastrophic rm commands (system paths)
# Covers Unix (macOS/Linux), Windows native paths, and Git Bash paths (/c/, /d/, etc.)
if echo "$COMMAND" | grep -qiE 'rm\s+(-rf|-fr|-r\s+-f|-f\s+-r)\s+(/|/etc|/var|/usr|/System|/Library|/[a-z]/(Windows|Program)|C:\\Windows|C:\\Program)\s*$'; then
  echo "rm on system root path detected. Requires approval." >&2
  exit 1
fi

# rm -rf *, kubectl delete, helm uninstall - let settings.json handle permission prompts

# Block database drop commands
if echo "$COMMAND" | grep -qiE '(DROP\s+(DATABASE|TABLE|SCHEMA)|TRUNCATE\s+TABLE)'; then
  echo "DROP/TRUNCATE database command detected. Requires approval." >&2
  exit 1
fi

# Block dangerous system commands (Unix and Windows)
if echo "$COMMAND" | grep -qiE '(mkfs\.|dd\s+if=|>\s*/dev/sd|format\s+[a-z]:|format\.com|diskpart|chmod\s+-R\s+777|chown\s+-R)'; then
  echo "Dangerous system command detected. Requires approval." >&2
  exit 1
fi

exit 0
