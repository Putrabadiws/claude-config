#!/bin/bash
# Google Drive MCP server launcher — OAuth credentials from ~/.claude/
# Setup: Run auth flow first, then register as MCP server
export GDRIVE_CREDENTIALS_PATH="$HOME/.claude/gdrive-credentials.json"
export GDRIVE_OAUTH_PATH="$HOME/.claude/gdrive-oauth.json"
exec npx -y @modelcontextprotocol/server-gdrive --stdio
