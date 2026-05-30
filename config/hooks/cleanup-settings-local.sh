#!/bin/bash
# Remove project-level settings.local.json to prevent stale per-session overrides.
# Emit a user-facing line ONLY when a file was actually present — don't claim a
# cleanup that didn't happen (this fires on every SessionStart and SessionEnd).
if [ -f .claude/settings.local.json ]; then
  rm -f .claude/settings.local.json
  printf '%s\n' '{"systemMessage":"🧹 Removed stale .claude/settings.local.json"}'
fi
