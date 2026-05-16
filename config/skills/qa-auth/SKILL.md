---
name: qa-auth
description: >
  Auth patterns for API and E2E tests with Keycloak. Token caching, TOTP handling,
  storageState, service accounts, multi-tenant testing, token refresh.
  Triggers: "test auth", "keycloak test", "token caching", "storageState", "TOTP test",
  "test login", "auth fixture", "multi-tenant test".
  Do NOT use for test code generation (use qa-test-gen) or CI pipeline auth setup (use qa-pipeline).
---

# Auth Patterns for Tests — Keycloak

Authentication is where most test suites break silently — tests pass locally (warm tokens) and fail in CI (cold start), or pass on first run and fail on the second (token expiry).

---

## Service Accounts vs User Accounts

| Account type | Use for | Risk |
|---|---|---|
| **Service account** (dedicated test user) | Smoke tests, prod-safe tests, long-running suites | Token must be rotatable, don't use real user data |
| **Ephemeral test user** (created per test) | Functional tests requiring clean state | More setup/teardown, slower |
| **Real user account** | Never | Can't reliably clean up, breaks prod data |

Rule: smoke tests and prod-targeted tests **always** use dedicated service accounts. Functional tests create ephemeral users via factory.

---

## Keycloak Realms

Configure realm, TOTP requirement, and client ID per platform — track in a project doc. Example shape:

| Platform | Realm | TOTP Required | Client ID |
|---|---|---|---|
| `<platform-a>` | `<realm-name>` | No | `frontend` |
| `<platform-b>` | `<realm-name>` | Yes (some roles) | `frontend` |

---

## Implementation by Test Type

### Browser / E2E tests (Playwright)

Standard login, TOTP login, storageState caching, token expiry handling, dataset-driven multi-user login, token refresh for long suites.

> Reference: [references/keycloak-browser.md](references/keycloak-browser.md)

### API tests (pytest, direct token)

Password grant token acquisition, in-memory token caching, session-scoped auth fixtures.

> Reference: [references/keycloak-api.md](references/keycloak-api.md)

### Java service tests (Spring Boot)

BaseControllerTests pattern, MockServer for JWKS, pure unit test auth mocking with `AuthContextHolder`.

> Reference: [references/java-mocking.md](references/java-mocking.md)

---

## Multi-Tenant Auth Testing

If your services use a tenant header (e.g. `Tenant-Id` or `Company-Id`) for isolation, always test cross-tenant access is rejected:

```python
# Cross-tenant isolation test
def test_tenant_a_cannot_access_tenant_b_data(client, tenant_a_headers, tenant_b_id):
    res = client.get(
        "/api/v1/alerts",
        headers={
            **tenant_a_headers,
            "Tenant-Id": tenant_b_id,
        },
    )
    assert res.status_code == 403
```

---

## Auth Scenarios to Always Test

```gherkin
Scenario: Unauthenticated request is rejected
  Given no auth token is provided
  When GET /api/v1/[resource] is called
  Then response status is 401
  And body contains success: false

Scenario: Expired token is rejected
  Given a Keycloak token that expired 1 minute ago
  When GET /api/v1/[resource] is called
  Then response status is 401

Scenario: User cannot access another tenant's resource
  Given user from tenant A is authenticated
  When GET /api/v1/[resource] is called with Tenant-Id header for tenant B
  Then response status is 403

Scenario: Token with insufficient role is rejected
  Given a viewer-role Keycloak token
  When DELETE /api/v1/[resource]/:id is called
  Then response status is 403
```

---

## Environment Variables Checklist

Required secrets per CI environment — never hardcode, never commit:

```bash
# Keycloak
KEYCLOAK_URL=https://keycloak.dev.example.com
KEYCLOAK_REALM=<your-realm>
KEYCLOAK_CLIENT=frontend

# Staging test accounts
TEST_USER_EMAIL=test-user@staging.example.com
TEST_USER_PASS=...
TEST_ADMIN_EMAIL=test-admin@staging.example.com
TEST_ADMIN_PASS=...
TEST_TOTP_SECRET=...   # if TOTP is required

# Prod smoke (read-only, isolated account)
SMOKE_USER=smoke@example.com
SMOKE_PASS=...
```

Store in CI secret store (masked). Never in `.env` files committed to the repo.

---

## See Also

- **qa-test-gen** — When generating test code that needs auth mocking or login fixtures
- **qa-test-data** — When creating authenticated test users via factories or managing credentials
- **qa-flaky** — When auth-related flakiness (token expiry, Keycloak instability) causes CI failures
- **qa-pipeline** — When configuring CI secrets, smoke test accounts, or auth setup stages
