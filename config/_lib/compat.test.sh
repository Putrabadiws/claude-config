#!/bin/bash
# Tests for compat.sh helpers.
# Verifies that each helper produces correct output on the current OS.
# Run: bash ~/.claude/_lib/compat.test.sh

source "$HOME/.claude/_lib/test-helpers.sh"
source "$HOME/.claude/_lib/compat.sh"

# Test: OS detection set at least one flag
if [ $((IS_MACOS + IS_LINUX + IS_WINDOWS)) -ge 1 ]; then
  echo "PASS: OS detection set a flag (macOS=$IS_MACOS, Linux=$IS_LINUX, Windows=$IS_WINDOWS)"; PASS=$((PASS + 1))
else
  echo "FAIL: no OS flag set"; FAIL=$((FAIL + 1))
fi

# Test: _date_from_epoch with known epoch (2021-01-01 00:00:00 UTC = 1609459200)
out=$(_date_from_epoch 1609459200 "%Y")
if [ "$out" = "2020" ] || [ "$out" = "2021" ]; then  # timezone dependent
  echo "PASS: _date_from_epoch produces 4-digit year ($out)"; PASS=$((PASS + 1))
else
  echo "FAIL: _date_from_epoch output unexpected: $out"; FAIL=$((FAIL + 1))
fi

# Test: _date_from_epoch with format that includes time
out=$(_date_from_epoch 1609459200 "%H:%M")
if echo "$out" | grep -qE '^[0-9]{2}:[0-9]{2}$'; then
  echo "PASS: _date_from_epoch HH:MM format"; PASS=$((PASS + 1))
else
  echo "FAIL: _date_from_epoch HH:MM unexpected: $out"; FAIL=$((FAIL + 1))
fi

# Test: _file_mtime returns integer epoch
tmp=$(mktemp)
mtime=$(_file_mtime "$tmp")
rm -f "$tmp"
if echo "$mtime" | grep -qE '^[0-9]+$'; then
  echo "PASS: _file_mtime returns epoch integer"; PASS=$((PASS + 1))
else
  echo "FAIL: _file_mtime returned: $mtime"; FAIL=$((FAIL + 1))
fi

# Test: _file_mtime on missing file returns empty
mtime=$(_file_mtime "/tmp/definitely-does-not-exist-$$")
if [ -z "$mtime" ]; then
  echo "PASS: _file_mtime on missing file returns empty"; PASS=$((PASS + 1))
else
  echo "FAIL: _file_mtime on missing file returned: $mtime"; FAIL=$((FAIL + 1))
fi

# Test: _realpath_f resolves an existing dir to absolute path
tmp=$(mktemp -d)
out=$(_realpath_f "$tmp")
rm -rf "$tmp"
if [ -n "$out" ] && [ "${out#/}" != "$out" ]; then
  echo "PASS: _realpath_f returns absolute path"; PASS=$((PASS + 1))
else
  echo "FAIL: _realpath_f returned: $out"; FAIL=$((FAIL + 1))
fi

# Test: _echo_e interprets \n as newline
out=$(_echo_e "a\nb")
lines=$(echo "$out" | wc -l | tr -d ' ')
if [ "$lines" = "2" ]; then
  echo "PASS: _echo_e interprets \\n as newline"; PASS=$((PASS + 1))
else
  echo "FAIL: _echo_e produced $lines lines, expected 2"; FAIL=$((FAIL + 1))
fi

# Test: _echo_e interprets \t as tab
out=$(_echo_e "a\tb")
if echo "$out" | grep -qP '\t' 2>/dev/null || echo "$out" | awk -F'\t' '{exit NF==2 ? 0 : 1}'; then
  echo "PASS: _echo_e interprets \\t as tab"; PASS=$((PASS + 1))
else
  echo "FAIL: _echo_e did not produce tab: $out"; FAIL=$((FAIL + 1))
fi

# Test: _sed_inplace edits file in place
tmp=$(mktemp)
echo "hello world" > "$tmp"
_sed_inplace 's/world/there/' "$tmp"
content=$(cat "$tmp")
rm -f "$tmp"
if [ "$content" = "hello there" ]; then
  echo "PASS: _sed_inplace edits in place"; PASS=$((PASS + 1))
else
  echo "FAIL: _sed_inplace didn't edit; got: $content"; FAIL=$((FAIL + 1))
fi

# Test: _sed_inplace doesn't leave .bak file
tmp=$(mktemp)
echo "foo" > "$tmp"
_sed_inplace 's/foo/bar/' "$tmp"
bak_exists=no
[ -f "$tmp.bak" ] && bak_exists=yes
rm -f "$tmp" "$tmp.bak"
if [ "$bak_exists" = "no" ]; then
  echo "PASS: _sed_inplace removes .bak file"; PASS=$((PASS + 1))
else
  echo "FAIL: _sed_inplace left .bak file behind"; FAIL=$((FAIL + 1))
fi

summary
