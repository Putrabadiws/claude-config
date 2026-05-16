---
name: pickup
description: Resume work from a handoff document. Reads the most recent (or specified) handoff, verifies current state matches expectations, and presents context so the session can continue seamlessly. Use for "pickup", "resume", "continue", "pick up where we left off", "what was I doing", "load handoff".
argument-hint: [optional handoff filename or search term]
---

# Session Pickup

Resume from a handoff document created by the `/handoff` skill.

## Process

1. Find handoff document
2. Read and parse it
3. Verify current state
4. Present context and next steps

### Step 1: Find Handoff Document

Use the Glob tool to search for handoff documents. Do NOT use shell commands with loops or pipes.

**Search order:**

1. Current directory first:
   - Glob: `docs/handoffs/*.md` in `./`

2. If nothing found, search workspace-wide:
   - Glob: `**/docs/handoffs/*.md` in `<workspace>/` (the user's workspace root)

**If `$ARGUMENTS` is provided**:
- If it's a file path, use Read to open it directly
- If it's a search term, Glob for `**/docs/handoffs/*<term>*.md`
- If it's a date (YYYY-MM-DD), Glob for `**/docs/handoffs/<date>-*.md`

**If multiple handoffs exist and no argument given**, read the first line of each (up to 5 most recent by filename sort) to get titles, then ask which one to load. If only one exists, load it automatically.

### Step 2: Read and Parse

Read the selected handoff file completely.

Extract these key fields:
- **Project** and **Branch**
- **Status** (Complete / In Progress / Blocked)
- **Remaining Work** (especially `[NEXT]` items)
- **Gotchas**
- **Resume** section (exact steps)

### Step 3: Verify Current State

Compare the handoff's expectations against reality:

**If the handoff references a git repo**, run these individually (not piped):

!`git rev-parse --is-inside-work-tree 2>/dev/null`
!`git branch --show-current 2>/dev/null`
!`git log --oneline -5 2>/dev/null`
!`git status --short 2>/dev/null`

Check for:
- **Branch mismatch**: Are we on the branch the handoff expects? If not, warn.
- **New commits**: Any commits since the handoff was written? Show them.
- **Dirty state**: Uncommitted changes that weren't in the handoff? Warn.
- **PR status**: If handoff mentions open PRs, check their current state via `gh`.

**If not a git repo**, verify the working directory and key files still exist.

### Step 4: Present Context

Output a structured summary:

```
## Resuming: <Title>

**Handoff from**: <date>
**Project**: <project>
**Branch**: <branch> (verified: <current branch>)
**Status**: <status>

### State Check
- <each verification result — matches/mismatches/warnings>

### What Was Done (recap)
<bullet summary from handoff — keep brief, 3-5 lines max>

### Next Steps
<remaining work items from handoff, [NEXT] first>

### Gotchas
<warnings from handoff + any new issues found during verification>
```

After presenting, ask:

> Ready to continue with `[NEXT]`: <next step description>?

If the handoff status was **Complete**, say so and ask what the user wants to work on next.

If status was **Blocked**, highlight what's needed to unblock and ask if the blocker is resolved.

## Rules

- **Don't assume** — verify. The handoff may be hours or days old.
- If a referenced branch was deleted or PR was merged, report it rather than failing.
- If the handoff mentions specific file paths, spot-check that key files still exist.
- Keep the recap short — the user wrote the handoff, they remember the broad strokes. Focus on **what's actionable now**.
- If state has diverged significantly (branch gone, major new commits by others), warn clearly before proceeding.
- Read the full handoff but present a condensed version. The user can ask for details.
