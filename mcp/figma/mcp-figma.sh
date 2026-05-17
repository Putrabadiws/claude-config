#!/bin/bash
# Figma MCP server launcher
# Setup: copy figma.env.sample to figma.env (next to this launcher) and fill in
# your API key. Alternatively on macOS:
#   security add-generic-password -a "$USER" -s "figma-api-key" -w "<token>"

# Resolve env file relative to this script (mirrored install layout).
LAUNCHER_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -f "$LAUNCHER_DIR/figma.env" ]; then
  set -a; source "$LAUNCHER_DIR/figma.env"; set +a
fi
# macOS Keychain fallback
if [ -z "$FIGMA_API_KEY" ] && command -v security &>/dev/null; then
  FIGMA_API_KEY=$(security find-generic-password -a "$USER" -s "figma-api-key" -w 2>/dev/null)
  export FIGMA_API_KEY
fi
if [ -n "${TEST_NO_EXEC:-}" ]; then
  echo "FIGMA_API_KEY=${FIGMA_API_KEY:-}"
  exit 0
fi
exec npx -y figma-developer-mcp --stdio
