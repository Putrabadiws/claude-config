#!/bin/bash
# Tests for validate-destructive.sh
# Run: bash ~/.claude/hooks/validate-destructive.test.sh

source "$HOME/.claude/_lib/test-helpers.sh"
HOOK="$(_test_script_dir "$0")/validate-destructive.sh"
_require_executable "$HOOK"

# Allow-cases (must NOT block)
run_test "allow normal git status"                'git status' 0
run_test "allow git push (without force)"         'git push origin main' 0
run_test "allow git push --force-with-lease"      'git push --force-with-lease origin main' 0
# Mutation-driven: exercises the lease-exclusion path. Without `-f` AND
# `--force-with-lease` together, the exclusion clause is dead code (since
# `--force-with-lease` doesn't match `(-f|--force)(\s|$)` on its own).
run_test "allow git push -f --force-with-lease"   'git push -f --force-with-lease origin main' 0
run_test "allow rm in user dir"                   'rm -rf /tmp/foo' 0
run_test "allow git reset --soft"                 'git reset --soft HEAD~1' 0
run_test "allow SELECT query"                     'psql -c "SELECT * FROM users"' 0
# Adversarial: SQL keywords mentioned as TEXT (not invoked through DB tool)
run_test "allow echo containing DROP TABLE"        'echo "do not DROP TABLE"' 0
run_test "allow grep over schema file"             'grep "DROP TABLE" schema.sql' 0
run_test "allow commit message mentioning drop"    'git commit -m "drop tables before refactor"' 0
run_test "allow awk script with DROP literal"      'awk "/DROP TABLE/{print}" schema.sql' 0

# DDL via real DB tools (must block, rc=1)
run_test "block psql DROP TABLE"                   'psql -c "DROP TABLE users"' 1
run_test "block mysql DROP DATABASE"               'mysql -e "DROP DATABASE production"' 1
run_test "block sqlite3 DROP SCHEMA"               'sqlite3 db.sqlite "DROP TABLE foo"' 1
run_test "block chained psql DROP after cd"        'cd /tmp && psql -c "DROP TABLE x"' 1

# Block-cases (must block, rc=1)
run_test "block git reset --hard"                 'git reset --hard origin/main' 1
run_test "block git clean -fd"                    'git clean -fd' 1
run_test "block git branch -D"                    'git branch -D feature/x' 1
run_test "block git push --force"                 'git push --force origin main' 1
run_test "block rm -rf /"                         'rm -rf /' 1
run_test "block rm -rf /etc"                      'rm -rf /etc' 1
run_test "block rm -rf /etc after &&"             'cd /tmp && rm -rf /etc' 1

# Adversarial: destructive verbs mentioned in text (echo / commit msg / MR description)
run_test "allow echo containing git reset --hard"      'echo "do not git reset --hard"' 0
run_test "allow MR description with git push --force"  'glab mr create --description "we used git push --force in legacy"' 0
run_test "allow echo containing rm -rf /etc"           'echo "rm -rf /etc is bad"' 0
run_test "allow commit mentioning chmod -R 777"        'git commit -m "removed chmod -R 777 hack"' 0
run_test "allow commit mentioning mkfs"                'git commit -m "fix mkfs.ext4 path detection"' 0
run_test "allow grep for diskpart in logs"             'grep diskpart /var/log/messages' 0
run_test "allow echo mentioning /dev/sda"              'echo "do not write to /dev/sda"' 0
run_test "allow PR body referencing dd if=/dev"        'gh pr create --body "we deprecated dd if=/dev/zero"' 0

# Adversarial: variable assignments mentioning destructive commands
run_test "allow variable assigning rm string"          'BAD_CMD="rm -rf /etc"' 0

# Adversarial: rm of custom user paths starting with system-prefix
run_test "allow rm /etc-bak (custom user path)"        'rm -rf /etc-bak' 0
run_test "allow rm /var-archive"                        'rm -rf /var-archive' 0
run_test "allow rm /usr-local-backup"                   'rm -rf /usr-local-backup' 0

# But /etc/subdir IS still caught
run_test "block rm /etc/myapp (real subpath)"          'rm -rf /etc/myapp' 1

# Wrapper prefixes (sudo / time / nohup / nice / env) — must still BLOCK
run_test "block sudo rm -rf /etc"                       'sudo rm -rf /etc' 1
run_test "block time rm -rf /etc"                       'time rm -rf /etc' 1
run_test "block nohup rm -rf /etc"                      'nohup rm -rf /etc' 1
run_test "block nice rm -rf /etc"                       'nice rm -rf /etc' 1
run_test "block nice -n 10 rm -rf /etc"                 'nice -n 10 rm -rf /etc' 1
run_test "block env VAR=x rm -rf /etc"                  'env FOO=bar rm -rf /etc' 1
run_test "block sudo psql DROP TABLE"                   'sudo psql -c "DROP TABLE x"' 1

# Command substitution and subshells — must BLOCK
run_test "block \$(rm -rf /etc) inside command"        'echo $(rm -rf /etc)' 1
run_test "block backtick rm inside command"             'echo `rm -rf /etc`' 1
run_test "block (rm -rf /etc) subshell"                 '(rm -rf /etc)' 1
run_test "block nested \$()"                           'echo result: $(cd /tmp && rm -rf /etc)' 1

# String-arg execution wrappers — must BLOCK (Check 6, uses ORIGINAL command)
run_test "block bash -c rm -rf /etc"                    'bash -c "rm -rf /etc"' 1
run_test "block sh -c rm -rf /var"                      'sh -c "rm -rf /var"' 1
run_test "block zsh -c destructive"                     'zsh -c "rm -rf /etc"' 1
run_test "block eval destructive string"                'eval "rm -rf /etc"' 1
run_test "block bash -c git reset --hard"               'bash -c "git reset --hard origin/main"' 1
run_test "block bash -c chmod -R 777"                   'bash -c "chmod -R 777 /var/log"' 1
run_test "block bash -c dd if=/dev/zero"                'bash -c "dd if=/dev/zero of=/dev/sda"' 1

# Pipe-to-destructive (xargs) — must BLOCK
run_test "block find | xargs rm"                        'find . -name "*.bak" | xargs rm -rf /etc/foo' 1
run_test "block xargs -n1 rm"                           'find . | xargs -n1 rm -rf /etc/x' 1
# Mutation-driven: `xargs -I {} rm ...` has a non-flag token (`{}`) between
# `-I` and `rm` that PREFIXES `(\s+-\S+)*` cannot consume. Check 3 misses;
# only Check 3b's per-sub-command xargs+rm/sys scan catches it. Removing
# Check 3b would let this slip through.
run_test "block xargs -I {} rm"                         'find . | xargs -I {} rm -rf /etc/x' 1

# Cross-sub-cmd contamination — should be FIXED by quote-stripping
run_test "allow commit msg w/ --force then push"       'git commit -m "fix --force-with-lease usage" && git push origin main' 0
run_test "allow echo --force then push"                 'echo "the --force flag is dangerous" && git push origin main' 0

# Edge: redirect to /dev/sd in echo text (should allow)
run_test "allow echo containing > /dev/sda"            'echo "do not redirect to /dev/sda please"' 0

# Edge: legitimate cat with /dev/sd reference (no >)
run_test "allow cat of file mentioning /dev/sda"       'cat notes.md' 0
# Mutation-driven: unquoted `/dev/sda` reference without `>` must NOT block.
# All other "allow /dev/sd" cases bury the path inside quoted strings that
# strip_quoted removes — so dropping the `>` requirement would still pass
# those tests. This one keeps the path visible to the regex.
run_test "allow ls /dev/sda (read, no redirect)"       'ls /dev/sda' 0

# Edge: real /dev/sda redirect — must BLOCK
run_test "block cat zeros > /dev/sda"                  'cat /dev/zero > /dev/sda' 1
run_test "block DROP TABLE"                       'psql -c "DROP TABLE users"' 1
run_test "block TRUNCATE TABLE"                   'psql -c "TRUNCATE TABLE logs"' 1
run_test "block mkfs"                             'mkfs.ext4 /dev/sda1' 1
run_test "block dd if=/dev"                       'dd if=/dev/zero of=/tmp/foo' 1
run_test "block chmod -R 777"                     'chmod -R 777 /var/log' 1

# Edge cases
run_test "empty command"                          '' 0
run_test "git push -f as flag in branch name"     'git push origin -fancy-branch' 0

summary
