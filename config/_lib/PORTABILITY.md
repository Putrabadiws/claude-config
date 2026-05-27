# Cross-Platform Portability Tracker

Status of each `.sh` script across operating systems. Update this file whenever you verify a script on a new platform or land changes that affect portability.

## How to verify on your OS

1. **Run the full test suite first:**
   ```bash
   bash ~/.claude/_lib/run-all-tests.sh
   ```
   All tests should pass. If any fail, that's a portability bug — open an issue / submit a fix.

2. **Run compat.sh tests in isolation** to confirm the wrappers work:
   ```bash
   bash ~/.claude/_lib/compat.test.sh
   ```
   All 10 helper tests should pass.

3. **For each script you want to verify**, run its `.test.sh` directly:
   ```bash
   bash ~/.claude/hooks/<script>.test.sh
   ```

4. **Mark the matrix below** with `✓` (verified pass), `✗` (verified fail — note the issue), or leave `?` (untested).

5. **If a test fails**, the bug is likely in one of:
   - GNU vs BSD command flag (see "Known divergences" below)
   - Regex GNU extension (`\s`, `\d`, `\w`, `\b`) — should be POSIX classes (`[[:space:]]`, `[0-9]`, `[[:alnum:]_]`)
   - bash 3.x (macOS) vs bash 4+ (Linux) syntax — bash 3.x lacks `${var,,}` lowercase, associative arrays, etc.
   - Path assumption (`/Users/...` vs `/home/...`)

## Known divergences (and how compat.sh solves them)

| Command form | macOS (BSD) | Linux (GNU) | compat.sh wrapper |
|--------------|-------------|-------------|--------------------|
| `date -d "@<epoch>"` | unknown flag | works | `_date_from_epoch <epoch> <fmt>` |
| `date -r <epoch>` | works | unknown flag | (handled by `_date_from_epoch`) |
| `stat -c %Y file` | unknown flag | works | `_file_mtime <file>` |
| `stat -f %m file` | works | unknown flag | (handled by `_file_mtime`) |
| `readlink -f` | absent on old macOS | works | `_realpath_f <path>` |
| `echo -e "\n"` | doesn't interpret | interprets | `_echo_e "<str>"` |
| `sed -i '...'` | BSD requires `''` suffix | works | `_sed_inplace <script> <file>` |
| `sed -E '\\s+'` | doesn't match | matches | Use `[[:space:]]+` (POSIX) |
| `grep -P` (PCRE) | absent | present | Stick to `-E` (ERE) |

## Verification matrix

Legend: ✓ verified pass / ✗ verified fail / ? untested

### Hooks (`~/.claude/hooks/`)

| Script | macOS | Linux | Windows (Git Bash) | Notes |
|--------|-------|-------|--------------------|-------|
| `bangor-context.sh` | ✓ | ? | ? | POSIX [[:space:]] used; no compat.sh needed |
| `block-bulk-config-copy.sh` | ✓ | ? | ? | grep -E with `\s` (works on BSD grep) |
| `check-config-update.sh` | ✓ | ? | ? | Uses git; depends on git availability |
| `check-mr-pr-after-push.sh` | ✓ | ? | ? | Unified glab/gh dispatcher; bash `[[ =~ ]]` regex with `[[:space:]]` |
| `cleanup-settings-local.sh` | ✓ | ? | ? | Trivial `rm -f` — fully portable |
| `docs-check.sh` | ✓ | ? | ? | grep -E with `\s` |
| `gitlab-github-context.sh` | ✓ | ? | ? | Unified gitlab/github dispatcher on remote URL; POSIX [[:space:]] used |
| `inject-claude-version.sh` | ✓ | ? | ? | sed with placeholder substitution — portable |
| `lint-check.sh` | ✓ | ? | ? | Calls external linters; depends on installed tools |
| `path-bootstrap.sh` | ✓ | ? | ✓ (has Windows branch) | OS-detection model script |
| `regex-self-check.sh` | ✓ | ? | ? | grep -E content detection |
| `require-tests.sh` | ✓ | ? | ? | Uses `printf '%b'` (was `echo -e`, fixed) |
| `session-context.sh` | ✓ | ? | ? | Calls git, kubectl |
| `session-end-tracking.sh` | ✓ | ? | ? | mv + jq |
| `validate-db-readonly.sh` | ✓ | ? | ? | grep -E with `\b` word boundary |
| `validate-destructive.sh` | ✓ | ? | ? | Uses `[[:space:]]` in sed (was `\s`, fixed) |

### Top-level (`~/.claude/`)

| Script | macOS | Linux | Windows (Git Bash) | Notes |
|--------|-------|-------|--------------------|-------|
| `statusline.sh` | ✓ | ? | ? | Sources `compat.sh` for `_date_from_epoch` + `_file_mtime`; keeps `_midnight_today` inline (statusline-specific) |

### Library (`~/.claude/_lib/`)

| Script | macOS | Linux | Windows (Git Bash) | Notes |
|--------|-------|-------|--------------------|-------|
| `compat.sh` | ✓ | ? | ? | All 10 helpers exercised by compat.test.sh |
| `test-helpers.sh` | ✓ | ? | ? | Uses jq + mktemp — portable |
| `run-all-tests.sh` | ✓ | ? | ? | `find -name` recursive scan |

## Verification log

When you verify a script on a new OS, append a dated entry here:

- 2026-05-17 — macOS Sequoia 25.5.0, bash 3.2.57, BSD coreutils — all 19 test files, 227 tests pass.
- _Add your entry below..._

## Outstanding

- **Windows (Git Bash / MSYS2) verification** — `path-bootstrap.sh` has Windows branch logic but actual end-to-end testing on a Windows machine hasn't been done.
- **Linux verification** — POSIX patterns and compat wrappers should "just work" but haven't been exercised on a Linux machine in this session.
