# Search Claude Code session history
claude-find() {
  local dim=$'\033[2m' cyan=$'\033[36m' yellow=$'\033[33m' green=$'\033[32m'
  local white=$'\033[1;37m' magenta=$'\033[35m' blue=$'\033[34m' reset=$'\033[0m'
  local italic=$'\033[3m'
  local bar="${dim}───────────────────────────────────────────────────────────────${reset}"
  local parser=~/.claude/claude-find-parse.py

  if [ $# -eq 0 ]; then
    printf "%s\n" "$bar"
    printf "${white}Usage:${reset} claude-find [-a|-e] [-n LIMIT] [-A] <search terms>\n\n"
    printf "  ${cyan}claude-find${reset} memory sync history    ${dim}# OR match (any term)${reset}\n"
    printf "  ${cyan}claude-find -a${reset} memory sync history ${dim}# AND match (all terms)${reset}\n"
    printf "  ${cyan}claude-find -e${reset} \"exact phrase here\"  ${dim}# exact string match${reset}\n"
    printf "  ${cyan}claude-find -n 20${reset} memory sync       ${dim}# limit results (default 10)${reset}\n"
    printf "  ${cyan}claude-find -A${reset} memory sync          ${dim}# include subagent runs (/tmp cwd)${reset}\n"
    printf "\n  ${dim}Results sorted by most recent session activity.${reset}\n"
    printf "  ${dim}By default, sessions with cwd under /tmp or /private/tmp are excluded${reset}\n"
    printf "  ${dim}(subagent dispatches, MR review bot, hook-spawned runs). Use -A to include.${reset}\n"
    printf "%s\n" "$bar"
    return 1
  fi

  local mode=or limit=10 include_all=
  while [[ "$1" == -* ]]; do
    case "$1" in
      -a) mode=and; shift ;;
      -e) mode=exact; shift ;;
      -n) shift; limit=$1; shift ;;
      -A) include_all=1; shift ;;
      *) break ;;
    esac
  done

  # Terminal width for truncating long preview content. $COLUMNS isn't
  # exported into subshells by default, so fall back to tput cols, then 100.
  local term_width=${COLUMNS:-0}
  [ "$term_width" -eq 0 ] && term_width=$(tput cols 2>/dev/null || echo 100)
  # _cf_trunc TEXT MAX_VISIBLE_CHARS — emits TEXT, or TEXT[:max-1]+"…" if longer.
  # Strings are already ANSI-stripped by the parser, so ${#t} ≈ visible width.
  # Wide East-Asian chars and tabs would skew the count but don't appear here.
  _cf_trunc() {
    local t="$1" max="$2"
    [ "$max" -lt 4 ] && { echo "$t"; return; }
    if [ ${#t} -gt $max ]; then echo "${t:0:$((max-1))}…"; else echo "$t"; fi
  }

  local pattern files
  local -a and_terms
  if [ "$mode" = "exact" ]; then
    pattern="${${*## }%% }"
    files=$(grep -Frl -- "$pattern" ~/.claude/projects/*/*.jsonl 2>/dev/null)
  elif [ "$mode" = "and" ]; then
    and_terms=("$@")
    pattern=$(echo "$@" | sed 's/ /\\|/g')
    files=$(grep -rl -- "${and_terms[1]}" ~/.claude/projects/*/*.jsonl 2>/dev/null)
    local i=2
    while [ $i -le ${#and_terms[@]} ] && [ -n "$files" ]; do
      files=$(echo "$files" | xargs grep -l -- "${and_terms[$i]}" 2>/dev/null)
      i=$((i + 1))
    done
  else
    pattern=$(echo "$@" | sed 's/ /\\|/g')
    files=$(grep -rl -- "$pattern" ~/.claude/projects/*/*.jsonl 2>/dev/null)
  fi

  # Default: drop subagent runs whose cwd is under a temp dir. Override with -A.
  # Covers /tmp, /private/tmp, and macOS per-user $TMPDIR (/var/folders/*/T,
  # also seen via the /private/ symlink prefix). Pattern: first occurrence of
  # "cwd":"..." in the JSONL.
  if [ -z "$include_all" ] && [ -n "$files" ]; then
    files=$(echo "$files" | while IFS= read -r f; do
      local first_cwd
      first_cwd=$(grep -m1 -o '"cwd":"[^"]*"' "$f" 2>/dev/null)
      case "$first_cwd" in
        *'"/tmp"'|*'"/tmp/'*) ;;
        *'"/private/tmp"'|*'"/private/tmp/'*) ;;
        *'"/var/folders/'*'/T"'|*'"/var/folders/'*'/T/'*) ;;
        *'"/private/var/folders/'*'/T"'|*'"/private/var/folders/'*'/T/'*) ;;
        *) echo "$f" ;;
      esac
    done)
  fi

  # Sort by mtime (newest first) and apply limit
  if [ -n "$files" ]; then
    files=$(echo "$files" | xargs ls -t 2>/dev/null | head -n "$limit")
  fi

  local count=0
  if [ -n "$files" ]; then
    echo "$files" | while read f; do
      local sid= cwd= slug= first_ts= last_ts= msg_count= first_msg= branch= last_prompt=
      {
        read -r sid
        read -r cwd
        read -r slug
        read -r first_ts
        read -r last_ts
        read -r msg_count
        read -r first_msg
        read -r branch
        read -r last_prompt
      } <<< "$(python3 "$parser" "$f" info 2>/dev/null)"

      local last_response=$(python3 "$parser" "$f" response 2>/dev/null)
      local matched=$(grep "$pattern" "$f" 2>/dev/null | python3 "$parser" "" match 2>/dev/null | head -3)

      # Per-label visible-prefix widths (chars before content begins):
      #   First:/Branch:/Period:  → 14   (`  Label:` + alignment spaces to col 14)
      #   Last chat:              → 16   (extra `› ` arrow)
      #   Response: continuation  → 4    (`  ␣␣`)
      #   Matched: continuation   → 6    (`    › `)
      count=$((count + 1))
      # Title: slug in magenta when present; "(unnamed)" in dim parens otherwise,
      # mirroring Claude Code's session picker which shows literal "(unnamed)"
      # rather than substituting the first prompt.
      # NB: assign inline ─ bare `local NAME` is `typeset NAME` in zsh and
      # prints existing values across loop iterations.
      local title="" title_color=""
      if [ -n "$slug" ]; then
        title="$slug"; title_color="$magenta"
      else
        title="(unnamed)"; title_color="${dim}${italic}"
      fi
      # Header format: "  #N  <title>  (M msgs)" — prefix=5+#N, suffix=9+#M
      local title_budget=$((term_width - 14 - ${#count} - ${#msg_count}))
      printf "%s\n" "$bar"
      printf "  ${white}#%d${reset}  ${title_color}%s${reset}  ${dim}(%s msgs)${reset}\n" "$count" "$(_cf_trunc "$title" $title_budget)" "$msg_count"
      printf "  ${yellow}Period:${reset}     %s ${dim}→${reset} %s\n" "${first_ts/T/ }" "${last_ts/T/ }"
      [ -n "$branch" ] && printf "  ${yellow}Branch:${reset}     ${blue}%s${reset}\n" "$(_cf_trunc "$branch" $((term_width - 14)))"
      printf "  ${yellow}First:${reset}      ${dim}%s${reset}\n" "$(_cf_trunc "$first_msg" $((term_width - 14)))"
      printf "  ${yellow}Last chat:${reset}  ${cyan}›${reset} ${dim}%s${reset}\n" "$(_cf_trunc "$last_prompt" $((term_width - 16)))"
      if [ -n "$last_response" ]; then
        printf "  ${yellow}Response:${reset}\n"
        echo "$last_response" | while IFS= read -r line; do
          printf "  ${dim}  %s${reset}\n" "$(_cf_trunc "$line" $((term_width - 4)))"
        done
      fi
      if [ -n "$matched" ]; then
        printf "  ${yellow}Matched:${reset}\n"
        echo "$matched" | while IFS= read -r line; do
          printf "    ${cyan}›${reset} ${dim}%s${reset}\n" "$(_cf_trunc "$line" $((term_width - 6)))"
        done
      fi
      printf "\n  ${green}cd %s && claude --resume %s${reset}\n\n" "$cwd" "$sid"
    done
  fi

  if [ $count -eq 0 ]; then
    printf "%s\n" "$bar"
    printf "  ${dim}No sessions found matching:${reset} %s\n" "$*"
    printf "%s\n" "$bar"
  fi
}
