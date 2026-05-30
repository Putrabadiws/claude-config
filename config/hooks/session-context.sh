#!/bin/bash
# SYNC:LOCAL-ONLY  — per-env divergence: bangor delegates only to bangor-context.sh.
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
# GIT_REMOTE is the owner/repo slug (e.g. "Bangor-Group-Indonesia/bangor-admin"),
# used in the CTX summary. Host routing (gitlab vs github) is handled inside
# gitlab-github-context.sh, which re-fetches the remote itself — no need to
# pass the full URL through.
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

SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty')

# Delegate org-context injection to dedicated hook (bangor-context.sh). The
# hook owns its own detection + injection + flag logic; we invoke it with a
# synthesized PreToolUse-shape input so it behaves identically to its normal
# trigger path. The flag it sets prevents re-injection on the first real
# PreToolUse Bash.
# SYNC:LOCAL-ONLY  — per-env divergence: bangor invokes only bangor-context.sh.
SYNTH_INPUT=$(jq -n --arg cwd "$PWD" --arg sid "$SESSION_ID" \
  '{cwd:$cwd,session_id:$sid,tool_input:{command:""}}')
# DELEGATE_MSGS collects each delegate's user-facing systemMessage (e.g.
# "📚 Loaded context: Bangor") so starting IN a Bangor repo shows BOTH the
# 🧭 environment line AND the context line(s). Without capturing it here the
# delegate's systemMessage is discarded and only 🧭 would show.
DELEGATE_MSGS=""
for ORG_HOOK in bangor-context.sh gitlab-github-context.sh; do
  HOOK_PATH="$HOME/.claude/hooks/$ORG_HOOK"
  [ ! -x "$HOOK_PATH" ] && continue
  ORG_OUT=$(echo "$SYNTH_INPUT" | "$HOOK_PATH" 2>/dev/null)
  ORG_CTX=$(echo "$ORG_OUT" | jq -r '.hookSpecificOutput.additionalContext // empty' 2>/dev/null)
  [ -n "$ORG_CTX" ] && CTX="${CTX}\n\n${ORG_CTX}"
  ORG_MSG=$(echo "$ORG_OUT" | jq -r '.systemMessage // empty' 2>/dev/null)
  [ -n "$ORG_MSG" ] && DELEGATE_MSGS="${DELEGATE_MSGS}${ORG_MSG}
"
done

# User-facing one-liner (systemMessage) — a condensed, scannable version of the
# Environment summary. systemMessage is the only channel that renders as an
# intentional "…says:" line rather than a raw "hook success:" blob.
SUMMARY="🧭 k8s:${K8S_CTX}"
if [ -n "$GIT_REMOTE" ]; then
  SUMMARY="${SUMMARY} · ${GIT_REMOTE}@${GIT_BRANCH}"
else
  SUMMARY="${SUMMARY} · ${GIT_BRANCH}"
fi
# Trim the " (Claude Code)" suffix for the user line only — CTX keeps raw version.
SUMMARY="${SUMMARY} · claude $(echo "$CLAUDE_VERSION" | sed 's/ (Claude Code)$//')"

# Stack each delegate's context line beneath the 🧭 line, so starting IN a
# Bangor repo shows both (🧭 environment + 📚 context).
FULL_MSG="$SUMMARY"
[ -n "$DELEGATE_MSGS" ] && FULL_MSG="${SUMMARY}
${DELEGATE_MSGS%$'\n'}"

# Output JSON using jq for proper escaping
jq -n \
  --arg ctx "$CTX" \
  --arg sum "$FULL_MSG" \
  '{
    suppressOutput: false,
    systemMessage: $sum,
    hookSpecificOutput: {
      hookEventName: "SessionStart",
      additionalContext: $ctx
    }
  }'
