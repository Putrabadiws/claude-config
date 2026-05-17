#!/bin/bash
# Validates Bash commands for destructive operations.
#
# DESIGN PRINCIPLES (structure-first — substring matching alone is fragile):
# 1. Strip "..." and '...' quoted strings from COMMAND before matching verbs.
#    This eliminates false positives from destructive tokens that appear as text
#    inside argument strings (echo "rm -rf /", git commit -m "drop tables",
#    MR/PR descriptions, etc.).
# 2. Normalize $(...), backticks `...`, and ( ... ) subshell markers to newlines
#    so verbs INSIDE them are still anchored to a sub-command boundary.
# 3. Anchor every verb regex to sub-command start (^, &&, ;, ||, |, newline),
#    allowing optional wrapper prefixes (sudo, time, nohup, xargs, exec, env).
# 4. For string-arg execution wrappers (bash -c, sh -c, zsh -c, eval): check
#    the ORIGINAL (unstripped) command for destructive content, since the
#    payload is inside the quoted argument we'd otherwise strip.
# 5. DDL (DROP/TRUNCATE) requires a DB tool (psql/mysql/sqlite3/mongosh/etc.)
#    as the first token of some sub-command — the SQL keyword is harmless
#    without an engine to execute it.
# 6. Redirect (>) to /dev/sd[a-z] requires a real device-path character to
#    avoid text-only mentions of /dev/sd*.
# 7. Rm system-path trailing context is the natural end of a shell argument
#    (\s | $ | / | ; | & | |) — eliminates "/etc-bak" style false positives
#    while still catching "/etc/myapp" (the / is a subpath separator).
#
# KNOWN LIMITATIONS (regex can't fully parse shell):
# - HEREDOC bodies (<<EOF ... EOF) flow through as part of the command stream
#   and may match verb regexes when fed to non-executing consumers like cat.
#   Mitigation: cat-style heredocs are rare in interactive use; psql/mysql
#   heredocs ARE correctly caught by the DB-tool-gated DDL check.
# - Cross-sub-command contamination on AND-chained checks (e.g. `git push`
#   + `--force` checks) is largely fixed by strip_quoted (commit msgs gone)
#   but theoretically still possible with unquoted contamination.
# - Bash control-flow keywords (do/then/else/{) are not treated as sub-command
#   boundaries — destructive commands inside loops/conditionals slip through.
#
# Exit 2 = block command, Exit 0 = allow command

source "$(dirname "$0")/path-bootstrap.sh"

if ! command -v jq &> /dev/null; then
  echo "Warning: jq not found, skipping validation" >&2
  exit 0
fi

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')
[ -z "$COMMAND" ] && exit 0

# --- Preprocessing ---
# Strip "..." and '...' quoted strings (escape-aware: \" and \' inside count).
strip_quoted() {
  echo "$1" | sed -E 's/"([^"\\]|\\.)*"//g' | sed -E "s/'([^'\\\\]|\\\\.)*'//g"
}
# Normalize $(...) / `...` / (...) — turn the boundary markers into newlines
# so verbs inside them anchor at the synthetic sub-command boundary.
normalize_cmdsub() {
  echo "$1" | sed -E 's/\$\(/\n/g; s/\(/\n/g; s/\)/\n/g' | tr '`' '\n'
}
CMD_STRIPPED=$(strip_quoted "$COMMAND")
CMD_CHECK=$(normalize_cmdsub "$CMD_STRIPPED")

# Extract the first NON-WRAPPER token of each sub-command. Strips leading
# wrappers like sudo / time / nohup / env VAR=x / nice -n N / xargs etc.,
# iterating up to 3 times to handle chained wrappers (e.g. "sudo time psql").
get_first_real_tokens() {
  # NOTE: BSD sed on macOS doesn't support \s — use [[:space:]] (POSIX) so
  # the wrapper-strip works cross-platform.
  echo "$1" | tr '|&;' '\n' | while IFS= read -r line; do
    line="${line#"${line%%[![:space:]]*}"}"
    for _ in 1 2 3; do
      line=$(echo "$line" | sed -E 's/^(sudo|time|nohup|setsid|exec|nice([[:space:]]+-n[[:space:]]+[^[:space:]]+)?|ionice([[:space:]]+-c[[:space:]]*[^[:space:]]+)?|env([[:space:]]+[^[:space:]]+=[^[:space:]]*)+|xargs([[:space:]]+[^[:space:]]+)*)[[:space:]]+//')
    done
    echo "$line" | awk '{print $1}'
  done
}

# Sub-command boundary, with optional wrapper prefixes consumed.
# PREFIXES: zero-or-more wrappers like sudo / time / nohup / xargs / env / exec.
# xargs uses `-\S+` to handle combined flag+value tokens like -n1, --max-args=1.
PREFIXES='(sudo|time|nohup|setsid|stdbuf(\s+-[ioe]\S+)*|exec|env(\s+\S+=\S*)+|nice(\s+-n\s+[-0-9]+)?|ionice(\s+-c\s*[0-9]+)?|xargs(\s+-\S+)*)\s+'
SUB_CMD="(^|&&|;|[|]+|\n)\s*(${PREFIXES})*"

# --- Check 1: destructive git commands ---
if echo "$CMD_CHECK" | grep -qE "${SUB_CMD}git\s+(reset\s+--hard|clean\s+-fd?|branch\s+-D)\b"; then
  echo "Destructive git command detected. Requires approval." >&2
  exit 1
fi

# --- Check 2: git push --force/-f (allow --force-with-lease) ---
# Use CMD_CHECK so commit-msg text contamination is already stripped.
if echo "$CMD_CHECK" | grep -qE "${SUB_CMD}git\s+push\b" \
   && echo "$CMD_CHECK" | grep -qE '(^|\s)(-f|--force)(\s|$)' \
   && ! echo "$CMD_CHECK" | grep -q '\-\-force-with-lease'; then
  echo "git push --force detected. Use --force-with-lease or approve." >&2
  exit 1
fi

# --- Check 3: catastrophic rm on system paths ---
# Trailing context (\s|$|/|;|&|\|) ensures we match /etc, /etc/subdir, /etc;cmd
# but NOT /etc-bak or other user-named paths starting with /etc-something.
if echo "$CMD_CHECK" | grep -qiE "${SUB_CMD}rm\s+(-rf|-fr|-r\s+-f|-f\s+-r)\s+(/|/etc|/var|/usr|/System|/Library|/[a-z]/(Windows|Program)|C:\\\\Windows|C:\\\\Program)(\s|$|/|;|&|\|)"; then
  echo "rm on system root path detected. Requires approval." >&2
  exit 1
fi

# --- Check 3b: xargs piping into destructive rm ---
# Xargs flag forms (-n1, -I {}, -P 4, --max-args=1, etc.) are too variable to
# anchor cleanly with the main verb regex. Instead, per-sub-command scan:
# if a sub-command contains `xargs` AND also has a destructive rm pattern, block.
#
# DELIBERATE REDUNDANCY with Check 3 (which includes xargs in PREFIXES): mutation
# testing showed dropping xargs from PREFIXES still passes all tests because 3b
# covers the same cases — but 3b uniquely catches `xargs -I {} rm ...` since the
# `{}` non-flag token breaks PREFIXES' `(\s+-\S+)*` consumption chain. We keep
# both as belt-and-suspenders: removing either weakens defense against future
# regex drift. Do NOT simplify by deleting one — the overlap is the safety net.
if echo "$CMD_CHECK" | tr '|&;' '\n' | grep -E '\bxargs\b' | grep -qiE '\brm\s+(-rf|-fr|-r\s+-f|-f\s+-r)\s+(/|/etc|/var|/usr|/System|/Library)(\s|$|/|;|&|\|)'; then
  echo "rm via xargs targeting system path. Requires approval." >&2
  exit 1
fi

# --- Check 4: DB DDL gated by DB tool presence (handles sudo psql etc.) ---
# Uses ORIGINAL command — SQL keyword is intentionally inside quotes.
# get_first_real_tokens strips wrapper prefixes (sudo/time/etc.) so wrapped
# DB invocations (e.g. `sudo psql -c "DROP TABLE x"`) are correctly caught.
if echo "$COMMAND" | grep -qiE '(DROP\s+(DATABASE|TABLE|SCHEMA)|TRUNCATE\s+TABLE)'; then
  if get_first_real_tokens "$COMMAND" | grep -qiE '^(psql|mysql|sqlite3?|mongosh?|redis-cli|cqlsh|duckdb|clickhouse-client)$'; then
    echo "DROP/TRUNCATE database command detected. Requires approval." >&2
    exit 1
  fi
fi

# --- Check 5: dangerous system commands ---
# Verb part anchored; redirect part requires /dev/sd[a-z] real device path.
if echo "$CMD_CHECK" | grep -qiE "${SUB_CMD}(mkfs\.|dd\s+if=|format\s+[a-z]:|format\.com|diskpart|chmod\s+-R\s+777|chown\s+-R)" \
   || echo "$CMD_CHECK" | grep -qiE '>\s*/dev/sd[a-z]'; then
  echo "Dangerous system command detected. Requires approval." >&2
  exit 1
fi

# --- Check 6: string-arg execution wrappers (bash -c / sh -c / zsh -c / eval) ---
# These take a SHELL STRING and execute it. The content is inside the quotes
# that strip_quoted removed, so we must scan the ORIGINAL command.
ORIG_TOKENS=$(echo "$COMMAND" | tr '|&;' '\n' | sed 's/^[[:space:]]*//' | awk '{print $1}' | tr '\n' ' ')
if echo "$ORIG_TOKENS" | grep -qE '\b(bash|sh|zsh|eval)\b' \
   && echo "$COMMAND" | grep -qE '\b(bash|sh|zsh)\s+-c\b|\beval\b'; then
  if echo "$COMMAND" | grep -qiE '(rm\s+-rf?\s+(/|/etc|/var|/usr|/System|/Library)|git\s+reset\s+--hard|git\s+clean\s+-fd?|git\s+branch\s+-D|mkfs\.|dd\s+if=/dev/(zero|random|urandom)|chmod\s+-R\s+777|chown\s+-R|>\s*/dev/sd[a-z])'; then
    echo "Destructive command inside bash -c / sh -c / zsh -c / eval. Requires approval." >&2
    exit 1
  fi
fi

exit 0
