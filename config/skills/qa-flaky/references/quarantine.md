# Quarantine Process

Step-by-step process for isolating flaky tests from the main CI pipeline.

---

## Step 1: Tag the test

```python
# pytest
@pytest.mark.flaky(reruns=3)
def test_checkout_flow():
    ...
```

```java
// JUnit 5 — use custom annotation or @Tag
@Tag("flaky")
@Test
@DisplayName("should complete checkout flow")
void shouldCompleteCheckoutFlow() { ... }
```

## Step 2: Move to quarantine folder (E2E repos)

```
e2e/<suite>/
├── Feature-Name/
│   └── scenario-test/
│       └── test_feature.py          # main suite — runs in CI
└── quarantine/
    └── test_feature_flaky.py        # excluded from main CI run
```

## Step 3: Exclude from main pipeline

```groovy
// Jenkinsfile
stage('E2E Tests') {
    steps {
        sh '''
            cd e2e/<suite>
            pytest --ignore=quarantine/ -v --alluredir=allure-results
        '''
    }
}

// Run quarantine separately, allow failure
stage('Quarantine Tests') {
    steps {
        catchError(buildResult: 'SUCCESS', stageResult: 'UNSTABLE') {
            sh '''
                cd e2e/<suite>
                pytest quarantine/ -v
            '''
        }
    }
}
```

## Step 4: File an issue

Required fields for every quarantined test:
- Test name and file path
- Failure rate (e.g. "fails ~2 out of 5 runs")
- Error message / stack trace observed
- Suspected cause (timing? data? network? environment?)
- Label: `test-debt`
- Deadline for fix (default: current sprint)

## Step 5: Resolve

Options in priority order:
1. **Fix the test** — remove race condition, add proper wait, fix data isolation
2. **Fix the product** — if the test reveals real flakiness in the product itself
3. **Rewrite the test** — if the approach is fundamentally unstable (e.g. polling instead of event-driven)
4. **Delete the test** — only if coverage is fully replaced by a more stable test at a lower layer
