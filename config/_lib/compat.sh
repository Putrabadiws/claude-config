#!/bin/bash
# Cross-platform compatibility helpers for shell scripts.
# Source from any *.sh that calls commands with BSD-vs-GNU divergence:
#   source "$HOME/.claude/_lib/compat.sh"
#
# Handles known divergence points:
#   - date -d "@<epoch>" (GNU)  vs  date -r <epoch> (BSD/macOS)
#   - stat -c %Y (GNU)          vs  stat -f %m (BSD/macOS)
#   - readlink -f (GNU)         vs  realpath / shell loop (BSD/macOS old)
#   - echo -e (GNU)             vs  printf '%b' (POSIX)
#   - sed -i '' '' (BSD)        vs  sed -i '...' (GNU)
#
# OS detection flags (set after sourcing):
#   $IS_MACOS, $IS_LINUX, $IS_WINDOWS  — 1 if true, 0 otherwise
#
# All helpers exit 0 with output on success; empty stdout on failure (no error
# spam, leaves error-handling decision to the caller).

# --- OS detection ---
IS_MACOS=0
IS_LINUX=0
IS_WINDOWS=0
case "$(uname -s)" in
  Darwin)               IS_MACOS=1 ;;
  Linux)                IS_LINUX=1 ;;
  MINGW*|MSYS*|CYGWIN*) IS_WINDOWS=1 ;;
esac
export IS_MACOS IS_LINUX IS_WINDOWS

# --- Date from epoch ---
# Usage: _date_from_epoch <epoch> <format>
# Prints formatted date string, or nothing if both forms fail.
_date_from_epoch() {
  local ts="$1" fmt="$2"
  date -d "@$ts" +"$fmt" 2>/dev/null || date -r "$ts" +"$fmt" 2>/dev/null
}

# --- File modification time (epoch seconds) ---
# Usage: _file_mtime <path>
# Prints epoch seconds, or empty if file missing / both forms fail.
_file_mtime() {
  stat -c %Y "$1" 2>/dev/null || stat -f %m "$1" 2>/dev/null
}

# --- Resolve absolute path (readlink -f equivalent) ---
# Usage: _realpath_f <path>
# Prints absolute resolved path, or empty if unresolvable.
_realpath_f() {
  if command -v realpath > /dev/null 2>&1; then
    realpath "$1" 2>/dev/null
  elif readlink -f "$1" > /dev/null 2>&1; then
    readlink -f "$1"
  else
    # POSIX fallback: cd + pwd. Doesn't fully resolve symlinks but gets the
    # absolute path. Sufficient for most hook use cases.
    ( cd "$(dirname "$1")" 2>/dev/null && printf '%s/%s\n' "$(pwd)" "$(basename "$1")" )
  fi
}

# --- Echo with escape interpretation (portable replacement for echo -e) ---
# Usage: _echo_e "<string with \n \t escapes>"
# Uses printf %b to interpret backslash escapes, BSD/GNU/POSIX compatible.
_echo_e() {
  printf '%b\n' "$1"
}

# --- sed in-place (handles BSD requiring -i '' suffix) ---
# Usage: _sed_inplace <sed-script> <file>
# Edits file in place. On BSD requires `-i ''`; on GNU plain `-i` works.
# This wrapper uses -i.bak then deletes the .bak file — works everywhere.
_sed_inplace() {
  local script="$1" file="$2"
  sed -i.bak -E "$script" "$file" && rm -f "$file.bak"
}
