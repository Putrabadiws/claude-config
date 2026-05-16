# Python/pytest Test Data Patterns

## Table of Contents

- [Factory Pattern](#factory-pattern)
- [Conftest Fixtures](#conftest-fixtures)
- [Cleanup: yield + afterEach (Preferred)](#cleanup-yield--aftereach-preferred)
- [Cleanup Error Handling](#cleanup-error-handling)
- [Parallel Safety: pytest-xdist](#parallel-safety-pytest-xdist)
- [Database per Worker (Maximum Isolation)](#database-per-worker-maximum-isolation)
- [Infrastructure Cleanup Patterns (Cross-Language)](#infrastructure-cleanup-patterns-cross-language)
  - [Dedicated Test Schema/Database](#dedicated-test-schemadatabase)
  - [TTL-Based Auto-Expiry](#ttl-based-auto-expiry)
  - [Scheduled Cleanup Pipeline](#scheduled-cleanup-pipeline)
  - [Cleanup Health Monitoring](#cleanup-health-monitoring)

## Factory Pattern

```python
# fixtures/factories/user_factory.py
import uuid

def build_user(**overrides):
    uid = str(uuid.uuid4())
    return {
        "id": overrides.get("id", uid),
        "email": overrides.get("email", f"test-{uid[:8]}@example.com"),
        "role": overrides.get("role", "user"),
        "active": overrides.get("active", True),
        **{k: v for k, v in overrides.items()
           if k not in ("id", "email", "role", "active")},
    }

def create_user(db, **overrides):
    user = build_user(**overrides)
    db.users.insert(user)
    return user
```

## Conftest Fixtures

```python
# conftest.py
import pytest

@pytest.fixture
def user(db):
    u = create_user(db)
    yield u
    db.users.delete(u["id"])  # cleanup even on failure

@pytest.fixture
def admin_user(db):
    u = create_user(db, role="admin")
    yield u
    db.users.delete(u["id"])
```

## Cleanup: yield + afterEach (Preferred)

```python
@pytest.fixture
def user(db):
    u = create_user(db)
    yield u
    db.users.delete(u["id"])  # cleanup after yield
```

## Cleanup Error Handling

```python
# Bad — cleanup error masks the original test failure
@pytest.fixture
def device(db):
    d = create_device(db)
    yield d
    db.devices.delete(d["id"])   # if this throws, original error is lost

# Good — log cleanup failures without masking test failure
@pytest.fixture
def device(db):
    d = create_device(db)
    yield d
    try:
        db.devices.delete(d["id"])
    except Exception as e:
        print(f"[cleanup] Failed to delete device {d['id']}: {e}")
        # Don't re-raise — the original test failure is more important
```

## Parallel Safety: pytest-xdist

```python
# conftest.py
@pytest.fixture(scope="session")
def worker_id(request):
    """Unique ID per xdist worker."""
    worker = getattr(request.config, 'workerinput', {})
    return worker.get('workerid', 'master')

@pytest.fixture
def run_prefix(worker_id):
    return f"{worker_id}-{uuid.uuid4().hex[:6]}"

@pytest.fixture
def user(db, run_prefix):
    u = create_user(db, email=f"test-{run_prefix}@example.com")
    yield u
    db.users.delete(u["id"])
```

## Database per Worker (Maximum Isolation)

```python
@pytest.fixture(scope="session")
def db(worker_id):
    schema = f"test_{worker_id}"
    engine = create_engine(f"{DATABASE_URL}/{schema}")
    create_schema(engine, schema)
    run_migrations(engine)
    yield engine
    drop_schema(engine, schema)
```

---

## Infrastructure Cleanup Patterns (Cross-Language)

### Dedicated Test Schema/Database

```yaml
# docker-compose.test.yml
services:
  postgres-test:
    image: postgres:15
    environment:
      POSTGRES_DB: testdb_${TEST_RUN_ID}
```

Drop the entire DB after the test suite. Nuclear option — fast, guaranteed clean.

### TTL-Based Auto-Expiry

For test data that outlives cleanup (cleanup crashes, CI runner killed):

```sql
-- Add columns to tables that receive test data
ALTER TABLE devices ADD COLUMN is_test_data BOOLEAN DEFAULT FALSE;

-- Periodic cleanup (cron or scheduled pipeline)
DELETE FROM devices
WHERE is_test_data = TRUE
  AND created_at < NOW() - INTERVAL '24 hours';
```

Mark all factory-created data:

```python
def create_device(db, **overrides):
    data = build_device(**overrides)
    data["is_test_data"] = True  # always tag factory data
    db.devices.insert(data)
    return data
```

### Scheduled Cleanup Pipeline

```groovy
// Jenkinsfile — runs nightly, cleans orphaned test data
pipeline {
    triggers { cron('H 3 * * *') }
    stages {
        stage('Cleanup Test Data') {
            steps {
                sh 'psql -h $DB_HOST -U $DB_USER -d $DB_NAME -c "DELETE FROM devices WHERE is_test_data = true AND created_at < NOW() - INTERVAL \'24 hours\'"'
            }
        }
    }
}
```

### Cleanup Health Monitoring

Track accumulation — alert if orphaned test records grow:

```python
count = db.execute("""
    SELECT COUNT(*) FROM devices
    WHERE is_test_data = true AND created_at < NOW() - INTERVAL '2 hours'
""").scalar()

if count > 500:
    notify_google_chat(f"⚠️ {count} orphaned test records older than 2h. Cleanup may be broken.")
```
