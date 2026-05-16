#!/bin/bash
# PostToolUse hook: after git push, check if branch has an open PR.
# Only acts when the command actually is (or chains to) `git push` AND the push succeeded.
# Uses the directory where the push ran (parsed from a `cd <path> && ...` prefix), falling
# back to session.cwd — this matters for monorepo workflows where pushes happen in
# submodules or sibling repos.

input=$(cat)
suppress() { echo '{"suppressOutput": true}'; exit 0; }

COMMAND=$(echo "$input" | jq -r '.tool_input.command // empty' 2>/dev/null)
# Match `git push` as a standalone token. Allow it after start-of-line, whitespace,
# or chain operators (&&, ||, ;, |).
echo "$COMMAND" | grep -qE '(^|[[:space:]]|&&|\|\||;|\|)git[[:space:]]+push([[:space:]]|$)' || suppress

# Only warn on successful push
EXIT=$(echo "$input" | jq -r '.tool_response.exit_code // 0' 2>/dev/null)
[ "$EXIT" != "0" ] && suppress

# Resolve the directory the push ran in.
PUSH_DIR=""
if [[ "$COMMAND" =~ ^[[:space:]]*cd[[:space:]]+\"?([^[:space:]\"\&]+)\"?[[:space:]]*\&\& ]]; then
  PUSH_DIR="${BASH_REMATCH[1]}"
  PUSH_DIR="${PUSH_DIR/#\~/$HOME}"
fi
DIR="${PUSH_DIR:-$(echo "$input" | jq -r '.session.cwd // empty' 2>/dev/null)}"
[ -z "$DIR" ] && DIR="$(pwd)"

# Must be a git repo
git -C "$DIR" rev-parse --git-dir > /dev/null 2>&1 || suppress

# Determine the branch being pushed.
BRANCH=$(echo "$COMMAND" | awk '
  {
    for (i=1; i<=NF; i++) {
      if ($i == "push") {
        for (j=i+1; j<=NF; j++) {
          arg=$j
          if (arg ~ /^-/) continue
          if (arg == "origin" || arg == "upstream") continue
          sub(/:.*$/, "", arg)
          if (arg ~ /^(&&|\|\||;|\|)$/) next
          print arg
          exit
        }
      }
    }
  }
')
[ -z "$BRANCH" ] && BRANCH=$(git -C "$DIR" branch --show-current 2>/dev/null)
[ -z "$BRANCH" ] && suppress

# Skip protected branches
case "$BRANCH" in
  main|master|develop|release*) suppress ;;
esac

command -v gh > /dev/null 2>&1 || suppress

# Query GitHub for open PRs from this branch. Use `gh pr list` scoped to the repo
# inferred from the current directory.
PR_COUNT=$(gh pr list --repo "$(gh repo view --json nameWithOwner --jq .nameWithOwner 2>/dev/null)" \
  --head "$BRANCH" --state open --json number 2>/dev/null \
  | jq 'length // 0' 2>/dev/null)

if [ "${PR_COUNT:-0}" = "0" ]; then
  jq -n --arg branch "$BRANCH" --arg dir "$DIR" '{
    hookSpecificOutput: {
      hookEventName: "PostToolUse",
      additionalContext: ("🚨 Branch [" + $branch + "] in " + $dir + " was pushed but has NO open pull request. Create one with `gh pr create` if this was not a draft/WIP push.")
    }
  }'
else
  suppress
fi
