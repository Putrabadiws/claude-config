#!/bin/bash
# PostToolUse hook for Edit/Write: when a file under ~/.claude/ is touched,
# emit a hint listing matching paths in the bangor-claude-config sync repo.
# Catches the "forgot to sync hand-edits" failure mode automatically.
#
# Output: systemMessage (user UI) + hookSpecificOutput.additionalContext (Claude context).
# Silent when no matches (file isn't synced — e.g., ~/.claude/projects, memory, secrets).
#
# Test override: set SYNC_HINT_REPOS_OVERRIDE to a colon-separated list of repo roots.
source "$(dirname "$0")/path-bootstrap.sh"

command -v jq >/dev/null 2>&1 || exit 0

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_response.filePath // .tool_input.file_path // empty' 2>/dev/null)
[ -z "$FILE_PATH" ] && exit 0

# Tilde expansion (defensive — Claude usually passes absolute paths)
case "$FILE_PATH" in
  "~"*) FILE_PATH="$HOME${FILE_PATH:1}" ;;
esac

# Only fire for paths under ~/.claude/
case "$FILE_PATH" in
  "$HOME/.claude/"*) ;;
  *) exit 0 ;;
esac

BASENAME=$(basename "$FILE_PATH")
[ -z "$BASENAME" ] && exit 0

if [ -n "$SYNC_HINT_REPOS_OVERRIDE" ]; then
  IFS=':' read -ra REPOS <<< "$SYNC_HINT_REPOS_OVERRIDE"
else
  REPOS=(
    "$HOME/bangor/bangor-claude-config"
  )
fi

MATCHES=""
for repo in "${REPOS[@]}"; do
  [ -d "$repo" ] || continue
  repo_name=$(basename "$repo")
  for tree in config mcp integrations; do
    [ -d "$repo/$tree" ] || continue
    while IFS= read -r found; do
      [ -z "$found" ] && continue
      rel="${found#$repo/}"
      MATCHES="${MATCHES}  ${repo_name}: ${rel}"$'\n'
    done < <(find "$repo/$tree" -maxdepth 6 -type f -name "$BASENAME" 2>/dev/null)
  done
done

[ -z "$MATCHES" ] && exit 0

MSG="Sync targets for ${BASENAME}:"$'\n'"$MATCHES"
jq -n --arg msg "$MSG" '{
  systemMessage: $msg,
  hookSpecificOutput: {
    hookEventName: "PostToolUse",
    additionalContext: $msg
  }
}'
exit 0
