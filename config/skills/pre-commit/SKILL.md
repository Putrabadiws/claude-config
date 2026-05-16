---
name: pre-commit
description: Setup or run pre-commit hooks, git hooks, husky, automatic formatting on commit.
argument-hint: [setup|run|update]
allowed-tools: Bash(pre-commit *), Bash(npm *), Bash(npx *), Read
---

# Pre-commit Hooks Setup

## Requested Action
Action: `$0`

## Detect Existing Setup
!`ls .pre-commit-config.yaml .husky package.json 2>/dev/null | head -3`

## Options

### Option 1: pre-commit (Python-based, works for all languages)

```bash
# Install pre-commit
pip install pre-commit

# Install hooks
pre-commit install

# Run on all files
pre-commit run --all-files

# Update hooks
pre-commit autoupdate
```

### Option 2: Husky (Node.js projects)

```bash
# Install husky
npm install -D husky lint-staged

# Initialize
npx husky init

# Add pre-commit hook
echo "npx lint-staged" > .husky/pre-commit
```

## Templates

### pre-commit-config.yaml (Python/Multi-language)

See [templates/pre-commit-config.yaml](templates/pre-commit-config.yaml)

### package.json additions (Node.js with Husky)

See [templates/package-lint-staged.json](templates/package-lint-staged.json)

## Recommended Hooks by Project Type

### Java/Spring Boot
```yaml
repos:
  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v4.5.0
    hooks:
      - id: trailing-whitespace
      - id: end-of-file-fixer
      - id: check-yaml
      - id: check-added-large-files
```

### Python/FastAPI
```yaml
repos:
  - repo: https://github.com/psf/black
    rev: 24.1.1
    hooks:
      - id: black
  - repo: https://github.com/pycqa/isort
    rev: 5.13.2
    hooks:
      - id: isort
  - repo: https://github.com/astral-sh/ruff-pre-commit
    rev: v0.1.14
    hooks:
      - id: ruff
        args: [--fix]
```

### JavaScript/TypeScript
```yaml
repos:
  - repo: https://github.com/pre-commit/mirrors-eslint
    rev: v8.56.0
    hooks:
      - id: eslint
        files: \.[jt]sx?$
        additional_dependencies:
          - eslint@8.56.0
  - repo: https://github.com/pre-commit/mirrors-prettier
    rev: v4.0.0-alpha.8
    hooks:
      - id: prettier
```

### Go
```yaml
repos:
  - repo: https://github.com/dnephin/pre-commit-golang
    rev: v0.5.1
    hooks:
      - id: go-fmt
      - id: go-imports
      - id: go-vet
```

## Common Commands

```bash
# Install hooks
pre-commit install

# Run all hooks on all files
pre-commit run --all-files

# Run specific hook
pre-commit run black --all-files

# Skip hooks temporarily
git commit --no-verify -m "message"

# Update hook versions
pre-commit autoupdate

# Uninstall
pre-commit uninstall
```

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Hook failed | Run `pre-commit run --all-files` to see details |
| Hook too slow | Add `stages: [commit]` to limit when it runs |
| Want to skip | `git commit --no-verify` (use sparingly) |
| Version conflict | `pre-commit autoupdate` |
