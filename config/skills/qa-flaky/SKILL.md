---
name: qa-flaky
description: >
  Flaky test handling — retry config, quarantine process, triage checklist, mobile-specific.
  Triggers: "flaky test", "quarantine", "test retry", "triage test failure",
  "intermittent test", "test fails in CI", "test passes locally".
  Do NOT use for writing new tests (use qa-test-gen) or CI pipeline config (use qa-pipeline).
---

# Flaky Test Handling

A test that passes and fails non-deterministically without code changes. Flaky tests are technical debt — they erode trust in the test suite and cause teams to ignore failures.

**Never silently skip or comment out a flaky test. Always quarantine and document.**

---

## Retry Configuration

See [references/retry-config.md](references/retry-config.md) for Playwright, JUnit 5, and pytest retry settings.

---

## Quarantine Process

See [references/quarantine.md](references/quarantine.md) for the full 5-step quarantine workflow (tag, move, exclude from pipeline, file issue, resolve).

---

## Common Causes & Fixes

### Timing / race conditions

**Symptom**: Fails on slow machines or high load. Passes locally.

```python
# Bad: hardcoded wait
await page.wait_for_timeout(2000)
time.sleep(2)

# Good: wait for specific condition
await page.wait_for_selector('[data-testid="result"]')
await expect(page.locator('[data-testid="status"]')).to_have_text('complete')
await page.wait_for_response(lambda resp: '/api/alerts' in resp.url and resp.status == 200)
```

### Shared / dirty test data

**Symptom**: Fails when run in parallel or after certain other tests.

Fix: Apply factory pattern + unique IDs per test. See `qa-test-data` skill.

### Environment instability

**Symptom**: Fails in CI but not locally, or only on certain runners.

Fix:
- Pin Docker image versions (use `postgres:15.4` not `postgres:latest`)
- Add health checks before tests start
- Check if staging environment has enough resources
- Check Jenkins runner resource limits

### Order-dependent tests

**Symptom**: Fails when run in isolation, passes in full suite (or vice versa).

Fix:
- Ensure setup fixtures fully reset state
- Never use module-level shared mutable state in tests
- Run with `--randomly-seed` to catch order dependencies:
  ```bash
  pytest --randomly-seed=12345
  ```

### Network / external dependency flakiness

**Symptom**: Timeout errors, connection refused, intermittent 503.

Fix:
- Mock external services in unit/integration tests (MockServer for Keycloak JWKS)
- For E2E: add retry at the HTTP client level for idempotent reads
- Verify Keycloak is healthy before running auth-dependent tests

---

## Triage Checklist — When E2E Fails in CI

```
[ ] Does it fail consistently or intermittently?
    → Consistent = likely a real bug
    → Intermittent = likely environment or timing

[ ] Does it fail locally against staging?
    → Yes = environment agnostic, likely real bug
    → No = CI-specific issue (Jenkins runner resources, timing, config)

[ ] Which service was updated this deploy?
    → Cross-reference with which service logs show errors

[ ] Do service logs show errors at the test failure timestamp?
    → Check correlation/trace IDs in test output vs service logs
    → kubectl logs -f deployment/<service> -n <namespace> --since=5m

[ ] Did any infra component (DB, Redis, RabbitMQ) have issues?
    → Check Grafana dashboards for the test run window

[ ] Did Keycloak have issues?
    → Token acquisition failures are a common CI flakiness source
    → Check Keycloak pod logs in ib-keycloak namespace
```

---

## Flaky Test Metrics

Track in your team dashboard:
- **Flaky rate**: flaky failures / total CI runs per week
- **Quarantine age**: how long each test has been quarantined
- **Resolution rate**: quarantined tests fixed per sprint

Target: flaky rate < 2% of CI runs. Zero tolerance for quarantine > 2 sprints.

---

## Mobile-Specific Flakiness

See [references/mobile.md](references/mobile.md) for Appium/Aman-specific causes, retry config, pre-test device setup, and mobile flaky rate tracking.

---

## See Also

- **qa-pipeline** — When configuring CI retry stages, quarantine exclusions, or nightly triage runs
- **qa-test-data** — When dirty or shared test data is the root cause of flakiness
- **qa-auth** — When token expiry or Keycloak instability causes intermittent auth failures
- **qa-workflow** — When flaky tests need to be tracked as coverage gaps in the coverage matrix
