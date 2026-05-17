#!/bin/bash
# SYNC:LOCAL-ONLY  — per-repo PLATFORM detection diverges; do not bulk-cp from live or other repo.
# Source shared cross-platform compat helpers (_date_from_epoch, _file_mtime, etc.)
source "$HOME/.claude/_lib/compat.sh"

input=$(cat)
echo "$input" | jq '.' > "$HOME/.claude/logs/statusline-raw.json" 2>/dev/null

# Detect real terminal width via /dev/tty (stdin is piped JSON)
TERM_WIDTH=$(stty size < /dev/tty 2>/dev/null | awk '{print $2}')
TERM_WIDTH="${TERM_WIDTH:-120}"

# Extract fields
MODEL=$(echo "$input" | jq -r '.model.display_name')
MODEL_ID=$(echo "$input" | jq -r '.model.id // empty')
VERSION=$(echo "$input" | jq -r '.version // empty')
DIR=$(echo "$input" | jq -r '.workspace.current_dir')
DURATION_MS=$(echo "$input" | jq -r '.cost.total_duration_ms // 0')
CTX_SIZE=$(echo "$input" | jq -r '.context_window.context_window_size // 200000')
CTX_INPUT=$(echo "$input" | jq -r '.context_window.current_usage.input_tokens // 0')
CTX_CACHE_CREATE=$(echo "$input" | jq -r '.context_window.current_usage.cache_creation_input_tokens // 0')
CTX_CACHE_READ=$(echo "$input" | jq -r '.context_window.current_usage.cache_read_input_tokens // 0')
FIVE_PCT=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
FIVE_RESET=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')
WEEK_PCT=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')
WEEK_RESET=$(echo "$input" | jq -r '.rate_limits.seven_day.resets_at // empty')

# Colors
CYAN='\033[36m'; GREEN='\033[32m'; YELLOW='\033[33m'; RED='\033[31m'
MAGENTA='\033[35m'; BLUE='\033[34m'; DIM='\033[2m'; BOLD='\033[1m'; RESET='\033[0m'

# Detect platform from path
PLATFORM=""
case "$DIR" in
  */bangor-claude-config*|*/.claude/*) PLATFORM="${CYAN}⚙️ Config${RESET}" ;;
  */pipeline-*|*/ci-components*)       PLATFORM="${DIM}🔧 CI/CD${RESET}" ;;
  */*-chart*|*/charts/*)               PLATFORM="${DIM}☸️ Helm${RESET}" ;;
esac

# Git info (cached)
CACHE_FILE="/tmp/cc-statusline-git"
CACHE_MAX_AGE=5

cache_is_stale() {
  [ ! -f "$CACHE_FILE" ] || \
  [ $(($(date +%s) - $(_file_mtime "$CACHE_FILE" || echo 0))) -gt $CACHE_MAX_AGE ]
}

if cache_is_stale; then
  if git -C "$DIR" rev-parse --git-dir > /dev/null 2>&1; then
    BRANCH=$(git -C "$DIR" branch --show-current 2>/dev/null)
    STAGED=$(git -C "$DIR" diff --cached --numstat 2>/dev/null | wc -l | tr -d ' ')
    MODIFIED=$(git -C "$DIR" diff --numstat 2>/dev/null | wc -l | tr -d ' ')
    echo "$BRANCH|$STAGED|$MODIFIED" > "$CACHE_FILE"
  else
    echo "||" > "$CACHE_FILE"
  fi
fi

IFS='|' read -r BRANCH STAGED MODIFIED < "$CACHE_FILE"

# Repo name = directory basename
REPO="${DIR##*/}"

# Build git status indicators
GIT_INFO=""
if [ -n "$BRANCH" ]; then
  case "$BRANCH" in
    release*|develop|main|master) BRANCH_COLOR="$RED$BOLD" ;;
    *)                            BRANCH_COLOR="$GREEN" ;;
  esac
  GIT_INFO=" ${DIM}on${RESET} ${BRANCH_COLOR}${BRANCH}${RESET}"
  [ "$STAGED" -gt 0 ] && GIT_INFO="${GIT_INFO} ${GREEN}+${STAGED}${RESET}"
  [ "$MODIFIED" -gt 0 ] && GIT_INFO="${GIT_INFO} ${YELLOW}~${MODIFIED}${RESET}"
fi

# Auto-compact buffer in tokens (~33k regardless of context size, overridable)
COMPACT_BUFFER="${CLAUDE_AUTOCOMPACT_BUFFER:-33000}"
COMPACT_THRESHOLD=$((CTX_SIZE - COMPACT_BUFFER))
COMPACT_PCT=$(awk "BEGIN {printf \"%.1f\", $COMPACT_THRESHOLD * 100 / $CTX_SIZE}")

# Token usage (computed early for precise threshold math)
CTX_USED=$((CTX_INPUT + CTX_CACHE_CREATE + CTX_CACHE_READ))
PCT=$(awk "BEGIN {printf \"%.1f\", $CTX_USED * 100 / ($CTX_SIZE > 0 ? $CTX_SIZE : 1)}")

# Remaining usable context before autocompact (token-based for precision)
USABLE_LEFT_TOKENS=$((COMPACT_THRESHOLD - CTX_USED))
[ "$USABLE_LEFT_TOKENS" -lt 0 ] && USABLE_LEFT_TOKENS=0
USABLE_LEFT=$(awk "BEGIN {printf \"%.1f\", $USABLE_LEFT_TOKENS * 100 / $CTX_SIZE}")
USABLE_LEFT_OF_COMPACT=$(awk "BEGIN {printf \"%.1f\", $USABLE_LEFT_TOKENS * 100 / ($COMPACT_THRESHOLD > 0 ? $COMPACT_THRESHOLD : 1)}")

# Shared tier logic: remaining headroom % → color + emoji + fire
# >40% green, 16-40% cyan, 5-16% yellow, <5% red
# Over-pace fire ladder: [0,-10]→🔥, (-10,-20]→🔥🔥, ... (-40,-50]→🔥🔥🔥🔥🔥, <-50→🔥🔥🔥🔥🔥+
compute_tier() {
  local remaining="$1"
  _TIER_FIRE=""
  if awk "BEGIN {exit !($remaining < -50)}"; then _TIER_FIRE="🔥🔥🔥🔥🔥+"
  elif awk "BEGIN {exit !($remaining < -40)}"; then _TIER_FIRE="🔥🔥🔥🔥🔥"
  elif awk "BEGIN {exit !($remaining < -30)}"; then _TIER_FIRE="🔥🔥🔥🔥"
  elif awk "BEGIN {exit !($remaining < -20)}"; then _TIER_FIRE="🔥🔥🔥"
  elif awk "BEGIN {exit !($remaining < -10)}"; then _TIER_FIRE="🔥🔥"
  elif awk "BEGIN {exit !($remaining < 0)}"; then _TIER_FIRE="🔥"
  fi
  if awk "BEGIN {exit !($remaining > 40)}"; then
    _TIER_CLR="$GREEN"; _TIER_EMOJI="✅"
  elif awk "BEGIN {exit !($remaining > 16)}"; then
    _TIER_CLR="$CYAN"; _TIER_EMOJI="🔷"
  elif awk "BEGIN {exit !($remaining > 5)}"; then
    _TIER_CLR="$YELLOW"; _TIER_EMOJI="⚠️"
  else
    _TIER_CLR="${RED}${BOLD}"; _TIER_EMOJI="🚨"
  fi
}

# Format percentage with tier emoji + color + optional 🔥🔥🔥
colour_pct() {
  local value="$1" remaining="$2"
  compute_tier "$remaining"
  printf "%s ${BOLD}${_TIER_CLR}%g%%${RESET}" "$_TIER_EMOJI" "$value"
  [ -n "$_TIER_FIRE" ] && printf " %s" "$_TIER_FIRE"
}

CTX_PCT_FMT=$(colour_pct "$PCT" "$USABLE_LEFT_OF_COMPACT")
compute_tier "$USABLE_LEFT_OF_COMPACT"
CTX_COLOR="$_TIER_CLR"

# Token usage formatting
if [ "$CTX_USED" -ge 1000 ]; then
  CTX_USED_FMT="$((CTX_USED / 1000))k"
else
  CTX_USED_FMT="$CTX_USED"
fi
if [ "$CTX_SIZE" -ge 1000000 ]; then
  CTX_SIZE_FMT="$((CTX_SIZE / 1000000))M"
elif [ "$CTX_SIZE" -ge 1000 ]; then
  CTX_SIZE_FMT="$((CTX_SIZE / 1000))k"
else
  CTX_SIZE_FMT="$CTX_SIZE"
fi

# Duration
TOTAL_SECS=$((DURATION_MS / 1000))
HOURS=$((TOTAL_SECS / 3600))
MINS=$(((TOTAL_SECS % 3600) / 60))
SECS=$((TOTAL_SECS % 60))
[ "$HOURS" -eq 0 ] && HOURS=""
[ "$MINS" -eq 0 ] && [ -z "$HOURS" ] && MINS=""
[ "$SECS" -eq 0 ] && [ -n "$MINS$HOURS" ] && SECS=""

# Dynamic widths
USABLE_WIDTH=$((TERM_WIDTH - 30))
LINE1_WIDTH="${STATUSLINE_LINE1_WIDTH:-$USABLE_WIDTH}"

# Truncate string with ANSI codes to N visible columns
truncate_ansi() {
  local max_w="$1" input="$2"
  local plain vis_len
  plain=$(printf '%b' "$input" | sed $'s/\033\[[0-9;]*m//g')
  vis_len=$(printf '%s' "$plain" | wc -m | tr -d ' ')
  [ "$vis_len" -le "$max_w" ] && { printf '%b' "$input"; return; }
  printf '%b' "$input" | LANG=en_US.UTF-8 perl -e '
    use Encode;
    binmode(STDIN, ":utf8"); binmode(STDOUT, ":raw");
    my $max = $ARGV[0];
    my $line = <STDIN>; chomp $line;
    my ($vis, $out, $i, $len) = (0, "", 0, length($line));
    while ($i < $len && $vis < $max - 1) {
      if (substr($line, $i, 1) eq "\033") {
        my $j = $i;
        $j++ while $j < $len && substr($line, $j, 1) ne "m";
        $out .= substr($line, $i, $j - $i + 1);
        $i = $j + 1;
      } else { $out .= substr($line, $i, 1); $vis++; $i++; }
    }
    print encode("UTF-8", $out . "\033[0m\x{2026}");
  ' "$max_w"
}

# Note: _date_from_epoch lives in ~/.claude/_lib/compat.sh (sourced at the top
# of this file). _midnight_today is statusline-specific so it stays here.
_midnight_today() {
  # Returns epoch of midnight today (local time)
  date -d "$(date +%Y-%m-%d)" +%s 2>/dev/null || \
    date -j -f "%Y%m%d%H%M%S" "$(date +%Y%m%d)000000" +%s 2>/dev/null
}

# Rate limit helpers
fmt_countdown() {
  local ts="$1" now
  [ -z "$ts" ] && return
  now=$(date +%s)
  local diff=$(( ts - now ))
  (( diff <= 0 )) && { printf "now"; return; }
  local h=$(( diff / 3600 )) m=$(( (diff % 3600) / 60 ))
  if (( h > 0 )); then printf "%dh%dm" "$h" "$m"
  else printf "%dm" "$m"; fi
}

fmt_reset_abs() {
  local ts="$1"
  [ -z "$ts" ] && return
  local now day_now day_reset minute hour_fmt
  now=$(date +%s)
  day_now=$(_date_from_epoch "$now" "%Y%m%d")
  day_reset=$(_date_from_epoch "$ts" "%Y%m%d")
  minute=$(_date_from_epoch "$ts" "%M")
  # Show :MM only when not on the hour — 5h windows rarely land on :00
  if [ "$minute" = "00" ]; then hour_fmt="%-l%p"; else hour_fmt="%-l:%M%p"; fi
  if [ "$day_now" = "$day_reset" ]; then
    _date_from_epoch "$ts" "$hour_fmt" | sed 's/AM/am/;s/PM/pm/'
  else
    _date_from_epoch "$ts" "%-d %b @ $hour_fmt" | sed 's/AM/am/;s/PM/pm/'
  fi
}

fmt_reset_dynamic() {
  local ts="$1" now diff
  [ -z "$ts" ] && return
  now=$(date +%s); diff=$(( ts - now ))
  if (( diff <= 0 )); then printf "now"
  elif (( diff < 86400 )); then fmt_countdown "$ts"
  else fmt_reset_abs "$ts"
  fi
}

# Compute proportional fair share for each window
# ELAPSED is ceiled to next 5-min bucket (min 300s) and EXPECTED is ceiled to
# integer % so it matches USED's integer-only granularity from the harness JSON.
FIVE_EXPECTED=100
if [ -n "$FIVE_RESET" ]; then
  FIVE_NOW=$(date +%s)
  FIVE_START=$(( FIVE_RESET - 5 * 3600 ))
  FIVE_ELAPSED=$(( FIVE_NOW - FIVE_START ))
  [ "$FIVE_ELAPSED" -lt 0 ] && FIVE_ELAPSED=0
  FIVE_ELAPSED=$(( (FIVE_ELAPSED + 299) / 300 * 300 ))
  [ "$FIVE_ELAPSED" -lt 300 ] && FIVE_ELAPSED=300
  FIVE_EXPECTED=$(awk "BEGIN {v=$FIVE_ELAPSED * 100 / (5 * 3600); v = int(v) + (v > int(v)); printf \"%d\", (v > 100 ? 100 : v)}")
fi
WEEK_EXPECTED=100
if [ -n "$WEEK_RESET" ]; then
  WEEK_NOW_E=$(date +%s)
  WEEK_START_E=$(( WEEK_RESET - 7 * 86400 ))
  WEEK_ELAPSED=$(( WEEK_NOW_E - WEEK_START_E ))
  [ "$WEEK_ELAPSED" -lt 0 ] && WEEK_ELAPSED=0
  WEEK_ELAPSED=$(( (WEEK_ELAPSED + 299) / 300 * 300 ))
  [ "$WEEK_ELAPSED" -lt 300 ] && WEEK_ELAPSED=300
  WEEK_EXPECTED=$(awk "BEGIN {v=$WEEK_ELAPSED * 100 / (7 * 86400); v = int(v) + (v > int(v)); printf \"%d\", (v > 100 ? 100 : v)}")
fi

# Remaining headroom: (expected - used) / expected * 100
# Negative = over pace → triggers 🔥🔥🔥
FIVE_REMAINING=$(awk "BEGIN {printf \"%g\", ($FIVE_EXPECTED - ${FIVE_PCT:-0}) / ($FIVE_EXPECTED > 0 ? $FIVE_EXPECTED : 1) * 100}")
WEEK_REMAINING=$(awk "BEGIN {printf \"%g\", ($WEEK_EXPECTED - ${WEEK_PCT:-0}) / ($WEEK_EXPECTED > 0 ? $WEEK_EXPECTED : 1) * 100}")

# Build rate limit segments (3 tiers for progressive truncation)
RATE_FULL="" RATE_NO_ABS="" RATE_BARE=""
if [ -n "$FIVE_PCT" ]; then
  FIVE_DYN=$(fmt_reset_dynamic "$FIVE_RESET")
  FIVE_ABS=$(fmt_reset_abs "$FIVE_RESET")
  FIVE_CLR=$(colour_pct "$FIVE_PCT" "$FIVE_REMAINING")
  RATE_BARE="${RATE_BARE} ${DIM}│${RESET} 5h: ${FIVE_CLR}"
  RATE_NO_ABS="${RATE_NO_ABS} ${DIM}│${RESET} 5h: ${FIVE_CLR}"
  [ -n "$FIVE_DYN" ] && RATE_NO_ABS="${RATE_NO_ABS} ${DIM}⌞${FIVE_DYN}⌝${RESET}"
  RATE_FULL="${RATE_FULL} ${DIM}│${RESET} 5h: ${FIVE_CLR}"
  if [ -n "$FIVE_DYN" ]; then
    if [ -n "$FIVE_ABS" ] && [ "$FIVE_DYN" != "$FIVE_ABS" ]; then
      RATE_FULL="${RATE_FULL} ${DIM}⌞${FIVE_DYN} (${FIVE_ABS})⌝${RESET}"
    else
      RATE_FULL="${RATE_FULL} ${DIM}⌞${FIVE_DYN}⌝${RESET}"
    fi
  fi
fi
if [ -n "$WEEK_PCT" ]; then
  WEEK_CLR=$(colour_pct "$WEEK_PCT" "$WEEK_REMAINING")
  # Day X/7: cycle at reset time-of-day, not midnight
  if [ -n "$WEEK_RESET" ]; then
    WEEK_NOW=$(date +%s)
    WEEK_START=$(( WEEK_RESET - 7 * 86400 ))
    ELAPSED=$(( WEEK_NOW - WEEK_START ))
    WEEK_DAY=$(( ELAPSED / 86400 + 1 ))
    [ "$WEEK_DAY" -lt 1 ] && WEEK_DAY=1
    [ "$WEEK_DAY" -gt 7 ] && WEEK_DAY=7
    if (( WEEK_DAY == 7 )); then
      # Day 7: show "day-7" until midnight local, then countdown
      TODAY_START=$(_midnight_today)
      DAY7_START=$(( WEEK_START + 6 * 86400 ))
      if (( DAY7_START >= TODAY_START )); then
        WEEK_LABEL="day-7"
      else
        WEEK_LABEL=$(fmt_countdown "$WEEK_RESET")
      fi
    else
      WEEK_LABEL="day-${WEEK_DAY}"
    fi
    WEEK_MIN=$(_date_from_epoch "$WEEK_RESET" "%M")
    if [ "$WEEK_MIN" = "00" ]; then WEEK_HFMT="%-l%p"; else WEEK_HFMT="%-l:%M%p"; fi
    WEEK_TIME=$(_date_from_epoch "$WEEK_RESET" "$WEEK_HFMT" | sed 's/AM/am/;s/PM/pm/')
  fi
  RATE_BARE="${RATE_BARE} ${DIM}│${RESET} 7d: ${WEEK_CLR}"
  RATE_NO_ABS="${RATE_NO_ABS} ${DIM}│${RESET} 7d: ${WEEK_CLR}"
  [ -n "$WEEK_RESET" ] && RATE_NO_ABS="${RATE_NO_ABS} ${DIM}⌞${WEEK_LABEL}⌝${RESET}"
  RATE_FULL="${RATE_FULL} ${DIM}│${RESET} 7d: ${WEEK_CLR}"
  if [ -n "$WEEK_RESET" ]; then
    if [ -n "$WEEK_TIME" ]; then
      RATE_FULL="${RATE_FULL} ${DIM}⌞${WEEK_LABEL} (${WEEK_TIME})⌝${RESET}"
    else
      RATE_FULL="${RATE_FULL} ${DIM}⌞${WEEK_LABEL}⌝${RESET}"
    fi
  fi
fi

# Model name from model.id
FULL_MODEL="$MODEL"
if [ -n "$MODEL_ID" ]; then
  case "$MODEL_ID" in
    *opus*)    VER=$(echo "$MODEL_ID" | sed -n 's/.*opus-\([0-9]*\)-\([0-9]*\)/\1.\2/p'); [ -n "$VER" ] && FULL_MODEL="Opus $VER" ;;
    *sonnet*)  VER=$(echo "$MODEL_ID" | sed -n 's/.*sonnet-\([0-9]*\)-\([0-9]*\).*/\1.\2/p'); [ -n "$VER" ] && FULL_MODEL="Sonnet $VER" ;;
    *haiku*)   VER=$(echo "$MODEL_ID" | sed -n 's/.*haiku-\([0-9]*\)-\([0-9]*\).*/\1.\2/p'); [ -n "$VER" ] && FULL_MODEL="Haiku $VER" ;;
  esac
fi

# Measure visible width
vis_len() { printf '%b' "$1" | sed $'s/\033\[[0-9;]*m//g' | wc -m | tr -d ' '; }

# Line 1: platform | repo + branch
LINE1=""
[ -n "$PLATFORM" ] && LINE1="${PLATFORM} ${DIM}│${RESET} "
LINE1="${LINE1}📂 ${BOLD}${REPO}${RESET}${GIT_INFO}"
LINE1_TRIMMED=$(truncate_ansi "$LINE1_WIDTH" "$LINE1")

# Line 2: ctx [emoji] XX% ⌞tokens⌝ │ 💥 compact info │ ⏱ duration
# Adaptive: show threshold when plenty of room, show remaining when ≤15%.
# Use awk for the comparison — USABLE_LEFT_OF_COMPACT is a float (%.1f), and
# bash `-le` requires integers. Matches the pattern used by compute_tier above.
if awk "BEGIN {exit !($USABLE_LEFT_OF_COMPACT <= 15)}"; then
  COMPACT_INFO="💥 ${CTX_COLOR}~${USABLE_LEFT}% left${RESET}"
else
  COMPACT_INFO="💥 ${DIM}auto-compact at ~${COMPACT_PCT}%${RESET}"
fi
LINE2="ctx ${CTX_PCT_FMT} ${DIM}⌞${CTX_USED_FMT}/${CTX_SIZE_FMT}⌝${RESET} ${DIM}│${RESET} ${COMPACT_INFO} ${DIM}│${RESET} ⏱ ${HOURS:+${HOURS}h }${MINS:+${MINS}m }${SECS:+${SECS}s}"

# Line 3: model + rate limits (progressive truncation)
LINE3_BASE="${CYAN}✦ ${FULL_MODEL}${RESET}"

LINE3=""
for tier in full no_abs no_reset bare none; do
  case "$tier" in
    full)      RATE="$RATE_FULL" ;;
    no_abs)    RATE="$RATE_NO_ABS" ;;
    no_reset)  RATE="$RATE_BARE" ;;
    bare)      RATE="$RATE_BARE" ;;
    none)      RATE="" ;;
  esac
  LINE3="${LINE3_BASE}${RATE}"
  [ "$(vis_len "$LINE3")" -le "$USABLE_WIDTH" ] && break
done

echo "$LINE1_TRIMMED"
printf '%b\n' "$LINE2"
printf '%b\n' "$LINE3"

# Line 4 (conditional): config update notification
PENDING_FILE="$HOME/.claude/.config-update-pending"
if [ -f "$PENDING_FILE" ]; then
  PENDING_COUNT=$(cat "$PENDING_FILE" 2>/dev/null | tr -d '[:space:]')
  [ -z "$PENDING_COUNT" ] && PENDING_COUNT="new"
  printf '%b\n' "${YELLOW}🔄 ${PENDING_COUNT} new commit(s) on team config — run ${BOLD}/bangor-sync-config${RESET}${YELLOW} to sync${RESET}"
fi

