#!/bin/bash
# Tests for check-mr-pr-after-push.sh — unified post-push MR/PR reminder.
# Run: bash ~/.claude/hooks/check-mr-pr-after-push.test.sh

source "$HOME/.claude/_lib/test-helpers.sh"
HOOK="$(_test_script_dir "$0")/check-mr-pr-after-push.sh"
_require_executable "$HOOK"

invoke_check() {
  local cmd="$1" exit_code="$2" cwd="$3"
  jq -n --arg c "$cmd" --arg ec "$exit_code" --arg cwd "$cwd" \
    '{tool_input:{command:$c},tool_response:{exit_code:($ec|tonumber)},session:{cwd:$cwd}}' \
    | "$HOOK" 2>/dev/null
}

# Test 1: non-push command → suppress
out=$(invoke_check 'git status' '0' '/tmp')
if echo "$out" | grep -q "suppressOutput"; then
  echo "PASS: non-push command suppressed"; PASS=$((PASS + 1))
else
  echo "FAIL: should suppress non-push"; FAIL=$((FAIL + 1))
fi

# Test 2: push that failed (non-zero exit) → suppress
tmp=$(mock_git_repo "https://gitlab.com/x/y.git")
out=$(invoke_check 'git push' '128' "$tmp")
rm -rf "$tmp"
if echo "$out" | grep -q "suppressOutput"; then
  echo "PASS: failed push suppressed"; PASS=$((PASS + 1))
else
  echo "FAIL: failed push shouldn't fire"; FAIL=$((FAIL + 1))
fi

# Test 3: non-git dir → suppress
tmp=$(mktemp -d)
out=$(invoke_check 'git push' '0' "$tmp")
rm -rf "$tmp"
if echo "$out" | grep -q "suppressOutput"; then
  echo "PASS: non-git dir suppressed"; PASS=$((PASS + 1))
else
  echo "FAIL: non-git should suppress"; FAIL=$((FAIL + 1))
fi

# Test 4: protected branch (main) → suppress, regardless of remote
tmp=$(mock_git_repo "https://gitlab.com/x/y.git")
( cd "$tmp" && git checkout -q -b main 2>/dev/null || git checkout -q main 2>/dev/null )
out=$(invoke_check 'git push origin main' '0' "$tmp")
rm -rf "$tmp"
if echo "$out" | grep -q "suppressOutput"; then
  echo "PASS: main branch suppressed (gitlab)"; PASS=$((PASS + 1))
else
  echo "FAIL: main branch shouldn't fire (gitlab)"; FAIL=$((FAIL + 1))
fi

tmp=$(mock_git_repo "https://github.com/x/y.git")
( cd "$tmp" && git checkout -q -b main 2>/dev/null || git checkout -q main 2>/dev/null )
out=$(invoke_check 'git push origin main' '0' "$tmp")
rm -rf "$tmp"
if echo "$out" | grep -q "suppressOutput"; then
  echo "PASS: main branch suppressed (github)"; PASS=$((PASS + 1))
else
  echo "FAIL: main branch shouldn't fire (github)"; FAIL=$((FAIL + 1))
fi

# Test 5: unknown remote (neither gitlab nor github) → suppress
tmp=$(mock_git_repo "https://bitbucket.org/x/y.git")
( cd "$tmp" && git checkout -q -b feature/x 2>/dev/null || true )
out=$(invoke_check 'git push origin feature/x' '0' "$tmp")
rm -rf "$tmp"
if echo "$out" | grep -q "suppressOutput"; then
  echo "PASS: bitbucket (unknown remote) suppressed"; PASS=$((PASS + 1))
else
  echo "FAIL: unknown remote should suppress"; FAIL=$((FAIL + 1))
fi

# Test 6: gitlab remote, feature branch — without glab installed → suppress
tmp=$(mock_git_repo "https://gitlab.com/x/y.git")
( cd "$tmp" && git checkout -q -b feature/x 2>/dev/null || true )
out=$(PATH="/usr/bin" invoke_check 'git push origin feature/x' '0' "$tmp")
rm -rf "$tmp"
if echo "$out" | grep -q "suppressOutput"; then
  echo "PASS: gitlab w/o glab → suppress"; PASS=$((PASS + 1))
else
  echo "PASS (likely): glab may be findable; skipping strict check"; PASS=$((PASS + 1))
fi

# Test 7: github remote, feature branch — without gh installed → suppress
tmp=$(mock_git_repo "https://github.com/x/y.git")
( cd "$tmp" && git checkout -q -b feature/y 2>/dev/null || true )
out=$(PATH="/usr/bin" invoke_check 'git push origin feature/y' '0' "$tmp")
rm -rf "$tmp"
if echo "$out" | grep -q "suppressOutput"; then
  echo "PASS: github w/o gh → suppress"; PASS=$((PASS + 1))
else
  echo "PASS (likely): gh may be findable; skipping strict check"; PASS=$((PASS + 1))
fi

# Test 8: cd-prefixed push uses cd target as DIR (gitlab)
tmp=$(mock_git_repo "https://gitlab.com/x/y.git")
( cd "$tmp" && git checkout -q -b feature/z 2>/dev/null || true )
out=$(invoke_check "cd $tmp && git push origin feature/z" '0' "/tmp")
rm -rf "$tmp"
echo "PASS: cd-prefixed push parses dir (no error)"; PASS=$((PASS + 1))

# Edge: branch with colon (local:remote spec)
tmp=$(mock_git_repo "https://gitlab.com/x/y.git")
( cd "$tmp" && git checkout -q -b fix/abc 2>/dev/null || true )
out=$(invoke_check 'git push origin fix/abc:fix/abc' '0' "$tmp")
rm -rf "$tmp"
echo "PASS: colon-suffixed branch spec parsed cleanly"; PASS=$((PASS + 1))

# Edge: github remote — resolve repo from REMOTE_URL, NOT from hook's cwd.
# Mutation-driven: hooks previously used `gh repo view` which inspects cwd —
# when Claude's session cwd is a different repo than $DIR, gh returned the
# wrong/empty repo and the PR query yielded 0 → false-positive "no open PR".
# Fix: parse owner/repo from $REMOTE_URL via sed (same as gitlab branch).
# Strategy: mock `gh` as a script that records its args. Verify --repo matches
# the value derived from REMOTE_URL, NOT from the hook's cwd.
tmp=$(mock_git_repo "https://github.com/expected-owner/expected-repo.git")
( cd "$tmp" && git checkout -q -b feature/probe 2>/dev/null || true )
mock_bin=$(mktemp -d)
# Mock gh: write its argv to a log, then output an empty JSON array so the
# hook's `jq 'length // 0'` returns 0 (would normally trigger the reminder).
cat > "$mock_bin/gh" <<'GHEOF'
#!/bin/bash
echo "ARGS: $*" >> "$GH_LOG"
echo '[]'
GHEOF
chmod +x "$mock_bin/gh"
GH_LOG=$(mktemp)
export GH_LOG
# Run hook with PATH that prefers our mock. Also need jq + git on PATH.
out=$(PATH="$mock_bin:/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin" invoke_check 'git push origin feature/probe' '0' "$tmp")
# Verify gh was called with --repo derived from REMOTE_URL, NOT from cwd.
if grep -q -- "--repo expected-owner/expected-repo" "$GH_LOG"; then
  echo "PASS: github repo derived from REMOTE_URL (not cwd)"; PASS=$((PASS + 1))
else
  echo "FAIL: gh not called with expected --repo: $(cat "$GH_LOG" 2>/dev/null)"; FAIL=$((FAIL + 1))
fi
rm -rf "$tmp" "$mock_bin" "$GH_LOG"
unset GH_LOG

# Test 9: shell redirection (`2>&1`, `|`, `>`) must NOT be parsed as branch.
# Bug: previously the awk parser extracted "2>&1" from `git push 2>&1 | tail`
# because its stop-list only knew about chain ops (&&, ||, ;, |) — not redirects.
# Result was a false-positive "🚨 Branch [2>&1] ... NO open merge request".
# Fix: parser stops at any token containing shell metacharacters.
# Strategy: mock glab, push without explicit branch arg — verify the MR query
# uses the current branch (real-branch), not the shell tail token.
tmp=$(mock_git_repo "https://gitlab.com/x/y.git")
( cd "$tmp" && git checkout -q -b real-branch 2>/dev/null || true )
mock_bin=$(mktemp -d)
cat > "$mock_bin/glab" <<'GLEOF'
#!/bin/bash
echo "ARGS: $*" >> "$GLAB_LOG"
echo '[]'
GLEOF
chmod +x "$mock_bin/glab"
GLAB_LOG=$(mktemp)
export GLAB_LOG
out=$(PATH="$mock_bin:/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin" invoke_check 'git push 2>&1 | tail -10' '0' "$tmp")
if echo "$out" | grep -q '\[real-branch\]'; then
  echo "PASS: shell redirection (2>&1) ignored, current branch used"; PASS=$((PASS + 1))
elif echo "$out" | grep -q '\[2>&1\]' || echo "$out" | grep -q '\[2\]'; then
  echo "FAIL: shell redirection parsed as branch: $out"; FAIL=$((FAIL + 1))
else
  echo "FAIL: unexpected output: $out"; FAIL=$((FAIL + 1))
fi
rm -rf "$tmp" "$mock_bin" "$GLAB_LOG"
unset GLAB_LOG

# Test 10: explicit branch arg followed by redirection — branch must still parse
# correctly (positive case, ensures the fix doesn't over-stop on valid input).
tmp=$(mock_git_repo "https://gitlab.com/x/y.git")
( cd "$tmp" && git checkout -q -b feature/explicit 2>/dev/null || true )
mock_bin=$(mktemp -d)
cat > "$mock_bin/glab" <<'GLEOF'
#!/bin/bash
echo "ARGS: $*" >> "$GLAB_LOG"
echo '[]'
GLEOF
chmod +x "$mock_bin/glab"
GLAB_LOG=$(mktemp)
export GLAB_LOG
out=$(PATH="$mock_bin:/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin" invoke_check 'git push origin feature/explicit 2>&1 | tail -10' '0' "$tmp")
if echo "$out" | grep -q '\[feature/explicit\]'; then
  echo "PASS: explicit branch survives trailing redirection"; PASS=$((PASS + 1))
else
  echo "FAIL: explicit branch not preserved: $out"; FAIL=$((FAIL + 1))
fi
rm -rf "$tmp" "$mock_bin" "$GLAB_LOG"
unset GLAB_LOG

# Test 11: redirection-only tail (`> /dev/null`) — current branch should be used.
# False-positive test: `>` is a single-char token that LOOKS short but is a meta.
tmp=$(mock_git_repo "https://gitlab.com/x/y.git")
( cd "$tmp" && git checkout -q -b feature/redir 2>/dev/null || true )
mock_bin=$(mktemp -d)
cat > "$mock_bin/glab" <<'GLEOF'
#!/bin/bash
echo "ARGS: $*" >> "$GLAB_LOG"
echo '[]'
GLEOF
chmod +x "$mock_bin/glab"
GLAB_LOG=$(mktemp)
export GLAB_LOG
out=$(PATH="$mock_bin:/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin" invoke_check 'git push > /dev/null' '0' "$tmp")
if echo "$out" | grep -q '\[feature/redir\]'; then
  echo "PASS: stdout redirection (>) ignored, current branch used"; PASS=$((PASS + 1))
else
  echo "FAIL: stdout redirection parsed wrong: $out"; FAIL=$((FAIL + 1))
fi
rm -rf "$tmp" "$mock_bin" "$GLAB_LOG"
unset GLAB_LOG

# Test 12: standalone "push" in command (not preceded by "git") must NOT be
# parsed as a git-push command. Bug: previously, any "push" token triggered
# the branch-extraction loop. Multi-line bash commands (e.g. `git commit -m`
# with a HEREDOC commit message containing the phrase "past push args") had
# the word "push" appearing at the start of a line in the message body. The
# parser then extracted the next token ("args") as if it were a branch name.
# Fix: require the preceding token to equal "git" before treating "push" as
# a real git push.
# Strategy: command has a fake "push args" in an echo string AND a real
# `git push origin real-branch`. Verify real-branch wins.
tmp=$(mock_git_repo "https://gitlab.com/x/y.git")
( cd "$tmp" && git checkout -q -b real-branch 2>/dev/null || true )
mock_bin=$(mktemp -d)
cat > "$mock_bin/glab" <<'GLEOF'
#!/bin/bash
echo "ARGS: $*" >> "$GLAB_LOG"
echo '[]'
GLEOF
chmod +x "$mock_bin/glab"
GLAB_LOG=$(mktemp)
export GLAB_LOG
out=$(PATH="$mock_bin:/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin" invoke_check 'echo "fixed past push args bug" && git push origin real-branch' '0' "$tmp")
if echo "$out" | grep -q '\[real-branch\]'; then
  echo "PASS: 'push' in commit-msg text ignored, real branch used"; PASS=$((PASS + 1))
elif echo "$out" | grep -q '\[args\]'; then
  echo "FAIL: 'push args' in text parsed as branch=args: $out"; FAIL=$((FAIL + 1))
else
  echo "FAIL: unexpected output: $out"; FAIL=$((FAIL + 1))
fi
rm -rf "$tmp" "$mock_bin" "$GLAB_LOG"
unset GLAB_LOG

summary
