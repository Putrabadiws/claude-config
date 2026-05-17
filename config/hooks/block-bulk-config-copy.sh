#!/bin/bash
# Blocks `cp` (or similar bulk overwrite) into a *-claude-config repo when the
# target file is unsafe to clobber. "Unsafe" = either:
#   (a) destination file is .json — JSON has no comments, so per-context
#       sections can't be flagged; always Edit for JSON.
#   (b) any path in the command (source OR destination) contains the local-only
#       marker (HTML comment in markdown, # comment in shell, etc.). Marker
#       indicates the file has context-specific content that cp would clobber.
# NOTE: marker keyword is assembled at runtime from string parts so this hook
# source doesn't self-flag (otherwise we'd be unable to cp the hook itself).
#
# Default: allow. Matches the rule in CLAUDE.md — diff first, cp if eligible.
#
# Exit 2 = block command, Exit 0 = allow command
source "$(dirname "$0")/path-bootstrap.sh"

if ! command -v jq &> /dev/null; then
  exit 0
fi

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')
[ -z "$COMMAND" ] && exit 0

# Marker patterns assembled from string parts so the literal keyword never
# appears as a contiguous substring in this source file (avoids self-flag).
MARKER_KW="SYNC"":""LOCAL-ONLY"
MARKER_REGEX="(<!--[[:space:]]*${MARKER_KW}[[:space:]]*-->|#[[:space:]]*${MARKER_KW})"

# Split COMMAND into sub-commands separated by | & ; and newlines, then check
# ONLY sub-commands that start with cp/rsync/tee/mv. This prevents false
# positives where a script has a write-verb in one sub-command and a path
# reference (e.g. grep over a settings.json) in another sub-command.
while IFS= read -r subcmd; do
  # Trim leading whitespace.
  subcmd="${subcmd#"${subcmd%%[![:space:]]*}"}"
  # Skip empty lines and sub-commands that don't start with a write-verb.
  echo "$subcmd" | grep -qE '^(cp|rsync|tee|mv)[[:space:]]+' || continue

  # Extract path-shaped tokens (anything starting with ~/, /, or ./) from THIS
  # sub-command's arguments only. Skip flags (- prefix) and trailing punctuation.
  PATHS=$(echo "$subcmd" | tr ' \t' '\n' | grep -E '^(~/|/|\./)' | sed 's/[;&|]*$//')

  for path in $PATHS; do
    expanded="${path/#\~\//$HOME/}"
    # JSON gate: always Edit for JSON config under claude-config.
    case "$path" in
      *-claude-config*|*/.claude/*)
        case "$path" in
          *.json)
            echo "BLOCKED: cp targets a .json file in a claude-config repo." >&2
            echo "JSON has no comments to mark local-only sections — use the Edit tool." >&2
            exit 2
            ;;
        esac
        ;;
    esac
    # Marker gate: applies to source and destination regardless of side.
    if [ -f "$expanded" ] && grep -qE "$MARKER_REGEX" "$expanded"; then
      echo "BLOCKED: file contains local-only marker (${MARKER_KW}): $path" >&2
      echo "Use the Edit tool for surgical replace — cp would clobber context-specific content." >&2
      exit 2
    fi
  done
done < <(echo "$COMMAND" | tr '|&;' '\n')

exit 0
