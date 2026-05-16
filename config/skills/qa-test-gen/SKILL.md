---
name: qa-test-gen
description: >
  Test generation by layer. Use when generating unit tests,
  integration tests, E2E tests, or API tests. Covers layer selection, naming conventions,
  error assertion patterns, and when NOT to test.
  Triggers: "generate tests", "write tests", "unit test", "integration test", "E2E test",
  "API test layer", "test naming", "error assertions".
  Do NOT use for test strategy planning (use qa-workflow), CI pipeline config (use qa-pipeline),
  or test data/fixtures (use qa-test-data).
  For Go-specific patterns see references/go.md, for Java see references/java.md.
disable-model-invocation: true
---

# Test Generation by Layer

## Layer Selection by Change Scope

| Change | Unit | Integration | API | E2E Journey | Skip reasoning |
|---|---|---|---|---|---|
| Pure function, no I/O | ✅ | ❌ | ❌ | ❌ | No boundaries to cross |
| Single service logic | ✅ | ✅ | ✅ | ❌ | Journey tests add no value for isolated change |
| Public API change | ✅ | ✅ | ✅ | ✅ | Public contract must be verified end-to-end |
| Cross-service feature | ✅ | ✅ | ✅ | ✅ | Integration is the risk |
| Admin CRUD (internal) | ✅ | ✅ | ✅ | ❌ | No consumer contracts, UI E2E is low ROI |
| Config/env change only | ❌ | ❌ | ✅ smoke | ❌ | Smoke sufficient — no logic changed |
| RC / release | ✅ | ✅ | ✅ | ✅ full suite | Full regression required |

### When NOT to Automate

| Situation | Why to skip | What to do instead |
|---|---|---|
| Pure functions with no branches | Unit test covers it fully | Unit test only |
| Admin CRUD with no business logic | E2E is high cost, low signal | Manual spot check or API test only |
| One-off data migration | Automation cost > value for single-run script | Manual verification + rollback plan |
| Exploratory / UX testing | Automation can't find what it doesn't know | Dedicated exploratory session |
| Rapidly changing UI (pre-stable) | Maintenance cost exceeds value | Delay automation until UI stabilizes |
| Third-party UI embeds | Unstable selectors, not your contract to test | Mock the integration, test at API layer |
| Visually subjective UX | No deterministic pass/fail | Manual design review |

**Rule of thumb**: if writing the test takes longer than it would ever save, don't write it yet. Document the gap instead.

---

## Test Naming Conventions

Consistent names make CI logs, HTML reports, and Slack notifications readable.

### Unit tests

**Java (JUnit 5):** `@DisplayName("should [outcome] when [condition]")`
```java
@Test
@DisplayName("should lock account when failed attempts reach threshold")
void shouldLockAccountWhenFailedAttemptsReachThreshold() { ... }

@Test
@DisplayName("should throw ValidationException when email is empty")
void shouldThrowValidationExceptionWhenEmailIsEmpty() { ... }
```

**Python (pytest):** `test_should_[outcome]_when_[condition]`
```python
def test_should_return_true_when_failed_attempts_reach_threshold():
def test_should_raise_validation_error_when_email_is_empty():
```

**TypeScript (Vitest/Jest):** `should [outcome] when [condition]`
```typescript
it('should return true when failed attempts reach threshold', () => { ... });
```

**Go (testify):** `TestFunctionName_Scenario_Expected`
```go
func TestIsAccountLocked_AtThreshold_ReturnsTrue(t *testing.T) { ... }
func TestIsAccountLocked_BelowThreshold_ReturnsFalse(t *testing.T) { ... }

// Table-driven: use t.Run subtests
func TestParseSNI(t *testing.T) {
    tests := []struct{ name string; ... }{ ... }
    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) { ... })
    }
}
```

### API tests (pytest + Playwright)

`test_[METHOD]_[endpoint]_[condition]_[outcome]`
```python
def test_post_devices_with_valid_payload_returns_201():
def test_post_devices_with_missing_name_returns_400():
def test_get_devices_id_with_unknown_id_returns_404():
```

### E2E journey tests

`test_[feature]_[user_flow]_[outcome]`
```python
def test_dns_filtering_user_blocks_domain_blocked_within_30s():
def test_auth_login_with_lockout_account_locked_after_3_attempts():
```

**Why it matters**: test names appear in CI failure emails, Allure reports, and chat notifications. `test_1` vs `test_post_devices_with_missing_name_returns_400` is the difference between a 5-minute and 30-minute triage.

---

## Unit Tests

**Java/Spring Boot (JUnit 5 + Mockito):** See [references/java.md](references/java.md) for BaseControllerTests, MockBean, pure unit test patterns.

### Python (pytest)

```python
def test_should_return_locked_when_failed_attempts_reach_threshold():
    result = is_account_locked(failed_attempts=3, threshold=3)
    assert result is True

def test_should_return_unlocked_when_below_threshold():
    result = is_account_locked(failed_attempts=2, threshold=3)
    assert result is False

# With mocking
@patch('app.services.account.db')
def test_lock_account_persists_timestamp(mock_db):
    lock_account(user_id='123')
    mock_db.update.assert_called_once()
    call_args = mock_db.update.call_args
    assert 'locked_at' in call_args[1]
```

### TypeScript (Vitest + React Testing Library)

```typescript
// src/componentsv2/AlertList/__tests__/AlertList.test.tsx
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';

describe('AlertList', () => {
  it('should render alert items when data is loaded', () => {
    render(<AlertList alerts={mockAlerts} />);
    expect(screen.getByText('Critical Alert')).toBeInTheDocument();
  });

  it('should show empty state when no alerts', () => {
    render(<AlertList alerts={[]} />);
    expect(screen.getByText('No alerts found')).toBeInTheDocument();
  });
});
```

**Go (testify + miniredis):** See [references/go.md](references/go.md) for table-driven tests, Fiber handler tests, testify/mock, miniredis patterns, and best practices.

---

## Integration Tests

**Owner**: QA + Dev
**Rules**: Real DB/containers, test module boundaries, verify state + side effects

**Java/Spring Boot:** See [references/java.md](references/java.md#integration-tests) for @Transactional integration test pattern.

**Go:** See [references/go.md](references/go.md#integration-tests) for miniredis-backed resolver and Fiber handler chain tests.

---

## E2E Tests

**Owner**: QA / SDET
**Framework**: Playwright (API + UI), Appium (mobile)
**Rules**: `data-testid` selectors, idempotent, env-agnostic via `BASE_URL`

### Playwright async

```python
import pytest
from playwright.async_api import Page, expect

@pytest.mark.asyncio
async def test_analyst_can_view_news_feed(page: Page, login_analyst):
    await page.goto(f"{BASE_URL}/news-feed")
    await expect(page.locator('[data-testid="news-list"]')).to_be_visible()
    items = page.locator('[data-testid="news-item"]')
    assert await items.count() > 0
```

### Playwright sync + responsive

```python
import pytest
from playwright.sync_api import Page, expect

DEVICES = [
    {"name": "Desktop", "width": 1920, "height": 1080},
    {"name": "iPad Pro 11", "width": 834, "height": 1194},
    {"name": "iPhone 13", "width": 390, "height": 844},
]

@pytest.mark.parametrize("device", DEVICES, ids=[d["name"] for d in DEVICES])
def test_dashboard_renders_correctly(page: Page, device, login_user):
    page.set_viewport_size({"width": device["width"], "height": device["height"]})
    page.goto(f"{BASE_URL}/dashboard")

    if device["width"] < 1024:
        # Mobile: hamburger menu
        page.locator('svg.first, .lg\\:hidden').first.click()

    expect(page.locator('[data-testid="dashboard-content"]')).to_be_visible()
```

### Appium (mobile)

```python
from appium import webdriver
from selenium.webdriver.common.by import By

def test_login_flow_mobile(driver):
    driver.find_element(By.ID, 'email_field').send_keys('user@test.com')
    driver.find_element(By.ID, 'password_field').send_keys('testpass')
    driver.find_element(By.ID, 'login_button').click()
    assert driver.find_element(By.ID, 'dashboard_title').is_displayed()
```

---

## Error Assertion Patterns

### The problem with shallow assertions

```python
# Bad — only checks status code, misses everything meaningful
assert res.status_code == 400

# Also bad — checks message but not code (messages change, codes shouldn't)
assert body["message"] == "Email is required"

# Good — checks status, stable error code, and structure
assert res.status_code == 400
assert body["error"]["code"] == "VALIDATION_ERROR"
assert body["error"]["field"] == "email"
assert isinstance(body["error"]["message"], str)  # message can change
```

### Response pattern assertions

```java
// MessageResponse
mockMvc.perform(post("/api/v1/alerts").content("{}"))
    .andExpect(status().isBadRequest())
    .andExpect(jsonPath("$.success").value(false))
    .andExpect(jsonPath("$.message").isNotEmpty());

// MessageResponseWithData — verify structure
mockMvc.perform(get("/api/v1/alerts"))
    .andExpect(status().isOk())
    .andExpect(jsonPath("$.success").value(true))
    .andExpect(jsonPath("$.data").isArray());

// Pagination — 1-indexed API
mockMvc.perform(get("/api/v1/alerts?page=1&size=20"))
    .andExpect(status().isOk())
    .andExpect(jsonPath("$.metadata.currentPage").value(1))
    .andExpect(jsonPath("$.metadata.totalPages").isNumber());
```

### Common error assertion mistakes

| Mistake | Problem | Fix |
|---|---|---|
| Only assert status code | Misses malformed error body | Also assert `success` and `message` fields |
| Assert full error message | Messages are not stable contracts | Assert `success: false` + error code if available |
| Don't assert Content-Type | Client may receive HTML error page | Assert `content-type: application/json` |
| Don't assert on error for 2xx | Silent data corruption | Always assert on response body shape |

### Unit test error assertions

**Java:** See [references/java.md](references/java.md#error-assertions) for assertThrows patterns.

```python
# Bad
with pytest.raises(Exception):
    validate_email("")

# Good
with pytest.raises(ValidationError, match="email is required"):
    validate_email("")
```

**Go:** See [references/go.md](references/go.md#error-assertions) for ErrorContains, ErrorAs, and handler error patterns.

---

## API Versioning

When a public API evolves (v1 → v2):
- Write tests for both versions simultaneously
- Test v1 endpoints still return v1-compatible responses after v2 is introduced
- Add scenario: `Scenario: v1 client receives v1-compatible response after v2 deployment`

---

## Out of Scope

Performance/load testing (k6, Locust) is a separate concern — see `qa-advanced` for brief guidance.

---

## See Also

- **qa-workflow** — When planning a multi-layer test effort before generating code
- **qa-prompts** — When you need a structured prompt to drive test generation interactively
- **qa-test-data** — When setting up factories, fixtures, and cleanup for generated tests
- **qa-auth** — When tests need Keycloak login, token caching, or multi-tenant auth mocking
- **qa-advanced** — When you need a11y, visual regression, migration, or feature flag tests
