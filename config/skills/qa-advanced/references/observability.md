# Observability in Test Runs

## Correlation IDs

Generate a unique test run ID and pass it through all requests. This lets you find exactly which service logs correspond to a test failure.

```python
# conftest.py
import os, time

@pytest.fixture(scope="session")
def test_run_id():
    return os.environ.get("BUILD_NUMBER", f"local-{int(time.time())}")

@pytest.fixture
def api_headers(auth_headers, test_run_id, request):
    return {
        **auth_headers,
        "X-Test-Run-ID": test_run_id,
        "X-Test-Name": request.node.name,
    }
```

In services: log `X-Test-Run-ID` in every request log. When a test fails, search your log aggregator (OpenSearch) for that ID:
```bash
kubectl logs -f deployment/ib-backend-mdr -n ib-dev | grep "test-run-id"
```

## Screenshot on Failure (Playwright — built-in)

```python
# conftest.py
@pytest.fixture(autouse=True)
def screenshot_on_failure(request, page):
    yield
    if request.node.rep_call.failed:
        page.screenshot(path=f"screenshots/{request.node.name}.png")
        # Attach to Allure report
        import allure
        allure.attach.file(f"screenshots/{request.node.name}.png",
                          name="failure-screenshot",
                          attachment_type=allure.attachment_type.PNG)
```

## Structured test output

```python
# Custom pytest plugin — log structured output per test
@pytest.hookimpl(tryfirst=True, hookwrapper=True)
def pytest_runtest_makereport(item, call):
    outcome = yield
    rep = outcome.get_result()
    if rep.when == "call":
        import json
        print(json.dumps({
            "test": item.name,
            "status": rep.outcome,
            "duration": rep.duration,
            "runId": os.environ.get("BUILD_NUMBER", "local"),
        }))
```
