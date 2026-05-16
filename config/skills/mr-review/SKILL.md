---
name: mr-review
description: Review merge request, MR, PR, pull request, code review, check MR, recheck MR, merge MR. Thorough analysis of changes with optional merge.
argument-hint: [mr-number or branch-name]
allowed-tools: Read, Grep, Glob, Bash(git *), Bash(glab *), Bash(./mvnw *), Bash(go test *), Bash(npm test *), Bash(pytest *)
---

# Merge Request Review

## Current Context
!`git branch --show-current 2>/dev/null || echo "not in git repo"`

## Review Process

0. **Protect local state** - Before any git operations, check for uncommitted changes and stash if needed:
   ```bash
   git stash --include-untracked -m "mr-review: stash before reviewing MR $ARGUMENTS"
   ```
   After review is complete, restore with `git stash pop`. **Never use `git checkout` or `git switch` during review** — only use read-only commands (`fetch`, `show`, `log`, `diff`, `merge-base`).
1. **Fetch MR context** - title, description, linked issues, **source and target branches**
2. **Establish branch context** - CRITICAL: before reviewing code, understand the branch topology.
   ```bash
   # Get source/target branches
   glab api projects/:fullpath/merge_requests/$ARGUMENTS | python3 -c "import sys,json; d=json.load(sys.stdin); print(f'source: {d[\"source_branch\"]}\ntarget: {d[\"target_branch\"]}')"
   # Fetch both branches
   git fetch origin <target-branch> <source-branch>
   # Inspect file state on target branch, NOT your working directory
   git show origin/<target-branch>:<file-path>
   ```

   **Diffing rules — use THREE-dot diff, never two-dot:**
   ```bash
   # CORRECT: three-dot diff shows only the MR's changes (since merge-base)
   git diff origin/<target-branch>...origin/<source-branch>
   git diff origin/<target-branch>...origin/<source-branch> --stat

   # WRONG: two-dot diff includes unrelated changes from the target branch
   # git diff origin/<target-branch>..origin/<source-branch>  ← NEVER USE THIS
   ```
   Two-dot (`..`) shows symmetric differences between branches — if the target has moved forward with other commits, those appear as reversed diffs, making it look like the MR is deleting code it never touched. Three-dot (`...`) shows only changes since the fork point, which is what an MR actually represents.

   **Trust hierarchy for what the MR changes:**
   1. `glab mr diff $ARGUMENTS` — canonical source (matches GitLab UI), use this first
   2. `git diff origin/<target>...origin/<source>` — for additional context, file-level exploration
   3. Never trust two-dot diff or your local working directory for MR scope

   **Why branch context matters:**
   - The source branch may have forked from `release`, `develop`, or another branch — this determines what code already exists as the baseline
   - Your local working directory may be on a completely different branch with features not yet in the target
   - The diff only makes sense relative to the target branch state
   - Do NOT flag "conflicts" with code that only exists on other branches (e.g., don't flag missing flavor support if flavors only exist on `develop` but MR targets `release`)
3. **Read project conventions** - Read `CLAUDE.md` and any convention docs in `docs/` relevant to the layers touched by the MR. Do this before reviewing code so findings are informed by project standards.
4. **Cross-reference docs** - if architectural or API changes, check `docs/`
5. **Review all commits** - check each commit message and its changes
6. **Review every changed file** - check the diff thoroughly, using target branch as context. Flag convention violations using the severity defined in each doc.
7. **Read existing comments/notes** - check for prior feedback and discussions
8. **Use the review template** - see [templates/review-comment.md](templates/review-comment.md)
9. **Post comment** - ALWAYS run `glab mr note` to post a single comprehensive comment. Do not just print it.
   - Pass the review inline via heredoc: `glab mr note $ARGUMENTS -m "$(cat <<'REVIEW' ... REVIEW)"`
   - **DO NOT** use `-F` or `--file` flags — `glab mr note` does not support them
   - Use single-quoted heredoc delimiter (`<<'REVIEW'`) to prevent shell expansion of `$`, backticks, etc.
   - If the comment is too large, split into smaller comments
10. **Run tests (optional)** - if the MR has source code changes, see [Post-Review: Run Tests](#post-review-run-tests)

## Commands

```bash
# View MR details
glab mr view $ARGUMENTS

# View MR diff
glab mr diff $ARGUMENTS

# List MR comments/notes (use glab API, NOT glab mr note list)
glab api projects/:fullpath/merge_requests/$ARGUMENTS/notes

# Post review comment (use single-quoted heredoc to avoid shell escaping)
glab mr note $ARGUMENTS -m "$(cat <<'REVIEW'
Your review content here with **markdown**, `backticks`, $variables safe
REVIEW
)"

# Post review comment + request changes
glab mr note $ARGUMENTS -m "$(cat <<'REVIEW'
...review...
REVIEW
)" && glab mr note $ARGUMENTS -m "/submit_review requested_changes"

# Post review comment + approve
glab mr note $ARGUMENTS -m "$(cat <<'REVIEW'
...review...
REVIEW
)" && glab mr note $ARGUMENTS -m "/submit_review approve"

# Just approve
glab mr approve $ARGUMENTS
```

## Post-Review: Run Tests

After posting the review comment, **ask the user** if they want to run the test suite against the MR branch. Skip this entirely if:
- The MR has no source code changes (docs-only, config-only, CI-only)
- No test runner is detected in the project

**Flow:**
1. Ask: "Do you want me to run the test suite for this MR?"
2. If user declines → proceed to merge section
3. If user accepts → detect project type and run tests:

| Indicator | Project Type | Test Command |
|-----------|-------------|--------------|
| `pom.xml` / `mvnw` | Java/Spring | `./mvnw test` |
| `go.mod` | Go | `go test ./...` |
| `package.json` with test script | Node/TS | `npm test` |
| `pytest.ini` / `pyproject.toml` / `setup.cfg` | Python | `pytest` |

4. Report results clearly: pass count, fail count, errors
5. If tests pass → update the review comment's Testing Checklist by posting a follow-up note:
   ```bash
   glab mr note $ARGUMENTS -m "$(cat <<'NOTE'
   **Test run results:** ✅ All tests passed

   Updated Testing Checklist:
   - [x] Tests pass locally
   NOTE
   )"
   ```
6. If tests fail → post failures as a follow-up note and reconsider the verdict:
   ```bash
   glab mr note $ARGUMENTS -m "$(cat <<'NOTE'
   **Test run results:** ❌ Tests failed

   <details>
   <summary>Failure details</summary>

   ```
   [insert relevant failure output here]
   ```

   </details>
   NOTE
   )"
   ```

**Important:** Every Bash command in this step requires user approval. Do NOT auto-run anything.

## Post-Review: Merge

After posting the review, **only if the verdict is ✅ Approve or ⚠️ Approve with comments**, ask the user if they want to merge the MR.

If the verdict is 🔄 Request changes or ❌ Reject, do NOT offer to merge.

Options to present:
- **Merge** — `glab mr merge $ARGUMENTS`
- **Squash and merge** — `glab mr merge $ARGUMENTS --squash`
- **Squash, merge, and delete source branch** — `glab mr merge $ARGUMENTS --squash --remove-source-branch`
- **Don't merge** — skip

If user chooses to merge and the review had minor issues (⚠️ Approve with comments), post a follow-up comment tagging the MR author to address the issues in a future MR:
```
glab mr note $ARGUMENTS -m "✅ Approved and merged.\n\n@author Please address these in the next MR:\n1. issue 1\n2. issue 2"
```

After merge, run `git pull origin <target-branch>` to sync local.

## What to Check

| Category | Check For |
|----------|-----------|
| **Functionality** | Does it do what it claims? Read the code for intent first — understand *what* the code is trying to achieve, then check if the *right mechanism* is used. |
| **Code Quality** | Readability, maintainability, patterns. Check against project conventions in `CLAUDE.md` and `docs/` |
| **Security** | Auth, input validation, secrets exposure |
| **Performance** | N+1 queries, unnecessary loops, memory leaks |
| **Tests** | New code tested? Edge cases covered? If suggesting test code examples, check `docs/` and `CLAUDE.md` for project-specific test conventions first — naming, structure, assertions, and framework patterns must match. |
| **Breaking Changes** | API contracts, schema migrations |
| **Rewrites** | See [Rewrite Verification](#rewrite-verification) below |
| **Documentation** | Updated if needed? |

## Comment Style

- **Be specific**: line number + what's wrong + suggestion
- **Severity levels**:
  - 🔴 `[BLOCKER]` - must fix before merge
  - 🟡 `[SHOULD FIX]` - important but not blocking
  - 🟢 `[NITPICK]` - style/preference, optional
- Don't nitpick style if it matches existing codebase
- **Code examples in suggestions must follow project conventions** — if you suggest a fix or test, it must match the project's patterns from `CLAUDE.md` and `docs/`

## Verdict Options

| Verdict | When to Use | Command |
|---------|-------------|---------|
| ✅ **Approve** | Good to merge | `glab mr approve` or `/submit_review approve` |
| ⚠️ **Approve with comments** | Minor issues, can merge | Comment + `/submit_review approve` |
| 🔄 **Request changes** | Must fix before merge | Comment + `/submit_review requested_changes` |
| ❌ **Reject** | Fundamental issues | Comment + close MR |

## Template

Use the template at [templates/review-comment.md](templates/review-comment.md) for consistent review format.

**Required elements:**
- Banner: `> 🤖 **Review by [Claude Code](https://claude.ai/claude-code)** (via @username)`
- Attribution footer: `✨ Generated with Claude Code (claude.ai/claude-code) {version} ({model})` — resolve version via: !`claude --version 2>/dev/null | head -1`

## Rewrite Verification

When a file is **rewritten** (not just modified — the diff shows most of the file replaced), apply extra scrutiny. Rewrites silently drop edge-case behavior that the original code handled.

**How to detect**: `--stat` shows high churn on a single file (e.g., `+120 -150`), or the diff replaces the core logic structure rather than patching individual lines.

**What to do**:

1. **Read the old file in full** (`git show origin/<target>:<path>`) — understand every behavioral contract: error handling, edge cases, fallback paths, API contracts with callers.
2. **Read the new file in full** — don't rely on the diff alone. Diffs obscure structural changes.
3. **Trace each old behavior through the new code**:
   - List the edge cases the old code handled (error recovery, input boundary conditions, fallbacks, ordering guarantees, etc.)
   - For each one, find the corresponding logic in the new code
   - If missing or changed, flag it — even if the new approach is "simpler"
4. **Check API surface**: does the function/class/component still honor all its parameters and return contracts? Parameters that exist but no longer work correctly are silent regressions.
5. **Check framework contracts**: if the old code fulfilled a required contract (interface methods, lifecycle callbacks, protocol hooks), verify the new code still does.

Behavioral regressions in rewrites are a **blocker**.

## Submodule MR Context

When reviewing MR in a submodule:

1. MR is on submodule, but impact may be platform-wide
2. Check `../docs/` for platform context:
   - `ARCHITECTURE.md` - system design
   - `DATA-FLOWS.md` - data flow between services
   - `API.md` - API contracts
   - `DEPLOYMENT.md` - K8s deployment mapping
3. Consider: does this change affect other submodules?
4. If API/contract changes: flag for cross-team awareness
5. If schema changes: check if other services depend on it
