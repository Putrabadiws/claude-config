---
name: init
description: Onboard new user - detect environment, install team config, set up tools and workspace paths.
argument-hint: [workspace path (optional)]
allowed-tools: Bash, Read, Write, Edit, Glob, Grep, AskUserQuestion, TaskCreate, TaskUpdate, TaskList
---

# Bangor Onboarding

Run the full onboarding flow for a new team member. This sets up `~/.claude/` with the team's shared config from this repo (`config/`).

If the user provided a workspace path as argument, use it directly (skip asking in step 1).

## Progress Tracking

Create these tasks at the start using `TaskCreate`, then update each with `TaskUpdate` as you go:

1. Detect environment
2. Get workspace location
3. Install core tools
4. Check existing config and install
5. Install managed settings (optional)
6. Personalize paths
7. Verify optional dependencies
8. Summary

Mark each task `in_progress` when starting, `completed` when done. If a step is skipped, mark it `completed` with a short note.

## Step 0: Detect Environment

Run:
- `uname -s` to detect OS
- `command -v bash` to confirm bash is available

Determine the environment:

| `uname -s` | Extra check | ENV |
|-------------|-------------|-----|
| `Darwin` | — | `macos` |
| `Linux` | `grep -qi microsoft /proc/version` → true | `wsl` |
| `Linux` | otherwise | `linux` |
| `MINGW64*` / `MSYS*` | — | `gitbash` |
| `CYGWIN*` | — | `cygwin` |

**Config mapping** (use throughout):

| ENV | Settings file | Shell rule | Notes |
|-----|--------------|------------|-------|
| `macos`, `linux` | `settings-macos.json` | `shell-macos.md` | |
| `wsl` | `settings-windows.json` | `shell-macos.md` | Linux paths, but may access `/mnt/c/` |
| `gitbash`, `cygwin` | `settings-windows.json` | `shell-windows.md` | Hooks need `bash` in PATH |

## Step 1: Get Workspace Location

Ask the user where they want to keep their Bangor repos. Default suggestion: `~/bangor`.

Use `AskUserQuestion`:
```
question: "Where do you want to store your Bangor repos?"
header: "Workspace path"
options:
  - label: "~/bangor (Recommended)"
    description: "Standard team workspace path"
  - label: "Custom path"
    description: "Enter your own path"
```

Create the directory if it doesn't exist:
```bash
mkdir -p "$WORKSPACE"
```

Persist the chosen path — it will replace every `<workspace>` placeholder during step 6.

## Step 2: Install Core Tools

Verify these tools are present. For each missing one, offer to install via the platform package manager:

| Tool | Why | macOS | Linux | Windows |
|------|-----|-------|-------|---------|
| `bash` 3.2+ | Hooks runtime | preinstalled | preinstalled | Git Bash |
| `git` | VCS | `brew install git` | `apt install git` | Git for Windows |
| `jq` | Hook JSON parsing | `brew install jq` | `apt install jq` | `choco install jq` |
| `curl` | Network checks | preinstalled | preinstalled | preinstalled |
| `gh` | GitHub CLI | `brew install gh` | follow docs.github.com | `winget install --id GitHub.cli` |

After install, run `gh auth status` and prompt the user to `gh auth login` if not authenticated.

## Step 3: Check Existing Config

Before copying anything, check if `~/.claude/` exists:

```bash
ls -la ~/.claude 2>/dev/null
```

If it exists, use `AskUserQuestion`:
```
question: "~/.claude/ already exists. What should I do?"
header: "Existing config"
options:
  - label: "Back up and replace (Recommended)"
    description: "Move existing to ~/.claude.bak.YYYYMMDD and install fresh"
  - label: "Merge — keep my customizations"
    description: "Diff each file, only copy missing/changed shared files; preserve local-only files"
  - label: "Abort"
    description: "Cancel installation, leave existing config untouched"
```

For "merge" mode: walk through each shared file and present a per-file decision when content differs.

### Files to install

| Source (in `config/`) | Destination |
|-----------------------|-------------|
| `CLAUDE.md` | `~/.claude/CLAUDE.md` |
| `settings-<os>.json` | `~/.claude/settings.json` |
| `statusline.sh` | `~/.claude/statusline.sh` |
| `mcp-figma.sh` | `~/.claude/mcp-figma.sh` (optional) |
| `mcp-gdrive.sh` | `~/.claude/mcp-gdrive.sh` (optional) |
| `agents/` | `~/.claude/agents/` |
| `hooks/` | `~/.claude/hooks/` |
| `skills/` | `~/.claude/skills/` |
| `rules/` (filter shell-*) | `~/.claude/rules/` |
| `claude-find*.{sh,py}`, `claude-resume.py` | `~/.claude/` |

For `rules/`, copy all `.md` except the OS-specific one that doesn't match. E.g. on macOS, remove `shell-windows.md`.

Make hooks and shell scripts executable:
```bash
chmod +x ~/.claude/hooks/*.sh ~/.claude/statusline.sh ~/.claude/*.sh
```

Persist the config-repo path so `check-config-update.sh` can use it:
```bash
echo "/abs/path/to/bangor-claude-config" > ~/.claude/.config-repo-path
```

## Step 4: Install Managed Settings (Optional)

Managed settings are system-level policies that **cannot be overridden** by user config. They enforce `allowManagedPermissionRulesOnly`, disable bypass mode, and lock down telemetry.

Ask the user via `AskUserQuestion`:
```
question: "Install managed (system-level) settings? Requires sudo / admin."
header: "Managed settings"
options:
  - label: "Yes, enforce team policy (Recommended)"
    description: "Locks down permission rules to managed allow-list — safer for prod work"
  - label: "Skip"
    description: "Use only user-level settings. Less restrictive."
```

If yes:
- macOS: `sudo cp config/managed-settings-macos.json "/Library/Application Support/ClaudeCode/managed-settings.json"`
- Linux/WSL: `sudo cp config/managed-settings-macos.json /etc/claude-code/managed-settings.json`
- Windows: copy `config/managed-settings-windows.json` to `%PROGRAMDATA%\ClaudeCode\managed-settings.json` (admin shell)

## Step 5: Personalize Paths

Replace every `<workspace>` placeholder in installed files with the absolute path captured in step 1.

```bash
WS="<absolute workspace path>"
# Use a grep-then-sed approach so we only touch files containing the token
grep -rl '<workspace>' ~/.claude/ 2>/dev/null \
  | xargs sed -i.bak "s|<workspace>|$WS|g"
# Remove the .bak files sed creates on macOS
find ~/.claude/ -name '*.bak' -delete
```

If the user installed managed settings in step 4, also rewrite `<workspace>` inside the managed settings file at its system path (requires sudo / admin).

## Step 6: Verify Optional Dependencies

Check for tools that some skills use but aren't strictly required:

| Tool | Used by |
|------|---------|
| `kubectl` | `/k8s`, `/logs` |
| `helm` | `/k8s` |
| `psql` | `/db` |
| `redis-cli` | `/db` |
| `ruff` | `/lint` for Python |
| `eslint` | `/lint` for JS/TS |
| `shellcheck` | hook lint |
| `node` ≥ 20 | Some MCP servers |
| `python3` ≥ 3.10 | Some scripts |

For each missing one, report it but don't auto-install — let the user choose later.

## Step 7: Summary

Print a short, actionable summary:

- ✅ Installed config from `bangor-claude-config` to `~/.claude/`
- ✅ Workspace: `$WORKSPACE`
- ⚠️ Missing optional: `<list>` (install when needed)
- 👉 Restart Claude Code to pick up the new config: exit and `claude` again.
- 👉 To stay current with team changes: `cd ~/bangor-claude-config && git pull` periodically; the session-start hook will surface updates automatically.

Do NOT auto-restart for the user — they may have unsaved work.
