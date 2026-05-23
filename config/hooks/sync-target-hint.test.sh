#!/bin/bash
# Tests for sync-target-hint.sh
# Run: bash $HOME/.claude/_lib/run-all-tests.sh (canonical)

source "$HOME/.claude/_lib/test-helpers.sh"
HOOK="$(_test_script_dir "$0")/sync-target-hint.sh"
_require_executable "$HOOK"

# Mock fixture repo so tests don't depend on actual repo contents
FIXTURE=$(mktemp -d)
trap "rm -rf '$FIXTURE'" EXIT

mkdir -p "$FIXTURE/bangor-claude-config/config/hooks"
mkdir -p "$FIXTURE/bangor-claude-config/mcp/figma"
touch "$FIXTURE/bangor-claude-config/config/hooks/foo.sh"
touch "$FIXTURE/bangor-claude-config/config/CLAUDE.md"
touch "$FIXTURE/bangor-claude-config/mcp/figma/mcp-figma.sh"

export SYNC_HINT_REPOS_OVERRIDE="$FIXTURE/bangor-claude-config"

# Local helper: run hook with given file_path, assert pattern match or silence
run_path_test() {
  local name="$1" file_path="$2" pattern="$3" expect="$4"
  local stdout
  stdout=$(jq -n --arg fp "$file_path" '{tool_name:"Edit",tool_input:{file_path:$fp}}' | "$HOOK" 2>/dev/null)
  case "$expect" in
    match)
      if echo "$stdout" | grep -q "$pattern"; then
        echo "PASS: $name"
        PASS=$((PASS + 1))
      else
        echo "FAIL: $name (expected '$pattern' in stdout, got: $stdout)"
        FAIL=$((FAIL + 1))
      fi
      ;;
    silent)
      if [ -z "$stdout" ]; then
        echo "PASS: $name (silent)"
        PASS=$((PASS + 1))
      else
        echo "FAIL: $name (expected silence, got: $stdout)"
        FAIL=$((FAIL + 1))
      fi
      ;;
  esac
}

# Trigger cases — file under ~/.claude/ that exists in fixture repo
run_path_test "trigger: hook file matches repo"         "$HOME/.claude/hooks/foo.sh"           "bangor-claude-config: config/hooks/foo.sh"    match
run_path_test "trigger: top-level CLAUDE.md"            "$HOME/.claude/CLAUDE.md"              "bangor-claude-config: config/CLAUDE.md"       match
run_path_test "trigger: mcp/ tree match"                "$HOME/.claude/mcp/figma/mcp-figma.sh" "bangor-claude-config: mcp/figma/mcp-figma.sh" match

# Normal-safe case — under ~/.claude/ but no repo match
run_path_test "normal: ~/.claude/ file absent in repos" "$HOME/.claude/projects/abc/foo.md"    "" silent

# False-positive case — path contains '.claude' substring but isn't ~/.claude/
run_path_test "false-positive: /tmp/.claude-fake/x.md"  "/tmp/.claude-fake/CLAUDE.md"          "" silent
run_path_test "false-positive: ~/.claude-extra/foo.md"  "$HOME/.claude-extra/foo.md"           "" silent

# Edge cases — empty / missing / tilde
stdout=$(echo '' | "$HOOK" 2>/dev/null); rc=$?
if [ "$rc" = 0 ] && [ -z "$stdout" ]; then
  echo "PASS: edge: empty stdin → silent rc=0"; PASS=$((PASS + 1))
else
  echo "FAIL: edge: empty stdin (rc=$rc, stdout=$stdout)"; FAIL=$((FAIL + 1))
fi

stdout=$(echo '{"tool_name":"Edit","tool_input":{}}' | "$HOOK" 2>/dev/null)
if [ -z "$stdout" ]; then
  echo "PASS: edge: missing file_path → silent"; PASS=$((PASS + 1))
else
  echo "FAIL: edge: missing file_path (got: $stdout)"; FAIL=$((FAIL + 1))
fi

run_path_test "edge: tilde-prefixed file_path"          "~/.claude/hooks/foo.sh"               "bangor-claude-config: config/hooks/foo.sh" match

summary
