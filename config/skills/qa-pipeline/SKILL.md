---
name: qa-pipeline
description: >
  CI/CD pipeline patterns for testing — Jenkins, release orchestration,
  smoke tests, sharding, caching, security scanning, Allure reporting.
  Triggers: "test pipeline", "CI test", "smoke test", "release testing", "RC pipeline",
  "test in Jenkins", "E2E pipeline", "nightly tests", "test caching", "Allure report",
  "security scan pipeline".
  Do NOT use for writing test code (use qa-test-gen), flaky test triage (use qa-flaky),
  or test strategy planning (use qa-workflow).
---

# CI/CD Pipeline Patterns for QA

## Tiered Pipeline (Fast Gates First)

```
unit → integration → api → [security] → smoke → e2e
```

Target stage durations — if exceeded, investigate before it compounds:

| Stage | Target | Action if exceeded |
|---|---|---|
| Unit | < 2 min | Parallelize, split test files |
| Integration | < 5 min | Use test containers, reduce seed data |
| API tests | < 5 min | Check staging cold start |
| Security scan | < 3 min | Run parallel to API tests |
| Smoke | < 1 min | Reduce scope — max 5 tests |
| Full E2E | < 15 min | Shard across runners |

---

## Pattern 1: Per-Service Pipeline (runs on every PR)

Builds, tests, scans, and deploys a single service. Runs unit tests, integration tests, OWASP dependency check, SonarQube, then Docker build + deploy on release branch.

See [references/jenkins.md](references/jenkins.md#pattern-1-per-service-pipeline-runs-on-every-pr) for implementation.

### Reusable CI Steps

- Maven test + coverage — JaCoCo coverage parsing, JUnit test reporting
- Coverage gate — Baseline comparison, new-code detection
- Go build + test — Go mod tidy, coverage via gotestsum
- Node test + coverage — npm ci, Jest/Vitest coverage
- Android build — Gradle lint, test, build (AAB/APK)
- OWASP dependency check — NVD database cached
- SonarQube scan — Code quality (non-blocking)
- SAST / secret scanning
- Docker build + push
- Changelog/release — git-cliff on semver tags

---

## Pattern 2: E2E Repo Pipeline (standalone, triggered by release)

Runs API tests and journey tests from the E2E repo against a target `BASE_URL`. Produces Allure results.

See [references/jenkins.md](references/jenkins.md#pattern-2-e2e-repo-pipeline-standalone-triggered-by-release) for implementation.

---

## Pattern 3: Release Orchestrator (RC Flow)

### RC trigger flow

```
1. Services merge to release branch → Jenkins builds + deploys to dev
2. Release manager: git tag v2.1.0-rc.1
3. Pipeline:
   a. Deploy full stack to staging (Helm)
   b. Run smoke suite (~30s) — health checks + critical path only
      → Fail fast if a service didn't start, Keycloak unreachable, auth broken
   c. Smoke passes → trigger full E2E suite
4. E2E pass → promote v2.1.0 → prod → run prod smoke
   E2E fail → auto rollback staging → triage → re-tag rc.2
```

### RC tag convention

```
v{major}.{minor}.{patch}-rc.{iteration}

Examples:
  v2.1.0-rc.1   # first RC attempt
  v2.1.0-rc.2   # after fixing E2E failures
  v2.1.0        # final release (promoted from rc)
```

---

## Smoke Test Stage

**Smoke suite rules:**
- Max 5 tests, max 60 seconds total
- Covers: service health endpoints, one Keycloak auth flow, one core read, one core write
- Never modifies prod data — read-only or uses isolated smoke accounts
- Separate pytest marker: `pytest -m smoke`

```python
# tests/smoke/test_health.py — max 5 tests, max 60s total

def test_backend_health(request_client, base_url):
    res = request_client.get(f"{base_url}/actuator/health")
    assert res.status_code == 200

async def test_auth_flow_completes(page, base_url):
    await page.goto(f"{base_url}/login")
    await page.fill("#username", os.environ["SMOKE_USER"])
    await page.fill("#password", os.environ["SMOKE_PASS"])
    await page.click("#kc-login")
    await page.wait_for_url("**/dashboard")

def test_core_read_endpoint(request_client, base_url, smoke_token):
    res = request_client.get(f"{base_url}/api/v1/alerts?page=1&size=1",
                            headers={"Authorization": f"Bearer {smoke_token}"})
    assert res.status_code == 200
```

---

## Multi-Environment Strategy

| Environment | Test suite | Trigger | Destructive tests |
|---|---|---|---|
| dev / local | unit + integration | on save / pre-commit | yes |
| staging | smoke + full E2E | on RC tag | yes |
| prod | smoke only | post-deploy | never |

Environment-specific config via env vars — same test code, different `BASE_URL` + `TEST_ENV` flag.
Skip destructive tests in non-local environments using markers:

```python
@pytest.mark.skipif(os.environ.get("TEST_ENV") == "prod", reason="Destructive — skipped in prod")
def test_delete_device():
    ...
```

---

## On E2E Failure in RC — Triage Order

1. Did smoke pass? No → service startup issue, check deploy logs first
2. Check which service was updated this RC vs unchanged
3. Review logs for that service at the test failure timestamp
4. Check if Keycloak is healthy — auth failures cascade everywhere
5. Rollback staging to previous stable versions of changed services only
6. Re-run smoke to confirm rollback restored green before re-running full E2E

---

## Security Scanning, Caching, Sharding, Nightly Schedules

See [references/jenkins.md](references/jenkins.md) for CI-specific implementation of:

- **Security scanning** — OWASP dependency check + Trivy container scan (parallel to API tests)
- **CI caching** — Maven/npm/Go dependency caching, Playwright browser cache
- **Test parallelization** — Playwright sharding, pytest-xdist parallel workers
- **Nightly E2E schedule** — Full suite run at 2 AM daily

### Test Reporting: Allure + Notification

pytest generates Allure results with `--alluredir=allure-results`. CI publishes the report. Notification script posts pass/fail summary to chat.

```bash
<workspace>/py/venv/bin/pip install allure-pytest
<workspace>/py/venv/bin/pytest --alluredir=allure-results -v
```

```python
# scripts/notify_results.py
import json, os, requests

results = json.load(open("allure-results/summary.json"))
total = results["statistic"]["total"]
passed = results["statistic"]["passed"]
failed = results["statistic"]["failed"]
pass_rate = f"{round(passed / total * 100)}%"

message = f"""
*RC Test Results — {os.environ.get('STACK_VERSION', 'unknown')}*
Passed: {passed}/{total} ({pass_rate})
{"Failed: " + str(failed) if failed > 0 else ""}
Full Report: {os.environ.get('BUILD_URL', '')}allure/
"""

requests.post(os.environ["GCHAT_WEBHOOK"], json={"text": message})
```

---

## Local Development

See [references/local-dev.md](references/local-dev.md) for first-time setup, running E2E tests locally, environment config, viewing Allure results, and common issues.

---

## E2E Repo Structure

```
e2e/<suite>/
├── tests/
│   ├── smoke/            # ≤5 tests, ≤60s — health + critical path only
│   ├── api/              # Playwright API (no browser)
│   │   ├── <service-a>/
│   │   ├── <service-b>/
│   │   └── <service-c>/
│   ├── ui/               # Browser journey tests
│   │   └── portal/
│   ├── journeys/         # Cross-service flows
│   └── quarantine/       # Flaky tests — excluded from main run
├── fixtures/
│   ├── factories/        # Factory functions per entity
│   └── seeds/            # One-time setup (if any)
├── config/
│   ├── local.env
│   ├── staging.env
│   └── prod-smoke.env
├── conftest.py
├── pytest.ini
└── requirements.txt
```

---

## See Also

- **qa-flaky** — When CI failures are intermittent and need retry config or quarantine
- **qa-test-data** — When parallel sharding or xdist workers need isolated test data
- **qa-auth** — When pipeline needs Keycloak credentials, smoke accounts, or token setup
- **qa-test-gen** — When adding new test layers that need corresponding CI stages
- **qa-advanced** — When adding security scans, a11y checks, or visual regression to the pipeline
