#!/bin/bash
# Runs linter on edited/written files based on file type
# Uses jq for safe JSON output with proper hookSpecificOutput wrapper
source "$(dirname "$0")/path-bootstrap.sh"

if ! command -v jq &> /dev/null; then
  echo '{"suppressOutput": true}'
  exit 0
fi

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

if [ -z "$FILE_PATH" ]; then
  echo '{"suppressOutput": true}'
  exit 0
fi

# Skip non-existent files (e.g., deleted files)
if [ ! -f "$FILE_PATH" ]; then
  echo '{"suppressOutput": true}'
  exit 0
fi

# Get file extension
EXT="${FILE_PATH##*.}"

# Early exit for non-code files
case "$EXT" in
  md|json|yaml|yml|toml|txt|xml|html|css|scss|less|svg|lock)
    echo '{"suppressOutput": true}'
    exit 0
    ;;
esac

# Helper function to output lint issues
output_lint_issue() {
  local linter="$1"
  local file="$2"
  local result="$3"
  local base; base=$(basename "$file")
  jq -n \
    --arg linter "$linter" \
    --arg file "$file" \
    --arg base "$base" \
    --arg result "$result" \
    '{
      systemMessage: "⚠️ \($linter): issues in \($base)",
      hookSpecificOutput: {
        hookEventName: "PostToolUse",
        additionalContext: "\($linter) issues in \($file):\n\($result)"
      }
    }'
}

# Run appropriate linter based on file type
case "$EXT" in
  js|jsx|ts|tsx|mjs|cjs)
    if command -v eslint &> /dev/null; then
      RESULT=$(eslint "$FILE_PATH" 2>&1)
      if [ $? -ne 0 ]; then
        output_lint_issue "ESLint" "$FILE_PATH" "$RESULT"
        exit 0
      fi
    fi
    ;;
  py)
    if command -v ruff &> /dev/null; then
      RESULT=$(ruff check "$FILE_PATH" 2>&1)
      if [ $? -ne 0 ]; then
        output_lint_issue "Ruff" "$FILE_PATH" "$RESULT"
        exit 0
      fi
    elif command -v flake8 &> /dev/null; then
      RESULT=$(flake8 "$FILE_PATH" 2>&1)
      if [ $? -ne 0 ]; then
        output_lint_issue "Flake8" "$FILE_PATH" "$RESULT"
        exit 0
      fi
    fi
    ;;
  go)
    # Skip golangci-lint (too slow), just check with go vet
    if command -v go &> /dev/null; then
      RESULT=$(go vet "$(dirname "$FILE_PATH")/..." 2>&1)
      if [ $? -ne 0 ]; then
        output_lint_issue "go vet" "$FILE_PATH" "$RESULT"
        exit 0
      fi
    fi
    ;;
  java)
    # Skip - Maven/Gradle handle this
    ;;
  sh|bash)
    if command -v shellcheck &> /dev/null; then
      RESULT=$(shellcheck "$FILE_PATH" 2>&1)
      if [ $? -ne 0 ]; then
        output_lint_issue "ShellCheck" "$FILE_PATH" "$RESULT"
        exit 0
      fi
    fi
    ;;
esac

echo '{"suppressOutput": true}'
exit 0
