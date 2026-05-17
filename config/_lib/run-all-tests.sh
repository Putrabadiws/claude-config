#!/bin/bash
# Discovers and runs all *.test.sh files recursively under a directory.
# Usage: bash ~/.claude/_lib/run-all-tests.sh [DIR]
#   DIR defaults to ~/.claude/ (scans hooks/, plus any other .sh in the tree).
# Exits 0 if all tests pass, non-zero otherwise.

SCAN_DIR="${1:-$HOME/.claude}"
if [ ! -d "$SCAN_DIR" ]; then
  echo "Directory not found: $SCAN_DIR" >&2
  exit 1
fi

TOTAL_PASS=0
TOTAL_FAIL=0
RUN_FILES=0

# Use find for recursive discovery; exclude node_modules and .git just in case.
while IFS= read -r -d '' test; do
  RUN_FILES=$((RUN_FILES + 1))
  echo "=== $(realpath --relative-to="$SCAN_DIR" "$test" 2>/dev/null || basename "$test") ==="
  output=$(bash "$test" 2>&1)
  echo "$output"
  pass=$(echo "$output" | grep -c "^PASS:")
  fail=$(echo "$output" | grep -c "^FAIL:")
  TOTAL_PASS=$((TOTAL_PASS + pass))
  TOTAL_FAIL=$((TOTAL_FAIL + fail))
  echo
done < <(find "$SCAN_DIR" -type f -name '*.test.sh' \( -not -path '*/node_modules/*' -not -path '*/.git/*' -not -path '*/plugins/cache/*' \) -print0)

if [ "$RUN_FILES" = "0" ]; then
  echo "No test files found in $SCAN_DIR (looking for *.test.sh)"
  exit 1
fi

echo "=== TOTAL ==="
echo "$RUN_FILES test files run, $TOTAL_PASS passed, $TOTAL_FAIL failed"
[ "$TOTAL_FAIL" = 0 ]
