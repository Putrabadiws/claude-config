#!/bin/bash
# Tests for path-bootstrap.sh — sourced library that adjusts PATH per OS.
# It has no standalone behavior (not invoked as a subprocess), so tests verify:
#   - sourcing succeeds
#   - PATH is exported
#   - platform-specific paths get added when present
# Run: bash ~/.claude/hooks/path-bootstrap.test.sh

source "$HOME/.claude/_lib/test-helpers.sh"
LIB="$(_test_script_dir "$0")/path-bootstrap.sh"
_require_executable "$LIB"

# Test 1: sourcing does not error
( source "$LIB" ) > /dev/null 2>&1
if [ $? -eq 0 ]; then
  echo "PASS: sources without error"; PASS=$((PASS + 1))
else
  echo "FAIL: sourcing errored"; FAIL=$((FAIL + 1))
fi

# Test 2: PATH is exported after sourcing
out=$( ( source "$LIB" && echo "$PATH" ) )
if [ -n "$out" ]; then
  echo "PASS: PATH is set after sourcing"; PASS=$((PASS + 1))
else
  echo "FAIL: PATH empty"; FAIL=$((FAIL + 1))
fi

# Test 3: on Darwin, /opt/homebrew/bin or /usr/local/bin should be in PATH if dir exists
if [ "$(uname -s)" = "Darwin" ]; then
  out=$( ( source "$LIB" && echo "$PATH" ) )
  if [ -d "/opt/homebrew/bin" ]; then
    if echo "$out" | grep -q "/opt/homebrew/bin"; then
      echo "PASS: Darwin /opt/homebrew/bin prepended"; PASS=$((PASS + 1))
    else
      echo "FAIL: /opt/homebrew/bin missing from PATH"; FAIL=$((FAIL + 1))
    fi
  elif [ -d "/usr/local/bin" ]; then
    if echo "$out" | grep -q "/usr/local/bin"; then
      echo "PASS: Darwin /usr/local/bin prepended"; PASS=$((PASS + 1))
    else
      echo "FAIL: /usr/local/bin missing from PATH"; FAIL=$((FAIL + 1))
    fi
  else
    echo "PASS: Darwin no brew dirs to add (vacuous)"; PASS=$((PASS + 1))
  fi
fi

# Test 4: idempotent — sourcing twice doesn't error
out=$( ( source "$LIB" && source "$LIB" ) > /dev/null 2>&1 && echo OK )
if [ "$out" = "OK" ]; then
  echo "PASS: idempotent re-source"; PASS=$((PASS + 1))
else
  echo "FAIL: re-sourcing failed"; FAIL=$((FAIL + 1))
fi

# Edge: doesn't unset any existing PATH entries
old="/some/custom/dir"
out=$( ( PATH="$old:/usr/bin" && source "$LIB" && echo "$PATH" ) )
if echo "$out" | grep -q "$old"; then
  echo "PASS: preserves existing PATH entries"; PASS=$((PASS + 1))
else
  echo "FAIL: dropped existing PATH entries"; FAIL=$((FAIL + 1))
fi

summary
