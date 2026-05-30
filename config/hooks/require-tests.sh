#!/bin/bash
# Blocks git commits that have source code changes but no test files staged
# Ensures unit tests are always written alongside code changes
source "$(dirname "$0")/path-bootstrap.sh"

if ! command -v jq &> /dev/null; then
  exit 0
fi

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

# Only check on git commit
if ! echo "$COMMAND" | grep -qE '^git commit'; then
  exit 0
fi

# Get staged files
STAGED=$(git diff --cached --name-only 2>/dev/null)
if [ -z "$STAGED" ]; then
  exit 0
fi

# Detect source files (code that needs tests)
SOURCE_JAVA=$(echo "$STAGED" | grep -E 'src/main/.*\.java$' || true)
SOURCE_GO=$(echo "$STAGED" | grep -E '\.go$' | grep -vE '(_test\.go|vendor/|mock_|mocks/)' || true)
SOURCE_TS=$(echo "$STAGED" | grep -E '\.(ts|tsx)$' | grep -vE '\.(test|spec)\.(ts|tsx)$' | grep -vE '(\.config\.(ts|js)$|\.d\.ts$|__tests__|node_modules)' || true)
SOURCE_PY=$(echo "$STAGED" | grep -E '\.py$' | grep -vE '(test_|_test\.py$|/tests/|conftest\.py|__init__\.py)' || true)

HAS_SOURCE=false
if [ -n "$SOURCE_JAVA" ] || [ -n "$SOURCE_GO" ] || [ -n "$SOURCE_TS" ] || [ -n "$SOURCE_PY" ]; then
  HAS_SOURCE=true
fi

# No source files staged — nothing to check
if [ "$HAS_SOURCE" = false ]; then
  exit 0
fi

# Detect test files
TEST_JAVA=$(echo "$STAGED" | grep -E 'src/test/.*\.java$' || true)
TEST_GO=$(echo "$STAGED" | grep -E '_test\.go$' || true)
TEST_TS=$(echo "$STAGED" | grep -E '\.(test|spec)\.(ts|tsx|js|jsx)$' || true)
TEST_PY=$(echo "$STAGED" | grep -E '(test_.*\.py$|_test\.py$|/tests/.*\.py$)' || true)

HAS_TESTS=false
if [ -n "$TEST_JAVA" ] || [ -n "$TEST_GO" ] || [ -n "$TEST_TS" ] || [ -n "$TEST_PY" ]; then
  HAS_TESTS=true
fi

if [ "$HAS_TESTS" = false ]; then
  # Build list of source files for context
  SOURCES=""
  [ -n "$SOURCE_JAVA" ] && SOURCES="${SOURCES}${SOURCE_JAVA}\n"
  [ -n "$SOURCE_GO" ] && SOURCES="${SOURCES}${SOURCE_GO}\n"
  [ -n "$SOURCE_TS" ] && SOURCES="${SOURCES}${SOURCE_TS}\n"
  [ -n "$SOURCE_PY" ] && SOURCES="${SOURCES}${SOURCE_PY}\n"

  echo "⛔ No tests staged — source changes need unit tests" >&2
  echo "  Source files:" >&2
  # BSD echo doesn't interpret \n; use printf for cross-platform escape handling.
  printf '%b' "$SOURCES" | head -10 >&2
  echo "  Write + stage tests before committing." >&2
  exit 1
fi

exit 0
