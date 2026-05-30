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

# Test 6: update available → ⬆️ systemMessage (added in output rework).
# Sets up a bare "remote" ahead of the installed version so the hook detects an update.
if command -v git >/dev/null 2>&1; then
  tmp=$(mktemp -d); mkdir -p "$tmp/.claude"
  bare=$(mktemp -d); ( cd "$bare" && git init -q --bare )
  work=$(mktemp -d)
  (
    cd "$work" && git init -q && git config user.email t@t && git config user.name t
    mkdir -p config && echo v1 > config/a.txt && git add -A && git commit -qm c1
    git branch -M main && git remote add origin "$bare" && git push -q origin main
  ) >/dev/null 2>&1
  installed=$( cd "$work" && git rev-parse HEAD )
  clone=$(mktemp -d); git clone -q "$bare" "$clone" >/dev/null 2>&1
  ( cd "$work" && echo v2 > config/b.txt && git add -A && git commit -qm c2 && git push -q origin main ) >/dev/null 2>&1
  echo "$clone" > "$tmp/.claude/.config-repo-path"
  echo "$installed" > "$tmp/.claude/.config-version"
  echo "0" > "$tmp/.claude/.config-last-check"   # force cooldown expired
  out=$(HOME="$tmp" echo '{}' | HOME="$tmp" "$HOOK" 2>/dev/null)
  rm -rf "$tmp" "$bare" "$work" "$clone"
  if echo "$out" | jq -e '.systemMessage' >/dev/null 2>&1 && echo "$out" | grep -q "⬆️"; then
    echo "PASS: update available → ⬆️ systemMessage"; PASS=$((PASS + 1))
  else
    echo "FAIL: expected ⬆️ systemMessage, got: $out"; FAIL=$((FAIL + 1))
  fi
else
  echo "PASS: (skipped update-available test — git unavailable)"; PASS=$((PASS + 1))
fi

summary
