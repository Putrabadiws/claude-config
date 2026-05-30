#!/bin/bash
# regex-self-check.sh — PreToolUse nudge on Edit/Write/NotebookEdit.
# Detects regex-bearing content and reminds Claude to state structural anchor
# + adversarial benign inputs before the regex ships.
# Exit 0 always — only emits additionalContext, never blocks.
source "$(dirname "$0")/path-bootstrap.sh"

if ! command -v jq &> /dev/null; then
  exit 0
fi

INPUT=$(cat)
TOOL=$(echo "$INPUT" | jq -r '.tool_name // empty')

case "$TOOL" in
  Edit|Write|NotebookEdit) ;;
  *) exit 0 ;;
esac

# Skip test fixtures and documentation files:
# - *.test.sh files for regex-detecting scripts legitimately contain regex patterns as test data.
# - *.md / *.markdown files often discuss regex syntax in prose (rule docs, README, etc.).
# Filename-based exclusion, not content-based.
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')
case "$FILE_PATH" in
  *.test.sh|*.md|*.markdown) exit 0 ;;
esac

CONTENT=$(echo "$INPUT" | jq -r '.tool_input.new_string // .tool_input.content // empty')
[ -z "$CONTENT" ] && exit 0

# Regex-bearing signals — any one triggers the nudge:
#   - grep with -E or -P flag (alone or combined with other flags like -qE, -oP)
#   - sed substitute (s/...) or sed -E
#   - python re.{compile,match,search,findall,sub}
#   - JS RegExp() constructor (with or without `new`)
#   - regex metacharacter escapes (\s, \S, \d, \D, \w, \W, \b, \B) — single backslash
if echo "$CONTENT" | grep -qE 'grep\s+-[A-Za-z]*[EP]|sed\s+(s/|-E)|re\.(compile|match|search|findall|sub)\(|RegExp\(|\\(s|S|d|D|w|W|b|B)\b'; then
  jq -n '{
    "systemMessage": "🔍 Regex edited — anchor to structure + test adversarial inputs",
    "hookSpecificOutput": {
      "hookEventName": "PreToolUse",
      "additionalContext": "REGEX DETECTED. Before this edit lands, your response MUST state: (1) the STRUCTURAL anchor your regex uses (e.g. command boundary, line start, word boundary, separator) — substring matches over structured input are fragile; (2) at least two ADVERSARIAL benign inputs (text that contains the pattern as substring but should NOT match) and verify the regex skips them. If either is missing, the regex is half-baked — rewrite."
    }
  }'
fi

exit 0
