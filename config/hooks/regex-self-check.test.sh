#!/bin/bash
# Tests for regex-self-check.sh
# The hook never blocks (exit 0 always); we verify by stdout pattern.
# Run: bash ~/.claude/hooks/regex-self-check.test.sh

source "$HOME/.claude/_lib/test-helpers.sh"
HOOK="$(_test_script_dir "$0")/regex-self-check.sh"
_require_executable "$HOOK"

PATTERN="REGEX DETECTED"

# Should-emit cases (regex-bearing content)
run_test_stdout "grep -qE invocation"             'grep -qE "^cp\s+"'                 Edit  "$PATTERN" yes
run_test_stdout "grep -E with other flags"        'grep -oE "[a-z]+" file'             Edit  "$PATTERN" yes
run_test_stdout "sed substitute"                  'sed s/foo/bar/g'                    Edit  "$PATTERN" yes
run_test_stdout "sed -E with pattern"             'sed -E "s/[0-9]+/N/g"'              Write "$PATTERN" yes
run_test_stdout "python re.compile"               'import re\nre.compile(r"\d+")'      Write "$PATTERN" yes
run_test_stdout "python re.search"                're.search(r"foo", text)'            Write "$PATTERN" yes
run_test_stdout "JS RegExp constructor"           'new RegExp("\\s+")'                 Edit  "$PATTERN" yes
run_test_stdout "regex metachar \\s"              'match \s+ here'                     Edit  "$PATTERN" yes
run_test_stdout "regex metachar \\w"              'pattern is \w+\b'                   Edit  "$PATTERN" yes

# Should-NOT-emit cases (no regex)
run_test_stdout "plain prose"                     'Just some plain text content'       Edit  "$PATTERN" no
run_test_stdout "code without regex"              'def add(a, b): return a + b'        Write "$PATTERN" no
run_test_stdout "grep fixed-string (no -E/-P)"    'grep hello file.txt'                Edit  "$PATTERN" no
run_test_stdout "wrong tool (Bash)"               'grep -E "cp\s+" file'               Bash  "$PATTERN" no
run_test_stdout "wrong tool (Read)"               'grep -E pattern file'               Read  "$PATTERN" no
run_test_stdout "mention of regex in docs"        'This function uses regex matching.' Edit  "$PATTERN" no

# Exclusion: *.test.sh files (test fixtures legitimately contain regex content)
stdout=$(jq -n --arg c 'grep -qE "\d+"' --arg f /tmp/foo.test.sh '{tool_name:"Edit",tool_input:{new_string:$c,file_path:$f}}' | "$HOOK" 2>/dev/null)
if echo "$stdout" | grep -q "$PATTERN"; then
  echo "FAIL: *.test.sh exclusion (got REGEX DETECTED on test fixture)"; FAIL=$((FAIL + 1))
else
  echo "PASS: *.test.sh exclusion (test fixtures correctly skipped)"; PASS=$((PASS + 1))
fi

# Exclusion: *.md files (documentation often mentions regex syntax in prose)
stdout=$(jq -n --arg c 'use \\s+ or [[:space:]] for whitespace' --arg f /tmp/CONVENTIONS.md '{tool_name:"Write",tool_input:{content:$c,file_path:$f}}' | "$HOOK" 2>/dev/null)
if echo "$stdout" | grep -q "$PATTERN"; then
  echo "FAIL: *.md exclusion (got REGEX DETECTED on docs)"; FAIL=$((FAIL + 1))
else
  echo "PASS: *.md exclusion (docs correctly skipped)"; PASS=$((PASS + 1))
fi

# Exclusion: *.markdown also skipped
stdout=$(jq -n --arg c 'pattern: \\d+' --arg f /tmp/notes.markdown '{tool_name:"Edit",tool_input:{new_string:$c,file_path:$f}}' | "$HOOK" 2>/dev/null)
if echo "$stdout" | grep -q "$PATTERN"; then
  echo "FAIL: *.markdown exclusion"; FAIL=$((FAIL + 1))
else
  echo "PASS: *.markdown exclusion"; PASS=$((PASS + 1))
fi

# Counter-check: regex content in a non-.test.sh / non-.md still triggers
stdout=$(jq -n --arg c 'grep -qE "\d+"' --arg f /tmp/foo.sh '{tool_name:"Edit",tool_input:{new_string:$c,file_path:$f}}' | "$HOOK" 2>/dev/null)
if echo "$stdout" | grep -q "$PATTERN"; then
  echo "PASS: non-test .sh still triggers"; PASS=$((PASS + 1))
else
  echo "FAIL: non-test .sh should have triggered"; FAIL=$((FAIL + 1))
fi

summary
