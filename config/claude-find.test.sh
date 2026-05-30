#!/bin/bash
# Tests for claude-find.sh — zsh function for searching session history.
#
# claude-find.sh is a SOURCED zsh function file (not executable), so the
# canonical _require_executable check doesn't apply. We invoke the function
# via `zsh -c 'source ...; claude-find "$@"' zsh <args>` with a sandboxed
# HOME so each case operates on isolated fixture JSONLs.

set -u

source "$HOME/.claude/_lib/test-helpers.sh"

SCRIPT="$(_test_script_dir "$0")/claude-find.sh"
PARSER="$(_test_script_dir "$0")/claude-find-parse.py"
[ -r "$SCRIPT" ] || { echo "FATAL: $SCRIPT not readable" >&2; exit 1; }
[ -r "$PARSER" ] || { echo "FATAL: $PARSER not readable" >&2; exit 1; }

# Build sandboxed HOME with a fake ~/.claude/projects/ tree.
new_sandbox() {
  local h
  h=$(mktemp -d)
  mkdir -p "$h/.claude/projects/proj-a" "$h/.claude/projects/proj-b"
  # Symlink parser so the script's `~/.claude/claude-find-parse.py` resolves.
  ln -s "$PARSER" "$h/.claude/claude-find-parse.py"
  echo "$h"
}

# Write a fixture JSONL.  $1=path, $2=cwd, $3=user-message text.
make_jsonl() {
  local path="$1" cwd="$2" msg="$3"
  local sid
  sid=$(basename "${path%.jsonl}")
  cat > "$path" <<EOF
{"type":"permission-mode","permissionMode":"default","sessionId":"$sid"}
{"type":"user","sessionId":"$sid","cwd":"$cwd","timestamp":"2026-05-20T10:00:00Z","gitBranch":"","message":{"content":"$msg"}}
{"type":"assistant","sessionId":"$sid","cwd":"$cwd","timestamp":"2026-05-20T10:00:05Z","message":{"content":[{"type":"text","text":"reply about claude code"}]}}
EOF
}

# Invoke claude-find with sandboxed HOME, return stdout.
# Pass args after the sandbox path; they reach claude-find verbatim via zsh "$@".
run_cf() {
  local h="$1"; shift
  HOME="$h" zsh -c "source '$SCRIPT'; claude-find \"\$@\"" zsh "$@" 2>/dev/null
}

# Same as run_cf but with a fixed COLUMNS so truncation is deterministic.
run_cf_width() {
  local h="$1" cols="$2"; shift 2
  HOME="$h" COLUMNS="$cols" zsh -c "source '$SCRIPT'; claude-find \"\$@\"" zsh "$@" 2>/dev/null
}

# --- Case 1 (normal-safe): no args → usage text + return 1
h=$(new_sandbox)
out=$(HOME="$h" zsh -c "source '$SCRIPT'; claude-find" 2>/dev/null); rc=$?
if [ "$rc" = "1" ] && echo "$out" | grep -q "Usage:"; then
  echo "PASS: no args → usage, rc=1"; PASS=$((PASS + 1))
else
  echo "FAIL: no args → rc=$rc"; FAIL=$((FAIL + 1))
fi
rm -rf "$h"

# --- Case 2 (trigger): default excludes /private/tmp cwd
h=$(new_sandbox)
make_jsonl "$h/.claude/projects/proj-a/normal-session.jsonl" "/Users/dev/project" "bootcamp claude question"
make_jsonl "$h/.claude/projects/proj-b/subagent-session.jsonl" "/private/tmp/worktree-x" "bootcamp claude subagent"
out=$(run_cf "$h" -a bootcamp claude)
if echo "$out" | grep -q "normal-session" && ! echo "$out" | grep -q "subagent-session"; then
  echo "PASS: default excludes /private/tmp cwd"; PASS=$((PASS + 1))
else
  echo "FAIL: default did not exclude /private/tmp"; echo "OUT:"; echo "$out"; FAIL=$((FAIL + 1))
fi
rm -rf "$h"

# --- Case 3 (trigger): -A includes /private/tmp cwd
h=$(new_sandbox)
make_jsonl "$h/.claude/projects/proj-a/normal-session.jsonl" "/Users/dev/project" "bootcamp claude question"
make_jsonl "$h/.claude/projects/proj-b/subagent-session.jsonl" "/private/tmp/worktree-x" "bootcamp claude subagent"
out=$(run_cf "$h" -A -a bootcamp claude)
if echo "$out" | grep -q "normal-session" && echo "$out" | grep -q "subagent-session"; then
  echo "PASS: -A includes /private/tmp"; PASS=$((PASS + 1))
else
  echo "FAIL: -A did not include /private/tmp"; echo "OUT:"; echo "$out"; FAIL=$((FAIL + 1))
fi
rm -rf "$h"

# --- Case 4 (false-positive): cwd containing "tmp" as substring but NOT under /tmp
# (e.g. /Users/x/tmp-experiments) — must NOT be excluded.
h=$(new_sandbox)
make_jsonl "$h/.claude/projects/proj-a/looks-tmp.jsonl" "/Users/candra/tmp-experiments" "bootcamp claude"
out=$(run_cf "$h" -a bootcamp claude)
if echo "$out" | grep -q "looks-tmp"; then
  echo "PASS: /Users/x/tmp-experiments not excluded (substring false-positive)"; PASS=$((PASS + 1))
else
  echo "FAIL: false-positive — non-/tmp path containing 'tmp' was excluded"; echo "OUT:"; echo "$out"; FAIL=$((FAIL + 1))
fi
rm -rf "$h"

# --- Case 5 (trigger): bare /tmp cwd (no subdir) is also excluded by default
h=$(new_sandbox)
make_jsonl "$h/.claude/projects/proj-a/tmp-bare.jsonl" "/tmp" "bootcamp claude"
make_jsonl "$h/.claude/projects/proj-b/normal.jsonl" "/Users/dev/project" "bootcamp claude"
out=$(run_cf "$h" -a bootcamp claude)
if ! echo "$out" | grep -q "tmp-bare" && echo "$out" | grep -q "normal"; then
  echo "PASS: bare /tmp cwd excluded"; PASS=$((PASS + 1))
else
  echo "FAIL: bare /tmp not handled"; echo "OUT:"; echo "$out"; FAIL=$((FAIL + 1))
fi
rm -rf "$h"

# --- Case 6 (edge): no matches → "No sessions found" message
h=$(new_sandbox)
make_jsonl "$h/.claude/projects/proj-a/unrelated.jsonl" "/Users/dev/project" "completely different topic"
out=$(run_cf "$h" -a bootcamp claude)
if echo "$out" | grep -q "No sessions found"; then
  echo "PASS: empty result → 'No sessions found' message"; PASS=$((PASS + 1))
else
  echo "FAIL: empty result not handled"; echo "OUT:"; echo "$out"; FAIL=$((FAIL + 1))
fi
rm -rf "$h"

# --- Case 7 (edge): -A with -e exact-mode and /private/tmp cwd
h=$(new_sandbox)
make_jsonl "$h/.claude/projects/proj-a/sub.jsonl" "/private/tmp/x" "exactly this phrase here"
out=$(run_cf "$h" -A -e "exactly this phrase")
if echo "$out" | grep -q "sub"; then
  echo "PASS: -A combined with -e on /tmp session"; PASS=$((PASS + 1))
else
  echo "FAIL: -A -e combo failed"; echo "OUT:"; echo "$out"; FAIL=$((FAIL + 1))
fi
rm -rf "$h"

# --- Case 8 (edge): only /tmp matches exist → default returns empty, -A returns them
h=$(new_sandbox)
make_jsonl "$h/.claude/projects/proj-a/only-tmp.jsonl" "/private/tmp/x" "bootcamp claude only"
out_default=$(run_cf "$h" -a bootcamp claude)
out_A=$(run_cf "$h" -A -a bootcamp claude)
if echo "$out_default" | grep -q "No sessions found" && echo "$out_A" | grep -q "only-tmp"; then
  echo "PASS: only-tmp fixture → default empty, -A finds it"; PASS=$((PASS + 1))
else
  echo "FAIL: only-tmp case mishandled"; echo "DEFAULT:"; echo "$out_default"; echo "-A:"; echo "$out_A"; FAIL=$((FAIL + 1))
fi
rm -rf "$h"

# --- Case 9 (trigger): macOS $TMPDIR-style cwd excluded
# Real observed example: /private/var/folders/0w/p_44yxbx3_jf1xqbpk4shh380000gn/T
h=$(new_sandbox)
make_jsonl "$h/.claude/projects/proj-a/tmpdir-session.jsonl" \
  "/private/var/folders/0w/p_44yxbx3_jf1xqbpk4shh380000gn/T" "bootcamp claude tmpdir"
make_jsonl "$h/.claude/projects/proj-b/normal.jsonl" "/Users/dev/project" "bootcamp claude"
out=$(run_cf "$h" -a bootcamp claude)
if ! echo "$out" | grep -q "tmpdir-session" && echo "$out" | grep -q "normal"; then
  echo "PASS: /private/var/folders/*/T cwd excluded"; PASS=$((PASS + 1))
else
  echo "FAIL: macOS \$TMPDIR not excluded"; echo "OUT:"; echo "$out"; FAIL=$((FAIL + 1))
fi
rm -rf "$h"

# --- Case 10 (trigger): /var/folders/*/T/subdir (non-/private prefix) also excluded
h=$(new_sandbox)
make_jsonl "$h/.claude/projects/proj-a/tmpdir-sub.jsonl" \
  "/var/folders/0w/abc123/T/cf-worktree" "bootcamp claude worktree"
out=$(run_cf "$h" -a bootcamp claude)
if ! echo "$out" | grep -q "tmpdir-sub" && echo "$out" | grep -q "No sessions found"; then
  echo "PASS: /var/folders/*/T/subdir excluded"; PASS=$((PASS + 1))
else
  echo "FAIL: /var/folders/*/T subdir not excluded"; echo "OUT:"; echo "$out"; FAIL=$((FAIL + 1))
fi
rm -rf "$h"

# --- Case 11 (false-positive): cwd with "var/folders" substring but NOT under */T
# (e.g. /Users/x/var-folders-notes) — must NOT be excluded.
h=$(new_sandbox)
make_jsonl "$h/.claude/projects/proj-a/var-folder-notes.jsonl" \
  "/Users/candra/var-folders-notes" "bootcamp claude notes"
out=$(run_cf "$h" -a bootcamp claude)
if echo "$out" | grep -q "var-folder-notes"; then
  echo "PASS: non-temp /var-folders-* path not excluded (substring false-positive)"; PASS=$((PASS + 1))
else
  echo "FAIL: false-positive — excluded a non-temp path with 'var/folders' substring"; echo "OUT:"; echo "$out"; FAIL=$((FAIL + 1))
fi
rm -rf "$h"

# --- Case 12 (false-positive): /var/folders/*/foo (not under /T) must NOT be excluded
# (only the /T temp subtree is the user-temp dir; other subdirs are unrelated)
h=$(new_sandbox)
make_jsonl "$h/.claude/projects/proj-a/var-folders-other.jsonl" \
  "/var/folders/0w/abc/C/cache-thing" "bootcamp claude cache"
out=$(run_cf "$h" -a bootcamp claude)
if echo "$out" | grep -q "var-folders-other"; then
  echo "PASS: /var/folders/*/C (not /T) not excluded"; PASS=$((PASS + 1))
else
  echo "FAIL: false-positive — excluded /var/folders subdir that isn't /T"; echo "OUT:"; echo "$out"; FAIL=$((FAIL + 1))
fi
rm -rf "$h"

# --- Case 13 (trigger): long First: line truncates to fit terminal width with "…"
# At COLUMNS=80, First: budget is 80-14=66 chars. A 200-char prompt must be cut.
h=$(new_sandbox)
long_msg="aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa bootcamp claude"
make_jsonl "$h/.claude/projects/proj-a/long.jsonl" "/Users/dev/project" "$long_msg"
out=$(run_cf_width "$h" 80 -a bootcamp claude)
# Find the First: line, strip ANSI, count visible chars after the label
first_line=$(echo "$out" | grep -a "First:" | head -1 | sed $'s/\033\\[[0-9;]*m//g')
visible_len=${#first_line}
if echo "$first_line" | grep -q "…" && [ "$visible_len" -le 80 ]; then
  echo "PASS: long First: truncated with … and fits in 80 cols ($visible_len chars)"; PASS=$((PASS + 1))
else
  echo "FAIL: First: line len=$visible_len, has-ellipsis=$(echo "$first_line" | grep -q "…" && echo yes || echo no)"
  echo "  line=[$first_line]"; FAIL=$((FAIL + 1))
fi
rm -rf "$h"

# --- Case 14 (false-positive on truncation): short content must NOT get "…" appended
h=$(new_sandbox)
short_msg="bootcamp claude short"
make_jsonl "$h/.claude/projects/proj-a/short.jsonl" "/Users/dev/project" "$short_msg"
out=$(run_cf_width "$h" 120 -a bootcamp claude)
first_line=$(echo "$out" | grep -a "First:" | head -1 | sed $'s/\033\\[[0-9;]*m//g')
if echo "$first_line" | grep -q "bootcamp claude short" && ! echo "$first_line" | grep -q "…"; then
  echo "PASS: short content not truncated (no spurious …)"; PASS=$((PASS + 1))
else
  echo "FAIL: short content mangled"; echo "  line=[$first_line]"; FAIL=$((FAIL + 1))
fi
rm -rf "$h"

# --- Case 15 (edge): wide terminal (COLUMNS=200) allows >120 char content
# This proves we removed the python 120-char artificial cap.
h=$(new_sandbox)
# 150-char content (was previously capped at 120 by python)
msg150="bootcamp claude $(printf 'x%.0s' {1..130})"
make_jsonl "$h/.claude/projects/proj-a/wide.jsonl" "/Users/dev/project" "$msg150"
out=$(run_cf_width "$h" 200 -a bootcamp claude)
first_line=$(echo "$out" | grep -a "First:" | head -1 | sed $'s/\033\\[[0-9;]*m//g')
# Count xs that survived. With python cap removed, ≥130 xs should appear when width allows.
x_count=$(echo "$first_line" | tr -cd 'x' | wc -c | tr -d ' ')
if [ "$x_count" -ge 130 ]; then
  echo "PASS: wide terminal shows full content beyond old 120-char cap ($x_count xs)"; PASS=$((PASS + 1))
else
  echo "FAIL: only $x_count xs survived — python cap still in effect?"; FAIL=$((FAIL + 1))
fi
rm -rf "$h"

# --- Case 16 (edge): very narrow terminal (COLUMNS=40) still functions, doesn't crash
h=$(new_sandbox)
make_jsonl "$h/.claude/projects/proj-a/narrow.jsonl" "/Users/dev/project" "bootcamp claude in a narrow terminal world"
out=$(run_cf_width "$h" 40 -a bootcamp claude); rc=$?
if [ "$rc" = "0" ] && echo "$out" | grep -q "narrow"; then
  echo "PASS: narrow terminal (40 cols) doesn't crash"; PASS=$((PASS + 1))
else
  echo "FAIL: narrow terminal crashed or produced no output (rc=$rc)"; FAIL=$((FAIL + 1))
fi
rm -rf "$h"

# --- Case 17 (trigger): explicit slug rendered as header title
h=$(new_sandbox)
cat > "$h/.claude/projects/proj-a/with-slug.jsonl" <<EOF
{"type":"permission-mode","permissionMode":"default","sessionId":"with-slug","slug":"my-cool-bootcamp-session"}
{"type":"user","sessionId":"with-slug","cwd":"/Users/dev/project","timestamp":"2026-05-20T10:00:00Z","message":{"content":"bootcamp claude question"}}
EOF
out=$(run_cf "$h" -a bootcamp claude)
if echo "$out" | grep -q "my-cool-bootcamp-session"; then
  echo "PASS: explicit slug rendered as title"; PASS=$((PASS + 1))
else
  echo "FAIL: slug not shown in header"; echo "$out"; FAIL=$((FAIL + 1))
fi
rm -rf "$h"

# --- Case 18 (trigger): no slug → literal "(unnamed)" in header, NOT first_msg
# (matches Claude Code's session picker which shows "(unnamed)" rather than
# substituting the first prompt as title)
h=$(new_sandbox)
make_jsonl "$h/.claude/projects/proj-a/no-slug.jsonl" "/Users/dev/project" "bootcamp claude question about X"
out=$(run_cf_width "$h" 120 -a bootcamp claude)
header=$(echo "$out" | sed $'s/\033\\[[0-9;]*m//g' | grep -E '^[[:space:]]+#[0-9]+[[:space:]]' | head -1)
# Header MUST contain "(unnamed)" and NOT show the user prompt as title.
# (The first_msg legitimately appears later in the "First:" line, so we only
# check the header line.)
if echo "$header" | grep -q "(unnamed)" && ! echo "$header" | grep -q "bootcamp claude question"; then
  echo "PASS: no slug → '(unnamed)' header, not first_msg"; PASS=$((PASS + 1))
else
  echo "FAIL: header should be '(unnamed)'; header=[$header]"; FAIL=$((FAIL + 1))
fi
rm -rf "$h"

# --- Case 19 (edge): no slug AND no user message → still "(unnamed)"
h=$(new_sandbox)
cat > "$h/.claude/projects/proj-a/no-user.jsonl" <<EOF
{"type":"permission-mode","permissionMode":"default","sessionId":"no-user"}
{"type":"assistant","sessionId":"no-user","cwd":"/Users/dev/project","timestamp":"2026-05-20T10:00:00Z","message":{"content":[{"type":"text","text":"bootcamp claude reply"}]}}
EOF
out=$(run_cf "$h" -a bootcamp claude)
header=$(echo "$out" | sed $'s/\033\\[[0-9;]*m//g' | grep -E '^[[:space:]]+#[0-9]+[[:space:]]' | head -1)
if echo "$header" | grep -q "(unnamed)"; then
  echo "PASS: no slug + no user msg → '(unnamed)' header"; PASS=$((PASS + 1))
else
  echo "FAIL: '(unnamed)' header missing; header=[$header]"; FAIL=$((FAIL + 1))
fi
rm -rf "$h"

# --- Case 20 (trigger): long slug truncated with … in header
h=$(new_sandbox)
long_slug=$(printf 'slug-word-%.0s' {1..20})
cat > "$h/.claude/projects/proj-a/long-slug.jsonl" <<EOF
{"type":"permission-mode","permissionMode":"default","sessionId":"long-slug","slug":"$long_slug"}
{"type":"user","sessionId":"long-slug","cwd":"/Users/dev/project","timestamp":"2026-05-20T10:00:00Z","message":{"content":"bootcamp claude"}}
EOF
out=$(run_cf_width "$h" 80 -a bootcamp claude)
header=$(echo "$out" | sed $'s/\033\\[[0-9;]*m//g' | grep -E '^[[:space:]]+#[0-9]+[[:space:]]' | head -1)
if echo "$header" | grep -q "…" && [ "${#header}" -le 80 ]; then
  echo "PASS: long slug truncated with … (header len=${#header})"; PASS=$((PASS + 1))
else
  echo "FAIL: long slug not truncated; header len=${#header} = [$header]"; FAIL=$((FAIL + 1))
fi
rm -rf "$h"

# --- Case 21a (trigger): "(unnamed)" header carries italic ANSI code (\033[3m)
h=$(new_sandbox)
make_jsonl "$h/.claude/projects/proj-a/no-slug.jsonl" "/Users/dev/project" "bootcamp claude"
out=$(run_cf "$h" -a bootcamp claude)
# The header line for an unnamed session should contain both dim (\033[2m)
# AND italic (\033[3m) ANSI codes wrapping "(unnamed)".
header_raw=$(echo "$out" | grep -a '(unnamed)' | head -1)
if echo "$header_raw" | grep -qE $'\033\\[2m\033\\[3m\\(unnamed\\)|\033\\[3m.*\\(unnamed\\)|\\(unnamed\\).*\033\\[3m'; then
  echo "PASS: '(unnamed)' header has italic ANSI"; PASS=$((PASS + 1))
else
  echo "FAIL: italic ANSI missing on unnamed header"; echo "  raw=[$header_raw]"; FAIL=$((FAIL + 1))
fi
rm -rf "$h"

# --- Case 21b (false-positive): named slug header must NOT carry italic ANSI
h=$(new_sandbox)
cat > "$h/.claude/projects/proj-a/named.jsonl" <<EOF
{"type":"permission-mode","permissionMode":"default","sessionId":"named","slug":"real-title"}
{"type":"user","sessionId":"named","cwd":"/Users/dev/project","timestamp":"2026-05-20T10:00:00Z","message":{"content":"bootcamp claude"}}
EOF
out=$(run_cf "$h" -a bootcamp claude)
# Find the header line (contains "#1") and check it does NOT have \033[3m
header_raw=$(echo "$out" | grep -a 'real-title' | head -1)
if echo "$header_raw" | grep -qE $'\033\\[3m'; then
  echo "FAIL: named slug header has italic (should only be magenta)"; echo "  raw=[$header_raw]"; FAIL=$((FAIL + 1))
else
  echo "PASS: named slug header is non-italic"; PASS=$((PASS + 1))
fi
rm -rf "$h"

# --- Case 22 (regression): no `title=...` / `title_color=...` debug output leaks.
# Bug: in zsh, `local NAME` (no value) acts like `typeset NAME` and PRINTS
# the variable on subsequent iterations of a loop that re-declares. Two
# results are required to trigger the second `local` invocation.
h=$(new_sandbox)
make_jsonl "$h/.claude/projects/proj-a/s1.jsonl" "/Users/dev/project" "bootcamp claude first"
make_jsonl "$h/.claude/projects/proj-b/s2.jsonl" "/Users/dev/project" "bootcamp claude second"
out=$(run_cf "$h" -a bootcamp claude)
if echo "$out" | grep -qE '^title=|^title_color='; then
  echo "FAIL: typeset-style leak ('title=...' line in output)"; echo "$out"; FAIL=$((FAIL + 1))
else
  echo "PASS: no typeset-style variable leak between iterations"; PASS=$((PASS + 1))
fi
rm -rf "$h"

summary
