# GitHub CLI Conventions

- Use `gh` for GitHub operations
- PR descriptions use `--body` (or `--body-file -` for HEREDOC)
- Don't use `--fill` with `--title`/`--body` (they override each other)

## Branch Rules

- Before code changes, check current branch - ask to switch to `develop` (or `main` if no `develop` branch) if needed
- Never push directly to: `develop`, `main`, `master`, `release`
- Always push to new branch, then open a PR
- Before creating a feature branch:
  1. `git status` — if local changes exist (tracked or untracked), analyze what they are and ask the user what to do (stash, commit, discard)
  2. `git checkout <base> && git pull origin <base>` to get latest
  3. Then create the feature branch from there
  4. Especially important for submodules which often sit at pinned commits behind the branch head

## PR Rules

- Before pushing to a branch that already has a PR, check if the PR was merged (`gh pr view <number> --json state`). If merged, create a new PR after pushing instead of assuming the existing PR will update.
- Open PRs against the team's default integration branch (`develop` if it exists, otherwise `main`).

## Commit Rules

- Don't amend or force push unless explicitly asked

## New Repo Setup

When setting up a new GitHub repo, apply these defaults via `gh api`:

### 1. Branches
Create `develop` (if the team uses GitFlow) and `release` branches from `main`.

### 2. Branch Protection
Protect `main`, `develop`, `release`:
```
PUT /repos/:owner/:repo/branches/<branch>/protection
  required_pull_request_reviews.required_approving_review_count=1
  required_pull_request_reviews.dismiss_stale_reviews=true
  enforce_admins=true
  required_status_checks.strict=true
  allow_force_pushes=false
  allow_deletions=false
```

### 3. Repo PR / Merge Settings
```
PATCH /repos/:owner/:repo
  allow_squash_merge=true
  allow_merge_commit=false
  allow_rebase_merge=false
  delete_branch_on_merge=true
  squash_merge_commit_title=PR_TITLE
  squash_merge_commit_message=PR_BODY
```

### 4. Actions
Confirm GitHub Actions is enabled and the team's reusable workflows (if any) are configured under `.github/workflows/`.
