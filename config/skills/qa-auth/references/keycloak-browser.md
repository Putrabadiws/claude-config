# Keycloak Browser Auth — Playwright

## Standard Login (No TOTP)

For suites that don't require a second factor.

```python
# Playwright sync
def login(page, username, password, base_url):
    page.goto(f"{base_url}/login")
    page.fill("#username", username)
    page.fill("#password", password)
    page.click("#kc-login")
    page.wait_for_url("**/dashboard")
```

## Login with TOTP (1-Indexed OTP Fields)

When TOTP is required, Keycloak renders individual digit fields `#otp1`..`#otp6`.

```python
# Playwright async
import pyotp

async def login_with_totp(page, username, password, totp_secret, base_url):
    await page.goto(f"{base_url}/login")
    await page.fill("#username", username)
    await page.fill("#password", password)
    await page.click("#kc-login")

    # TOTP — Keycloak uses 1-indexed individual digit fields: #otp1..#otp6
    otp_code = pyotp.TOTP(totp_secret).now()
    for i, digit in enumerate(otp_code, start=1):
        await page.fill(f"#otp{i}", digit)
    await page.click("#kc-login")
    await page.wait_for_url("**/dashboard")
```

## storageState Caching (Per Role)

The single biggest auth performance win. Without caching, every test logs in — adds 1-3s per test and causes flaky tests from Keycloak load.

### Setup: save authenticated state to disk

```python
# tests/auth/setup.py — run once before suite (globalSetup equivalent)
import json
import os
from playwright.sync_api import sync_playwright

def setup_auth_states(base_url):
    roles = {
        "admin": (os.environ["TEST_ADMIN_EMAIL"], os.environ["TEST_ADMIN_PASS"]),
        "user": (os.environ["TEST_USER_EMAIL"], os.environ["TEST_USER_PASS"]),
    }

    with sync_playwright() as p:
        browser = p.chromium.launch()
        for role, (email, password) in roles.items():
            page = browser.new_page()
            login(page, email, password, base_url)

            # Save authenticated state to disk
            page.context.storage_state(path=f"auth-state/{role}.json")
            page.close()
        browser.close()
```

### Fixtures: load cached auth state

```python
# conftest.py — load cached auth state
@pytest.fixture(scope="session")
def admin_context(browser):
    context = browser.new_context(storage_state="auth-state/admin.json")
    yield context
    context.close()

@pytest.fixture
def admin_page(admin_context):
    page = admin_context.new_page()
    yield page
    page.close()
```

## Token Expiry Handling

Validate cached storageState before reuse. Re-login only when token is invalid.

```python
import time

def is_token_valid(storage_state_path, base_url):
    try:
        with open(storage_state_path) as f:
            state = json.load(f)

        # Extract token from cookies or localStorage
        token = None
        for cookie in state.get("cookies", []):
            if cookie["name"] == "auth_token":
                token = cookie["value"]
                break

        if not token:
            for origin in state.get("origins", []):
                for entry in origin.get("localStorage", []):
                    if entry["name"] == "token":
                        token = json.loads(entry["value"]).get("token")
                        break

        if not token:
            return False

        import requests
        res = requests.get(f"{base_url}/api/auth/verify",
                          headers={"Authorization": f"Bearer {token}"})
        return res.ok
    except Exception:
        return False

# In setup: only re-login if token is invalid
state_path = f"auth-state/{role}.json"
if not os.path.exists(state_path) or not is_token_valid(state_path, base_url):
    # ... perform login and save state
```

## Token Refresh for Long-Running Suites

For suites where tokens expire before completion:

```python
# Playwright — check token before each test
@pytest.fixture(autouse=True)
def refresh_token_if_needed(page, base_url):
    token = page.evaluate("() => localStorage.getItem('token')")
    if token and is_token_expiring_soon(token):
        # Re-authenticate
        login(page, os.environ["TEST_USER_EMAIL"], os.environ["TEST_USER_PASS"], base_url)

def is_token_expiring_soon(token):
    import base64
    try:
        payload = json.loads(base64.b64decode(token.split('.')[1] + '=='))
        return payload['exp'] < time.time() + 60  # expires in < 1 min
    except Exception:
        return True  # can't parse = treat as expired
```

## Dataset-Driven Multi-User Login

Parametrize tests across multiple user accounts from a JSON dataset.

### conftest.py hook

```python
# conftest.py — pytest_generate_tests hook
def pytest_generate_tests(metafunc):
    if "record" in metafunc.fixturenames:
        dataset_path = metafunc.config.getoption("--dataset")
        with open(dataset_path) as f:
            records = json.load(f)
        metafunc.parametrize("record", records, ids=[r["username"] for r in records])
```

### Dataset format

```json
// data/login_dataset.json
[
  {
    "username": "analyst@example.test",
    "password": "...",
    "totp_secret": "BASE32SECRET",
    "role": "analyst",
    "tenant": "Tenant A"
  },
  {
    "username": "customer@example.test",
    "password": "...",
    "totp_secret": null,
    "role": "customer",
    "tenant": null
  }
]
```
