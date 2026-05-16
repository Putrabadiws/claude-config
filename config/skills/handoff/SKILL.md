---
name: handoff
description: Create a session handoff document capturing what was done, decisions made, current state, and remaining work so the next session can resume seamlessly. Use for "handoff", "end session", "wrap up", "session summary", "pick up tomorrow", "save progress", "context dump".
disable-model-invocation: true
argument-hint: [optional topic/title]
---

# Session Handoff

Create a handoff document so the next session can resume without context loss.

## Process

1. Gather context
2. Analyze conversation
3. Write handoff document
4. Confirm

### Step 1: Gather Context

!`date +%Y-%m-%d`

Detect if in a git repo:
!`git rev-parse --is-inside-work-tree 2>/dev/null`

**If in a git repo**, also run:
!`git rev-parse --show-toplevel 2>/dev/null && echo "---" && git branch --show-current 2>/dev/null`
!`git log --oneline -15 2>/dev/null`
!`git status --short 2>/dev/null`
!`git diff --stat 2>/dev/null`
!`git stash list 2>/dev/null`

**If NOT in a git repo**, skip all git commands. Focus on files changed, commands run, and conversation content.

Also check for active tasks via TaskList.

### Step 2: Analyze Conversation

Extract from the full conversation:

1. **Objective** — What the user was trying to accomplish
2. **Work completed** — Concrete actions taken:
   - Files created/modified/deleted (with paths)
   - Git: commits (hashes + messages), MRs created (URLs), branches
   - Infra: deployments, config changes, k8s operations
   - Research: findings, conclusions, URLs visited
3. **Decisions** — Choices made and **why**, rejected alternatives
4. **Current state** — Where things stand:
   - Git: clean/dirty, pushed/unpushed, open MRs
   - Non-git: what's saved, what's in-flight, what's ephemeral
5. **Remaining work** — Prioritized:
   - `[NEXT]` — Immediate next step (actionable)
   - `[TODO]` — Required, any order
   - `[NICE]` — Optional, discussed but not committed to
   - `[BLOCKED]` — Needs external input/action
6. **Gotchas** — Fragile state, partial work, time-sensitive items
7. **References** — Links, issue numbers, commands that were useful

### Step 3: Write Handoff

Create `./docs/handoffs/<date>-<slug>.md`:
- `<date>`: today as `YYYY-MM-DD`
- `<slug>`: kebab-case from session objective or `$ARGUMENTS`
- If file exists, append `-2`, `-3`, etc.
- Create `./docs/handoffs/` if needed

Use this template — **skip empty sections entirely**:

```markdown
# Handoff: <Title>

**Date**: YYYY-MM-DD
**Project**: <repo or project name>
**Branch**: <branch> *(omit if not git)*
**Status**: Complete | In Progress | Blocked

## Objective

<What we set out to do and why>

## What Was Done

- <concrete action with file paths, commit hashes, URLs>
- <each item specific enough to verify>

## Decisions

- **<What>**: <Why, what was rejected>

## Current State

<Exact state — uncommitted changes, unpushed commits, running processes, open MRs, or "nothing in flight">

## Remaining Work

- `[NEXT]` <step with enough detail to act on immediately>
- `[TODO]` <required items>
- `[NICE]` <optional>
- `[BLOCKED]` <what + what's needed to unblock>

## Gotchas

<Warnings the next session must know — fragile state, deadlines, known issues>

## References

<URLs, issue numbers, doc pages, useful commands>

## Resume

<Exact steps to pick up: cd, checkout, install, run — or "start a new session in <dir>">
```

### Step 4: Confirm

1. Print the file path
2. Print 3-5 line summary of the handoff
3. Warn if uncommitted changes or unpushed commits exist (git repos only)

## Rules

- Be **specific**: `dns-resolver-core-golang/pkg/resolver/cache.go:145-180` not "the DNS resolver"
- Include **commit hashes** when applicable — they're the source of truth
- Skip sections with no content — no empty placeholders
- For exploratory/research sessions with no code changes, focus on findings and conclusions
- Write for a **fresh Claude session with zero prior context**
- If `$ARGUMENTS` is provided, use it as the handoff title/slug
