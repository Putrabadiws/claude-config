#!/bin/bash
# Tests for mcp-figma.sh launcher (env resolution).
#
# Run with TEST_NO_EXEC=1 to short-circuit before the `exec npx ...` line.
# Stdout echoes the resolved FIGMA_API_KEY for assertion.

set -u

source "$HOME/.claude/_lib/test-helpers.sh"

LAUNCHER="$(_test_script_dir "$0")/mcp-figma.sh"
_require_executable "$LAUNCHER"

# Build a tmp dir that mirrors the launcher folder, with a controllable env file.
# We can't put env files next to the real launcher (would dirty the repo), so we
# COPY the launcher into a tmp dir alongside the test env file and invoke it
# there — this exercises the $(dirname "$0") resolution.

setup_tmp_launcher() {
  local tmp
  tmp=$(mktemp -d)
  cp "$LAUNCHER" "$tmp/mcp-figma.sh"
  chmod +x "$tmp/mcp-figma.sh"
  echo "$tmp"
}

# Case 1 (trigger): env file present with FIGMA_API_KEY → exported.
tmp=$(setup_tmp_launcher)
echo 'FIGMA_API_KEY=key-from-envfile' > "$tmp/figma.env"
out=$( unset FIGMA_API_KEY; TEST_NO_EXEC=1 "$tmp/mcp-figma.sh" 2>&1)
if echo "$out" | grep -q '^FIGMA_API_KEY=key-from-envfile$'; then
  echo "PASS: env file co-located → FIGMA_API_KEY exported"; PASS=$((PASS + 1))
else
  echo "FAIL: env file load — got: $out"; FAIL=$((FAIL + 1))
fi
rm -rf "$tmp"

# Case 2 (trigger, multi-var false-positive guard): env file with multiple vars
# → all exported, not just the first one.
tmp=$(setup_tmp_launcher)
cat > "$tmp/figma.env" <<'EOF'
SOMETHING_ELSE=other
FIGMA_API_KEY=second-var
EOF
out=$( unset FIGMA_API_KEY; TEST_NO_EXEC=1 "$tmp/mcp-figma.sh" 2>&1)
if echo "$out" | grep -q '^FIGMA_API_KEY=second-var$'; then
  echo "PASS: multi-var env file → later var still exported"; PASS=$((PASS + 1))
else
  echo "FAIL: multi-var env file — got: $out"; FAIL=$((FAIL + 1))
fi
rm -rf "$tmp"

# Case 3 (normal-safe): no env file, no keychain match → FIGMA_API_KEY empty.
# Mock `security` to always return non-zero (no match). PATH alone isn't enough
# because /usr/bin/security would be found further down PATH.
tmp=$(setup_tmp_launcher)
mock_bin=$(mktemp -d)
printf '#!/bin/bash\nexit 1\n' > "$mock_bin/security"; chmod +x "$mock_bin/security"
out=$( unset FIGMA_API_KEY; PATH="$mock_bin:/usr/bin:/bin" TEST_NO_EXEC=1 "$tmp/mcp-figma.sh" 2>&1)
if echo "$out" | grep -q '^FIGMA_API_KEY=$'; then
  echo "PASS: no env, no keychain → FIGMA_API_KEY empty"; PASS=$((PASS + 1))
else
  echo "FAIL: no-env-no-keychain — got: $out"; FAIL=$((FAIL + 1))
fi
rm -rf "$tmp" "$mock_bin"

# Case 4 (trigger): no env file, keychain has key → comes from keychain.
# Mock `security` as a fake binary that always echoes a known value when asked
# `security find-generic-password -a USER -s figma-api-key -w`.
tmp=$(setup_tmp_launcher)
mock_bin=$(mktemp -d)
cat > "$mock_bin/security" <<'EOF'
#!/bin/bash
# Mock security tool — only handle the figma lookup pattern.
for arg in "$@"; do
  if [ "$arg" = "figma-api-key" ]; then
    echo "key-from-keychain"
    exit 0
  fi
done
exit 1
EOF
chmod +x "$mock_bin/security"
out=$( unset FIGMA_API_KEY; PATH="$mock_bin:/usr/bin:/bin" TEST_NO_EXEC=1 "$tmp/mcp-figma.sh" 2>&1)
if echo "$out" | grep -q '^FIGMA_API_KEY=key-from-keychain$'; then
  echo "PASS: no env + keychain hit → FIGMA_API_KEY from keychain"; PASS=$((PASS + 1))
else
  echo "FAIL: keychain fallback — got: $out"; FAIL=$((FAIL + 1))
fi
rm -rf "$tmp" "$mock_bin"

# Case 5 (edge): empty env file → no FIGMA_API_KEY set (fall through to keychain).
tmp=$(setup_tmp_launcher)
: > "$tmp/figma.env"   # empty file
mock_bin=$(mktemp -d)
printf '#!/bin/bash\nexit 1\n' > "$mock_bin/security"; chmod +x "$mock_bin/security"
out=$( unset FIGMA_API_KEY; PATH="$mock_bin:/usr/bin:/bin" TEST_NO_EXEC=1 "$tmp/mcp-figma.sh" 2>&1)
if echo "$out" | grep -q '^FIGMA_API_KEY=$'; then
  echo "PASS: empty env file → key empty"; PASS=$((PASS + 1))
else
  echo "FAIL: empty env — got: $out"; FAIL=$((FAIL + 1))
fi
rm -rf "$tmp" "$mock_bin"

summary
