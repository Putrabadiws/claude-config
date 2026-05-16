#!/bin/bash
# Checks if documentation should be updated based on staged changes
# Runs before git commit to remind about docs updates
source "$(dirname "$0")/path-bootstrap.sh"

# Check if jq is available
if ! command -v jq &> /dev/null; then
  echo '{"suppressOutput": true}'
  exit 0
fi

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

# Only check on git commit
if ! echo "$COMMAND" | grep -qE '^git commit'; then
  echo '{"suppressOutput": true}'
  exit 0
fi

# Get staged files
STAGED=$(git diff --cached --name-only 2>/dev/null)

if [ -z "$STAGED" ]; then
  echo '{"suppressOutput": true}'
  exit 0
fi

# Build reminder based on what's staged
REMINDERS=""

# API changes
if echo "$STAGED" | grep -qE '(Controller|Route|Endpoint|Handler|controller|route|endpoint|handler)\.(java|py|go|ts)$'; then
  REMINDERS="${REMINDERS}\n- API changes detected → update API.md"
fi

# Database/schema changes
if echo "$STAGED" | grep -qE '(models?|entities|schema|migrations?|changelog)'; then
  REMINDERS="${REMINDERS}\n- Schema changes detected → update DATABASE.md"
fi

# New service/component (newly added files only)
if git diff --cached --diff-filter=A --name-only 2>/dev/null | grep -qE '(services?|components?)/[^/]+\.(java|py|go|ts)$'; then
  REMINDERS="${REMINDERS}\n- New service/component → update ARCHITECTURE.md"
fi

# Config changes
if echo "$STAGED" | grep -qE '(application\.(properties|ya?ml)|config\.(py|ts|go)|\.env\.example)'; then
  REMINDERS="${REMINDERS}\n- Config changes detected → update CONFIGURATION.md"
fi

# Deployment changes
if echo "$STAGED" | grep -qE '(Dockerfile|docker-compose|helm|k8s|values\.ya?ml)'; then
  REMINDERS="${REMINDERS}\n- Deployment changes detected → update DEPLOYMENT.md"
fi

# If we have reminders, output them
if [ -n "$REMINDERS" ]; then
  # Check if docs folder exists (could be ../docs/ for submodules)
  DOCS_PATH=""
  if [ -d "docs" ]; then
    DOCS_PATH="docs/"
  elif [ -d "../docs" ]; then
    DOCS_PATH="../docs/"
  fi

  if [ -n "$DOCS_PATH" ]; then
    MESSAGE="Documentation check:${REMINDERS}\n\nDocs location: ${DOCS_PATH}"
    jq -n \
      --arg msg "$MESSAGE" \
      '{
        hookSpecificOutput: {
          hookEventName: "PreToolUse",
          additionalContext: $msg
        }
      }'
    exit 0
  fi
fi

echo '{"suppressOutput": true}'
exit 0
