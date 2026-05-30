#!/bin/bash
# Tests for compare-all.sh.
#
# Strategy: each test stands up its own tmp repo + tmp local pair, populates
# fixture files, invokes the script with explicit argv (no env coupling),
# greps the stdout output for the expected section/file.
#
# We don't use run_test/run_test_content from test-helpers.sh — those are for
# stdin-driven hooks, not argv-driven scripts. We still pull in PASS/FAIL/
# summary/_test_script_dir/_require_executable so the harness picks us up.

set -u

source "$HOME/.claude/_lib/test-helpers.sh"

SCRIPT="$(_test_script_dir "$0")/compare-all.sh"
_require_executable "$SCRIPT"

# setup_pair → echoes "REPO LOCAL" (two tmp dirs). Caller must rm -rf both.
setup_pair() {
  local repo local_dir
  repo=$(mktemp -d)
  local_dir=$(mktemp -d)
  mkdir -p "$repo/config" "$local_dir"
  echo "$repo $local_dir"
}

# expect_contains NAME OUTPUT PATTERN
expect_contains() {
  local name="$1" out="$2" pat="$3"
  if printf '%s' "$out" | grep -qF -- "$pat"; then
    echo "PASS: $name"
    PASS=$((PASS + 1))
  else
    echo "FAIL: $name (missing pattern: $pat)"
    echo "----- output -----"; printf '%s\n' "$out"; echo "------------------"
    FAIL=$((FAIL + 1))
  fi
}

# expect_not_contains NAME OUTPUT PATTERN
expect_not_contains() {
  local name="$1" out="$2" pat="$3"
  if printf '%s' "$out" | grep -qF -- "$pat"; then
    echo "FAIL: $name (unexpected pattern present: $pat)"
    echo "----- output -----"; printf '%s\n' "$out"; echo "------------------"
    FAIL=$((FAIL + 1))
  else
    echo "PASS: $name"
    PASS=$((PASS + 1))
  fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Case 1 (normal-safe): byte-identical files → SAME.
# ─────────────────────────────────────────────────────────────────────────────
read -r REPO LOCAL <<<"$(setup_pair)"
mkdir -p "$REPO/config/hooks" "$LOCAL/hooks"
echo "identical" > "$REPO/config/hooks/foo.sh"
echo "identical" > "$LOCAL/hooks/foo.sh"
out=$("$SCRIPT" "$REPO/config" "$LOCAL" 2>&1)
expect_contains "identical files → SAME counted, not in CHANGED" "$out" "SAME: 1"
expect_not_contains "identical files → no CHANGED section" "$out" "hooks/foo.sh"
rm -rf "$REPO" "$LOCAL"

# ─────────────────────────────────────────────────────────────────────────────
# Case 2 (trigger): pure <workspace> placeholder drift → filter normalizes to SAME.
# ─────────────────────────────────────────────────────────────────────────────
read -r REPO LOCAL <<<"$(setup_pair)"
mkdir -p "$REPO/config/skills/k8s" "$LOCAL/skills/k8s"
cat > "$REPO/config/skills/k8s/SKILL.md" <<'EOF'
- Repo: <workspace>/service-a
- Helm: <workspace>/service-b
EOF
cat > "$LOCAL/skills/k8s/SKILL.md" <<'EOF'
- Repo: /Users/test/work/service-a
- Helm: /Users/test/work/service-b
EOF
out=$("$SCRIPT" "$REPO/config" "$LOCAL" 2>&1)
expect_contains "pure placeholder drift → SAME" "$out" "SAME: 1"
expect_not_contains "pure placeholder drift → not in CHANGED" "$out" "skills/k8s/SKILL.md"
rm -rf "$REPO" "$LOCAL"

# ─────────────────────────────────────────────────────────────────────────────
# Case 3 (false-positive guard): real drift on the suffix side of a hunk that
# ALSO looks placeholder-shaped → must surface as CHANGED, not silently absorbed.
# ─────────────────────────────────────────────────────────────────────────────
read -r REPO LOCAL <<<"$(setup_pair)"
mkdir -p "$REPO/config/skills/k8s" "$LOCAL/skills/k8s"
cat > "$REPO/config/skills/k8s/SKILL.md" <<'EOF'
- Repo: <workspace>/new-repo-name
EOF
cat > "$LOCAL/skills/k8s/SKILL.md" <<'EOF'
- Repo: /Users/test/work/old-repo-name
EOF
out=$("$SCRIPT" "$REPO/config" "$LOCAL" 2>&1)
expect_contains "real drift in suffix → CHANGED" "$out" "skills/k8s/SKILL.md"
expect_contains "real drift in suffix → shown in CHANGED section" "$out" "=== CHANGED ==="
rm -rf "$REPO" "$LOCAL"

# ─────────────────────────────────────────────────────────────────────────────
# Case 4 (trigger): file in repo, not in local → NEW IN REPO.
# ─────────────────────────────────────────────────────────────────────────────
read -r REPO LOCAL <<<"$(setup_pair)"
mkdir -p "$REPO/config/hooks" "$LOCAL/hooks"
echo "brand new hook" > "$REPO/config/hooks/new-hook.sh"
out=$("$SCRIPT" "$REPO/config" "$LOCAL" 2>&1)
expect_contains "missing local → NEW IN REPO section" "$out" "=== NEW IN REPO"
expect_contains "missing local → file listed" "$out" "hooks/new-hook.sh"
rm -rf "$REPO" "$LOCAL"

# ─────────────────────────────────────────────────────────────────────────────
# Case 5 (trigger): file in local mirror dir, not in repo → NEW IN LOCAL.
# ─────────────────────────────────────────────────────────────────────────────
read -r REPO LOCAL <<<"$(setup_pair)"
mkdir -p "$REPO/config/hooks" "$LOCAL/hooks"
echo "my personal hook" > "$LOCAL/hooks/personal-hook.sh"
out=$("$SCRIPT" "$REPO/config" "$LOCAL" 2>&1)
expect_contains "local-only in hooks/ → NEW IN LOCAL section" "$out" "=== NEW IN LOCAL"
expect_contains "local-only in hooks/ → file listed" "$out" "hooks/personal-hook.sh"
rm -rf "$REPO" "$LOCAL"

# ─────────────────────────────────────────────────────────────────────────────
# Case 6 (edge): file in ~/.claude/ outside the mirror dirs (e.g. projects/) →
# NOT walked, must not appear as NEW IN LOCAL.
# ─────────────────────────────────────────────────────────────────────────────
read -r REPO LOCAL <<<"$(setup_pair)"
mkdir -p "$LOCAL/projects/some-session"
echo "runtime data not config" > "$LOCAL/projects/some-session/history.jsonl"
out=$("$SCRIPT" "$REPO/config" "$LOCAL" 2>&1)
expect_not_contains "runtime data not walked → not NEW IN LOCAL" "$out" "projects/"
rm -rf "$REPO" "$LOCAL"

# ─────────────────────────────────────────────────────────────────────────────
# Case 7 (trigger): real drift on non-placeholder file → CHANGED with filtered
# diff body containing the actual differing lines.
# ─────────────────────────────────────────────────────────────────────────────
read -r REPO LOCAL <<<"$(setup_pair)"
mkdir -p "$REPO/config/hooks" "$LOCAL/hooks"
printf 'line one\nrepo version\n' > "$REPO/config/hooks/drift.sh"
printf 'line one\nlocal version\n' > "$LOCAL/hooks/drift.sh"
out=$("$SCRIPT" "$REPO/config" "$LOCAL" 2>&1)
expect_contains "real drift → CHANGED section" "$out" "=== CHANGED ==="
expect_contains "real drift → diff body has repo line" "$out" "repo version"
expect_contains "real drift → diff body has local line" "$out" "local version"
rm -rf "$REPO" "$LOCAL"

# ─────────────────────────────────────────────────────────────────────────────
# Case 8 (edge): managed-settings.json with MANAGED_LOCAL unreadable on
# this OS — we can't fake the system path, but we CAN verify the script
# surfaces a path that doesn't exist as NEW IN REPO (or ERRORS if perms).
# Skipped if managed-settings is actually present and identical.
# ─────────────────────────────────────────────────────────────────────────────
read -r REPO LOCAL <<<"$(setup_pair)"
echo '{"managed":"yes"}' > "$REPO/config/managed-settings.json"
out=$("$SCRIPT" "$REPO/config" "$LOCAL" 2>&1)
# Either it's reported as NEW IN REPO (path doesn't exist on test runner's
# system) or as CHANGED/SAME if the runner happens to have one installed.
# What we MUST NOT see: the file silently absent from output entirely.
if printf '%s' "$out" | grep -qE 'managed-settings\.json|=== ERRORS ==='; then
  echo "PASS: managed-settings.json surfaced (NEW/CHANGED/SAME/ERROR)"
  PASS=$((PASS + 1))
else
  echo "FAIL: managed-settings.json never appeared in output"
  printf '%s\n' "$out"
  FAIL=$((FAIL + 1))
fi
rm -rf "$REPO" "$LOCAL"

# ─────────────────────────────────────────────────────────────────────────────
# Case 9 (edge): empty repo config/ → script exits 0, summary shows SAME: 0.
# ─────────────────────────────────────────────────────────────────────────────
read -r REPO LOCAL <<<"$(setup_pair)"
out=$("$SCRIPT" "$REPO/config" "$LOCAL" 2>&1); rc=$?
expect_contains "empty repo → exits cleanly" "$out" "SUMMARY"
if [ "$rc" = 0 ]; then
  echo "PASS: empty repo → exit 0"
  PASS=$((PASS + 1))
else
  echo "FAIL: empty repo → exit $rc"
  FAIL=$((FAIL + 1))
fi
rm -rf "$REPO" "$LOCAL"

# ─────────────────────────────────────────────────────────────────────────────
# Case 10 (edge): missing repo config dir → exits 1 with error on stderr.
# ─────────────────────────────────────────────────────────────────────────────
out=$("$SCRIPT" "/nonexistent/path/config" "$HOME/.claude" 2>&1); rc=$?
if [ "$rc" = 1 ]; then
  echo "PASS: missing repo dir → exit 1"
  PASS=$((PASS + 1))
else
  echo "FAIL: missing repo dir → exit $rc (expected 1)"
  FAIL=$((FAIL + 1))
fi
expect_contains "missing repo dir → error message" "$out" "ERROR"

# ─────────────────────────────────────────────────────────────────────────────
# Case 11 (trigger, false-positive boundary): a hunk that has <workspace> on
# the `>` side but ALSO has real drift on a DIFFERENT pair within the same
# hunk → filter must keep the whole hunk (line-counts match but per-pair
# prefix/suffix breaks).
# ─────────────────────────────────────────────────────────────────────────────
read -r REPO LOCAL <<<"$(setup_pair)"
mkdir -p "$REPO/config/skills/k8s" "$LOCAL/skills/k8s"
cat > "$REPO/config/skills/k8s/SKILL.md" <<'EOF'
- Repo: <workspace>/foo
- Comment: see <workspace>/docs for details
EOF
cat > "$LOCAL/skills/k8s/SKILL.md" <<'EOF'
- Repo: /Users/test/work/foo
- Comment: regular text, no docs reference
EOF
out=$("$SCRIPT" "$REPO/config" "$LOCAL" 2>&1)
expect_contains "mixed placeholder+real → CHANGED" "$out" "skills/k8s/SKILL.md"
rm -rf "$REPO" "$LOCAL"

# ─────────────────────────────────────────────────────────────────────────────
# Case 12 (trigger): mcp/ tree walks correctly — file mirrored to
# ~/.claude/mcp/<svc>/<file> on local.
# ─────────────────────────────────────────────────────────────────────────────
read -r REPO LOCAL <<<"$(setup_pair)"
mkdir -p "$REPO/mcp/figma" "$LOCAL/mcp/figma"
echo "same content" > "$REPO/mcp/figma/mcp-figma.sh"
echo "same content" > "$LOCAL/mcp/figma/mcp-figma.sh"
out=$("$SCRIPT" "$REPO/config" "$LOCAL" 2>&1)
expect_contains "mcp/ tree walked → SAME counted" "$out" "SAME: 1"
expect_not_contains "mcp/ identical files → not in CHANGED" "$out" "mcp/figma/mcp-figma.sh"
rm -rf "$REPO" "$LOCAL"

# ─────────────────────────────────────────────────────────────────────────────
# Case 13 (trigger): mcp/ file in repo, missing locally → NEW IN REPO with the
# mcp/ prefix preserved.
# ─────────────────────────────────────────────────────────────────────────────
read -r REPO LOCAL <<<"$(setup_pair)"
mkdir -p "$REPO/mcp/gdrive"
echo "new launcher" > "$REPO/mcp/gdrive/mcp-gdrive.sh"
out=$("$SCRIPT" "$REPO/config" "$LOCAL" 2>&1)
expect_contains "missing mcp/ file → NEW IN REPO" "$out" "mcp/gdrive/mcp-gdrive.sh"
rm -rf "$REPO" "$LOCAL"

# ─────────────────────────────────────────────────────────────────────────────
# Case 14 (false-positive guard): `.env.sample` in repo with corresponding
# `.env` on local — script SKIPS .env.sample entirely (templates are not
# diffed against filled-in local copies; that diff is always noise). The
# local `.env` is also never flagged as orphan because its `.sample` exists.
# ─────────────────────────────────────────────────────────────────────────────
read -r REPO LOCAL <<<"$(setup_pair)"
mkdir -p "$REPO/mcp/figma" "$LOCAL/mcp/figma"
echo "FIGMA_API_KEY=<placeholder>" > "$REPO/mcp/figma/figma.env.sample"
echo "FIGMA_API_KEY=real-value"    > "$LOCAL/mcp/figma/figma.env"
out=$("$SCRIPT" "$REPO/config" "$LOCAL" 2>&1)
expect_not_contains "env.sample with local .env → not NEW IN REPO" "$out" "figma.env.sample"
expect_not_contains "local .env (consent-renamed) → not flagged as orphan" "$out" "=== NEW IN LOCAL"
expect_contains "env.sample skipped entirely → SAME: 0 (template not counted)" "$out" "SAME: 0"
rm -rf "$REPO" "$LOCAL"

# ─────────────────────────────────────────────────────────────────────────────
# Case 15 (trigger): integrations/ tree — same mirrored-walk semantics.
# ─────────────────────────────────────────────────────────────────────────────
read -r REPO LOCAL <<<"$(setup_pair)"
mkdir -p "$REPO/integrations/rate-limit"
echo "appscript code" > "$REPO/integrations/rate-limit/rate-limit-appscript.js"
out=$("$SCRIPT" "$REPO/config" "$LOCAL" 2>&1)
expect_contains "integrations/ file → NEW IN REPO" "$out" "integrations/rate-limit/rate-limit-appscript.js"
rm -rf "$REPO" "$LOCAL"

# ─────────────────────────────────────────────────────────────────────────────
# Case 16 (edge): personal MCP folder under ~/.claude/mcp/<svc>/ with no
# repo counterpart → NEW IN LOCAL (mirrored orphans detected).
# ─────────────────────────────────────────────────────────────────────────────
read -r REPO LOCAL <<<"$(setup_pair)"
mkdir -p "$LOCAL/mcp/personal"
echo "my custom launcher" > "$LOCAL/mcp/personal/mcp-personal.sh"
out=$("$SCRIPT" "$REPO/config" "$LOCAL" 2>&1)
expect_contains "local-only mcp dir → NEW IN LOCAL" "$out" "mcp/personal/mcp-personal.sh"
rm -rf "$REPO" "$LOCAL"

# ─────────────────────────────────────────────────────────────────────────────
# Case 17 (trigger): .env.sample files are skipped from comparison entirely.
# Repo carries the placeholder template; local has a filled-in .env with real
# credentials. Diffing them always shows divergence (not actionable) so the
# script skips both directions.
# ─────────────────────────────────────────────────────────────────────────────
read -r REPO LOCAL <<<"$(setup_pair)"
mkdir -p "$REPO/mcp/figma" "$LOCAL/mcp/figma"
echo "FIGMA_API_KEY=<placeholder>"   > "$REPO/mcp/figma/figma.env.sample"
echo "FIGMA_API_KEY=real-key-12345"  > "$LOCAL/mcp/figma/figma.env"
out=$("$SCRIPT" "$REPO/config" "$LOCAL" 2>&1)
expect_not_contains "env.sample never shows in CHANGED" "$out" "figma.env.sample"
expect_not_contains "filled-in local .env not flagged as orphan" "$out" "=== NEW IN LOCAL"
rm -rf "$REPO" "$LOCAL"

# ─────────────────────────────────────────────────────────────────────────────
# Case 18 (trigger): <bash for windows only> placeholder filter — a hunk that
# differs ONLY by the placeholder substitution is dropped as noise. Repo carries
# the placeholder (Windows users replace with "bash "); macOS/Linux install
# strips it. So macOS local has bare path, repo has placeholder prefix.
# ─────────────────────────────────────────────────────────────────────────────
read -r REPO LOCAL <<<"$(setup_pair)"
mkdir -p "$REPO/config" "$LOCAL"
echo '"command": "~/.claude/hooks/foo.sh"' > "$LOCAL/settings.json"
echo '"command": "<bash for windows only>~/.claude/hooks/foo.sh"' > "$REPO/config/settings.json"
out=$("$SCRIPT" "$REPO/config" "$LOCAL" 2>&1)
expect_contains "pure <bash for windows only> drift → SAME" "$out" "SAME: 1"
expect_not_contains "pure <bash for windows only> drift → not in CHANGED" "$out" "settings.json"
rm -rf "$REPO" "$LOCAL"

# ─────────────────────────────────────────────────────────────────────────────
# Case 19 (false-positive guard): <bash for windows only> placeholder is
# present BUT there's also real content drift (different script name) →
# keep the hunk.
# ─────────────────────────────────────────────────────────────────────────────
read -r REPO LOCAL <<<"$(setup_pair)"
mkdir -p "$REPO/config" "$LOCAL"
echo '"command": "~/.claude/hooks/local-only.sh"'                  > "$LOCAL/settings.json"
echo '"command": "<bash for windows only>~/.claude/hooks/repo.sh"' > "$REPO/config/settings.json"
out=$("$SCRIPT" "$REPO/config" "$LOCAL" 2>&1)
expect_contains "placeholder + real drift → CHANGED" "$out" "settings.json"
rm -rf "$REPO" "$LOCAL"

# ─────────────────────────────────────────────────────────────────────────────
# Case 20 (trigger): cruft skip — .pytest_cache and __pycache__ files in repo
# are gitignored generated artifacts. Never appear in output.
# ─────────────────────────────────────────────────────────────────────────────
read -r REPO LOCAL <<<"$(setup_pair)"
mkdir -p "$REPO/config/.pytest_cache" "$REPO/config/__pycache__" "$REPO/mcp/openproject/__pycache__"
echo "junk"  > "$REPO/config/.pytest_cache/CACHEDIR.TAG"
echo "junk2" > "$REPO/config/__pycache__/foo.cpython-314.pyc"
echo "junk3" > "$REPO/mcp/openproject/__pycache__/bar.pyc"
out=$("$SCRIPT" "$REPO/config" "$LOCAL" 2>&1)
expect_not_contains "pytest_cache not in NEW IN REPO" "$out" "pytest_cache"
expect_not_contains "__pycache__ not in NEW IN REPO" "$out" "__pycache__"
rm -rf "$REPO" "$LOCAL"

# ─────────────────────────────────────────────────────────────────────────────
# Case 21 (trigger): .DS_Store on local side → never flagged as NEW IN LOCAL.
# ─────────────────────────────────────────────────────────────────────────────
read -r REPO LOCAL <<<"$(setup_pair)"
mkdir -p "$LOCAL/skills" "$LOCAL/hooks"
echo "macOS finder cruft" > "$LOCAL/skills/.DS_Store"
echo "macOS finder cruft" > "$LOCAL/hooks/.DS_Store"
out=$("$SCRIPT" "$REPO/config" "$LOCAL" 2>&1)
expect_not_contains ".DS_Store not flagged as orphan" "$out" ".DS_Store"
rm -rf "$REPO" "$LOCAL"

# ─────────────────────────────────────────────────────────────────────────────
# Case 22 (false-positive guard for cruft): a file containing "pytest_cache" in
# its NAME but not under a .pytest_cache DIRECTORY should still be compared.
# Catches a regression where the pattern matches too broadly.
# ─────────────────────────────────────────────────────────────────────────────
read -r REPO LOCAL <<<"$(setup_pair)"
mkdir -p "$REPO/config/skills/cache-utils"
echo "real file content" > "$REPO/config/skills/cache-utils/pytest_cache_helper.md"
out=$("$SCRIPT" "$REPO/config" "$LOCAL" 2>&1)
expect_contains "regular file with cache-y name → still surfaces" "$out" "pytest_cache_helper.md"
rm -rf "$REPO" "$LOCAL"

summary
