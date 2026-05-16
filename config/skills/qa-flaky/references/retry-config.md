# Retry Configuration

Framework-specific retry settings for CI test runs.

---

## Playwright (Falcon E2E)

```python
# pytest.ini or pyproject.toml
[tool.pytest.ini_options]
# requires pytest-rerunfailures
addopts = "--reruns 2 --reruns-delay 1"
timeout = 30
asyncio_mode = "auto"
```

```typescript
// playwright.config.ts (if using TS Playwright directly)
export default defineConfig({
  retries: process.env.CI ? 2 : 0,  // retry on CI, fail fast locally
  timeout: 30_000,
  expect: { timeout: 5_000 },
  use: {
    actionTimeout: 10_000,
    navigationTimeout: 30_000,
  },
});
```

## JUnit 5 (Spring Boot services)

```java
// No built-in retry — use custom extension or maven-surefire-plugin rerun
// pom.xml
<plugin>
    <groupId>org.apache.maven.plugins</groupId>
    <artifactId>maven-surefire-plugin</artifactId>
    <configuration>
        <rerunFailingTestsCount>2</rerunFailingTestsCount>
    </configuration>
</plugin>
```

## pytest (Python services)

```ini
# pytest.ini
[pytest]
addopts = --reruns 2 --reruns-delay 1
timeout = 30
```
