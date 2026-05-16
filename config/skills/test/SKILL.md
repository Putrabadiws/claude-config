---
name: test
description: Run tests - auto-detects project type (Jest, pytest, go test, mvn test). Run all or specific tests.
argument-hint: [file-or-pattern (optional)]
allowed-tools: Bash(npm test *), Bash(npx jest *), Bash(pytest *), Bash(go test *), Bash(./mvnw test *)
---

# Run Tests

## Detect Project Type
!`ls package.json pyproject.toml requirements.txt go.mod pom.xml 2>/dev/null | head -1 || echo "unknown"`

## Quick Commands by Type

### JavaScript/TypeScript (Jest/Vitest)
```bash
# Run all tests
npm test

# Run specific file
npx jest $ARGUMENTS

# Run with coverage
npm test -- --coverage

# Watch mode
npm test -- --watch

# Run specific test name
npx jest -t "test name pattern"
```

### Python (pytest)
```bash
# Run all tests
pytest

# Run specific file
pytest $ARGUMENTS

# Run with coverage
pytest --cov=app

# Run specific test
pytest -k "test_name_pattern"

# Verbose output
pytest -v

# Stop on first failure
pytest -x
```

### Go
```bash
# Run all tests
go test ./...

# Run specific package
go test $ARGUMENTS

# With coverage
go test -cover ./...

# Verbose
go test -v ./...

# Run specific test
go test -run "TestName" ./...

# Race detection
go test -race ./...
```

### Java/Spring Boot (Maven)
```bash
# Run all tests
./mvnw test

# Run specific test class
./mvnw test -Dtest=$ARGUMENTS

# Skip tests
./mvnw install -DskipTests

# Run with specific profile
./mvnw test -Ptest
```

## Auto-Detect and Run

| File Present | Project Type | Command |
|--------------|--------------|---------|
| `package.json` | Node.js | `npm test` |
| `pyproject.toml` | Python | `pytest` |
| `requirements.txt` | Python | `pytest` |
| `go.mod` | Go | `go test ./...` |
| `pom.xml` | Java/Maven | `./mvnw test` |

## Common Patterns

### Run Failed Tests Only
```bash
# Jest
npx jest --onlyFailures

# pytest
pytest --lf

# Go - rerun manually
go test -v ./... 2>&1 | grep FAIL
```

### Run Tests in CI Mode
```bash
# Jest
CI=true npm test

# pytest
pytest --tb=short -q

# Go
go test -short ./...

# Maven
./mvnw test -B
```

## Debugging Failed Tests

1. **Run single test** with verbose output
2. **Check test logs** for assertion failures
3. **Add debug logging** if needed
4. **Check test fixtures/mocks** for stale data
