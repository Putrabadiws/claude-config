#!/bin/bash
# Tests for gitlab-github-context.sh — unified context-injection hook.
# Run: bash ~/.claude/hooks/gitlab-github-context.test.sh

source "$HOME/.claude/_lib/test-helpers.sh"
HOOK="$(_test_script_dir "$0")/gitlab-github-context.sh"
_require_executable "$HOOK"

run_context_case() {
  local name="$1" remote_url="$2" expect_fires="$3"
  local sid="test-ctx-$$-$RANDOM"
  local dir
  if [ -n "$remote_url" ] && [ "$remote_url" != "_no_remote_" ]; then
    dir=$(mock_git_repo "$remote_url")
  elif [ "$remote_url" = "_no_remote_" ]; then
    dir=$(mktemp -d); ( cd "$dir" && git init -q ) > /dev/null
  else
    dir=$(mktemp -d)  # not even a git repo
  fi

  local stdout
  stdout=$(jq -n --arg cwd "$dir" --arg sid "$sid" '{cwd:$cwd,session_id:$sid,tool_input:{command:""}}' | "$HOOK" 2>/dev/null)

  rm -rf "$dir" "/tmp/gitlab-rules-injected-${sid}" "/tmp/github-rules-injected-${sid}"

  local fired=no
  echo "$stdout" | grep -q "additionalContext" && fired=yes

  if [ "$fired" = "$expect_fires" ]; then
    echo "PASS: $name"; PASS=$((PASS + 1))
  else
    echo "FAIL: $name (expected fires=$expect_fires, got=$fired)"; FAIL=$((FAIL + 1))
  fi
}

# No-fire cases
run_context_case "no cwd, no command"                       ""                                       no
run_context_case "non-git dir"                              "_non_git_"                              no
run_context_case "git repo, no remote"                      "_no_remote_"                            no
run_context_case "bitbucket remote (unknown host)"          "https://bitbucket.org/foo/bar.git"      no

# Fire cases — gitlab
run_context_case "gitlab https"                             "https://gitlab.com/foo/bar.git"         yes
run_context_case "gitlab ssh"                               "git@gitlab.com:foo/bar.git"             yes
run_context_case "self-hosted gitlab"                       "http://gitlab.dev.example/foo/bar.git"  yes

# Fire cases — github
run_context_case "github https"                             "https://github.com/foo/bar.git"        yes
run_context_case "github ssh"                               "git@github.com:foo/bar.git"            yes
run_context_case "github enterprise"                        "https://github.acme.com/foo/bar.git"   yes

# Flag suppression
sid="test-ctx-suppressed-gitlab"
dir=$(mock_git_repo "https://gitlab.com/foo/bar.git")
touch "/tmp/gitlab-rules-injected-${sid}"
stdout=$(jq -n --arg cwd "$dir" --arg sid "$sid" '{cwd:$cwd,session_id:$sid,tool_input:{command:""}}' | "$HOOK" 2>/dev/null)
rm -rf "$dir" "/tmp/gitlab-rules-injected-${sid}"
if echo "$stdout" | grep -q "additionalContext"; then
  echo "FAIL: flagged gitlab session should suppress"; FAIL=$((FAIL + 1))
else
  echo "PASS: flagged gitlab session → suppressed"; PASS=$((PASS + 1))
fi

sid="test-ctx-suppressed-github"
dir=$(mock_git_repo "https://github.com/foo/bar.git")
touch "/tmp/github-rules-injected-${sid}"
stdout=$(jq -n --arg cwd "$dir" --arg sid "$sid" '{cwd:$cwd,session_id:$sid,tool_input:{command:""}}' | "$HOOK" 2>/dev/null)
rm -rf "$dir" "/tmp/github-rules-injected-${sid}"
if echo "$stdout" | grep -q "additionalContext"; then
  echo "FAIL: flagged github session should suppress"; FAIL=$((FAIL + 1))
else
  echo "PASS: flagged github session → suppressed"; PASS=$((PASS + 1))
fi

# cd target detection
sid="test-ctx-cdtarget"
dir=$(mock_git_repo "https://gitlab.com/foo/bar.git")
stdout=$(jq -n --arg cwd "/tmp" --arg sid "$sid" --arg cmd "cd $dir && git status" '{cwd:$cwd,session_id:$sid,tool_input:{command:$cmd}}' | "$HOOK" 2>/dev/null)
rm -rf "$dir" "/tmp/gitlab-rules-injected-${sid}"
if echo "$stdout" | grep -q "additionalContext"; then
  echo "PASS: cd target detected (overrides cwd)"; PASS=$((PASS + 1))
else
  echo "FAIL: cd target should be used over cwd"; FAIL=$((FAIL + 1))
fi

# systemMessage on fire (added in output rework)
sid="test-ctx-sm-$$"
dir=$(mock_git_repo "https://gitlab.com/foo/bar.git")
stdout=$(jq -n --arg cwd "$dir" --arg sid "$sid" '{cwd:$cwd,session_id:$sid,tool_input:{command:""}}' | "$HOOK" 2>/dev/null)
rm -rf "$dir" "/tmp/gitlab-rules-injected-${sid}"
if echo "$stdout" | jq -e '.systemMessage' >/dev/null 2>&1 && echo "$stdout" | grep -q "GitLab rules loaded"; then
  echo "PASS: emits '📚 GitLab rules loaded' systemMessage"; PASS=$((PASS + 1))
else
  echo "FAIL: expected GitLab systemMessage, got: $stdout"; FAIL=$((FAIL + 1))
fi

# Submodule / worktree: .git is a FILE (gitlink), not a dir — must still fire.
# `git init --separate-git-dir` reproduces exactly that layout.
realgit=$(mktemp -d); work=$(mktemp -d)
( cd "$work" && git init -q --separate-git-dir="$realgit" && git remote add origin "https://gitlab.com/foo/bar.git" ) >/dev/null 2>&1
sid="test-ctx-submodule-$$"
stdout=$(jq -n --arg cwd "$work" --arg sid "$sid" '{cwd:$cwd,session_id:$sid,tool_input:{command:""}}' | "$HOOK" 2>/dev/null)
gitfile_kind=$( [ -f "$work/.git" ] && echo file || echo other )
rm -rf "$work" "$realgit" "/tmp/gitlab-rules-injected-${sid}"
if [ "$gitfile_kind" = file ] && echo "$stdout" | grep -q "GitLab rules loaded"; then
  echo "PASS: submodule (.git is a file) still fires"; PASS=$((PASS + 1))
else
  echo "FAIL: submodule .git-as-file should fire (gitkind=$gitfile_kind), got: $stdout"; FAIL=$((FAIL + 1))
fi

summary
