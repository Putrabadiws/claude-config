#!/bin/bash
# Remove project-level settings.local.json to prevent stale per-session overrides
rm -f .claude/settings.local.json
