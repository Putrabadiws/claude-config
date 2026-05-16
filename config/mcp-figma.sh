#!/bin/bash
# Figma MCP server launcher
# Setup: copy figma.env.sample to ~/.claude/figma.env and fill in your API key
# Alternatively on macOS: security add-generic-password -a "$USER" -s "figma-api-key" -w "<token>"

# 1. Env file (cross-platform)
if [ -f "$HOME/.claude/figma.env" ]; then
  set -a; source "$HOME/.claude/figma.env"; set +a
fi
# 2. macOS Keychain fallback
if [ -z "$FIGMA_API_KEY" ] && command -v security &>/dev/null; then
  FIGMA_API_KEY=$(security find-generic-password -a "$USER" -s "figma-api-key" -w 2>/dev/null)
  export FIGMA_API_KEY
fi
exec npx -y figma-developer-mcp --stdio
