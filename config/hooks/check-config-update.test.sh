#!/bin/bash
# Tests for check-config-update.sh — SessionStart hook checking for new commits
# on origin/main of the team config repo. Uses HOME-redirected fake state.
# Run: bash ~/.claude/hooks/check-config-update.test.sh

source "$HOME/.claude/_lib/test-helpers.sh"
HOOK="$(_test_script_dir "$0")/check-config-update.sh"
_require_executable "$HOOK"

# Helper: invoke with fake HOME so we don't touch real state files.
invoke_in_fake_home() {
  local fake_home="$1"
  HOME="$fake_home" echo '{}' | HOME="$fake_home" "$HOOK" 2>/dev/null
}

# Test 1: no .config-repo-path file → suppressOutput (not onboarded)
tmp=$(mktemp -d)
mkdir -p "$tmp/.claude"
out=$(invoke_in_fake_home "$tmp")
rm -rf "$tmp"
if echo "$out" | grep -q "suppressOutput"; then
  echo "PASS: not onboarded → suppressOutput"; PASS=$((PASS + 1))
else
  echo "FAIL: should suppress when not onboarded"; FAIL=$((FAIL + 1))
fi

# Test 2: .config-repo-path points to non-git dir → suppressOutput
tmp=$(mktemp -d)
mkdir -p "$tmp/.claude"
echo "/tmp/not-a-git-repo-$$" > "$tmp/.claude/.config-repo-path"
out=$(invoke_in_fake_home "$tmp")
rm -rf "$tmp"
if echo "$out" | grep -q "suppressOutput"; then
  echo "PASS: missing repo dir → suppressOutput"; PASS=$((PASS + 1))
else
  echo "FAIL: should suppress when repo dir invalid"; FAIL=$((FAIL + 1))
fi

# Test 3: within 24h cooldown → suppressOutput
tmp=$(mktemp -d)
mkdir -p "$tmp/.claude"
fake_repo=$(mktemp -d)
( cd "$fake_repo" && git init -q ) > /dev/null
echo "$fake_repo" > "$tmp/.claude/.config-repo-path"
echo "$(date +%s)" > "$tmp/.claude/.config-last-check"
out=$(invoke_in_fake_home "$tmp")
rm -rf "$tmp" "$fake_repo"
if echo "$out" | grep -q "suppressOutput"; then
  echo "PASS: within cooldown → suppressOutput"; PASS=$((PASS + 1))
else
  echo "FAIL: should suppress within cooldown"; FAIL=$((FAIL + 1))
fi

# Test 4: cooldown expired but fetch fails (no remote) → suppressOutput
tmp=$(mktemp -d)
mkdir -p "$tmp/.claude"
fake_repo=$(mktemp -d)
( cd "$fake_repo" && git init -q ) > /dev/null
echo "$fake_repo" > "$tmp/.claude/.config-repo-path"
# Set last-check to 25h ago
echo "$(( $(date +%s) - 25 * 3600 ))" > "$tmp/.claude/.config-last-check"
out=$(invoke_in_fake_home "$tmp")
rm -rf "$tmp" "$fake_repo"
if echo "$out" | grep -q "suppressOutput"; then
  echo "PASS: fetch failure → suppressOutput"; PASS=$((PASS + 1))
else
  echo "FAIL: failed fetch should suppress, got: $out"; FAIL=$((FAIL + 1))
fi

# Test 5: edge — empty input still produces valid JSON
tmp=$(mktemp -d)
mkdir -p "$tmp/.claude"
out=$(invoke_in_fake_home "$tmp")
rm -rf "$tmp"
if echo "$out" | jq -e . > /dev/null 2>&1; then
  echo "PASS: emits valid JSON"; PASS=$((PASS + 1))
else
  echo "FAIL: invalid JSON output"; FAIL=$((FAIL + 1))
fi

summary
