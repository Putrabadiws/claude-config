# Search Claude Code session history
claude-find() {
  local dim=$'\033[2m' cyan=$'\033[36m' yellow=$'\033[33m' green=$'\033[32m'
  local white=$'\033[1;37m' magenta=$'\033[35m' blue=$'\033[34m' reset=$'\033[0m'
  local bar="${dim}───────────────────────────────────────────────────────────────${reset}"
  local parser=~/.claude/claude-find-parse.py

  if [ $# -eq 0 ]; then
    printf "%s\n" "$bar"
    printf "${white}Usage:${reset} claude-find [-a|-e] [-n LIMIT] <search terms>\n\n"
    printf "  ${cyan}claude-find${reset} memory sync history    ${dim}# OR match (any term)${reset}\n"
    printf "  ${cyan}claude-find -a${reset} memory sync history ${dim}# AND match (all terms)${reset}\n"
    printf "  ${cyan}claude-find -e${reset} \"exact phrase here\"  ${dim}# exact string match${reset}\n"
    printf "  ${cyan}claude-find -n 20${reset} memory sync       ${dim}# limit results (default 10)${reset}\n"
    printf "\n  ${dim}Results sorted by most recent session activity.${reset}\n"
    printf "%s\n" "$bar"
    return 1
  fi

  local mode=or limit=10
  while [[ "$1" == -* ]]; do
    case "$1" in
      -a) mode=and; shift ;;
      -e) mode=exact; shift ;;
      -n) shift; limit=$1; shift ;;
      *) break ;;
    esac
  done

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

      count=$((count + 1))
      printf "%s\n" "$bar"
      printf "  ${white}#%d${reset}  ${magenta}%s${reset}  ${dim}(%s msgs)${reset}\n" "$count" "${slug:-unnamed}" "$msg_count"
      printf "  ${yellow}Period:${reset}     %s ${dim}→${reset} %s\n" "${first_ts/T/ }" "${last_ts/T/ }"
      [ -n "$branch" ] && printf "  ${yellow}Branch:${reset}     ${blue}%s${reset}\n" "$branch"
      printf "  ${yellow}First:${reset}      ${dim}%s${reset}\n" "$first_msg"
      printf "  ${yellow}Last chat:${reset}  ${cyan}›${reset} ${dim}%s${reset}\n" "$last_prompt"
      if [ -n "$last_response" ]; then
        printf "  ${yellow}Response:${reset}\n"
        echo "$last_response" | while IFS= read -r line; do
          printf "  ${dim}  %s${reset}\n" "$line"
        done
      fi
      if [ -n "$matched" ]; then
        printf "  ${yellow}Matched:${reset}\n"
        echo "$matched" | while IFS= read -r line; do
          printf "    ${cyan}›${reset} ${dim}%s${reset}\n" "$line"
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
