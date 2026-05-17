#!/bin/bash
# Tests for docs-check.sh
# Hook reads staged files via `git diff --cached`, emits reminder JSON when
# documentation-affecting changes are staged AND docs/ directory exists.
# Run: bash ~/.claude/hooks/docs-check.test.sh

source "$HOME/.claude/_lib/test-helpers.sh"
HOOK="$(_test_script_dir "$0")/docs-check.sh"
_require_executable "$HOOK"

# Helper: setup git repo, stage files, optionally create docs/ dir, run hook, check stdout.
run_docs_check_case() {
  local name="$1"
  local has_docs="$2"      # "yes" / "no"
  local expect_reminder="$3"  # "yes" / "no"
  shift 3
  local files=("$@")

  local tmp
  tmp=$(mktemp -d)
  ( cd "$tmp" && git init -q && git config user.email t@t && git config user.name t ) > /dev/null 2>&1
  [ "$has_docs" = "yes" ] && mkdir -p "$tmp/docs"
  for f in "${files[@]}"; do
    mkdir -p "$(dirname "$tmp/$f")"
    echo "stub" > "$tmp/$f"
    ( cd "$tmp" && git add "$f" ) > /dev/null 2>&1
  done

  local stdout
  stdout=$(cd "$tmp" && jq -n --arg c 'git commit -m "x"' '{tool_input:{command:$c}}' | "$HOOK" 2>/dev/null)
  rm -rf "$tmp"

  local has_reminder=no
  echo "$stdout" | grep -q "Documentation check" && has_reminder=yes

  if [ "$has_reminder" = "$expect_reminder" ]; then
    echo "PASS: $name"; PASS=$((PASS + 1))
  else
    echo "FAIL: $name (expected reminder=$expect_reminder, got=$has_reminder)"; FAIL=$((FAIL + 1))
  fi
}

# Allow-cases (no reminder)
run_docs_check_case "no doc-affecting files"                  yes no  README.md
run_docs_check_case "docs/ missing → no reminder even on API change"  no  no  src/UserController.java
run_docs_check_case "non-commit command"                      yes no
# explicit non-commit test
tmp=$(mktemp -d)
stdout=$(cd "$tmp" && jq -n --arg c 'ls' '{tool_input:{command:$c}}' | "$HOOK" 2>/dev/null)
rm -rf "$tmp"
if echo "$stdout" | grep -q "Documentation check"; then
  echo "FAIL: non-commit triggered docs reminder"; FAIL=$((FAIL + 1))
else
  echo "PASS: non-commit ignored"; PASS=$((PASS + 1))
fi

# Trigger-cases (reminder expected)
run_docs_check_case "API change → reminder"                   yes yes src/UserController.java
run_docs_check_case "schema/model change → reminder"          yes yes src/models/user.py
run_docs_check_case "migration file → reminder"               yes yes src/migrations/001_init.py
run_docs_check_case "new service file → reminder"             yes yes src/services/auth.go
run_docs_check_case "Dockerfile change → reminder"            yes yes Dockerfile
run_docs_check_case "application.yml config change"           yes yes src/main/resources/application.yml

# Edge: no staged files
tmp=$(mktemp -d)
( cd "$tmp" && git init -q ) > /dev/null 2>&1
mkdir -p "$tmp/docs"
stdout=$(cd "$tmp" && jq -n --arg c 'git commit -m x' '{tool_input:{command:$c}}' | "$HOOK" 2>/dev/null)
rm -rf "$tmp"
if echo "$stdout" | grep -q "Documentation check"; then
  echo "FAIL: empty staging triggered reminder"; FAIL=$((FAIL + 1))
else
  echo "PASS: empty staging → no reminder"; PASS=$((PASS + 1))
fi

summary
