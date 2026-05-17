#!/bin/bash
# Tests for block-bulk-config-copy.sh (marker-based version).
# Run: bash ~/.claude/hooks/block-bulk-config-copy.test.sh

source "$HOME/.claude/_lib/test-helpers.sh"
HOOK="$(_test_script_dir "$0")/block-bulk-config-copy.sh"
_require_executable "$HOOK"

# Set up temp source/dest files we can read in tests.
TMP=$(mktemp -d)
PLAIN_SRC="$TMP/plain.md"
MARKED_SRC="$TMP/marked.md"
PLAIN_DEST="$TMP/itsec-claude-config/plain.md"
MARKED_DEST="$TMP/itsec-claude-config/marked.md"
JSON_DEST="$TMP/itsec-claude-config/settings.json"
mkdir -p "$TMP/itsec-claude-config"
echo "no marker here" > "$PLAIN_SRC"
echo "no marker here" > "$PLAIN_DEST"
echo "header" > "$MARKED_SRC"
echo "<!--""SYNC"":""LOCAL-ONLY""-->" >> "$MARKED_SRC"
echo "body" >> "$MARKED_SRC"
echo "header" > "$MARKED_DEST"
echo "<!--""SYNC"":""LOCAL-ONLY""-->" >> "$MARKED_DEST"
echo '{}' > "$JSON_DEST"

# Shell-marker source file (uses # comment marker, not HTML comment).
# Marker keyword written via adjacent-string-concat to avoid self-flagging
# this test file when synced across repos.
SHELL_MARKED_SRC="$TMP/script.sh"
printf '#!/bin/bash\n# ''SYNC'':''LOCAL-ONLY''\necho x\n' > "$SHELL_MARKED_SRC"
PLAIN_DEST_SH="$TMP/itsec-claude-config/dest.sh"
echo "x" > "$PLAIN_DEST_SH"

# .json file OUTSIDE any claude-config repo (target plain /tmp).
PLAIN_JSON_SRC="$TMP/plain.json"
PLAIN_JSON_DEST="$TMP/plain-dest.json"
echo '{}' > "$PLAIN_JSON_SRC"

# --- Out of scope: cp not targeting *-claude-config ---
run_test "allow cp into /tmp (not config)"                  "cp $PLAIN_SRC /tmp/foo.md" 0
run_test "allow cp of two non-config files"                 "cp /tmp/a /tmp/b" 0
# Mutation-driven: proves the location gate (*-claude-config*|*/.claude/*) is
# needed — without it, ANY .json cp would block, even outside claude-config.
run_test "allow cp .json outside claude-config"             "cp $PLAIN_JSON_SRC $PLAIN_JSON_DEST" 0

# --- Verb not at sub-command start (cp mentioned as text) ---
run_test "allow glab mr w/ cp in description"               'glab mr create --description "use cp to sync -claude-config files"' 0
run_test "allow echo with cp text"                          'echo "cp /a /b ... -claude-config"' 0

# --- Allow cp when neither side has marker, and not JSON ---
run_test "allow cp plain → plain in claude-config"          "cp $PLAIN_SRC $PLAIN_DEST" 0

# --- Block when source has marker ---
run_test "block cp when source has marker"                  "cp $MARKED_SRC $PLAIN_DEST" 2
# Mutation-driven: shell # marker form must also be detected, not just the
# HTML comment form. Without both branches in MARKER_REGEX, .sh files with
# the marker comment would slip through unnoticed.
run_test "block cp when shell source has # marker"          "cp $SHELL_MARKED_SRC $PLAIN_DEST_SH" 2

# --- Block when destination has marker ---
run_test "block cp when destination has marker"             "cp $PLAIN_SRC $MARKED_DEST" 2

# --- Block when destination is .json under claude-config ---
run_test "block cp to .json in claude-config"               "cp /tmp/x.json $JSON_DEST" 2
run_test "block cp source-and-target both .json claude-config"  "cp $PLAIN_SRC $JSON_DEST" 2

# --- Edge: cp via tee/mv/rsync still subject to checks ---
run_test "block tee to .json in claude-config"              "echo x | tee $JSON_DEST" 2
run_test "block mv plain to marked"                         "mv $PLAIN_SRC $MARKED_DEST" 2

# --- Edge: redirect targeting claude-config json ---
# Note: this is a > redirect, not cp/rsync/tee/mv. Current hook gates on those verbs;
# > redirect alone isn't caught here (caught by validate-destructive for /dev/sd*).
# Documenting current behavior:
run_test "allow plain redirect to claude-config json (out of scope here)"  "echo x > $JSON_DEST" 0

# --- Regression: cp in one sub-cmd + .json reference in another sub-cmd should NOT false-positive ---
# Previously the hook scanned ALL path tokens in the entire command, so a script
# like "cp foo.sh bar.sh && grep pattern settings.json" would block on the .json.
# Fix: per-sub-command scanning means .json in non-cp segments is ignored.
run_test "allow cp + sibling grep over .json"               "cp $PLAIN_SRC $PLAIN_DEST && grep foo $JSON_DEST" 0
run_test "allow cp + sibling echo with .json text"          "cp $PLAIN_SRC $PLAIN_DEST ; echo 'see $JSON_DEST for details'" 0
run_test "allow multi-line cp + diff with .json"            "$(printf 'cp %s %s\ndiff %s %s' "$PLAIN_SRC" "$PLAIN_DEST" "$PLAIN_DEST" "$JSON_DEST")" 0

# --- Cleanup ---
rm -rf "$TMP"

summary
