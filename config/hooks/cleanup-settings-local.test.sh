#!/bin/bash
# Tests for cleanup-settings-local.sh
# The hook removes .claude/settings.local.json from the cwd. Test by running
# in a tempdir with controlled state.
# Run: bash ~/.claude/hooks/cleanup-settings-local.test.sh

source "$HOME/.claude/_lib/test-helpers.sh"
HOOK="$(_test_script_dir "$0")/cleanup-settings-local.sh"
_require_executable "$HOOK"

# Test: file exists → should be removed
tmp=$(mktemp -d)
mkdir -p "$tmp/.claude"
echo '{"foo":"bar"}' > "$tmp/.claude/settings.local.json"
( cd "$tmp" && echo '{}' | "$HOOK" > /dev/null 2>&1 )
if [ ! -f "$tmp/.claude/settings.local.json" ]; then
  echo "PASS: removes existing settings.local.json"; PASS=$((PASS + 1))
else
  echo "FAIL: file should have been removed"; FAIL=$((FAIL + 1))
fi
rm -rf "$tmp"

# Test: file absent → should exit cleanly
tmp=$(mktemp -d)
mkdir -p "$tmp/.claude"
( cd "$tmp" && echo '{}' | "$HOOK" > /dev/null 2>&1 )
rc=$?
if [ "$rc" = "0" ]; then
  echo "PASS: exits cleanly when no file"; PASS=$((PASS + 1))
else
  echo "FAIL: should exit 0, got $rc"; FAIL=$((FAIL + 1))
fi
rm -rf "$tmp"

# Test: .claude dir doesn't exist → still exits cleanly
tmp=$(mktemp -d)
( cd "$tmp" && echo '{}' | "$HOOK" > /dev/null 2>&1 )
rc=$?
if [ "$rc" = "0" ]; then
  echo "PASS: exits cleanly when .claude/ missing"; PASS=$((PASS + 1))
else
  echo "FAIL: should exit 0, got $rc"; FAIL=$((FAIL + 1))
fi
rm -rf "$tmp"

# Test: cwd has unrelated .claude files → those are untouched
tmp=$(mktemp -d)
mkdir -p "$tmp/.claude"
echo 'project config' > "$tmp/.claude/settings.json"
echo 'local override' > "$tmp/.claude/settings.local.json"
( cd "$tmp" && echo '{}' | "$HOOK" > /dev/null 2>&1 )
if [ -f "$tmp/.claude/settings.json" ] && [ ! -f "$tmp/.claude/settings.local.json" ]; then
  echo "PASS: only settings.local.json removed, settings.json kept"; PASS=$((PASS + 1))
else
  echo "FAIL: wrong file affected"; FAIL=$((FAIL + 1))
fi
rm -rf "$tmp"

# Edge: cwd outside any project (no .claude dir, no setup)
tmp=$(mktemp -d)
( cd "$tmp" && echo '{}' | "$HOOK" > /dev/null 2>&1 )
rc=$?
if [ "$rc" = "0" ]; then
  echo "PASS: edge — runs cleanly in unrelated dir"; PASS=$((PASS + 1))
else
  echo "FAIL: edge — should exit 0"; FAIL=$((FAIL + 1))
fi
rm -rf "$tmp"

summary
