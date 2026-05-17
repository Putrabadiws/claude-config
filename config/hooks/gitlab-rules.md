# GitLab CLI Conventions

- Use `glab` not `gh`
- MR descriptions use `--description` not `--body`
- Don't use `--fill` with `--title`/`--description` (they override each other)

## Branch Rules

- Before code changes, check current branch - ask to switch to `develop` if needed
- Never push directly to: `develop`, `release`, `master`, `main`
- Always push to new branch, then create MR to `develop` only (not release/main/master unless stated otherwise)
- Before creating a feature branch:
  1. `git status` — if local changes exist (tracked or untracked), analyze what they are and ask the user what to do (stash, commit, discard)
  2. `git checkout develop && git pull origin develop` (or target branch) to get latest
  3. Then create the feature branch from there
  4. Especially important for submodules which often sit at pinned commits behind the branch head

## MR Rules

- Before pushing to a branch that already has an MR, check if the MR was merged (`glab api projects/:fullpath/merge_requests/<id>` → check `state`). If merged, create a new MR after pushing instead of assuming the existing MR will update.

## Commit Rules

- Don't amend or force push unless explicitly asked

## Exceptions

| Repo Type | Rule |
|-----------|------|
| Main module repos (e.g., `ib-dns-all`) | Protected branch rules still apply — never push directly to release/develop/main/master. Create a new branch, then MR to the tracked branch (usually `release`). |

## New Repo Setup

When setting up a new GitLab repo, apply these settings via API (`glab api`):

### 1. Branches
Create and push `develop` and `release` branches from `master`/`main`.

### 2. Branch Protection
Protect `master`/`main`, `develop`, `release`:
```
POST /projects/:id/protected_branches
  name=<branch>, merge_access_level=40 (Maintainer), push_access_level=0 (No one), allow_force_push=false
```

### 3. Project MR Settings
```
PUT /projects/:id
  squash_option=default_on
  remove_source_branch_after_merge=true
  only_allow_merge_if_pipeline_succeeds=true
  only_allow_merge_if_all_discussions_are_resolved=true
  merge_commit_template=%{reference} %{title}\n\n%{description}
  squash_commit_template=%{title} (%{reference})\n\n%{description}
```

### 4. Instance Runners
Enable instance runners for the project:
```
PUT /projects/:id
  shared_runners_enabled=true
```

### 5. CI/CD (when tech stack is known)
Add `.gitlab-ci.yml` with workflow rules and shared CI components:
```yaml
workflow:
  rules:
    - if: $CI_PIPELINE_SOURCE == "merge_request_event" && ($CI_MERGE_REQUEST_TARGET_BRANCH_NAME == "develop" || $CI_MERGE_REQUEST_TARGET_BRANCH_NAME =~ /^release/)

include:
  - component: gitlab.dev.candradimuka/devsecops/ci-components/<name>@~latest
```
Available: maven-test-coverage, maven-coverage-gate, go-build-test, nodejs-test-coverage, nodejs-eslint-check, aikido-sast, sonarqube-scan, docker-build-push, owasp-dependency-check, changelog-release, swiftlint-check, android-build-release, maven-spotless-check

## Connection Issues

GitLab (`gitlab.dev.candradimuka`) occasionally fails to connect - retry is normal.
If still failing, check and reconnect VPN automatically (don't ask the user):
- **macOS**: `scutil --nc list` → if disconnected, `scutil --nc start "Ziti Desktop Edge 2"` → wait ~5s → retry
- **Windows**: `ipconfig | findstr /i "Ziti"` or check Ziti Desktop Edge in system tray

### SSH vs HTTP

- SSH (port 22) is **not available** on `gitlab.dev.candradimuka` — connections are refused
- Always use **HTTP** URLs for clone/push/pull: `http://gitlab.dev.candradimuka/<group>/<repo>.git`
- Existing repos already use HTTP remotes
