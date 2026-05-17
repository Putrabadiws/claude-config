#!/bin/bash
# Tests for inject-claude-version.sh — three-branch attribution logic.
# Branch A: placeholders present → replace via updatedInput.
# Branch B: attribution line present manually → verify version/model match.
# Branch C: no attribution → emit IMPORTANT note with resolved values.
# Run: bash ~/.claude/hooks/inject-claude-version.test.sh

source "$HOME/.claude/_lib/test-helpers.sh"
HOOK="$(_test_script_dir "$0")/inject-claude-version.sh"
_require_executable "$HOOK"

# The hook reads version from $CLAUDE_CODE_VERSION env (or claude --version fallback)
# and model from .transcript_path JSONL. We control both via env + a temp transcript.

# Prepare a fake transcript file with a known model
TRANSCRIPT=$(mktemp)
cat > "$TRANSCRIPT" <<EOF
{"type":"assistant","message":{"model":"claude-opus-4-7"}}
EOF
export CLAUDE_CODE_VERSION="2.1.143"

# Helper: invoke with command + transcript, return stdout
invoke_hook() {
  local cmd="$1"
  jq -n --arg c "$cmd" --arg t "$TRANSCRIPT" '{tool_input:{command:$c},transcript_path:$t}' | "$HOOK" 2>/dev/null
}

# Stage 1 — early exit: non-commit/MR/PR commands ignored
out=$(invoke_hook 'ls -la')
if [ -z "$out" ]; then
  echo "PASS: non-commit command — silent exit"; PASS=$((PASS + 1))
else
  echo "FAIL: should be silent on non-commit (got: $out)"; FAIL=$((FAIL + 1))
fi

# Regression: substring mention of verb in argument text should NOT fire
out=$(invoke_hook 'grep "glab mr create" /tmp/file')
if [ -z "$out" ]; then
  echo "PASS: grep with glab mr create in arg — silent"; PASS=$((PASS + 1))
else
  echo "FAIL: substring match false-positive (got: $out)"; FAIL=$((FAIL + 1))
fi

out=$(invoke_hook 'echo "git commit guidance: use -m"')
if [ -z "$out" ]; then
  echo "PASS: echo mentioning git commit — silent"; PASS=$((PASS + 1))
else
  echo "FAIL: echo substring false-positive"; FAIL=$((FAIL + 1))
fi

out=$(invoke_hook 'cat README | grep "gh pr create"')
if [ -z "$out" ]; then
  echo "PASS: piped grep with gh pr substring — silent"; PASS=$((PASS + 1))
else
  echo "FAIL: piped grep substring false-positive"; FAIL=$((FAIL + 1))
fi

# Counter-check: chained git commit after && still fires
out=$(invoke_hook 'cd /tmp && git commit -m "msg {{claude-code-version}}"')
if echo "$out" | jq -e '.hookSpecificOutput.updatedInput.command' > /dev/null 2>&1; then
  echo "PASS: chained && git commit triggers Branch A"; PASS=$((PASS + 1))
else
  echo "FAIL: chained && git commit should fire"; FAIL=$((FAIL + 1))
fi

# Branch A — placeholders {{claude-code-version}}, {{claude-model}}
out=$(invoke_hook 'git commit -m "msg {{claude-code-version}} ({{claude-model}})"')
if echo "$out" | jq -e '.hookSpecificOutput.updatedInput.command' > /dev/null 2>&1; then
  updated=$(echo "$out" | jq -r '.hookSpecificOutput.updatedInput.command')
  if echo "$updated" | grep -q "2.1.143" && echo "$updated" | grep -q "claude-opus-4-7"; then
    echo "PASS: Branch A — placeholders replaced"; PASS=$((PASS + 1))
  else
    echo "FAIL: Branch A — values not substituted in: $updated"; FAIL=$((FAIL + 1))
  fi
else
  echo "FAIL: Branch A — no updatedInput emitted"; FAIL=$((FAIL + 1))
fi

# Branch A — legacy single-brace {version}, {model}
out=$(invoke_hook 'git commit -m "msg {version} ({model})"')
updated=$(echo "$out" | jq -r '.hookSpecificOutput.updatedInput.command // empty')
if echo "$updated" | grep -q "2.1.143" && echo "$updated" | grep -q "claude-opus-4-7"; then
  echo "PASS: Branch A — legacy {version}/{model} replaced"; PASS=$((PASS + 1))
else
  echo "FAIL: Branch A legacy — not substituted (got: $updated)"; FAIL=$((FAIL + 1))
fi

# Branch B — manual substitution, CORRECT values → short context only
out=$(invoke_hook 'git commit -m "msg ✨ Generated with Claude Code (claude.ai/claude-code) 2.1.143 (claude-opus-4-7)"')
ctx=$(echo "$out" | jq -r '.hookSpecificOutput.additionalContext // empty')
if echo "$ctx" | grep -q "Claude Code version: 2.1.143" && ! echo "$ctx" | grep -q "MISMATCH"; then
  echo "PASS: Branch B — correct manual substitution → short context"; PASS=$((PASS + 1))
else
  echo "FAIL: Branch B correct — wrong message: $ctx"; FAIL=$((FAIL + 1))
fi

# Branch B — WRONG model format ("Opus 4.7" instead of dashed ID)
out=$(invoke_hook 'git commit -m "msg ✨ Generated with Claude Code (claude.ai/claude-code) 2.1.143 (Opus 4.7)"')
ctx=$(echo "$out" | jq -r '.hookSpecificOutput.additionalContext // empty')
if echo "$ctx" | grep -q "ATTRIBUTION MISMATCH"; then
  echo "PASS: Branch B — wrong model triggers MISMATCH"; PASS=$((PASS + 1))
else
  echo "FAIL: Branch B mismatch not detected: $ctx"; FAIL=$((FAIL + 1))
fi

# Branch B — WRONG version
out=$(invoke_hook 'git commit -m "msg ✨ Generated with Claude Code (claude.ai/claude-code) 0.0.1 (claude-opus-4-7)"')
ctx=$(echo "$out" | jq -r '.hookSpecificOutput.additionalContext // empty')
if echo "$ctx" | grep -q "ATTRIBUTION MISMATCH"; then
  echo "PASS: Branch B — wrong version triggers MISMATCH"; PASS=$((PASS + 1))
else
  echo "FAIL: Branch B wrong version not detected"; FAIL=$((FAIL + 1))
fi

# Branch C — no attribution at all → IMPORTANT note
out=$(invoke_hook 'git commit -m "plain message no attribution"')
ctx=$(echo "$out" | jq -r '.hookSpecificOutput.additionalContext // empty')
if echo "$ctx" | grep -q "IMPORTANT: attribution line missing"; then
  echo "PASS: Branch C — missing attribution → IMPORTANT note"; PASS=$((PASS + 1))
else
  echo "FAIL: Branch C — should emit IMPORTANT note: $ctx"; FAIL=$((FAIL + 1))
fi

# Branch C — message contains "Generated" as plain text (not attribution line).
# Mutation-driven: proves Branch B detection MUST match the full
# `✨ Generated with Claude Code` prefix, not just substring `Generated`.
# Without strict prefix matching, this would wrongly trigger Branch B and emit
# ATTRIBUTION MISMATCH instead of the IMPORTANT note for missing attribution.
out=$(invoke_hook 'git commit -m "Generated new feature without attribution"')
ctx=$(echo "$out" | jq -r '.hookSpecificOutput.additionalContext // empty')
if echo "$ctx" | grep -q "IMPORTANT: attribution line missing" && ! echo "$ctx" | grep -q "MISMATCH"; then
  echo "PASS: Branch C — 'Generated' as plain word still takes Branch C"; PASS=$((PASS + 1))
else
  echo "FAIL: Branch C — 'Generated' substring wrongly triggered Branch B: $ctx"; FAIL=$((FAIL + 1))
fi

# Filter: glab mr create triggers same logic
out=$(invoke_hook 'glab mr create --description "{{claude-code-version}}"')
updated=$(echo "$out" | jq -r '.hookSpecificOutput.updatedInput.command // empty')
if echo "$updated" | grep -q "2.1.143"; then
  echo "PASS: glab mr create — Branch A fires"; PASS=$((PASS + 1))
else
  echo "FAIL: glab mr create not handled"; FAIL=$((FAIL + 1))
fi

# Filter: gh pr create triggers same logic
out=$(invoke_hook 'gh pr create --body "{{claude-code-version}}"')
updated=$(echo "$out" | jq -r '.hookSpecificOutput.updatedInput.command // empty')
if echo "$updated" | grep -q "2.1.143"; then
  echo "PASS: gh pr create — Branch A fires"; PASS=$((PASS + 1))
else
  echo "FAIL: gh pr create not handled"; FAIL=$((FAIL + 1))
fi

# Cleanup
rm -f "$TRANSCRIPT"
unset CLAUDE_CODE_VERSION

summary
