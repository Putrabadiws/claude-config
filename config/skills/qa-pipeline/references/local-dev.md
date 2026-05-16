# Local Development — Running E2E Tests

## First-time setup

```bash
# 1. Create venv if missing
python3 -m venv <workspace>/py/venv

# 2. Install dependencies for the suite you're working on
cd <workspace>/e2e/<suite>
<workspace>/py/venv/bin/pip install -r requirements.txt

# 3. Install Playwright browsers (only for browser/UI suites)
<workspace>/py/venv/bin/python -m playwright install chromium
```

Each suite has its own `requirements.txt` — install per suite, not globally.

## Running tests

```bash
VENV=<workspace>/py/venv/bin

# Run entire suite
$VENV/pytest --ignore=quarantine/ -v

# Run specific test folder
$VENV/pytest tests/api/<service>/ -v

# Run single file
$VENV/pytest tests/ui/portal/test_dashboard.py -v

# Run by marker
$VENV/pytest -m smoke -v
$VENV/pytest -m "not slow" -v

# Run with keyword filter
$VENV/pytest -k "test_post_devices" -v

# Parallel (if pytest-xdist installed)
$VENV/pytest -n auto --ignore=quarantine/ -v
```

## Environment config

Each suite has env files in `config/`:

```
config/
├── local.env         # local dev (rarely used — most run against staging)
├── staging.env       # default target
└── prod-smoke.env    # prod smoke only — read-only tests
```

Override target environment:

```bash
# Load env file (check your suite's conftest.py for how it reads these)
$VENV/pytest --env-file=config/staging.env -v

# Or override BASE_URL directly
BASE_URL=https://staging.example.com $VENV/pytest tests/smoke/ -v

# Override specific variables
TEST_USER_EMAIL=analyst@test.com TEST_USER_PASS=secret $VENV/pytest tests/api/ -v
```

Tests run against `BASE_URL` (staging by default). Auth credentials come from env vars — see qa-auth skill for the full list.

## Viewing results

```bash
# Generate Allure results
$VENV/pytest --alluredir=allure-results --ignore=quarantine/ -v

# Serve Allure report locally (requires allure CLI)
allure serve allure-results

# If allure CLI not installed
brew install allure
```

Screenshots from failed UI tests land in `allure-results/` as attachments — visible in the Allure report under each failed test step.

## Common issues

| Problem | Cause | Fix |
|---|---|---|
| `playwright._impl._errors.Error: Executable doesn't exist` | Browsers not installed | `<workspace>/py/venv/bin/python -m playwright install chromium` |
| `401 Unauthorized` on all API tests | Token acquisition failed — wrong credentials or Keycloak down | Check `KEYCLOAK_URL`, `TEST_USER_EMAIL`, `TEST_USER_PASS` env vars. Verify Keycloak is reachable. |
| `ConnectionError` / staging unreachable | VPN not connected | Check VPN connectivity for your network |
| `ModuleNotFoundError` | Wrong venv or missing deps | `<workspace>/py/venv/bin/pip install -r requirements.txt` |
| TOTP failures | Clock skew or wrong secret | Verify `TEST_TOTP_SECRET` env var. Check system clock sync. |
| Tests pass locally, fail in CI | Auth state cached locally but cold in CI | Don't rely on `auth-state/*.json` files in git — CI generates fresh ones. |
