---
name: sync-config
description: Sync local ~/.claude/ config with the team bangor-claude-config repo.
disable-model-invocation: true
allowed-tools: Bash(git *), Bash(gh *), Bash(cp *), Bash(chmod *), Bash(diff *), Bash(ls *), Bash(cat *), Bash(date *), Bash(mkdir *), Read, Grep, Glob, Edit, Write
---

# /sync-config

Sync local `~/.claude/` config with the team's `bangor-claude-config` repo. This skill is **never auto-invoked** — only runs when the user explicitly types `/sync-config`.

## Pre-flight

1. Read `~/.claude/.config-repo-path` to get the repo location
2. If file doesn't exist → ask user for the path to their `bangor-claude-config` clone, then write it to `~/.claude/.config-repo-path`
3. Verify the path exists and is a git repo

## Step 1: Prepare the repo

1. Check `git -C <repo> status` for uncommitted changes (tracked and untracked)
2. If uncommitted changes exist:
   - Show the user what's dirty
   - `git -C <repo> stash push -m "sync-config: auto-stash before sync"`
   - Track that we stashed (need to pop later)
3. `git -C <repo> checkout main`
4. `git -C <repo> pull origin main`

## Step 2: Compare all config files

Compare every file in the repo's `config/` against the installed copy in `~/.claude/`.

### File mapping

| Repo path | Installed path | Notes |
|-----------|---------------|-------|
| `config/CLAUDE.md` | `~/.claude/CLAUDE.md` | |
| `config/statusline.sh` | `~/.claude/statusline.sh` | |
| `config/hooks/*.sh` | `~/.claude/hooks/*.sh` | Except `path-bootstrap.sh` which is shared util |
| `config/hooks/github-rules.md` | `~/.claude/hooks/github-rules.md` | |
| `config/rules/*.md` | `~/.claude/rules/*.md` | |
| `config/skills/*/` (entire dir) | `~/.claude/skills/*/` | Compare **all files** recursively — SKILL.md, `references/`, `templates/`, loose `.md` files |
| `config/agents/*.md` | `~/.claude/agents/*.md` | |
| `config/claude-find.sh` | `~/.claude/claude-find.sh` | Shell function for session search |
| `config/claude-find-parse.py` | `~/.claude/claude-find-parse.py` | Python parser for session JSONL |
| `config/claude-resume.py` | `~/.claude/claude-resume.py` | Terminal startup resume hint |
| `config/settings-macos.json` | `~/.claude/settings.json` | macOS/Linux only — **special merge logic** |
| `config/settings-windows.json` | `~/.claude/settings.json` | Windows only — **special merge logic** |
| `config/managed-settings-macos.json` | See below | macOS/Linux only — **requires sudo**, special merge logic |
| `config/managed-settings-windows.json` | See below | Windows only — **requires admin**, special merge logic |

### Detect OS for settings/managed-settings file selection

```bash
case "$(uname -s)" in
  MINGW*|MSYS*|CYGWIN*)
    SETTINGS_SRC="config/settings-windows.json"
    MANAGED_SRC="config/managed-settings-windows.json"
    MANAGED_DST="%PROGRAMDATA%/ClaudeCode/managed-settings.json"
    ;;
  Darwin)
    SETTINGS_SRC="config/settings-macos.json"
    MANAGED_SRC="config/managed-settings-macos.json"
    MANAGED_DST="/Library/Application Support/ClaudeCode/managed-settings.json"
    ;;
  Linux)
    SETTINGS_SRC="config/settings-macos.json"
    MANAGED_SRC="config/managed-settings-macos.json"
    MANAGED_DST="/etc/claude-code/managed-settings.json"
    ;;
esac
```

### Skip platform-irrelevant files

Based on detected OS, **completely exclude** the other platform's files from comparison. Do not prompt, do not mention — just skip silently.

| Current OS | Skip these repo files |
|------------|----------------------|
| macOS/Linux | `config/settings-windows.json`, `config/managed-settings-windows.json`, `config/rules/shell-windows.md` |
| Windows | `config/settings-macos.json`, `config/managed-settings-macos.json`, `config/rules/shell-macos.md` |

### Managed settings: special rules

- Installed to **system paths** (not `~/.claude/`), requires `sudo` (macOS/Linux) or admin (Windows)
- Same merge logic as `settings.json` — union arrays, don't overwrite wholesale
- `additionalDirectories` uses `<workspace>/` placeholders in repo — compare content structure, not literal paths
- If managed-settings doesn't exist at the system path yet, ask user before creating (first install requires elevated permissions)
- If update is needed, warn user that `sudo` will be required before proceeding

### For each non-skill file pair, categorize:

1. **Only in repo** → new file from team (to apply).
2. **Only in `~/.claude/`** → personal customization. Leave alone, skip silently.
3. **Both exist, identical** → skip.
4. **Both exist, different** → requires contextual analysis (Step 3).

List all non-skill files in both locations, categorize every pair. Read BOTH versions fully for every file that differs — no shortcuts, no assumptions.

### Skills: bash-driven enumeration (CRITICAL)

**Do NOT enumerate skills manually or include them in the file-by-file comparison above.** Skills are handled separately using bash to guarantee none are missed:

```bash
cd <repo-path>
mkdir -p ~/.claude/skills
for skill_dir in config/skills/*/; do
  name=$(basename "$skill_dir")
  if [ ! -d ~/.claude/skills/"$name" ]; then
    echo "NEW:$name"
  elif diff -rq "$skill_dir" ~/.claude/skills/"$name"/ >/dev/null 2>&1; then
    echo "SAME:$name"
  else
    echo "DIFF:$name"
  fi
done
```

Process each category:

- **NEW** → copy immediately, no prompt needed: `cp -r config/skills/<name> ~/.claude/skills/`
- **SAME** → skip silently
- **DIFF** → for each conflicting skill, read both SKILL.md versions and resolve:
  - Repo is strictly newer/better (new sections, bug fixes, new features) → overwrite local
  - Local has improvements repo doesn't have → keep local, flag for sync-back
  - Both have unique changes → smart merge (combine both improvements)
  - When unclear → ask user with AskUserQuestion (same conflict UI as Step 4)

Include skill results in the Step 3 summary alongside non-skill files.

## Step 3: Present findings overview

After analyzing all files, present a **summary overview** grouped by action type:

```
Here's what I found:

From repo → local (N files):
  - skills/qa-scenario/SKILL.md — new skill
  - skills/frontend-perf-audit/SKILL.md — fix CRLF line endings

Sync-back to repo (N files with local improvements):
  - hooks/check-pr-after-push.sh — stronger PR verification wording
  - hooks/github-rules.md — new branch protection section added

Skipped (identical or personal): settings.json, shell-macos.md, ...

I'll walk through each change one by one for your approval.
```

## Step 4: Apply changes ONE BY ONE (CRITICAL)

**DO NOT batch changes. DO NOT proceed without confirmation on each item.**

Process files one at a time (repo → local first, then sync-back). For each file:

1. Present a brief description (1-2 sentences) of what changed and why
2. Use `AskUserQuestion` with the selection UI — never free-text y/n

### For new files from repo:

Present the description, then:
```
AskUserQuestion:
  question: "[1/N] New file: skills/qa-scenario/SKILL.md — QA scenario generation skill for creating structured test scenarios from PRDs with Playwright integration. Apply?"
  header: "New file"
  options:
    - label: "Apply"
      description: "Copy this new file to ~/.claude/"
    - label: "Skip"
      description: "Don't apply this file"
```

### For updated files from repo:

```
AskUserQuestion:
  question: "[2/N] Update: skills/frontend-perf-audit/SKILL.md — fixed CRLF line endings to LF, no content changes. Apply?"
  header: "Update"
  options:
    - label: "Apply"
      description: "Overwrite local with repo version"
    - label: "Skip"
      description: "Keep current local version"
```

### For files where local is better (sync-back):

```
AskUserQuestion:
  question: "[3/N] Sync-back: hooks/check-pr-after-push.sh — your local version has stronger PR verification wording and warning when branch has no open PR. Sync to team repo?"
  header: "Sync-back"
  options:
    - label: "Sync to repo"
      description: "Copy local improvements to bangor-claude-config and open a PR"
    - label: "Skip"
      description: "Keep local only, don't sync to team"
```

### For files where both have improvements:

```
AskUserQuestion:
  question: "[4/N] Merge needed: hooks/github-rules.md — repo has new CI components, local has additional branch protection section. How to proceed?"
  header: "Merge"
  options:
    - label: "Merge both (Recommended)"
      description: "Combine improvements from both versions, apply locally, and sync back to repo"
    - label: "Keep local"
      description: "Keep your version as-is, skip repo changes"
    - label: "Take repo"
      description: "Overwrite with repo version, discard local improvements"
    - label: "Skip"
      description: "Don't touch this file"
```

### Rules for the interactive flow:

- **One AskUserQuestion per file** — wait for response before proceeding to next
- After each response, immediately execute the chosen action before presenting the next file
- Keep a running tally: "Applied 3/7, skipped 1, synced 2, 1 remaining"
- Brief but informative — 1-2 sentences in the question explaining WHAT changed
- For new files: describe the purpose/functionality of the new content
- For updates: describe what specifically changed
- For sync-back: explain what's better in the local version

## Step 5: Execute sync-back PRs

After all individual items are confirmed, execute sync-back for approved items:

1. In the bangor-claude-config repo, create a single branch for all sync-backs:
   ```
   git checkout -b sync/local-improvements-<date>
   ```
2. Copy each approved sync-back file to the repo's `config/` path
3. For any files containing personalized workspace paths: convert real paths back to `<workspace>/` placeholders before copying
4. Commit all sync-back files together:
   ```
   git add <changed files>
   git commit -m "sync: local config improvements

   - <brief description of each file>"
   ```
5. Push and create PR:
   ```
   git push origin <branch>
   gh pr create --title "sync: local config improvements" --body "..." --base main
   ```
6. Report the PR URL to user

### Special handling: settings.json

**NEVER overwrite settings.json wholesale.** Smart merge only:

| Section | Strategy |
|---------|----------|
| `permissions.allow` | Union — add new entries from repo, keep local extras |
| `permissions.deny` | Union — add new entries from repo, keep local extras |
| `permissions.ask` | Union — add new entries from repo, keep local extras |
| `permissions.additionalDirectories` | **Keep local** — these are user-specific paths |
| `hooks.*` (each event array) | Union hook entries by command path; if same command exists in both, prefer repo version |
| `statusLine` | Take repo version |
| `enabledPlugins` | Union — add new plugins from repo, keep local extras |
| `effortLevel`, `alwaysThinkingEnabled`, etc. | Keep local (personal preference) |

After merging, write the result to `~/.claude/settings.json`.

### Special handling: files with `<workspace>` paths

Some files contain personalized workspace paths (local has real paths, repo has `<workspace>/` placeholders).

When comparing any of these files:
- Ignore path differences — only compare the actual content/structure around the paths
- If repo has new sections → add them to local (substituting `<workspace>` with actual path)
- If local has content improvements → sync back to repo (convert real paths back to `<workspace>/` placeholders)

### Expected differences injected by `init` skill (do NOT flag as sync-back)

The `init` skill appends optional blocks to `~/.claude/CLAUDE.md` during onboarding. These are **expected local-only additions** — never propose syncing them back to the team repo.

| File | Section | Injected by |
|------|---------|-------------|
| `~/.claude/CLAUDE.md` | `# Session History` block (claude-find docs) | `init` skill, conditional on user opting into claude-find install |

When diffing `CLAUDE.md`, if the only local-extra content is one of these known-injected blocks, skip it silently — do not flag it in the findings summary.

## Step 6: Finalize

1. **Verify skills** — confirm no skills were missed:
   ```bash
   echo "Repo skills: $(ls -1d <repo>/config/skills/*/ 2>/dev/null | wc -l | tr -d ' ')"
   echo "Local skills: $(ls -1d ~/.claude/skills/*/ 2>/dev/null | wc -l | tr -d ' ')"
   ```
   Local count should be >= repo count (user may have personal skills). If local < repo, re-run the skill enumeration — something was missed.

2. Make all hooks and scripts executable:
   ```bash
   chmod +x ~/.claude/hooks/*.sh ~/.claude/statusline.sh ~/.claude/*.sh
   ```

3. Stamp version:
   ```bash
   git -C <repo> rev-parse HEAD > ~/.claude/.config-version
   ```

4. Stamp check time:
   ```bash
   date +%s > ~/.claude/.config-last-check
   ```

5. Remove the update notification flag (stops statusline banner):
   ```bash
   rm -f ~/.claude/.config-update-pending
   ```

6. If we stashed in Step 1:
   ```bash
   git -C <repo> checkout <original-branch>
   git -C <repo> stash pop
   ```
   If pop has conflicts → warn user, do NOT silently drop the stash.

## Step 7: Summary

Present a clear summary:

```
Update complete.

Applied from repo:
  - hooks/check-config-update.sh (new)
  - skills/mr-review/SKILL.md (updated)
  - ...

Synced back to repo (PR opened):
  - hooks/github-rules.md → PR #123: sync(hooks): improved branch protection docs
  - ...

Skipped (identical):
  - hooks/validate-destructive.sh
  - ...

Personal files (untouched):
  - rules/my-custom-rule.md
  - ...

Config version: abc1234 (origin/main)
```
