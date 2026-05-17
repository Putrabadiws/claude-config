---
name: bangor-sync-config
description: Pull latest from the bangor-claude-config repo and run the canonical sync skill from there. Thin wrapper — real logic lives in the repo so updates auto-propagate.
disable-model-invocation: true
allowed-tools: Bash(git *), Bash(cat *), Read
---

# `/bangor-sync-config` (wrapper)

This is a thin wrapper. The real sync logic lives in the repo at `.claude/skills/sync-config/SKILL.md` and is always pulled fresh on every invocation — no stale-skill problem.

## Steps

1. Resolve the repo path:
   ```bash
   REPO=$(cat ~/.claude/.config-repo-path 2>/dev/null)
   if [ -z "$REPO" ]; then
     echo "ERROR: ~/.claude/.config-repo-path missing. Run /init first to onboard." >&2
     exit 1
   fi
   if [ ! -d "$REPO/.git" ]; then
     echo "ERROR: $REPO is not a git repo. Re-run /init or fix the path file." >&2
     exit 1
   fi
   ```

2. Pull latest. **If pull fails (offline, auth issue), STOP** and ask the user to fix the connectivity issue, then re-invoke `/bangor-sync-config`:
   ```bash
   if ! git -C "$REPO" pull --quiet 2>&1; then
     echo "ERROR: Could not pull latest from $REPO." >&2
     echo "Possible causes: offline, git auth expired, network issue." >&2
     echo "Fix the connectivity issue, then re-invoke /bangor-sync-config." >&2
     exit 1
   fi
   ```

3. Read the canonical sync skill from the freshly-pulled repo and follow its instructions:
   - Use the `Read` tool on `$REPO/.claude/skills/sync-config/SKILL.md`.
   - Execute every step in that file exactly as written.
   - The canonical handles: stale-install self-bootstrap (Step 0), then incremental sync of `~/.claude/` from `config/`.
