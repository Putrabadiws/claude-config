# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Repo Is

Shared Claude Code configuration for the Bangor team. The `config/` directory gets copied to `~/.claude` to provide consistent rules, skills, hooks, and permissions across all team members.

## New User Setup (Onboarding Flow)

**IMPORTANT**: If this is a new session and the user hasn't given a specific task, proactively ask: "Would you like to set up your environment? Run `/init` to get started."

The `/init` skill is the single source of truth for the onboarding flow. Run it — it handles everything interactively:

- Environment detection (macOS/Linux/WSL/Windows)
- Workspace discovery
- Core tool installation (bash, git, jq, curl, gh)
- Config installation with smart merge (contextual diff analysis)
- Managed settings (system-level security policies)
- Path personalization
- Optional dependency verification
- Welcome message with next steps

All steps use `AskUserQuestion` selection UI and `TaskCreate` progress tracking. See `.claude/skills/init/SKILL.md` for full details.

## Structure

```
├── .claude/
│   └── skills/                       # Project-level skills (only available in this repo)
│       └── init/SKILL.md             # Onboarding skill — /init
├── config/
│   ├── CLAUDE.md                     # Global user instructions → ~/.claude/CLAUDE.md
│   ├── mcp-figma.sh                  # Figma MCP server launcher → ~/.claude/mcp-figma.sh
│   ├── mcp-gdrive.sh                 # Google Drive MCP server launcher → ~/.claude/mcp-gdrive.sh
│   ├── settings-macos.json           # macOS permissions/hooks → ~/.claude/settings.json
│   ├── settings-windows.json         # Windows permissions/hooks → ~/.claude/settings.json
│   ├── statusline.sh                 # Statusline script → ~/.claude/statusline.sh
│   ├── managed-settings-macos.json   # macOS managed settings (system-level, requires sudo)
│   ├── managed-settings-windows.json # Windows managed settings (system-level, requires admin)
│   ├── agents/                       # Custom agent definitions (code-reviewer, debugger)
│   ├── hooks/                        # PreToolUse/PostToolUse/SessionStart shell scripts
│   ├── rules/
│   │   ├── docs-maintenance.md       # Doc update triggers
│   │   ├── docs-convention.md        # Format for convention docs
│   │   ├── prod-safety.md            # Production environment guardrails
│   │   ├── python-env.md             # Python venv conventions
│   │   ├── style-*.md                # Language style rules (auto-load via paths frontmatter)
│   │   ├── shell-macos.md            # macOS only
│   │   └── shell-windows.md          # Windows only
│   └── skills/                       # Team-shared skills → ~/.claude/skills/
│       ├── <name>/SKILL.md           # Skill definition (frontmatter + instructions)
│       ├── <name>/templates/         # Some skills have template files
│       └── <name>/references/        # Some skills have reference docs
└── README.md
```

### Path Placeholder Convention

Skills and rules use `<workspace>` as a placeholder for the user's actual workspace path. During onboarding (step 6), this gets replaced with the real path in the installed copy at `~/.claude/`.

## Making Changes

**Skills**: Each skill in `config/skills/<name>/SKILL.md`. Frontmatter fields: `name`, `description`, `argument-hint`, `allowed-tools`. Some skills include `templates/` or `references/` subdirectories for supporting files. Follow existing patterns.

**Rules**: Add `.md` files to `config/rules/`. Use `paths` frontmatter to auto-load by file pattern (e.g., `paths: ["**/*.go"]`). Rules without `paths` are always loaded.

**Hooks**: Shell scripts in `config/hooks/`. Contract:
- Receive JSON on stdin with `tool_input` (varies by hook event)
- Must output valid JSON: either `{"hookSpecificOutput": {"hookEventName": "...", "additionalContext": "..."}}` or `{"suppressOutput": true}`
- Exit codes: `0` = allow, `1` = warn/suggest (non-blocking), `2` = block the tool call
- Must be executable (`chmod +x`)
- Use `jq` for safe JSON parsing/creation (gracefully degrade if missing)

**Permissions**: Edit `config/settings-macos.json` and/or `config/settings-windows.json`. Evaluation order: `deny` > `ask` > `allow` (first match wins). Keep both files in sync for shared permissions; only OS-specific entries should differ.

**Managed Settings**: Edit `config/managed-settings-macos.json` and/or `config/managed-settings-windows.json`. These are system-level configs that **cannot be overridden** by user or project settings. Installed to:
- macOS: `/Library/Application Support/ClaudeCode/managed-settings.json` (requires `sudo`)
- Linux/WSL: `/etc/claude-code/managed-settings.json` (requires `sudo`)
- Windows: `%PROGRAMDATA%\ClaudeCode\managed-settings.json` (requires admin)

Key enforced fields:
- `allowManagedPermissionRulesOnly: "true"` — user/project permission rules are ignored
- `disableBypassPermissionsMode: "disable"` — prevents `--dangerously-skip-permissions`
- `CLAUDE_CODE_ENABLE_TELEMETRY: false` — no telemetry
- `additionalDirectories` — uses `<workspace>` placeholders, personalized during onboarding

## How It All Fits Together

This repo is a **config distribution mechanism**, not a runtime application. The flow:

1. User clones this repo and runs onboarding (or manually copies)
2. `config/` contents get copied to `~/.claude/` (the Claude Code user config directory)
3. Claude Code reads `~/.claude/` at session start — rules, hooks, permissions, skills all take effect
4. User works in other Bangor repos; the installed config provides shared conventions

**Config is source-of-truth here, `~/.claude/` is the deployed copy.** When updating config, edit files in this repo first, then re-copy to `~/.claude/` (or re-run onboarding). Personal customizations go directly in `~/.claude/` and are not tracked here.

### Safety Layers

All hooks require `bash` (3.2+) and `jq`. See onboarding step 4 for install instructions.

The hooks and permissions form a defense-in-depth safety system:
- `settings.json` permissions: first gate — `deny` blocks before hooks run, `ask` prompts the user
- `validate-destructive.sh`: catches dangerous git/system/SQL commands that slip through
- `validate-db-readonly.sh`: enforces read-only for all database CLI tools (psql, redis-cli, mongo, OpenSearch)
- `docs-check.sh`: reminds to update docs when committing changes to APIs, schemas, configs, deployments
- `require-tests.sh`: blocks commits with source code changes but no test files staged (Java, Go, TS, Python)
- `lint-check.sh`: auto-lints files after Edit/Write (async, non-blocking)
- `inject-claude-version.sh`: two-layer version injection — rewrites literal `{{claude-code-version}}`/`{{claude-model}}` placeholders via `updatedInput`, and provides `additionalContext` as fallback when the LLM resolves tokens itself
- `check-config-update.sh`: daily check (on session startup) if the team `bangor-claude-config` repo has new commits on `origin/main`; writes `.config-update-pending` flag for statusline notification
- `github-context.sh`: injects GitHub PR / branch conventions once per session when inside a git repo
- `check-pr-after-push.sh`: post-`git push` reminder if the pushed branch has no open PR
- `session-context.sh`: injects k8s context, git branch, project type at session start; persists version and model to `~/.claude/.session-env` for other hooks

## Testing Changes

Start a new Claude Code session to pick up changes. Config files are read once at session start.

For hooks specifically:
```bash
chmod +x config/hooks/*.sh
# Test a hook manually:
echo '{"tool_input": {"command": "git reset --hard"}}' | ./config/hooks/validate-destructive.sh
```

## Gotchas

- **Two settings files**: `settings-macos.json` and `settings-windows.json` must stay in sync for shared permissions. Only OS-specific entries (e.g., paths, shell tools) should differ.
- **Hook exit codes matter**: `exit 1` warns but allows; `exit 2` blocks. Using the wrong one changes behavior significantly.
- **Skills reference local files with relative paths**: Some skills use `references/` subdirectories. These paths are relative to the SKILL.md location, so the directory structure must be preserved during copy.
- **WSL has a separate `~/.claude`**: WSL's home (`/home/<user>`) is different from Windows home (`C:\Users\<user>`). If the user runs Claude Code in both WSL and Windows terminals, they need config in both locations.
- **Windows hooks require `bash` in PATH**: `settings-windows.json` invokes hooks via `bash ~/.claude/hooks/<script>.sh`. Git Bash provides this, but verify `bash` is in PATH for cmd/PowerShell environments.
- **Managed settings override everything**: When `allowManagedPermissionRulesOnly` is set, user-level (`~/.claude/settings.json`) and project-level (`.claude/settings.json`) permission rules are **ignored**. Only managed settings permissions apply. Keep managed settings in sync with user-level settings when adding new permissions.
- **Two managed settings files**: Like `settings-*.json`, `managed-settings-macos.json` and `managed-settings-windows.json` must stay in sync for shared permissions. Only OS-specific entries should differ.
