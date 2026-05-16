---
name: lint
description: Run linter - format, check style, fix code formatting. Auto-detects project type. Do NOT use for auto-generated code, vendored dependencies, or build artifacts.
argument-hint: [file-or-directory]
allowed-tools: Bash(npm *), Bash(npx *), Bash(black *), Bash(isort *), Bash(ruff *), Bash(go fmt *), Bash(goimports *), Bash(./mvnw *)
---

# Code Linting

## Detect Project Type
!`ls package.json pyproject.toml requirements.txt go.mod pom.xml 2>/dev/null | head -1 || echo "unknown"`

## Quick Commands by Type

### JavaScript/TypeScript (React, Next.js)
```bash
# Check
npm run lint

# Fix
npm run lint -- --fix
npx prettier --write .

# Single file
npx eslint $ARGUMENTS --fix
npx prettier --write $ARGUMENTS
```

### Python (FastAPI)
```bash
# Format
black .
isort .

# Lint
ruff check .
ruff check --fix .

# Single file
black $ARGUMENTS
isort $ARGUMENTS
ruff check $ARGUMENTS --fix
```

### Go
```bash
# Format
go fmt ./...
goimports -w .

# Lint (if golangci-lint installed)
golangci-lint run

# Single file
go fmt $ARGUMENTS
goimports -w $ARGUMENTS
```

### Java (Spring Boot)
```bash
# Checkstyle (if configured)
./mvnw checkstyle:check

# Spotless (if configured)
./mvnw spotless:apply
```

## Auto-Detect and Run

Based on files in current directory:

| File Present | Project Type | Command |
|--------------|--------------|---------|
| `package.json` | Node.js | `npm run lint && npx prettier --write .` |
| `pyproject.toml` | Python | `black . && isort . && ruff check --fix .` |
| `requirements.txt` | Python | `black . && isort .` |
| `go.mod` | Go | `go fmt ./... && goimports -w .` |
| `pom.xml` | Java/Maven | `./mvnw checkstyle:check` (if configured) |

## Fix Common Issues

### ESLint
```bash
# Disable rule for line
// eslint-disable-next-line rule-name

# Disable rule for file
/* eslint-disable rule-name */
```

### Python
```bash
# Ignore line for ruff
x = 1  # noqa: E501

# Ignore file for black
# fmt: off
code here
# fmt: on
```

### Go
```bash
# Ignore line
//nolint:errcheck
```

## Pre-commit Integration

If `.pre-commit-config.yaml` exists:
```bash
pre-commit run --all-files
```
