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

REL="${FILE_PATH#$HOME/.claude/}"
[ -z "$REL" ] && exit 0

# Map source path to its exact target in each sync repo. Anchoring on the full
# relative path (not basename) avoids the collision case where the same filename
# exists in many sibling folders — e.g. SKILL.md under every config/skills/<name>/.
# ~/.claude/mcp/<svc>/... and ~/.claude/integrations/<svc>/... map to parallel
# trees in the repo; everything else maps under config/.
case "$REL" in
  mcp/*|integrations/*) TARGET_REL="$REL" ;;
  *)                    TARGET_REL="config/$REL" ;;
esac

if [ -n "$SYNC_HINT_REPOS_OVERRIDE" ]; then
  IFS=':' read -ra REPOS <<< "$SYNC_HINT_REPOS_OVERRIDE"
else
  REPOS=(
    "$HOME/bangor/bangor-claude-config"
  )
fi

MATCHES=""
REPO_NAMES=""
for repo in "${REPOS[@]}"; do
  [ -d "$repo" ] || continue
  [ -f "$repo/$TARGET_REL" ] || continue
  repo_name=$(basename "$repo")
  MATCHES="${MATCHES}  ${repo_name}: ${TARGET_REL}"$'\n'
  [ -z "$REPO_NAMES" ] && REPO_NAMES="$repo_name" || REPO_NAMES="$REPO_NAMES, $repo_name"
done

[ -z "$MATCHES" ] && exit 0

# systemMessage = tight repo-name list for the user; additionalContext keeps the
# full source→target paths so Claude knows exactly what to sync.
MSG="Sync targets for ${REL}:"$'\n'"$MATCHES"
jq -n --arg sm "🔄 Sync → ${REPO_NAMES}" --arg ctx "$MSG" '{
  systemMessage: $sm,
  hookSpecificOutput: {
    hookEventName: "PostToolUse",
    additionalContext: $ctx
  }
}'
exit 0
