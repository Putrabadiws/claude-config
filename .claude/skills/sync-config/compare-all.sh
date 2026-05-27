#!/bin/bash
# compare-all.sh — Full audit of repo's config/ vs installed ~/.claude/.
#
# Walks every file under <repo>/config/ and the matching path under <local>/,
# plus orphans under <local>/{hooks,rules,skills,agents}/ that aren't in repo,
# and categorizes each pair as one of:
#
#   SAME           — byte-identical, or only differs by <workspace> placeholder
#                    substitution (forward direction: repo has `<workspace>`,
#                    local has substituted absolute path)
#   CHANGED        — real drift remains after filtering placeholder hunks
#   NEW IN REPO    — exists in repo but not local
#   NEW IN LOCAL   — exists in local (under one of the known mirror dirs) but
#                    not in repo (personal customization)
#
# Special-cased: `managed-settings.json` is compared against the OS install
# path (/Library/Application Support/ClaudeCode/... on macOS, etc.). If that
# path is unreadable, it's surfaced under ERRORS instead of NEW IN REPO.
#
# Usage:
#   compare-all.sh [<repo-config-dir>] [<local-dir>]
#
# Defaults:
#   repo-config-dir = $(cat ~/.claude/.config-repo-path)/config
#   local-dir       = ~/.claude

set -u

REPO_CONFIG=${1:-}
LOCAL_DIR=${2:-$HOME/.claude}

if [ -z "$REPO_CONFIG" ]; then
  base=$(cat ~/.claude/.config-repo-path 2>/dev/null)
  [ -n "$base" ] && REPO_CONFIG="$base/config"
fi

[ -d "$REPO_CONFIG" ] || { echo "ERROR: repo config dir not found: ${REPO_CONFIG:-<unset>}" >&2; exit 1; }
[ -d "$LOCAL_DIR" ]   || { echo "ERROR: local dir not found: $LOCAL_DIR" >&2; exit 1; }

# Derive repo root (parent of config/) — used to also walk mcp/ and integrations/.
REPO_ROOT=$(cd "$REPO_CONFIG/.." && pwd)

# OS-specific install path for managed-settings.json.
case "$(uname -s)" in
  Darwin)                MANAGED_LOCAL="/Library/Application Support/ClaudeCode/managed-settings.json" ;;
  Linux)                 MANAGED_LOCAL="/etc/claude-code/managed-settings.json" ;;
  MINGW*|MSYS*|CYGWIN*)  MANAGED_LOCAL="${PROGRAMDATA:-C:/ProgramData}/ClaudeCode/managed-settings.json" ;;
  *)                     MANAGED_LOCAL="" ;;
esac

# Install-time placeholder filter. Drops diff hunks that are pure placeholder
# substitution. Recognized placeholders:
#   <workspace>             — substituted with the user's workspace path
#   <bash for windows only> — substituted with "bash " (Windows) or "" (mac/Linux)
# See compare-all.test.sh for the rule semantics.
FILTER_AWK='
function is_hunk_header(line) {
  return line ~ /^[0-9]+(,[0-9]+)?[acd][0-9]+(,[0-9]+)?$/
}
function is_change_hunk(line) {
  return line ~ /^[0-9]+(,[0-9]+)?c[0-9]+(,[0-9]+)?$/
}
# Try to match `lt` against `gt` after splitting `gt` on a placeholder. Returns
# 1 if `lt` == `gt` with placeholder replaced by some value (possibly empty).
function pair_matches_placeholder(gt, lt, placeholder,    pos, prefix, suffix) {
  pos = index(gt, placeholder)
  if (pos == 0) return 0
  prefix = substr(gt, 1, pos - 1)
  suffix = substr(gt, pos + length(placeholder))
  if (substr(lt, 1, length(prefix)) != prefix) return 0
  if (length(lt) < length(prefix) + length(suffix)) return 0
  if (length(suffix) > 0 && substr(lt, length(lt) - length(suffix) + 1) != suffix) return 0
  return 1
}
function flush_hunk(    i, gt, lt, ok) {
  if (!filterable || n_lt == 0 || n_lt != n_gt) {
    printf "%s", hunk_buf
    in_hunk = 0; n_lt = 0; n_gt = 0; hunk_buf = ""; filterable = 0
    delete lt_lines; delete gt_lines
    return
  }
  ok = 1
  for (i = 1; i <= n_lt; i++) {
    gt = gt_lines[i]; lt = lt_lines[i]
    # Try each recognized placeholder. Pair passes if ANY placeholder matches.
    if (pair_matches_placeholder(gt, lt, "<workspace>")) continue
    if (pair_matches_placeholder(gt, lt, "<bash for windows only>")) continue
    ok = 0; break
  }
  if (!ok) printf "%s", hunk_buf
  in_hunk = 0; n_lt = 0; n_gt = 0; hunk_buf = ""; filterable = 0
  delete lt_lines; delete gt_lines
}
BEGIN { in_hunk = 0; n_lt = 0; n_gt = 0; hunk_buf = ""; filterable = 0 }
is_hunk_header($0) {
  if (in_hunk) flush_hunk()
  in_hunk = 1
  filterable = is_change_hunk($0)
  hunk_buf = $0 ORS
  next
}
in_hunk {
  hunk_buf = hunk_buf $0 ORS
  if (substr($0, 1, 2) == "< ") { n_lt++; lt_lines[n_lt] = substr($0, 3) }
  else if (substr($0, 1, 2) == "> ") { n_gt++; gt_lines[n_gt] = substr($0, 3) }
  next
}
{ print }
END { if (in_hunk) flush_hunk() }
'

# Result buffers — temp dir so we can hold per-file diff bodies separately.
TMPDIR_RUN=$(mktemp -d)
trap 'rm -rf "$TMPDIR_RUN"' EXIT

NEW_REPO_LIST="$TMPDIR_RUN/new_repo.txt"
NEW_LOCAL_LIST="$TMPDIR_RUN/new_local.txt"
CHANGED_LIST="$TMPDIR_RUN/changed.txt"
ERRORS_LIST="$TMPDIR_RUN/errors.txt"
DIFFS_DIR="$TMPDIR_RUN/diffs"
mkdir -p "$DIFFS_DIR"
: > "$NEW_REPO_LIST"; : > "$NEW_LOCAL_LIST"; : > "$CHANGED_LIST"; : > "$ERRORS_LIST"
SAME_COUNT=0

# Compare one (repo, local, relative-name) triple.
compare_pair() {
  repo_file=$1; local_file=$2; rel=$3
  if [ ! -e "$local_file" ]; then
    echo "$rel" >> "$NEW_REPO_LIST"
    return
  fi
  if [ ! -r "$local_file" ]; then
    echo "$rel: cannot read $local_file (permission denied?)" >> "$ERRORS_LIST"
    return
  fi
  raw=$(diff "$local_file" "$repo_file" 2>/dev/null)
  if [ -z "$raw" ]; then
    SAME_COUNT=$((SAME_COUNT + 1))
    return
  fi
  filtered=$(printf '%s\n' "$raw" | awk "$FILTER_AWK")
  if [ -z "$filtered" ]; then
    SAME_COUNT=$((SAME_COUNT + 1))
    return
  fi
  echo "$rel" >> "$CHANGED_LIST"
  # Path-safe filename for diff body.
  safe=$(printf '%s' "$rel" | tr '/' '__')
  printf '%s\n' "$filtered" > "$DIFFS_DIR/$safe"
}

# Path patterns that are filesystem cruft, not config — never compared. These
# are gitignored generated artifacts (pytest/python caches) or OS metadata.
# Not a general exclude list — strictly limited to NEVER-config patterns.
_is_cruft() {
  case "$1" in
    *.pytest_cache/*|.pytest_cache/*|*__pycache__/*|*/.DS_Store|.DS_Store) return 0 ;;
  esac
  return 1
}

# Walk repo config/ (flat install → ~/.claude/).
while IFS= read -r repo_file; do
  rel="${repo_file#"$REPO_CONFIG"/}"
  _is_cruft "$rel" && continue
  if [ "$rel" = "managed-settings.json" ]; then
    if [ -z "$MANAGED_LOCAL" ]; then
      echo "$rel: no managed-settings path for OS $(uname -s)" >> "$ERRORS_LIST"
      continue
    fi
    compare_pair "$repo_file" "$MANAGED_LOCAL" "$rel"
  else
    compare_pair "$repo_file" "$LOCAL_DIR/$rel" "$rel"
  fi
done < <(find "$REPO_CONFIG" -type f | sort)

# Walk repo mcp/ and integrations/ (mirrored install → ~/.claude/<top>/<rel>).
# `.env.sample` files are installation templates — skip them. The renamed
# local `.env` is filled in with real credentials, so diffing it against the
# placeholder template always shows divergence (noise, never actionable).
for top in mcp integrations; do
  [ -d "$REPO_ROOT/$top" ] || continue
  while IFS= read -r repo_file; do
    rel_in_top="${repo_file#"$REPO_ROOT"/$top/}"
    rel="$top/$rel_in_top"
    _is_cruft "$rel" && continue
    case "$rel" in
      */*.env.sample) continue ;;
      *) compare_pair "$repo_file" "$LOCAL_DIR/$rel" "$rel" ;;
    esac
  done < <(find "$REPO_ROOT/$top" -type f | sort)
done

# Walk local mirror dirs for orphans (files in local but not in repo).
for sub in hooks rules skills agents mcp integrations; do
  [ -d "$LOCAL_DIR/$sub" ] || continue
  while IFS= read -r local_file; do
    rel="${local_file#"$LOCAL_DIR"/}"
    _is_cruft "$rel" && continue
    # For mcp/ + integrations/: the repo-side may carry `.sample` while local
    # has the renamed `.env` — treat the `.env` as in-repo if its `.sample` exists.
    repo_candidate="$REPO_CONFIG/$rel"
    if [ ! -e "$repo_candidate" ]; then
      case "$rel" in
        mcp/*|integrations/*)
          repo_alt="$REPO_ROOT/$rel"
          repo_alt_sample="$REPO_ROOT/$rel.sample"
          if [ ! -e "$repo_alt" ] && [ ! -e "$repo_alt_sample" ]; then
            echo "$rel" >> "$NEW_LOCAL_LIST"
          fi
          ;;
        *)
          echo "$rel" >> "$NEW_LOCAL_LIST"
          ;;
      esac
    fi
  done < <(find "$LOCAL_DIR/$sub" -type f | sort)
done

# Emit grouped output.
emit_section() {
  header=$1; file=$2
  [ -s "$file" ] || return
  echo "=== $header ==="
  sort -u "$file"
  echo
}

emit_section "NEW IN REPO (apply to local)" "$NEW_REPO_LIST"
if [ -s "$NEW_LOCAL_LIST" ]; then
  echo "=== NEW IN LOCAL ==="
  echo "Files present locally but not in the team repo. Investigate each one:"
  echo "if the change is worth sharing, sync it back to the team repo and open an MR/PR."
  echo "Otherwise leave it as a personal customization."
  echo
  sort -u "$NEW_LOCAL_LIST"
  echo
fi

if [ -s "$CHANGED_LIST" ]; then
  echo "=== CHANGED ==="
  while IFS= read -r rel; do
    safe=$(printf '%s' "$rel" | tr '/' '__')
    echo
    echo "--- $rel ---"
    cat "$DIFFS_DIR/$safe"
  done < <(sort -u "$CHANGED_LIST")
  echo
fi

emit_section "ERRORS" "$ERRORS_LIST"

# Summary line.
n_new_repo=$(wc -l < "$NEW_REPO_LIST" | tr -d ' ')
n_new_local=$(wc -l < "$NEW_LOCAL_LIST" | tr -d ' ')
n_changed=$(wc -l < "$CHANGED_LIST" | tr -d ' ')
n_errors=$(wc -l < "$ERRORS_LIST" | tr -d ' ')
echo "=== SUMMARY ==="
printf 'NEW IN REPO: %s   NEW IN LOCAL: %s   CHANGED: %s   SAME: %s   ERRORS: %s\n' \
  "$n_new_repo" "$n_new_local" "$n_changed" "$SAME_COUNT" "$n_errors"
