#!/bin/bash
# Tests for require-tests.sh
# The hook reads `git diff --cached --name-only` from cwd, so each test runs
# inside a temp git repo with controlled staged content.
# Run: bash ~/.claude/hooks/require-tests.test.sh

source "$HOME/.claude/_lib/test-helpers.sh"
HOOK="$(_test_script_dir "$0")/require-tests.sh"
_require_executable "$HOOK"

# Helper: create a git repo, stage the given files (with placeholder content), then
# invoke the hook with `git commit` and assert exit code.
run_require_tests_case() {
  local name="$1"
  local expected_rc="$2"
  shift 2
  local files=("$@")

  local tmp
  tmp=$(mktemp -d)
  ( cd "$tmp" && git init -q && git config user.email t@t && git config user.name t ) > /dev/null 2>&1
  for f in "${files[@]}"; do
    mkdir -p "$(dirname "$tmp/$f")"
    echo "// stub" > "$tmp/$f"
    ( cd "$tmp" && git add "$f" ) > /dev/null 2>&1
  done

  local actual_rc
  actual_rc=$(cd "$tmp" && jq -n --arg c 'git commit -m "test"' '{tool_input:{command:$c}}' | "$HOOK" > /dev/null 2>&1; echo $?)
  rm -rf "$tmp"

  if [ "$actual_rc" = "$expected_rc" ]; then
    echo "PASS: $name"; PASS=$((PASS + 1))
  else
    echo "FAIL: $name (rc=$actual_rc, expected $expected_rc)"; FAIL=$((FAIL + 1))
  fi
}

# Allow-cases (must NOT block, rc=0)
run_require_tests_case "no source files staged (docs only)"        0  README.md
run_require_tests_case "Go source with test file"                  0  pkg/foo.go pkg/foo_test.go
run_require_tests_case "TS source with .test.ts"                   0  src/foo.ts src/foo.test.ts
run_require_tests_case "Python source with test_ prefix"           0  app/foo.py app/test_foo.py
run_require_tests_case "Java source under src/main with test"      0  src/main/java/F.java src/test/java/FTest.java
run_require_tests_case "vendored Go file (no test needed)"         0  vendor/lib/foo.go

# Block-cases (must block, rc=1)
run_require_tests_case "Go source without test"                    1  pkg/foo.go
run_require_tests_case "TS source without test"                    1  src/foo.ts
run_require_tests_case "Python source without test"                1  app/foo.py
run_require_tests_case "Java main without Test class"              1  src/main/java/Foo.java
run_require_tests_case "Multiple source files no tests"            1  a.go b.ts c.py

# Edge: non-git-commit command shouldn't trigger
tmp=$(mktemp -d)
rc=$(cd "$tmp" && jq -n --arg c 'ls -la' '{tool_input:{command:$c}}' | "$HOOK" > /dev/null 2>&1; echo $?)
rm -rf "$tmp"
if [ "$rc" = "0" ]; then
  echo "PASS: non-commit command ignored"; PASS=$((PASS + 1))
else
  echo "FAIL: non-commit should exit 0 (got $rc)"; FAIL=$((FAIL + 1))
fi

summary
