# Coverage Matrix

| Scenario | Unit | Integration | API | E2E | Status |
|---|---|---|---|---|---|
| Happy path | ✅ | ✅ | ✅ | ✅ | Covered |
| Null input | ✅ | ✅ | ✅ | ❌ | Partial |
| Redis unavailable | ✅ | ❌ | ❌ | ❌ | Gap |
| Auth bypass | ❓ | ❓ | ❓ | ❓ | Unanswered — QA to clarify |

---

## Test Maintenance Protocol

**When requirements change:**
1. Update scenario file first — scenarios are source of truth
2. Run coverage matrix to identify which tests are now invalid
3. Update tests to match new scenarios — do not leave orphaned tests
4. Mark removed scenarios as `# deprecated: [reason] [date]` before deleting

**Pruning obsolete tests:**
- Quarterly: run coverage matrix, identify tests with no matching scenario
- Tests with no scenario = candidates for deletion (confirm with QA first)
- Never delete without checking if the scenario was renamed vs truly removed

**Test debt:**
- Track in GitLab issues with label `test-debt`
- Prioritize: flaky > missing coverage > outdated assertions > style
