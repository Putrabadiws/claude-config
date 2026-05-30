#!/bin/bash
# Tests for inject-shell-test-reminder.sh — PreToolUse Edit|Write|NotebookEdit
# nudge that fires on *.sh files (excluding *.test.sh) and emits the test +
# compat.sh rule via hookSpecificOutput.additionalContext. Exit always 0.
# Run: bash ~/.claude/hooks/inject-shell-test-reminder.test.sh

source "$HOME/.claude/_lib/test-helpers.sh"
HOOK="$(_test_script_dir "$0")/inject-shell-test-reminder.sh"
_require_executable "$HOOK"

# Test wrapper: invoke with given tool_name + file_path, capture stdout.
invoke() {
  local tool="$1" path="$2"
  jq -n --arg t "$tool" --arg p "$path" \
    '{tool_name:$t,tool_input:{file_path:$p,new_string:"x",content:"x"}}' \
    | "$HOOK" 2>/dev/null
}

PATTERN="SHELL TEST DISCIPLINE"

# --- SHOULD-FIRE: editing or writing a .sh file (non-test) ---

# Sibling does not exist → message says "DOES NOT EXIST"
out=$(invoke "Write" "/tmp/this-path-does-not-exist-$RANDOM.sh")
if echo "$out" | grep -q "$PATTERN" && echo "$out" | grep -q "DOES NOT EXIST"; then
  echo "PASS: fires on new .sh (sibling missing)"; PASS=$((PASS + 1))
else
  echo "FAIL: should fire with 'DOES NOT EXIST' on new .sh, got: $out"; FAIL=$((FAIL + 1))
fi

# Sibling exists → message says "EXISTS"
TMP_SRC=$(mktemp -d)
echo '#' > "$TMP_SRC/foo.sh"
echo '#' > "$TMP_SRC/foo.test.sh"
out=$(invoke "Edit" "$TMP_SRC/foo.sh")
rm -rf "$TMP_SRC"
if echo "$out" | grep -q "$PATTERN" && echo "$out" | grep -q "EXISTS"; then
  echo "PASS: fires on .sh edit when sibling exists"; PASS=$((PASS + 1))
else
  echo "FAIL: should fire with 'EXISTS' when sibling present, got: $out"; FAIL=$((FAIL + 1))
fi

# NotebookEdit on .sh also fires (covers all three matched tools).
out=$(invoke "NotebookEdit" "/tmp/nb-target-$RANDOM.sh")
if echo "$out" | grep -q "$PATTERN"; then
  echo "PASS: fires on NotebookEdit + .sh"; PASS=$((PASS + 1))
else
  echo "FAIL: should fire on NotebookEdit, got: $out"; FAIL=$((FAIL + 1))
fi

# --- SHOULD-NOT-FIRE: adversarial benign inputs ---

# Editing *.test.sh — rule doesn't apply to test files themselves
out=$(invoke "Edit" "/tmp/foo.test.sh")
if echo "$out" | grep -q "$PATTERN"; then
  echo "FAIL: false-positive on *.test.sh edit"; FAIL=$((FAIL + 1))
else
  echo "PASS: silent on *.test.sh"; PASS=$((PASS + 1))
fi

# Path containing .sh as a non-suffix substring (.sh in middle)
out=$(invoke "Edit" "/tmp/dot-sh-config.txt")
if echo "$out" | grep -q "$PATTERN"; then
  echo "FAIL: false-positive on .txt with .sh substring"; FAIL=$((FAIL + 1))
else
  echo "PASS: silent on .txt with .sh substring"; PASS=$((PASS + 1))
fi

# Backup file ending in .sh.bak — should not match
out=$(invoke "Edit" "/tmp/foo.sh.bak")
if echo "$out" | grep -q "$PATTERN"; then
  echo "FAIL: false-positive on .sh.bak"; FAIL=$((FAIL + 1))
else
  echo "PASS: silent on .sh.bak"; PASS=$((PASS + 1))
fi

# .shtml is not .sh
out=$(invoke "Edit" "/tmp/foo.shtml")
if echo "$out" | grep -q "$PATTERN"; then
  echo "FAIL: false-positive on .shtml"; FAIL=$((FAIL + 1))
else
  echo "PASS: silent on .shtml"; PASS=$((PASS + 1))
fi

# Wrong tool (Bash) — hook only listens to Edit/Write/NotebookEdit
out=$(invoke "Bash" "/tmp/foo.sh")
if echo "$out" | grep -q "$PATTERN"; then
  echo "FAIL: false-positive on Bash tool"; FAIL=$((FAIL + 1))
else
  echo "PASS: silent on non-Edit/Write tool"; PASS=$((PASS + 1))
fi

# Empty file_path — no path → no fire
out=$(echo '{"tool_name":"Edit","tool_input":{"new_string":"x"}}' | "$HOOK" 2>/dev/null)
if echo "$out" | grep -q "$PATTERN"; then
  echo "FAIL: false-positive on empty file_path"; FAIL=$((FAIL + 1))
else
  echo "PASS: silent on empty file_path"; PASS=$((PASS + 1))
fi

# Exit code MUST always be 0 (non-blocking by design)
echo '{"tool_name":"Edit","tool_input":{"file_path":"/tmp/x.sh"}}' | "$HOOK" > /dev/null 2>&1
rc=$?
if [ "$rc" = 0 ]; then
  echo "PASS: exit 0 even when firing"; PASS=$((PASS + 1))
else
  echo "FAIL: should exit 0 (rc=$rc)"; FAIL=$((FAIL + 1))
fi

# systemMessage on .sh edit (added in output rework)
out=$(invoke "Write" "/tmp/sm-check-$RANDOM.sh")
if echo "$out" | jq -e '.systemMessage' >/dev/null 2>&1 && echo "$out" | grep -q "🧪"; then
  echo "PASS: emits 🧪 systemMessage on .sh edit"; PASS=$((PASS + 1))
else
  echo "FAIL: expected 🧪 systemMessage, got: $out"; FAIL=$((FAIL + 1))
fi

summary
