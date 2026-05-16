---
name: qa-advanced
description: >
  Advanced testing patterns — accessibility (axe-core), visual regression, database migration
  testing, feature flag testing, observability in test runs, performance testing overview.
  Triggers: "accessibility test", "a11y", "visual regression", "screenshot test",
  "migration test", "feature flag test", "test observability", "correlation ID",
  "load test", "performance test".
  Do NOT use for standard unit/integration/E2E tests (use qa-test-gen) or CI pipeline setup (use qa-pipeline).
---

# Advanced Testing Patterns

Routing guide for advanced QA patterns. Read the reference file matching your topic.

---

## Accessibility Testing (a11y)

Audit UI pages for WCAG compliance using axe-core with Playwright. Covers automated violation scanning, keyboard navigation tests, and a priority checklist for what to test first.

Reference: [references/a11y.md](references/a11y.md)

## Visual Regression Testing

Compare page screenshots against baselines to catch unintended UI changes. Covers Playwright screenshot assertions, masking dynamic content, baseline management, and responsive breakpoints.

Reference: [references/visual-regression.md](references/visual-regression.md)

## Database Migration Testing

Verify schema migrations work on non-empty tables and roll back cleanly. Covers Liquibase (Java/Spring) and Alembic (Python/FastAPI) patterns with a migration test checklist.

Reference: [references/migration-testing.md](references/migration-testing.md)

## Feature Flag Testing

Test both flag-on and flag-off paths. Covers Gherkin scenario parameterization, fixture-based flag control, smoke test rules for flag-agnostic environments, and edge case questions to always answer.

Reference: [references/feature-flags.md](references/feature-flags.md)

## Observability in Test Runs

Trace test failures back to service logs. Covers correlation IDs via `X-Test-Run-ID` headers, automatic screenshot capture on failure with Allure attachment, and structured JSON test output.

Reference: [references/observability.md](references/observability.md)

---

## Performance / Load Testing (Brief)

Out of scope for this skill. Tools to be aware of: **k6** (JavaScript), **Locust** (Python, already in some Falcon requirements.txt). Run nightly or pre-RC on critical endpoints, not in every MR pipeline. Treat as a separate skill/workstream from functional QA.

---

## See Also

- **qa-test-gen** — Standard layer-specific test patterns before adding advanced checks
- **qa-pipeline** — Integrating a11y, visual regression, or migration tests into CI stages
- **qa-test-data** — Factory-created seed data for migration or feature flag tests
- **qa-flaky** — Intermittent false positives from visual regression or a11y tests
