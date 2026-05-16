#!/bin/bash
# Checks if the shared claude-config repo has new commits on origin/main
# Runs at session startup only (not resume/compact), with 24h cooldown
# Exit 0 always — never blocks session start
source "$(dirname "$0")/path-bootstrap.sh"

# Read stdin (required by hook contract)
INPUT=$(cat)

CLAUDE_DIR="$HOME/.claude"
VERSION_FILE="$CLAUDE_DIR/.config-version"
LAST_CHECK_FILE="$CLAUDE_DIR/.config-last-check"
REPO_PATH_FILE="$CLAUDE_DIR/.config-repo-path"

# --- Guard: not onboarded yet ---
if [ ! -f "$REPO_PATH_FILE" ]; then
  jq -n '{"suppressOutput": true}'
  exit 0
fi

REPO_PATH=$(cat "$REPO_PATH_FILE" | tr -d '[:space:]')

if [ ! -d "$REPO_PATH/.git" ]; then
  jq -n '{"suppressOutput": true}'
  exit 0
fi

# --- 24h cooldown ---
NOW=$(date +%s)
if [ -f "$LAST_CHECK_FILE" ]; then
  LAST_CHECK=$(cat "$LAST_CHECK_FILE" | tr -d '[:space:]')
  if [ -n "$LAST_CHECK" ] && [ "$((NOW - LAST_CHECK))" -lt 86400 ]; then
    jq -n '{"suppressOutput": true}'
    exit 0
  fi
fi

# --- Fetch remote (with git-level timeout for cross-platform compat) ---
# http.lowSpeedLimit/Time handles stalled connections; hook-level timeout (settings.json) kills total hang
if ! git -C "$REPO_PATH" \
  -c http.lowSpeedLimit=1000 \
  -c http.lowSpeedTime=5 \
  fetch origin main --quiet 2>/dev/null; then
  # Network failure (Ziti down, timeout, etc.)
  # Stamp cooldown so we don't retry every session today
  echo "$NOW" > "$LAST_CHECK_FILE"
  jq -n '{"suppressOutput": true}'
  exit 0
fi

# Stamp successful check
echo "$NOW" > "$LAST_CHECK_FILE"

# --- Compare versions ---
REMOTE_HEAD=$(git -C "$REPO_PATH" rev-parse origin/main 2>/dev/null)
if [ -z "$REMOTE_HEAD" ]; then
  jq -n '{"suppressOutput": true}'
  exit 0
fi

INSTALLED=""
if [ -f "$VERSION_FILE" ]; then
  INSTALLED=$(cat "$VERSION_FILE" | tr -d '[:space:]')
fi

if [ "$INSTALLED" = "$REMOTE_HEAD" ]; then
  jq -n '{"suppressOutput": true}'
  exit 0
fi

# --- New commits available — build summary ---
# If INSTALLED hash exists in repo history, use range log; otherwise treat as first check
if [ -n "$INSTALLED" ] && git -C "$REPO_PATH" cat-file -e "$INSTALLED" 2>/dev/null; then
  COMMIT_LOG=$(git -C "$REPO_PATH" log --oneline "$INSTALLED..origin/main" 2>/dev/null)
  CHANGED_FILES=$(git -C "$REPO_PATH" diff --name-only "$INSTALLED" "origin/main" -- config/ 2>/dev/null | head -20)
else
  COMMIT_LOG=$(git -C "$REPO_PATH" log --oneline -10 origin/main 2>/dev/null)
  CHANGED_FILES="(full comparison needed)"
fi

# Count commits safely (avoid grep piping issues)
if [ -n "$COMMIT_LOG" ]; then
  COMMIT_COUNT=$(echo "$COMMIT_LOG" | wc -l | tr -d ' ')
else
  COMMIT_COUNT="unknown"
fi

# Write flag file for statusline to pick up
PENDING_FILE="$CLAUDE_DIR/.config-update-pending"
echo "$COMMIT_COUNT" > "$PENDING_FILE"

# Inject context for Claude
CONTEXT="TEAM CONFIG UPDATE AVAILABLE

The shared claude-config repo has ${COMMIT_COUNT} new commit(s) on origin/main not yet applied to ~/.claude/.

New commits:
${COMMIT_LOG}

Changed config files:
${CHANGED_FILES}

Inform the user about this update and suggest they sync their local config.
Do NOT auto-apply — wait for the user to explicitly opt in."

jq -n --arg ctx "$CONTEXT" '{
  hookSpecificOutput: {
    hookEventName: "SessionStart",
    additionalContext: $ctx
  }
}'
