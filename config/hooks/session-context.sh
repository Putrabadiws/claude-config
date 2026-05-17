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
# Capture full URL too — host (github vs other) gets lost by the owner/repo strip
# but is needed to route the right rules file.
GIT_REMOTE_URL=$(git remote get-url origin 2>/dev/null || echo "")
GIT_REMOTE=$(echo "$GIT_REMOTE_URL" | sed 's/.*[:/]\([^/]*\/[^/]*\)\.git/\1/')

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

SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty')

# Burger Bangor business context. Triggers if cwd is under ~/bangor (the user's
# workspace for Bangor repos) OR the git remote points to the Bangor org.
# Sets the same flag the PreToolUse hook checks, so we don't re-inject on first bash.
BANGOR_MATCH=false
case "$PWD" in
  "$HOME/bangor"|"$HOME/bangor"/*) BANGOR_MATCH=true ;;
esac
if ! $BANGOR_MATCH && echo "$GIT_REMOTE_URL" | grep -qiE 'bangor-group-indonesia'; then
  BANGOR_MATCH=true
fi
if $BANGOR_MATCH; then
  BANGOR_CTX="$HOME/.claude/hooks/bangor-context.md"
  if [ -f "$BANGOR_CTX" ]; then
    CTX="${CTX}\n\n$(cat "$BANGOR_CTX")"
    [ -n "$SESSION_ID" ] && touch "/tmp/bangor-context-injected-${SESSION_ID}"
  fi
fi

# Route rules by remote host. Match raw URL — owner/repo strip loses the host.
case "$GIT_REMOTE_URL" in
  *github*)
    if [ -f "$HOME/.claude/hooks/github-rules.md" ]; then
      CTX="${CTX}\n\n$(cat "$HOME/.claude/hooks/github-rules.md")"
      [ -n "$SESSION_ID" ] && touch "/tmp/github-rules-injected-${SESSION_ID}"
    fi
    ;;
esac

# Output JSON using jq for proper escaping
jq -n \
  --arg ctx "$CTX" \
  '{
    hookSpecificOutput: {
      hookEventName: "SessionStart",
      additionalContext: $ctx
    }
  }'
