#!/bin/bash
# Test helpers for shell scripts (hooks, skill scripts, any *.sh with testable behavior).
# Source from each *.test.sh:
#   source "$HOME/.claude/_lib/test-helpers.sh"
#   HOOK="$(_test_script_dir "$0")/my-script.sh"   # resolves to ABSOLUTE path
#   _require_executable "$HOOK"                    # fail loudly if missing
#   run_test "case name" 'shell command string' EXPECTED_EXIT_CODE
#   summary
#
# Conventions:
#   - Each test = one separate script invocation via stdin pipe. No shared state.
#   - $HOOK must be set by the caller before calling run_test*.
#   - Exit 0 from this file = all tests passed; non-zero = at least one failure.
#
# IMPORTANT: never write `HOOK="$(dirname "$0")/..."` directly — when `$0` is a
# relative path (`bash hooks/foo.test.sh`), HOOK becomes relative too, and any
# subshell that `cd`s into a tmpdir before invoking $HOOK gets a broken path.
# Use `_test_script_dir` which absolutizes via `cd && pwd`.

PASS=0
FAIL=0

# _test_script_dir SCRIPT_PATH
# Echoes the absolute dir containing SCRIPT_PATH. Call with "$0" from a test:
#   HOOK="$(_test_script_dir "$0")/foo.sh"
_test_script_dir() {
  ( cd "$(dirname "$1")" && pwd )
}

# _require_executable PATH
# Fails loudly (exit 1) if PATH is missing or not executable. Catches bad
# `$0` resolution before silent test failures pile up.
_require_executable() {
  local p="$1"
  if [ ! -x "$p" ]; then
    echo "FATAL: script under test not executable or missing: $p" >&2
    echo "  (likely cause: \$0 was relative; use _test_script_dir to absolutize)" >&2
    exit 1
  fi
}

# run_test NAME CMD EXPECTED_EXIT_CODE
# For PreToolUse Bash hooks: mocks tool_input.command and asserts hook exit code.
run_test() {
  local name="$1" cmd="$2" expected_rc="$3"
  local actual_rc
  actual_rc=$(jq -n --arg c "$cmd" '{tool_input:{command:$c}}' | "$HOOK" > /dev/null 2>&1; echo $?)
  if [ "$actual_rc" = "$expected_rc" ]; then
    echo "PASS: $name"
    PASS=$((PASS + 1))
  else
    echo "FAIL: $name (rc=$actual_rc, expected $expected_rc)"
    echo "       cmd: $cmd"
    FAIL=$((FAIL + 1))
  fi
}

# run_test_content NAME CONTENT TOOL_NAME EXPECTED_EXIT_CODE
# For PreToolUse Edit/Write hooks: mocks tool_input.new_string (and .content) + tool_name.
run_test_content() {
  local name="$1" content="$2" tool="$3" expected_rc="$4"
  local actual_rc
  actual_rc=$(jq -n --arg c "$content" --arg t "$tool" '{tool_name:$t,tool_input:{new_string:$c,content:$c}}' | "$HOOK" > /dev/null 2>&1; echo $?)
  if [ "$actual_rc" = "$expected_rc" ]; then
    echo "PASS: $name"
    PASS=$((PASS + 1))
  else
    echo "FAIL: $name (rc=$actual_rc, expected $expected_rc)"
    FAIL=$((FAIL + 1))
  fi
}

# run_test_stdout NAME CMD TOOL_NAME PATTERN EXPECT_MATCH
# For hooks that emit additionalContext (don't change exit code but emit JSON on stdout):
# - EXPECT_MATCH=yes → PATTERN must appear in stdout
# - EXPECT_MATCH=no  → PATTERN must NOT appear in stdout
run_test_stdout() {
  local name="$1" content="$2" tool="$3" pattern="$4" expect_match="$5"
  local stdout
  stdout=$(jq -n --arg c "$content" --arg t "$tool" '{tool_name:$t,tool_input:{new_string:$c,content:$c}}' | "$HOOK" 2>/dev/null)
  if [ "$expect_match" = "yes" ]; then
    if echo "$stdout" | grep -q "$pattern"; then
      echo "PASS: $name (emitted '$pattern')"
      PASS=$((PASS + 1))
    else
      echo "FAIL: $name (expected '$pattern' in stdout, got: $stdout)"
      FAIL=$((FAIL + 1))
    fi
  else
    if echo "$stdout" | grep -q "$pattern"; then
      echo "FAIL: $name (false-positive: '$pattern' in stdout: $stdout)"
      FAIL=$((FAIL + 1))
    else
      echo "PASS: $name (no '$pattern' emitted)"
      PASS=$((PASS + 1))
    fi
  fi
}

summary() {
  echo "---"
  echo "$PASS passed, $FAIL failed"
  [ "$FAIL" = 0 ]
}

# mock_git_repo REMOTE_URL
# Creates a temp git dir with the given remote URL set on origin.
# Echoes the temp dir path. Caller is responsible for `rm -rf` on cleanup.
mock_git_repo() {
  local remote="$1"
  local dir
  dir=$(mktemp -d)
  ( cd "$dir" && git init -q && git remote add origin "$remote" )
  echo "$dir"
}
