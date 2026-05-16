# Playwright E2E Test Data Patterns

## API-Created Test Data

For E2E tests that can't use DB-level cleanup, create data via API and tag it:

```python
# Tag all test data with a test run ID
run_id = f"test-{uuid.uuid4().hex[:8]}"

device = api.create_device({
    "name": f"test-device-{run_id}",
    "_testRunId": run_id,
})

# Global teardown: delete all data tagged with this runId
api.delete_where({"_testRunId": run_id})
```

## E2E Directory Structures

### Dataset-driven (multi-user / parametrized)

```
e2e/<suite>/
├── conftest.py                 # Fixtures: page, login, dataset
├── Feature-Name/
│   └── scenario-test/
│       ├── conftest.py         # pytest_generate_tests hook
│       ├── data/
│       │   └── login_dataset.json   # Multi-user test data
│       └── test_feature.py
```

### Standard (single-user fixtures)

```
e2e/<suite>/
├── conftest.py                 # Fixtures: page, device, credentials
├── Feature-Name/
│   └── test_feature.py
```

## Parallel Safety: Worker Index

```python
# Use worker index as part of run ID
run_id = f"{int(time.time())}-{os.environ.get('PLAYWRIGHT_WORKER_INDEX', 0)}"
test_email = f"test-{run_id}@example.com"
```

## Sharding: Data Safety Across Runners

Each shard runner needs independent data:

```python
# Use shard index as part of run ID
shard_index = os.environ.get("CI_NODE_INDEX", os.environ.get("PLAYWRIGHT_SHARD", "0"))
run_id = f"shard-{shard_index}-{int(time.time())}"

# All factories use run_id as prefix
user = create_user(db, email=f"test-{run_id}@example.com")
```

## Parallel-Safe Smoke Accounts

For smoke tests against prod/preprod (can't create/delete users):
- Use dedicated smoke test accounts, one per environment
- Accounts are read-only — never created or deleted during test runs
- Credentials stored in CI secret store (masked)
- If a smoke test needs to write data — use a dedicated smoke org/tenant, never shared user data

## Seeding Shared Infrastructure (When Unavoidable)

Sometimes you need shared data that's expensive to create per test (e.g. a populated ML model, a complex org hierarchy). If you must share:

1. Create in `globalSetup` (Playwright) or `session`-scoped fixture (pytest)
2. Make it **read-only** — tests never mutate shared data
3. Tag with `_shared: true` so cleanup scripts skip it
4. Document explicitly: "this data is shared, do not modify in tests"
