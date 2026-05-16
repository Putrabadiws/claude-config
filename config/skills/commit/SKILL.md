---
name: commit
description: Git commit, push, and create MR/PR. Use for "commit", "push and mr", "commit and push", "create merge request", "submit changes". Do NOT use for creating branches, reviewing code, or resolving merge conflicts.
disable-model-invocation: true
argument-hint: [message (optional)]
allowed-tools: Bash(git status *), Bash(git log *), Bash(git diff *), Bash(git show *), Bash(git branch *), Bash(git rev-parse *), Bash(git ls-files *), Bash(git fetch *), Bash(git merge-base *), Bash(git rev-list *), Bash(./mvnw *), Bash(npm test *), Bash(go test *), Bash(pytest *), Bash(cat *)
---

# Git Commit

## Pre-flight Checks
!`git branch --show-current`
!`git status --short`

## Commit Convention

```
<type>(<scope>): <description>

Types: feat, fix, docs, style, refactor, test, chore
Scope: service name or component
```

### Examples
```
feat(mdr): add alert bulk update endpoint
fix(dns-resolver): handle nil pointer in cache lookup
docs(corvus): update API documentation
refactor(aegis): extract embedding logic to service
test(fates): add unit tests for document processor
chore(deps): upgrade spring boot to 3.3.1
```

## Attribution

Always append `✨ Generated with [Claude Code](https://claude.ai/claude-code) {{claude-code-version}} ({{claude-model}})` as a separate line in the commit body and MR description body.

```
feat(mdr): add alert bulk update endpoint

✨ Generated with [Claude Code](https://claude.ai/claude-code) {{claude-code-version}} ({{claude-model}})
```

## Process

1. **Check branch** - If on main/master/develop/release, create a new branch first
2. **Review staged** - `git diff --cached`
3. **Review unstaged** - `git status` for untracked files
4. **Create commit** - Use conventional format with attribution
5. **Pipeline pre-check** - Run pre-push checks (see below)
6. **Push** - `git push -u origin $(git branch --show-current)`
7. **Create MR** - `glab mr create` targeting `develop` (unless stated otherwise)
8. **Verify** - Return the MR URL

## Pipeline Pre-check (before push)

Run these checks AFTER committing but BEFORE pushing. Stop and warn if any check fails.

### 1. Branch Freshness (always)

```bash
git fetch origin develop
BEHIND=$(git rev-list --count HEAD..origin/develop)
```

| Behind | Action |
|--------|--------|
| 0 | OK, proceed |
| 1-10 | Warn: "Branch is $BEHIND commits behind develop. Rebase recommended to avoid CI failure." Ask user to rebase or proceed anyway. |
| 10+ | Strong warning: "Branch is $BEHIND commits behind develop. Rebase strongly recommended." |

### 2. Local Test Run (if `.gitlab-ci.yml` has `compare_coverage` or similar stage)

Detect project type and run tests:

| File | Command |
|------|---------|
| `pom.xml` / `mvnw` | `./mvnw test -q` |
| `package.json` | `npm test` |
| `go.mod` | `go test ./...` |
| `pytest.ini` / `pyproject.toml` | `pytest` |

If tests fail, stop and warn. Do NOT push with failing tests.

### 3. Coverage Comparison (Java projects with JaCoCo, optional)

Only when `.gitlab-ci.yml` contains coverage comparison AND branch is fresh (already rebased):

```bash
# Get current branch test count
./mvnw test jacoco:report -q
CURRENT_TESTS=$(find target/surefire-reports -name "TEST-*.xml" | xargs grep -h 'testsuite' | sed 's/.*tests="\([0-9]*\)".*/\1/' | awk '{sum+=$1} END {print sum+0}')
if [ -f target/site/jacoco/jacoco.csv ]; then
  CURRENT_COV=$(awk -F"," 'NR>1 { i+=$4+$5; c+=$5 } END { printf "%.2f", 100*c/i }' target/site/jacoco/jacoco.csv)
else
  CURRENT_COV="N/A"
fi

# Report to user
echo "Tests: $CURRENT_TESTS | Coverage: $CURRENT_COV%"
```

Skip the full baseline comparison locally (too slow — CI handles it). Just ensure tests pass and report the numbers so user has visibility.

### Pre-check Summary

Print a summary before pushing:

```
Pipeline Pre-check:
  Branch freshness: ✓ up to date (or ✗ X commits behind)
  Tests: ✓ passed (N tests) (or ✗ failed)
  Coverage: XX.XX%
```

If any ✗, ask user whether to proceed or fix first.

## Branch Rules

| Branch | Can Commit? | Action |
|--------|-------------|--------|
| `main`, `master` | NO | Create new branch first |
| `develop` | NO (except pipeline repos) | Create new branch first |
| `release` | NO | Create new branch first |
| `feature/*`, `fix/*`, `perf/*`, etc. | YES | Commit directly |

When creating a new branch, use the convention: `<type>/<short-description>` (e.g., `feat/add-auth`, `fix/null-pointer`, `perf/optimize-query`).

## MR Description Format

```
glab mr create --title "<same as commit subject>" --description "$(cat <<'EOF'
## Summary
<bullet points of what changed and why>

## Test plan
<checklist of testing steps>

✨ Generated with [Claude Code](https://claude.ai/claude-code) {{claude-code-version}} ({{claude-model}})
EOF
)" --target-branch develop
```
