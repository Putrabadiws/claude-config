#!/bin/bash
# Tests for session-context.sh — SessionStart hook, emits environment context.
# The hook reads cwd via $PWD (process cwd) for some git detection and writes
# ~/.claude/.session-env. To avoid clobbering the real file, we don't actually
# invoke the side-effect path; we focus on output shape.
# Run: bash ~/.claude/hooks/session-context.test.sh

source "$HOME/.claude/_lib/test-helpers.sh"
HOOK="$(_test_script_dir "$0")/session-context.sh"
_require_executable "$HOOK"

# Wrapper: invoke hook in a subshell from a chosen cwd, capture stdout.
invoke_in_dir() {
  local dir="$1"
  local sid="$2"
  ( cd "$dir" && jq -n --arg sid "$sid" '{session_id:$sid,source:"startup"}' | "$HOOK" 2>/dev/null )
}

# Test 1: produces valid JSON with hookSpecificOutput.additionalContext
tmp=$(mktemp -d)
out=$(invoke_in_dir "$tmp" "test-$$-1")
rm -rf "$tmp"
if echo "$out" | jq -e '.hookSpecificOutput.additionalContext' > /dev/null 2>&1; then
  echo "PASS: emits valid JSON with additionalContext"; PASS=$((PASS + 1))
else
  echo "FAIL: invalid JSON output: $out"; FAIL=$((FAIL + 1))
fi

# Test 2: context string mentions Environment:
tmp=$(mktemp -d)
out=$(invoke_in_dir "$tmp" "test-$$-2")
rm -rf "$tmp"
if echo "$out" | jq -r '.hookSpecificOutput.additionalContext' 2>/dev/null | grep -q "Environment:"; then
  echo "PASS: context includes Environment: prefix"; PASS=$((PASS + 1))
else
  echo "FAIL: missing Environment: in output"; FAIL=$((FAIL + 1))
fi

# Test 3: detects node project when package.json present
tmp=$(mktemp -d)
echo '{}' > "$tmp/package.json"
out=$(invoke_in_dir "$tmp" "test-$$-3")
rm -rf "$tmp"
if echo "$out" | jq -r '.hookSpecificOutput.additionalContext' 2>/dev/null | grep -q "project=node"; then
  echo "PASS: detects node project"; PASS=$((PASS + 1))
else
  echo "FAIL: should report project=node"; FAIL=$((FAIL + 1))
fi

# Test 4: detects go project when go.mod present
tmp=$(mktemp -d)
echo 'module x' > "$tmp/go.mod"
out=$(invoke_in_dir "$tmp" "test-$$-4")
rm -rf "$tmp"
if echo "$out" | jq -r '.hookSpecificOutput.additionalContext' 2>/dev/null | grep -q "project=go"; then
  echo "PASS: detects go project"; PASS=$((PASS + 1))
else
  echo "FAIL: should report project=go"; FAIL=$((FAIL + 1))
fi

# Test 5: branch detection in git repo
tmp=$(mock_git_repo "https://gitlab.com/foo/bar.git")
( cd "$tmp" && git checkout -q -b feature/test 2>/dev/null || true ) > /dev/null 2>&1
out=$(invoke_in_dir "$tmp" "test-$$-5")
rm -rf "$tmp" "/tmp/gitlab-rules-injected-test-$$-5"
ctx=$(echo "$out" | jq -r '.hookSpecificOutput.additionalContext' 2>/dev/null)
if echo "$ctx" | grep -q "branch="; then
  echo "PASS: includes git branch info"; PASS=$((PASS + 1))
else
  echo "FAIL: missing branch info"; FAIL=$((FAIL + 1))
fi

# Edge: empty input (no session_id) — still emits some context
tmp=$(mktemp -d)
out=$(cd "$tmp" && echo '{}' | "$HOOK" 2>/dev/null)
rm -rf "$tmp"
if echo "$out" | jq -e '.hookSpecificOutput' > /dev/null 2>&1; then
  echo "PASS: handles empty session_id"; PASS=$((PASS + 1))
else
  echo "FAIL: should still emit JSON even without session_id"; FAIL=$((FAIL + 1))
fi

# systemMessage present + leads with "🧭 k8s:" label (added in output rework)
tmp=$(mktemp -d)
out=$(invoke_in_dir "$tmp" "test-$$-sm")
rm -rf "$tmp"
if echo "$out" | jq -e '.systemMessage' > /dev/null 2>&1; then
  echo "PASS: emits systemMessage"; PASS=$((PASS + 1))
else
  echo "FAIL: missing systemMessage: $out"; FAIL=$((FAIL + 1))
fi
sm=$(echo "$out" | jq -r '.systemMessage' 2>/dev/null)
case "$sm" in
  "🧭 k8s:"*) echo "PASS: systemMessage leads with 🧭 k8s: label"; PASS=$((PASS + 1)) ;;
  *) echo "FAIL: systemMessage should start with '🧭 k8s:', got: $sm"; FAIL=$((FAIL + 1)) ;;
esac

summary
