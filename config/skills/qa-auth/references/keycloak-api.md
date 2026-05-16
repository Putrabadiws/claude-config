# Keycloak API Auth — Direct Token Acquisition

## Password Grant with Token Caching

Acquire tokens directly from Keycloak's token endpoint. Cache in-memory with expiry tracking to avoid redundant requests.

```python
import requests
import time

_token_cache = {}

def get_keycloak_token(base_url, realm, client_id, username, password):
    cache_key = f"{realm}:{username}"
    cached = _token_cache.get(cache_key)

    if cached and cached["expiry"] > time.time() + 30:
        return cached["token"]

    res = requests.post(
        f"{base_url}/realms/{realm}/protocol/openid-connect/token",
        data={
            "grant_type": "password",
            "client_id": client_id,
            "username": username,
            "password": password,
        },
    )
    res.raise_for_status()
    body = res.json()

    _token_cache[cache_key] = {
        "token": body["access_token"],
        "expiry": time.time() + body["expires_in"],
    }
    return body["access_token"]
```

## Auth Fixtures (pytest)

Session-scoped fixtures to provide pre-authenticated headers. Use `get_keycloak_token` from above.

```python
# conftest.py
import pytest

@pytest.fixture(scope="session")
def auth_headers(base_url):
    token = get_keycloak_token(
        base_url=os.environ["KEYCLOAK_URL"],
        realm=os.environ.get("KEYCLOAK_REALM", "mdr-dev"),
        client_id=os.environ.get("KEYCLOAK_CLIENT", "frontend"),
        username=os.environ["TEST_USER_EMAIL"],
        password=os.environ["TEST_USER_PASS"],
    )
    return {"Authorization": f"Bearer {token}"}

@pytest.fixture(scope="session")
def admin_headers(base_url):
    token = get_keycloak_token(
        base_url=os.environ["KEYCLOAK_URL"],
        realm=os.environ.get("KEYCLOAK_REALM", "mdr-dev"),
        client_id=os.environ.get("KEYCLOAK_CLIENT", "frontend"),
        username=os.environ["TEST_ADMIN_EMAIL"],
        password=os.environ["TEST_ADMIN_PASS"],
    )
    return {"Authorization": f"Bearer {token}"}

# Usage
def test_list_alerts(client, auth_headers):
    res = client.get("/api/v1/alerts", headers=auth_headers)
    assert res.status_code == 200
```

## Token Refresh for Long-Running Suites

The `_token_cache` in `get_keycloak_token` handles this automatically — if the cached token is within 30s of expiry, it re-acquires. For explicit refresh in long suites, call `get_keycloak_token` again; the cache check handles staleness.

For Playwright-based token refresh (browser context), see `keycloak-browser.md`.
