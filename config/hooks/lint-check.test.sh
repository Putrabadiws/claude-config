#!/bin/bash
# Tests for lint-check.sh — PostToolUse Edit|Write hook that runs linters.
# Run: bash ~/.claude/hooks/lint-check.test.sh

source "$HOME/.claude/_lib/test-helpers.sh"
HOOK="$(_test_script_dir "$0")/lint-check.sh"
_require_executable "$HOOK"

# Helper: invoke with file_path, return stdout
invoke_lint() {
  local file_path="$1"
  jq -n --arg f "$file_path" '{tool_input:{file_path:$f}}' | "$HOOK" 2>/dev/null
}

# Test: no file_path → suppressOutput
out=$(echo '{"tool_input":{}}' | "$HOOK" 2>/dev/null)
if echo "$out" | grep -q "suppressOutput"; then
  echo "PASS: missing file_path → suppressOutput"; PASS=$((PASS + 1))
else
  echo "FAIL: should suppress on missing file_path: $out"; FAIL=$((FAIL + 1))
fi

# Test: non-existent file → suppressOutput
out=$(invoke_lint "/tmp/does-not-exist-$$.ts")
if echo "$out" | grep -q "suppressOutput"; then
  echo "PASS: non-existent file → suppressOutput"; PASS=$((PASS + 1))
else
  echo "FAIL: should suppress on non-existent file"; FAIL=$((FAIL + 1))
fi

# Test: .md file → suppressOutput (non-code)
tmp=$(mktemp -t lint-check-XXXXXX.md)
echo "# heading" > "$tmp"
out=$(invoke_lint "$tmp")
rm -f "$tmp"
if echo "$out" | grep -q "suppressOutput"; then
  echo "PASS: .md → suppressOutput"; PASS=$((PASS + 1))
else
  echo "FAIL: .md should suppress"; FAIL=$((FAIL + 1))
fi

# Test: .json file → suppressOutput
tmp=$(mktemp -t lint-check-XXXXXX.json)
echo '{}' > "$tmp"
out=$(invoke_lint "$tmp")
rm -f "$tmp"
if echo "$out" | grep -q "suppressOutput"; then
  echo "PASS: .json → suppressOutput"; PASS=$((PASS + 1))
else
  echo "FAIL: .json should suppress"; FAIL=$((FAIL + 1))
fi

# Test: .yaml → suppressOutput
tmp=$(mktemp -t lint-check-XXXXXX.yaml)
echo 'key: value' > "$tmp"
out=$(invoke_lint "$tmp")
rm -f "$tmp"
if echo "$out" | grep -q "suppressOutput"; then
  echo "PASS: .yaml → suppressOutput"; PASS=$((PASS + 1))
else
  echo "FAIL: .yaml should suppress"; FAIL=$((FAIL + 1))
fi

# Test: clean python file (no ruff issues) → suppressOutput
# Only run if ruff or flake8 is available
if command -v ruff > /dev/null 2>&1 || command -v flake8 > /dev/null 2>&1; then
  tmp=$(mktemp -t lint-check-XXXXXX.py)
  echo "x = 1" > "$tmp"
  out=$(invoke_lint "$tmp")
  rm -f "$tmp"
  if echo "$out" | grep -q "suppressOutput"; then
    echo "PASS: clean .py → suppressOutput"; PASS=$((PASS + 1))
  else
    echo "FAIL: clean .py should suppress, got: $out"; FAIL=$((FAIL + 1))
  fi
else
  echo "PASS: clean .py linter — skipped (no ruff/flake8)"; PASS=$((PASS + 1))
fi

# Edge: .lock file (dependency lockfile) → suppressOutput
tmp=$(mktemp -t lint-check-XXXXXX.lock)
echo 'lock' > "$tmp"
out=$(invoke_lint "$tmp")
rm -f "$tmp"
if echo "$out" | grep -q "suppressOutput"; then
  echo "PASS: .lock → suppressOutput (edge)"; PASS=$((PASS + 1))
else
  echo "FAIL: .lock should suppress"; FAIL=$((FAIL + 1))
fi

# systemMessage on a real lint failure (added in output rework). shellcheck flags
# `echo $foo` (SC2086); assert the ⚠️ line + additionalContext both appear.
if command -v shellcheck >/dev/null 2>&1; then
  d=$(mktemp -d); bad="$d/bad.sh"
  printf '#!/bin/bash\nfoo=bar\necho $foo\n' > "$bad"
  out=$(invoke_lint "$bad")
  rm -rf "$d"
  if echo "$out" | jq -e '.systemMessage' >/dev/null 2>&1 && echo "$out" | grep -q "⚠️"; then
    echo "PASS: lint failure emits ⚠️ systemMessage"; PASS=$((PASS + 1))
  else
    echo "FAIL: expected ⚠️ systemMessage on shellcheck failure, got: $out"; FAIL=$((FAIL + 1))
  fi
else
  echo "PASS: (lint ⚠️ systemMessage test skipped — no shellcheck)"; PASS=$((PASS + 1))
fi

summary
