#!/bin/bash
# SYNC:LOCAL-ONLY  — per-repo PLATFORM tests diverge; do not bulk-cp.
# Tests for statusline.sh — renders status info from Claude Code's statusline
# JSON payload. We use the captured sample at ~/.claude/logs/statusline-raw.json
# when available, and synthesize fallback inputs otherwise.
# Run: bash ~/.claude/statusline.test.sh

source "$HOME/.claude/_lib/test-helpers.sh"
HOOK="$(_test_script_dir "$0")/statusline.sh"
_require_executable "$HOOK"

# Wrapper: pipe input into the hook, capture stdout (with terminal redirection
# since statusline reads stty from /dev/tty)
run_statusline() {
  local input="$1"
  echo "$input" | "$HOOK" 2>/dev/null
}

# Test 1: empty JSON object → doesn't crash, exits cleanly
out=$(run_statusline '{}')
rc=$?
if [ "$rc" = "0" ]; then
  echo "PASS: empty JSON → exits 0"; PASS=$((PASS + 1))
else
  echo "FAIL: empty JSON crashed (rc=$rc)"; FAIL=$((FAIL + 1))
fi

# Test 2: minimal valid payload renders model name
minimal='{"model":{"display_name":"Opus 4.7","id":"claude-opus-4-7"},"workspace":{"current_dir":"/tmp"},"cost":{"total_duration_ms":1000},"context_window":{"context_window_size":200000,"current_usage":{"input_tokens":1000}}}'
out=$(run_statusline "$minimal")
if echo "$out" | grep -q "Opus 4.7"; then
  echo "PASS: renders model name"; PASS=$((PASS + 1))
else
  echo "FAIL: model name not rendered"; FAIL=$((FAIL + 1))
fi

# Test 3: renders cwd basename
out=$(run_statusline "$minimal")
if echo "$out" | grep -q "tmp"; then
  echo "PASS: renders workspace dir"; PASS=$((PASS + 1))
else
  echo "FAIL: workspace dir not in output"; FAIL=$((FAIL + 1))
fi

# Test 4: context percentage shown
out=$(run_statusline "$minimal")
if echo "$out" | grep -qE "ctx.*%"; then
  echo "PASS: shows ctx percentage"; PASS=$((PASS + 1))
else
  echo "FAIL: missing ctx percentage"; FAIL=$((FAIL + 1))
fi

# Test 5: platform detection for bangor-claude-config path (bangor's Config platform)
bangor_config='{"model":{"display_name":"Sonnet 4.6","id":"claude-sonnet-4-6"},"workspace":{"current_dir":"/Users/x/bangor/bangor-claude-config"},"cost":{"total_duration_ms":0},"context_window":{"context_window_size":200000,"current_usage":{}}}'
out=$(run_statusline "$bangor_config")
if echo "$out" | grep -q "Config"; then
  echo "PASS: detects Config platform"; PASS=$((PASS + 1))
else
  echo "FAIL: Config platform not detected"; FAIL=$((FAIL + 1))
fi

# Test 6: use captured sample (most realistic input)
SAMPLE="$HOME/.claude/logs/statusline-raw.json"
if [ -f "$SAMPLE" ]; then
  sample_input=$(cat "$SAMPLE")
  out=$(run_statusline "$sample_input")
  rc=$?
  if [ "$rc" = "0" ] && [ -n "$out" ]; then
    echo "PASS: captured sample renders without crash"; PASS=$((PASS + 1))
  else
    echo "FAIL: sample crashed (rc=$rc, output: $out)"; FAIL=$((FAIL + 1))
  fi
else
  echo "PASS: captured sample test — skipped (no sample file)"; PASS=$((PASS + 1))
fi

# Edge: very large context (>1M tokens) — formatting should still work
big_ctx='{"model":{"display_name":"Opus 4.7","id":"claude-opus-4-7"},"workspace":{"current_dir":"/tmp"},"cost":{"total_duration_ms":0},"context_window":{"context_window_size":1000000,"current_usage":{"input_tokens":500000}}}'
out=$(run_statusline "$big_ctx")
if echo "$out" | grep -qE "1M|1000k"; then
  echo "PASS: 1M context size formatted"; PASS=$((PASS + 1))
else
  echo "FAIL: 1M context formatting wrong"; FAIL=$((FAIL + 1))
fi

# Edge: rate limit info present
rl_input='{"model":{"display_name":"Opus 4.7","id":"claude-opus-4-7"},"workspace":{"current_dir":"/tmp"},"cost":{"total_duration_ms":0},"context_window":{"context_window_size":200000,"current_usage":{}},"rate_limits":{"five_hour":{"used_percentage":25,"resets_at":'"$(( $(date +%s) + 3600 ))"'}}}'
out=$(run_statusline "$rl_input")
if echo "$out" | grep -q "5h:"; then
  echo "PASS: renders rate limit info"; PASS=$((PASS + 1))
else
  echo "FAIL: rate limit not rendered"; FAIL=$((FAIL + 1))
fi

summary
