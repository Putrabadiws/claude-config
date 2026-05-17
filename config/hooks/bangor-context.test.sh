#!/bin/bash
# SYNC:LOCAL-ONLY  — Bangor-team-specific tests; do not sync to ib or other repos.
# Tests for bangor-context.sh — fires on Bangor-Group-Indonesia remotes OR
# when working under ~/bangor. Sets /tmp/bangor-context-injected-${sid} flag.
# Run: bash ~/.claude/hooks/bangor-context.test.sh

source "$HOME/.claude/_lib/test-helpers.sh"
HOOK="$(_test_script_dir "$0")/bangor-context.sh"
_require_executable "$HOOK"

run_bangor_context_case() {
  local name="$1" cwd="$2" remote_url="$3" expect_fires="$4"
  local sid="test-bangor-$$-$RANDOM"
  local dir="$cwd"
  local cleanup_dir=""
  if [ -n "$remote_url" ] && [ -z "$cwd" ]; then
    dir=$(mock_git_repo "$remote_url")
    cleanup_dir="$dir"
  fi

  local stdout
  stdout=$(jq -n --arg cwd "$dir" --arg sid "$sid" '{cwd:$cwd,session_id:$sid,tool_input:{command:""}}' | "$HOOK" 2>/dev/null)
  [ -n "$cleanup_dir" ] && rm -rf "$cleanup_dir"
  rm -f "/tmp/bangor-context-injected-${sid}"

  local fired=no
  echo "$stdout" | grep -q "additionalContext" && fired=yes

  if [ "$fired" = "$expect_fires" ]; then
    echo "PASS: $name"; PASS=$((PASS + 1))
  else
    echo "FAIL: $name (expected fires=$expect_fires, got=$fired)"; FAIL=$((FAIL + 1))
  fi
}

# Fire-cases (Bangor org repo or under ~/bangor)
run_bangor_context_case "github remote in Bangor org"            ""  "https://github.com/Bangor-Group-Indonesia/foo.git"  yes
run_bangor_context_case "ssh remote in Bangor org"               ""  "git@github.com:Bangor-Group-Indonesia/foo.git"      yes

# Path-based match: ~/bangor (we synthesize via env var $HOME/bangor presence simulated)
# We can't easily simulate $HOME/bangor since real $HOME exists. Skip if ~/bangor doesn't exist.
if [ -d "$HOME/bangor" ]; then
  run_bangor_context_case "cwd under ~/bangor"                   "$HOME/bangor"      ""    yes
fi

# No-fire cases
run_bangor_context_case "non-Bangor github remote"               ""  "https://github.com/anyone/else.git"                 no
run_bangor_context_case "gitlab remote"                          ""  "https://gitlab.com/foo/bar.git"                     no
run_bangor_context_case "no remote, random tempdir"              ""  ""                                                    no

# Edge: flag suppression
sid="test-bangor-suppressed"
dir=$(mock_git_repo "https://github.com/Bangor-Group-Indonesia/foo.git")
touch "/tmp/bangor-context-injected-${sid}"
stdout=$(jq -n --arg cwd "$dir" --arg sid "$sid" '{cwd:$cwd,session_id:$sid,tool_input:{command:""}}' | "$HOOK" 2>/dev/null)
rm -rf "$dir" "/tmp/bangor-context-injected-${sid}"
if echo "$stdout" | grep -q "additionalContext"; then
  echo "FAIL: flagged session should suppress fire"; FAIL=$((FAIL + 1))
else
  echo "PASS: flagged session → suppressed"; PASS=$((PASS + 1))
fi

summary
