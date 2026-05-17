#!/bin/bash
# Google Drive MCP server launcher — OAuth credentials co-located with launcher.
# Setup: Run auth flow first, then register as MCP server.

LAUNCHER_DIR="$(cd "$(dirname "$0")" && pwd)"
export GDRIVE_CREDENTIALS_PATH="$LAUNCHER_DIR/gdrive-credentials.json"
export GDRIVE_OAUTH_PATH="$LAUNCHER_DIR/gdrive-oauth.json"
if [ -n "${TEST_NO_EXEC:-}" ]; then
  echo "GDRIVE_CREDENTIALS_PATH=$GDRIVE_CREDENTIALS_PATH"
  echo "GDRIVE_OAUTH_PATH=$GDRIVE_OAUTH_PATH"
  exit 0
fi
exec npx -y @modelcontextprotocol/server-gdrive --stdio
