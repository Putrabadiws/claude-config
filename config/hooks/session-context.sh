#!/bin/bash
# Gathers rich context at session startup
# Uses jq for safe JSON creation to handle special characters
source "$(dirname "$0")/path-bootstrap.sh"

# Read stdin (SessionStart payload — fields: session_id, transcript_path, cwd, source).
# Note: SessionStart does NOT include .model, so we don't try to derive it here;
# inject-claude-version.sh resolves the model from transcript_path when needed.
INPUT=$(cat)

# Collect context
K8S_CTX=$(kubectl config current-context 2>/dev/null || echo "none")
GIT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "not a git repo")
GIT_REMOTE=$(git remote get-url origin 2>/dev/null | sed 's/.*[:/]\([^/]*\/[^/]*\)\.git/\1/' || echo "")

# Detect project type
PROJECT_TYPE="unknown"
if [ -f "package.json" ]; then
  PROJECT_TYPE="node"
elif [ -f "go.mod" ]; then
  PROJECT_TYPE="go"
elif [ -f "pom.xml" ] || [ -f "mvnw" ]; then
  PROJECT_TYPE="java/maven"
elif [ -f "requirements.txt" ] || [ -f "pyproject.toml" ]; then
  PROJECT_TYPE="python"
elif [ -f "Cargo.toml" ]; then
  PROJECT_TYPE="rust"
fi

# Get Claude Code version
CLAUDE_VERSION=$(claude --version 2>/dev/null || echo "unknown")
# Trim to just version number if multi-line output
CLAUDE_VERSION=$(echo "$CLAUDE_VERSION" | head -1)

# Persist version for other hooks (e.g., inject-claude-version.sh).
# ~/.claude/.session-env is the canonical source read by inject-claude-version.sh.
# $CLAUDE_ENV_FILE is the Claude Code native env mechanism (exports as shell vars);
# written as a bonus when available, but not relied upon since availability varies.
# Model is intentionally NOT persisted here — SessionStart payload lacks it; the
# inject-claude-version hook reads transcript_path to get the actual model.
SESSION_ENV="$HOME/.claude/.session-env"
echo "CLAUDE_CODE_VERSION=\"${CLAUDE_VERSION}\"" > "$SESSION_ENV"
if [ -n "$CLAUDE_ENV_FILE" ]; then
  echo "export CLAUDE_CODE_VERSION=\"${CLAUDE_VERSION}\"" >> "$CLAUDE_ENV_FILE"
fi

# Build context string safely with jq
CTX="Environment: k8s=${K8S_CTX}, branch=${GIT_BRANCH}, project=${PROJECT_TYPE}, claude=${CLAUDE_VERSION}"
[ -n "$GIT_REMOTE" ] && CTX="${CTX}, repo=${GIT_REMOTE}"

# If in a git repo, append github rules and set flag for PreToolUse hook
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty')
GITHUB_RULES=""
if [ "$GIT_BRANCH" != "not a git repo" ] && [ -f "$HOME/.claude/hooks/github-rules.md" ]; then
  GITHUB_RULES=$(cat "$HOME/.claude/hooks/github-rules.md")
  CTX="${CTX}\n\n${GITHUB_RULES}"
  # Set flag so PreToolUse hook skips re-injection
  [ -n "$SESSION_ID" ] && touch "/tmp/github-rules-injected-${SESSION_ID}"
fi

# Output JSON using jq for proper escaping
jq -n \
  --arg ctx "$CTX" \
  '{
    hookSpecificOutput: {
      hookEventName: "SessionStart",
      additionalContext: $ctx
    }
  }'
