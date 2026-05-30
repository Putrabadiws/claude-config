#!/bin/bash
# PostToolUse hook: after a successful `git push`, check if the branch has an
# open Merge Request (GitLab) or Pull Request (GitHub) and remind the user if
# not. Dispatches based on the remote URL — gitlab.* → glab API, github.* → gh
# CLI. Silently no-ops on unknown remote hosts.
#
# Replaces the prior split `check-mr-after-push.sh` + `check-pr-after-push.sh`.
# Same boilerplate (push detection, dir/branch resolution, protected-branch
# skip) is shared; only the per-platform API call differs.

input=$(cat)
suppress() { echo '{"suppressOutput": true}'; exit 0; }

COMMAND=$(echo "$input" | jq -r '.tool_input.command // empty' 2>/dev/null)
# Match `git push` as a standalone token after start, whitespace, or chain ops.
echo "$COMMAND" | grep -qE '(^|[[:space:]]|&&|\|\||;|\|)git[[:space:]]+push([[:space:]]|$)' || suppress

# Only act on successful pushes.
EXIT=$(echo "$input" | jq -r '.tool_response.exit_code // 0' 2>/dev/null)
[ "$EXIT" != "0" ] && suppress

# Resolve push directory: prefer `cd <path> && ...` prefix, fall back to session.cwd.
PUSH_DIR=""
if [[ "$COMMAND" =~ ^[[:space:]]*cd[[:space:]]+\"?([^[:space:]\"\&]+)\"?[[:space:]]*\&\& ]]; then
  PUSH_DIR="${BASH_REMATCH[1]}"
  PUSH_DIR="${PUSH_DIR/#\~/$HOME}"
fi
DIR="${PUSH_DIR:-$(echo "$input" | jq -r '.session.cwd // empty' 2>/dev/null)}"
[ -z "$DIR" ] && DIR="$(pwd)"

git -C "$DIR" rev-parse --git-dir > /dev/null 2>&1 || suppress

# Determine the branch being pushed. Parse from the command first (handles
# submodule/sibling-repo pushes); fall back to current branch.
BRANCH=$(echo "$COMMAND" | awk '
  {
    for (i=1; i<=NF; i++) {
      # Only treat "push" as a git-push command when preceded by "git". Without
      # this check, the word "push" appearing inside a commit message (e.g.,
      # "past push args and into the shell tail") gets parsed as if it were a
      # real `git push` and the next word ("args") gets extracted as the branch.
      if ($i == "push" && i > 1 && $(i-1) == "git") {
        for (j=i+1; j<=NF; j++) {
          arg=$j
          if (arg ~ /^-/) continue
          if (arg == "origin" || arg == "upstream") continue
          # Stop at chain ops (`&&`, `||`, `;`, `|`), redirections (`>`, `2>&1`,
          # `>/dev/null`, `&>`, etc.), backgrounding (`&`), or subshells (`(`,
          # `)`). Any token containing shell metacharacters cannot be a branch
          # name (git rejects these chars), so seeing one means we are past the
          # push args and into the shell tail — stop looking. Fixes a bug where
          # `git push 2>&1 | tail` had `2>&1` extracted as the branch name.
          if (arg ~ /[<>&;|()]/) next
          sub(/:.*$/, "", arg)
          print arg
          exit
        }
      }
    }
  }
')
[ -z "$BRANCH" ] && BRANCH=$(git -C "$DIR" branch --show-current 2>/dev/null)
[ -z "$BRANCH" ] && suppress

# Skip protected branches.
case "$BRANCH" in
  main|master|develop|release*) suppress ;;
esac

# Dispatch based on remote URL.
REMOTE_URL=$(git -C "$DIR" remote get-url origin 2>/dev/null)

case "$REMOTE_URL" in
  *gitlab*)
    command -v glab > /dev/null 2>&1 || suppress
    PROJECT=$(echo "$REMOTE_URL" | sed -E 's#^(https?://[^/]+/|git@[^:]+:)##; s#\.git$##')
    PROJECT_ENC=$(echo "$PROJECT" | sed 's#/#%2F#g')
    [ -z "$PROJECT_ENC" ] && suppress
    BRANCH_ENC=$(echo "$BRANCH" | sed 's#/#%2F#g')
    MR_COUNT=$(glab api "projects/${PROJECT_ENC}/merge_requests?source_branch=${BRANCH_ENC}&state=opened" 2>/dev/null \
      | jq 'length // 0' 2>/dev/null)
    if [ "${MR_COUNT:-0}" = "0" ]; then
      jq -n --arg branch "$BRANCH" --arg dir "$DIR" '{
        systemMessage: ("🚨 " + $branch + " pushed · no open MR"),
        hookSpecificOutput: {
          hookEventName: "PostToolUse",
          additionalContext: ("🚨 Branch [" + $branch + "] in " + $dir + " was pushed but has NO open merge request. Create one with `glab mr create` if this was not a draft/WIP push.")
        }
      }'
    else
      suppress
    fi
    ;;
  *github*)
    command -v gh > /dev/null 2>&1 || suppress
    # Parse owner/repo directly from REMOTE_URL — same approach as gitlab branch.
    # We must NOT use `gh repo view` here: gh resolves from the hook's cwd, not
    # $DIR. When pushing from a sub-repo while Claude's session cwd is elsewhere
    # (or in a different repo entirely), gh repo view returns the wrong/empty
    # repo, PR query returns empty, hook emits a false "no open PR" reminder.
    REPO=$(echo "$REMOTE_URL" | sed -E 's#^(https?://[^/]+/|git@[^:]+:)##; s#\.git$##')
    [ -z "$REPO" ] && suppress
    PR_COUNT=$(gh pr list --repo "$REPO" --head "$BRANCH" --state open --json number 2>/dev/null \
      | jq 'length // 0' 2>/dev/null)
    if [ "${PR_COUNT:-0}" = "0" ]; then
      jq -n --arg branch "$BRANCH" --arg dir "$DIR" '{
        systemMessage: ("🚨 " + $branch + " pushed · no open PR"),
        hookSpecificOutput: {
          hookEventName: "PostToolUse",
          additionalContext: ("🚨 Branch [" + $branch + "] in " + $dir + " was pushed but has NO open pull request. Create one with `gh pr create` if this was not a draft/WIP push.")
        }
      }'
    else
      suppress
    fi
    ;;
  *)
    # Unknown remote host (not gitlab, not github) — no MR/PR check to do.
    suppress
    ;;
esac
