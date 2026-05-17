#!/bin/bash
# Tests for mcp-gdrive.sh launcher (path resolution).
#
# Run with TEST_NO_EXEC=1 to short-circuit before `exec npx ...`. Stdout echoes
# the resolved GDRIVE_CREDENTIALS_PATH and GDRIVE_OAUTH_PATH for assertion.

set -u

source "$HOME/.claude/_lib/test-helpers.sh"

LAUNCHER="$(_test_script_dir "$0")/mcp-gdrive.sh"
_require_executable "$LAUNCHER"

setup_tmp_launcher() {
  local tmp
  tmp=$(mktemp -d)
  cp "$LAUNCHER" "$tmp/mcp-gdrive.sh"
  chmod +x "$tmp/mcp-gdrive.sh"
  echo "$tmp"
}

# Case 1 (trigger): paths resolve to launcher dir.
tmp=$(setup_tmp_launcher)
out=$(TEST_NO_EXEC=1 "$tmp/mcp-gdrive.sh" 2>&1)
if echo "$out" | grep -qF "GDRIVE_CREDENTIALS_PATH=$tmp/gdrive-credentials.json"; then
  echo "PASS: credentials path mirrored to launcher dir"; PASS=$((PASS + 1))
else
  echo "FAIL: credentials path — got: $out"; FAIL=$((FAIL + 1))
fi
if echo "$out" | grep -qF "GDRIVE_OAUTH_PATH=$tmp/gdrive-oauth.json"; then
  echo "PASS: oauth path mirrored to launcher dir"; PASS=$((PASS + 1))
else
  echo "FAIL: oauth path — got: $out"; FAIL=$((FAIL + 1))
fi
rm -rf "$tmp"

# Case 2 (trigger): paths resolve to NEW launcher dir when relocated.
tmp=$(setup_tmp_launcher)
mkdir -p "$tmp/sub/dir"
mv "$tmp/mcp-gdrive.sh" "$tmp/sub/dir/mcp-gdrive.sh"
out=$(TEST_NO_EXEC=1 "$tmp/sub/dir/mcp-gdrive.sh" 2>&1)
if echo "$out" | grep -qF "GDRIVE_CREDENTIALS_PATH=$tmp/sub/dir/gdrive-credentials.json"; then
  echo "PASS: paths follow the launcher when relocated"; PASS=$((PASS + 1))
else
  echo "FAIL: relocated launcher — got: $out"; FAIL=$((FAIL + 1))
fi
rm -rf "$tmp"

# Case 3 (false-positive guard): paths must NOT come from $HOME/.claude/ (the
# old flat install location).  This guards against a future regression where
# someone accidentally re-hardcodes the home path.
tmp=$(setup_tmp_launcher)
out=$(TEST_NO_EXEC=1 "$tmp/mcp-gdrive.sh" 2>&1)
if echo "$out" | grep -qF "GDRIVE_CREDENTIALS_PATH=$HOME/.claude/gdrive-credentials.json"; then
  echo "FAIL: paths regressed to ~/.claude/ flat layout"; FAIL=$((FAIL + 1))
else
  echo "PASS: paths NOT hardcoded to ~/.claude/ (good)"; PASS=$((PASS + 1))
fi
rm -rf "$tmp"

# Case 4 (normal-safe): launcher runs without env files present (no error).
tmp=$(setup_tmp_launcher)
out=$(TEST_NO_EXEC=1 "$tmp/mcp-gdrive.sh" 2>&1); rc=$?
if [ "$rc" = 0 ]; then
  echo "PASS: launcher exits 0 even without credential files (auth flow handles missing)"; PASS=$((PASS + 1))
else
  echo "FAIL: launcher exited rc=$rc when env files missing"; FAIL=$((FAIL + 1))
fi
rm -rf "$tmp"

# Case 5 (edge): launcher invoked from a different cwd → paths still relative
# to launcher, not cwd.
tmp=$(setup_tmp_launcher)
mkdir -p "$tmp/elsewhere"
out=$(cd "$tmp/elsewhere" && TEST_NO_EXEC=1 "$tmp/mcp-gdrive.sh" 2>&1)
if echo "$out" | grep -qF "GDRIVE_CREDENTIALS_PATH=$tmp/gdrive-credentials.json"; then
  echo "PASS: paths anchored to launcher dir, not cwd"; PASS=$((PASS + 1))
else
  echo "FAIL: paths drifted to cwd — got: $out"; FAIL=$((FAIL + 1))
fi
rm -rf "$tmp"

summary
