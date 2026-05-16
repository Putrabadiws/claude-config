---
name: qa-test-data
description: >
  Test data and fixture strategy. Factory patterns, data cleanup,
  parallel safety, TTL-based fallback.
  Triggers: "test data", "test fixtures", "factory pattern", "test cleanup", "test isolation",
  "parallel test data", "test seed".
  Do NOT use for test code generation (use qa-test-gen) or flaky test triage (use qa-flaky).
---

# Test Data & Fixture Strategy

## Core Principles

1. **Isolation** — each test creates and owns its data. No test depends on another's data.
2. **Factories over seeds** — generate minimal required data per test, not a global dump.
3. **Cleanup always** — even on test failure. Use `@AfterEach`, `yield`, or `finally`.
4. **Parallel safety** — use unique identifiers per test run. Never hardcode shared values.

---

## Factory Pattern — Language Reference

Use `build()` for in-memory objects, `create()` for persisted records. Always accept overrides.

| Language | Reference |
|----------|-----------|
| Java/Spring (JUnit 5) | [references/java.md](references/java.md) — static factory, `@Transactional` rollback |
| Go (testify) | [references/java.md](references/java.md#go-testify) — struct factory, `t.Cleanup` |
| Python (pytest) | [references/python.md](references/python.md) — dict factory, `yield` fixtures, conftest |
| TypeScript (Vitest) | [references/typescript.md](references/typescript.md) — object factory, `afterEach` cleanup |
| Playwright (E2E) | [references/playwright.md](references/playwright.md) — API-created data, tagged cleanup |

---

## Parallel Test Safety

Prefix test data identifiers with a unique run ID. Never share mutable data between parallel workers.

| Context | Strategy | Reference |
|---------|----------|-----------|
| JUnit + `@Transactional` | UUID per test (sufficient) | [java.md](references/java.md) |
| pytest-xdist | `worker_id` + UUID prefix | [python.md](references/python.md#parallel-safety-pytest-xdist) |
| Playwright workers | Worker index in run ID | [playwright.md](references/playwright.md#parallel-safety-worker-index) |
| Playwright sharding | Shard index + timestamp | [playwright.md](references/playwright.md#sharding-data-safety-across-runners) |
| Database per worker | Schema/DB per xdist worker | [python.md](references/python.md#database-per-worker-maximum-isolation) |

---

## Data Cleanup Strategies

| Strategy | Best for | Reference |
|----------|----------|-----------|
| Transaction rollback | Java integration tests | [java.md](references/java.md#cleanup-transaction-rollback-preferred) |
| `yield` + delete | pytest fixtures | [python.md](references/python.md#cleanup-yield--aftereach-preferred) |
| `afterEach` delete | TypeScript unit tests | [typescript.md](references/typescript.md#cleanup) |
| Tagged cleanup (`_testRunId`) | E2E tests without DB access | [playwright.md](references/playwright.md#api-created-test-data) |
| Dedicated test DB (drop after suite) | Full isolation, CI | [python.md](references/python.md#dedicated-test-schemadatabase) |
| TTL auto-expiry + cron | Orphaned data fallback | [python.md](references/python.md#ttl-based-auto-expiry) |

**Rule**: Cleanup errors must not swallow test failures — catch and log, never re-raise. See [python.md](references/python.md#cleanup-error-handling).

---

## Shared vs Per-Test Data

| Data type | Strategy | Example |
|-----------|----------|---------|
| Feature flags / config | Shared, read-only | Seeded once at suite start |
| Reference data (countries, categories) | Shared, read-only | Seeded once |
| User accounts | Per-test factory | Created in `@BeforeEach` / `yield` fixture |
| Transactions / events | Per-test factory | Created inline |
| External service responses | Per-test mock/stub | MockServer / nock per test |

**Rule**: If two tests could conflict over the same data row, it must be per-test.

### Shared infrastructure (when unavoidable)

Create in `globalSetup` or `session`-scoped fixture. Make it read-only. Tag with `_shared: true`. See [playwright.md](references/playwright.md#seeding-shared-infrastructure-when-unavoidable).

---

## Smoke Accounts (Prod/Preprod)

Dedicated read-only accounts per environment. Credentials in CI secret store (masked). Never create or delete during test runs. See [playwright.md](references/playwright.md#parallel-safe-smoke-accounts).

---

## E2E Fixture Files

See [playwright.md](references/playwright.md#e2e-directory-structures) for example directory layouts.

---

## Cleanup Infrastructure

Scheduled pipeline + health monitoring for orphaned test data. See [python.md](references/python.md#scheduled-cleanup-pipeline) and [python.md](references/python.md#cleanup-health-monitoring).

---

## See Also

- **qa-test-gen** — When generating test code that needs the factory and cleanup patterns defined here
- **qa-flaky** — When dirty/shared test data is causing intermittent failures
- **qa-pipeline** — When configuring CI parallelization or sharding that requires data isolation
- **qa-auth** — When test data includes authenticated users or multi-tenant contexts
