# claude-config

Shared Claude Code configuration for the Bangor team.

## What's Included

| Path | Description |
|------|-------------|
| `config/` | Files installed to `~/.claude/` (the "always" set) |
| `config/CLAUDE.md` | Global instructions (style, behavior, quick reference) |
| `config/settings.json` | Combined permissions/hooks → `~/.claude/settings.json` (install substitutes the `<bash for windows only>` placeholder per OS) |
| `config/managed-settings.json` | System-level managed settings → installed to OS-specific managed-settings path (see Setup) |
| `config/agents/` | Custom agent definitions (code-reviewer, debugger) |
| `config/hooks/` | PreToolUse/PostToolUse shell scripts (cross-platform) |
| `config/rules/` | Auto-loaded context rules (includes OS-specific shell rules) |
| `config/skills/` | Team-shared slash commands → `~/.claude/skills/` |
| `config/_lib/` | Shared shell helpers (test harness, compat wrappers) → `~/.claude/_lib/` |
| `config/claude-find.sh` | Session history search function (shell) |
| `config/claude-find-parse.py` | Session JSONL parser for claude-find and claude-resume |
| `config/claude-resume.py` | Terminal startup script showing recent sessions to resume |
| `mcp/` | MCP server bundles (mirrored install — each `<service>/` folder copies to `~/.claude/mcp/<service>/`) |
| `mcp/figma/` | Figma MCP launcher + env template (Keychain fallback) |
| `mcp/gdrive/` | Google Drive MCP launcher (OAuth credentials co-located) |
| `.claude/skills/` | Project-level skills (e.g., `/init`, `/sync-config` — only available in this repo) |

## Setup

### Option A: Guided Setup (Recommended)

1. Clone this repo:
   ```bash
   git clone <repo-url> ~/bangor-claude-config
   ```

2. Start Claude Code in this directory and run `/init`:
   ```bash
   cd ~/bangor-claude-config && claude
   ```
   ```
   > /init
   ```

   This will:
   - Detect your OS (macOS/Windows/WSL)
   - Ask for your workspace location
   - Handle existing `~/.claude` config (backup/merge)
   - Copy OS-appropriate files (settings, shell rules)
   - Personalize paths in config files
   - Check all dependencies are installed (offer to install missing ones)

### Option B: Manual Setup

#### 1. Clone

```bash
git clone <repo-url> ~/bangor-claude-config
```

#### 2. Copy config to ~/.claude

Back up your existing config first if you have one:

```bash
# Backup existing config
[ -d ~/.claude ] && mv ~/.claude ~/.claude.bak

# Create ~/.claude and copy shared files
mkdir -p ~/.claude
cp ~/bangor-claude-config/config/CLAUDE.md ~/.claude/
cp -r ~/bangor-claude-config/config/agents ~/.claude/
cp -r ~/bangor-claude-config/config/hooks ~/.claude/
cp -r ~/bangor-claude-config/config/skills ~/.claude/

# Copy rules (exclude wrong OS shell file)
mkdir -p ~/.claude/rules
cp ~/bangor-claude-config/config/rules/*.md ~/.claude/rules/
# macOS: rm ~/.claude/rules/shell-windows.md
# Windows: rm ~/.claude/rules/shell-macos.md

# Install settings.json — substitute the <bash for windows only> placeholder per OS:
# macOS / Linux / WSL (drop the placeholder so hooks run directly):
sed 's/<bash for windows only>//g' ~/bangor-claude-config/config/settings.json > ~/.claude/settings.json
# Windows (Git Bash) — replace placeholder with `bash ` so hooks run via bash:
sed 's/<bash for windows only>/bash /g' ~/bangor-claude-config/config/settings.json > ~/.claude/settings.json
```

#### 3. Make hooks executable

```bash
chmod +x ~/bangor-claude-config/config/hooks/*.sh
```

#### 4. Set your model (optional)

The shared config doesn't set a model. Add your preferred model to `~/.claude/settings.json`:

```json
{
  "model": "sonnet"
}
```

Or set it per-session: `claude --model opus`

## Available Skills

| Skill | Description |
|-------|-------------|
| `/commit` | Git commit with conventional format |
| `/mr-review` | Thorough PR review |
| `/test` | Run tests (auto-detects project type) |
| `/lint` | Run linter (auto-detects project type) |
| `/logs` | View and analyze kubectl logs |
| `/db` | Database queries (PostgreSQL, Redis, OpenSearch) |
| `/api-test` | Test API endpoints |
| `/migration` | Database migrations (Liquibase, Alembic) |
| `/env-check` | Validate environment setup |
| `/pre-commit` | Setup pre-commit hooks |
| `/k8s` | Kubernetes troubleshooting and component guides |
| `/new-service` | Scaffold new microservice |
| `/style-*` | Language-specific style guides (go, python, react, spring) |

## Hooks

| Hook | Trigger | Purpose |
|------|---------|---------|
| `validate-destructive.sh` | PreToolUse (Bash) | Blocks dangerous git/system commands |
| `validate-db-readonly.sh` | PreToolUse (Bash) | Enforces read-only database access |
| `docs-check.sh` | PreToolUse (Bash) | Reminds to update docs on git commit |
| `github-context.sh` | PreToolUse (Bash) | Injects GitHub/PR conventions in git repos |
| `lint-check.sh` | PostToolUse (Edit/Write) | Auto-lint after file changes |
| `check-pr-after-push.sh` | PostToolUse (Bash, git push) | Reminds if pushed branch has no open PR |
| `session-context.sh` | SessionStart | Injects environment context |

## External Integrations (macOS)

The `/init` skill sets these up automatically. Manual setup:

| Integration | Auth | What it provides |
|---|---|---|
| **Figma** | API key in Keychain (`figma-api-key`) | Design data and image export via MCP server |
| **Google Drive** | OAuth client JSON + token | Google Docs/Sheets via MCP server |

Secrets are stored in macOS Keychain and exported via `~/.zshenv`. MCP servers are registered with `claude mcp add` and use launcher scripts at `~/.claude/mcp/<service>/mcp-<service>.sh` (mirrored from `mcp/<service>/` in this repo).

## Customization

Add personal overrides to your `~/.claude/settings.json`. Claude Code merges settings from multiple sources.

### Personal additions you might want

```json
{
  "model": "opus",
  "alwaysThinkingEnabled": true
}
```

## Notes

- Uses `gh` for GitHub operations
- Rules in `rules/` are auto-loaded by Claude Code based on `paths` frontmatter
