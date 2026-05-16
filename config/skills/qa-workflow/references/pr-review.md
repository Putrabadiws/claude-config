# Test PR Review Conventions

## What belongs in a test PR description

```markdown
## What this tests
[Feature or bug being covered — link to original feature PR or ticket]

## Scenarios covered
- [ ] Happy path: [describe]
- [ ] Edge case: [describe]
- [ ] Negative path: [describe]

## Scenarios NOT covered (and why)
- [scenario]: blocked on Q3 (unanswered — see issue #123)
- [scenario]: out of scope — covered by manual exploratory session

## Test layer
- [ ] Unit  [ ] Integration  [ ] API  [ ] E2E

## How to run locally
```bash
# Java
./mvnw test -Dtest=AlertControllerTest

# Python
pytest tests/test_alert.py -v

# Vitest
npm test -- AlertList

# Playwright (E2E)
cd e2e/<suite> && pytest test_dashboard.py -v
```

## Test data
- Uses factory pattern ✅ / hardcoded data ⚠️ (explain why)
- Cleanup included ✅ / manual cleanup needed ⚠️ (explain)
```

## Reviewer checklist for test PRs

**Coverage**
- [ ] Scenarios in the PR description match the tests written
- [ ] Unanswered/deferred scenarios are documented, not silently absent
- [ ] No redundant tests (same scenario tested at multiple layers unnecessarily)

**Test quality**
- [ ] Test names follow convention: `@DisplayName` (Java) / `test_should_...` (Python) / `should...` (TS)
- [ ] No `// similar to above`, `// etc.`, or placeholder comments
- [ ] Each unit test has a single assertion focus
- [ ] Negative paths assert on specific error codes, not just status codes

**Data & isolation**
- [ ] Factory pattern used — no hardcoded shared identifiers
- [ ] Cleanup present (`@AfterEach` / `yield` fixture / `afterEach`) for data-creating tests
- [ ] `is_test_data: true` (or equivalent) on all factory-created records

**Flakiness risk**
- [ ] No `waitForTimeout` / `sleep` — only condition-based waits
- [ ] No shared mutable state between tests
- [ ] Tests can run in parallel and in any order

**Auth**
- [ ] Auth uses fixture/storageState — no inline login per test
- [ ] Service accounts used for smoke/prod tests — no real user credentials

## Who reviews what

| Test type | Primary reviewer | Secondary |
|---|---|---|
| Unit tests (Java/Python/TS) | Dev who owns the service | QA (scenario coverage check) |
| Integration tests | Dev + QA jointly | — |
| E2E / API tests | QA / SDET | Dev (auth + data patterns) |
| Migration tests | Dev | QA (rollback scenario) |

## When to request changes vs approve with comments

**Request changes** if:
- Tests don't cover the scenarios listed in the PR description
- Hardcoded shared data that will cause parallel failures
- Missing cleanup — will pollute staging
- `waitForTimeout` present — flakiness incoming

**Approve with comment** if:
- Minor naming inconsistency
- Could add one more edge case (but coverage is already solid)
- Style preference

**Never approve silently** a test PR that has no PR description — send it back for description first.
