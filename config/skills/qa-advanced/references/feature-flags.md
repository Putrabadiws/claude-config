# Feature Flag Testing

## Core problem

Feature flags mean a feature can be ON for some users/envs and OFF for others. Tests that don't account for flags are unreliable in staging and meaningless in prod smoke.

## Scenario parameterization

```gherkin
Feature: DNS threat intelligence (behind flag: enable_threat_intel)

  @flag_on
  Scenario: Threat intel enrichment applied when flag is enabled
    Given the "enable_threat_intel" flag is ON for this device
    When a DNS query resolves to a known malicious IP
    Then the response includes threat intel metadata
    And the query is blocked

  @flag_off
  Scenario: Threat intel enrichment skipped when flag is disabled
    Given the "enable_threat_intel" flag is OFF for this device
    When a DNS query resolves to a known malicious IP
    Then the response does not include threat intel metadata
```

## Test implementation

```python
# Playwright — control flags via API or env var
@pytest.fixture
def with_flag(api_client):
    def _set(flag_name, value=True, scope="test"):
        api_client.post("/api/internal/flags",
                       json={"flag": flag_name, "value": value, "scope": scope})
        return flag_name
    return _set

@pytest.fixture(autouse=True)
def cleanup_flags(api_client, request):
    yield
    # Reset any flags set during the test
    for flag in getattr(request, "_flags_set", []):
        api_client.delete(f"/api/internal/flags/{flag}?scope=test")

def test_blocks_malicious_domain_with_flag_on(page, with_flag):
    with_flag("enable_threat_intel")
    # ... test behavior when flag is ON

def test_does_not_apply_threat_intel_with_flag_off(page):
    # flag defaults to OFF — no setup needed
    # ... test default behavior
```

## Smoke tests must be flag-agnostic

Smoke tests run post-deploy in prod. They can't know or control flag state.

Rules:
- Test behavior that exists regardless of flag state
- If testing a flagged feature in smoke: use a dedicated smoke account with known flag state
- Never assert on behavior that depends on a flag you haven't explicitly set

## Edge cases to always test for flags

For every feature behind a flag, add to the edge case Q&A:
- Q: What happens if flag is changed mid-session?
- Q: What's the default state for new users / new devices?
- Q: Is the flag per-user, per-device, per-tenant, or global?
- Q: Is there a UI to manage flags, or only API/env var?
