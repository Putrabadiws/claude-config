---
name: qa-workflow
description: >
  QA test workflow orchestrator and prompt templates. Use when planning test strategy, writing test scenarios,
  creating coverage matrices, starting any multi-layer testing effort, or needing a structured prompt template
  for QA phases (edge case review, scenario generation, task planning, test audit, coverage report, test PR review).
  Triggers: "test plan", "test strategy", "QA workflow", "test coverage", "scenario authorship",
  "coverage matrix", "decompose into tests", "test from requirements", "test prompt", "QA prompt",
  "test PR review", "test audit", "review AI tests", "coverage report".
  Do NOT use for single-file test generation (use qa-test-gen), pipeline setup (use qa-pipeline),
  or isolated concerns like flaky tests (use qa-flaky).
---

# QA Test Workflow

Orchestrates AI-assisted QA — scenario authorship, task planning, test generation coordination, and coverage tracking.

## Behavior Contract

Non-negotiable. Apply before doing anything.

### Rule 1: Always Plan Before Executing
For any request involving more than one scenario or one test file:
1. Create a task list first — do not start generating tests
2. Present the plan to QA — wait for explicit approval
3. Execute one task at a time — complete each fully before moving on
4. Mark tasks done — update the list as you go

### Rule 2: Ask About Edge Cases, Never Assume
After reading a feature or source code:
1. Identify potential gaps across all categories (see Edge Case Review)
2. Present as explicit numbered questions — not suggestions already incorporated
3. Wait for QA's answers before generating any test code
4. If no answer within the session: flag as `❓ Unanswered` in coverage matrix, proceed with partial coverage, note explicitly which scenarios are missing

**Wrong (assuming):** "I've added a null input scenario..."
**Correct (asking):** "Q3. What should happen if `userId` is null — error thrown, silent failure, or specific message?"

### Rule 3: Never Truncate, Skip, or Defer
Banned phrases:
- `// similar to above` / `// repeat for other cases` / `// etc.`
- `you can extend this pattern for...`
- `I'll leave the remaining tests as an exercise`

Every test must be fully written. If scope is large, break into more tasks — never compress quality.

### Rule 4: Each Task Must Be Self-Contained
When breaking into tasks or spawning agents:
- Every task carries its own full context — feature description, code, scenarios, tech stack, rules
- No task references "the previous task" or "as discussed above"
- An agent receiving only that task's packet should complete it with zero additional context

### Rule 5: Define Done Before Starting
For each task, state explicitly: what files are created, what scenarios are covered, what the success criteria is.

## Core Philosophy

- **QA owns scenarios** — coverage, edge cases, negative paths, user flows
- **AI generates test drafts** — from scenarios + source code context
- **Dev reviews unit tests** — not writes them from scratch
- **QA/SDET owns E2E repos** — E2E independent from service repos
- **Scenario coverage > line coverage** as the north star metric
- **Flaky tests are technical debt** — quarantine, don't ignore

## Workflow Overview

```
[PLAN] Read feature + code → ask edge case questions → QA answers
[PLAN] Create task list → QA approves
[TASK 1] Write/refine scenarios (interactive Q&A)
[TASK 2..N] Generate tests per layer (complete, no skipping)
[PARALLEL] Test data / fixtures per layer
[VERIFY] Coverage matrix — scenarios vs layers, gaps flagged
[PIPELINE] Tiered CI (unit → integration → api → smoke → e2e)
[RC] Release tag → deploy full stack → trigger E2E → pass/rollback
[MAINTAIN] Update on requirement change, prune obsolete, triage flaky
```

## Phase 1: Edge Case Review (Mandatory First Step)

### 1.1 Analyze and Question

Read feature + code, then ask QA directly about gaps in these categories:

| Category | What to ask about |
|---|---|
| Input validation | null, empty, wrong type, character limits, format |
| Authorization | unauthenticated, wrong Keycloak role, cross-tenant resource access |
| State & idempotency | double-submit, concurrent updates, mid-operation failure |
| External dependencies | timeout, unavailable, slow, retry behavior |
| Boundaries | min/max values, empty list vs null, pagination edges (1-indexed API) |
| Side effects | events emitted, DB state changed, queue messages, notifications sent |
| Security | injection vectors, sensitive data exposure, rate limiting |
| Multi-tenancy | cross-tenant data leak, Tenant-Id / Company-Id header spoofing |
| Mobile (if applicable) | offline mode, network transitions (WiFi→LTE), background/foreground lifecycle, push notification handling, deep links, device rotation, app update mid-session |

### 1.2 Question Format

```
Before I generate scenarios, I need to clarify gaps I don't see specified:

[Input validation]
Q1. What happens when `email` is empty string — validation error or null pointer?
Q2. Is there a max length on `deviceName`? What error if exceeded?

[Authorization]
Q3. Can a user with ANALYST role query another company's DNS logs, or is access scoped via Company-Id?

[External dependencies]
Q4. If Redis is unavailable, does the resolver fail open or fail closed?

Please answer each before I proceed.
If you're unsure — say so. I'll flag it as a coverage gap, not skip it.
If we're on a deadline — tell me which to skip and I'll mark them ❓.
```

### 1.3 Escalation Path

If QA doesn't answer or is unavailable:
- **On deadline**: Ask QA to explicitly mark which questions to skip vs block on
- **Skipped questions**: Enter as `❓ Unanswered — [question]` in coverage matrix
- **Never**: Assume an answer and silently incorporate it

## Phase 2: Task Planning

After edge case Q&A, create a task list before any code is written.

```markdown
## Test Generation Plan — [Feature Name]
Approved by QA: [ ] pending

### Task 1: Scenario authorship
- Scope: [feature], covering [list confirmed scenarios]
- Output: `scenarios/[feature].feature`
- Done when: All Q&A answers reflected, quality checklist complete

### Task 2: Unit tests — [ServiceName]
- Scope: Functions [list explicitly]
- Output: `[service]/src/test/java/.../[Feature]Test.java` or `tests/test_[feature].py`
- Mocks needed: [list — AuthContextHolder, repositories, external clients]
- Done when: Every function has test coverage, all edge cases covered

### Task 3: Integration tests — [ServiceName]
- Scope: [scenarios requiring real DB/queue]
- Output: `[service]/src/test/java/.../[Feature]IntegrationTest.java`
- Done when: State persistence + side effects verified

### Task 4: E2E API tests
- Scope: [endpoints]
- Output: `e2e/[suite]/[service]/test_[feature].py`
- Done when: All response codes covered, headers verified

### Task 5: E2E journey tests
- Scope: [cross-service flow]
- Output: `e2e/[suite]/[feature]/test_[flow].py`
- Done when: Full user journey verified, cleanup confirmed

### Task 6: Coverage matrix
- Output: `coverage/[feature]-matrix.md`
- Done when: All scenarios mapped, gaps documented
```

**Present to QA. Do not start Task 1 until approved.**

## Phase 3: Scenario Authorship

```gherkin
# Edge case Q&A:
# Q1: [question] → A: [answer]
# Q2: [question] → A: [unanswered — flagged as gap]

Feature: [Feature Name]
  Background:
    Given [shared precondition]

  Scenario: [happy path]
    Given / When / Then / And

  Scenario: [boundary / edge case]
    Given / When / Then

  Scenario: [negative path — include specific error code/message]
    Given / When / Then / And [system state unchanged]

  Scenario: [external dependency failure]
    Given [downstream unavailable]
    When [action]
    Then [fail open / fail closed / retry behavior]
```

**Quality Checklist:**
- [ ] Happy paths covered
- [ ] All Q&A answers reflected as scenarios
- [ ] Boundary values (min, max, zero, null, empty string)
- [ ] Negative paths with specific error codes/messages
- [ ] External dependency failures
- [ ] Side effects (events, DB, message queues, notifications)
- [ ] Idempotency (what happens on duplicate calls)
- [ ] Unanswered Q&A items flagged in coverage matrix

## Agent Context Packet Format

See [references/agent-packet.md](references/agent-packet.md) for the full self-contained packet template.

## Coverage Matrix & Test Maintenance

See [references/coverage-matrix.md](references/coverage-matrix.md) for the matrix template and maintenance protocol (requirement changes, pruning, test debt).

## Roles Reference

| Role | Owns | Uses AI for |
|---|---|---|
| **QA / SDET** | Scenarios, edge case Q&A, E2E repos, coverage matrix, flaky triage | Scenario generation, gap detection, test drafts |
| **Dev** | Unit test review (JUnit/pytest/Vitest), service-level integration tests | Unit test generation from decomposed scenarios |
| **DevOps** | CI pipelines, Helm charts, K8s deploys, rollback scripts | — |
| **Claude Code** | Test drafting, task planning, agent packets | All layers |

---

## Prompt Templates

All prompts pause at checkpoints and wait for QA input. Never one-shot.
Load the full template from [references/templates.md](references/templates.md) before presenting to the user.

### Prompt Index

| # | Name | Use when | Template |
|---|------|----------|----------|
| 1 | [Start a New Feature](references/templates.md#prompt-1-start-a-new-feature-full-workflow-entry-point) | Beginning full test coverage for a new feature | Full workflow: edge cases, Q&A, task plan, execution |
| 2 | [Edge Case Review](references/templates.md#prompt-2-edge-case-review-only) | Auditing existing scenarios for gaps | Gap analysis across 9 categories, Q&A before any changes |
| 3 | [Generate Scenarios](references/templates.md#prompt-3-generate-scenarios-after-edge-case-qa) | Edge case Q&A is done, need Gherkin scenarios | Scenarios from confirmed answers, gaps documented |
| 4 | [Task Planning](references/templates.md#prompt-4-task-planning-after-scenarios-approved) | Scenarios approved, need a test generation plan | Numbered task list with scope, output path, DoD |
| 5 | [Execute Single Task](references/templates.md#prompt-5-execute-single-task-agent-context-packet) | Running one task from the plan (or spawning a sub-agent) | Self-contained context packet with all rules |
| 6 | [Coverage Matrix](references/templates.md#prompt-6-generate-coverage-matrix) | Tests generated, need a coverage report | Scenario-to-layer mapping with gap analysis |
| 7 | [Audit Test Suite](references/templates.md#prompt-7-review-or-audit-existing-test-suite) | Reviewing an existing test suite for issues | Orphaned, redundant, outdated, shallow, missing tests |
| 8 | [Dev Review of AI Tests](references/templates.md#prompt-8-dev-review-of-ai-generated-unit-tests) | Dev taking ownership of AI-generated tests | False positives, wrong mocks, missing assertions |
| 9 | [OpenAPI / Schema Validation](references/templates.md#prompt-9-openapi--schema-validation) | Validating API response contracts against specs | Schema tests, backward compatibility tests |

### Test PR Review

Conventions for writing and reviewing test PR descriptions, reviewer checklists, and approval guidelines.
See [references/pr-review.md](references/pr-review.md).

---

## See Also

- **qa-test-gen** — When generating actual test code for a specific layer (unit, integration, E2E)
- **qa-test-data** — When setting up factories, fixtures, or cleanup for generated tests
- **qa-pipeline** — When configuring CI stages to run the tests this workflow produces
- **qa-flaky** — When triaging or quarantining tests that fail intermittently after generation
