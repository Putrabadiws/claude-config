# Agent Context Packet Format

Each agent receives a fully self-contained packet. No cross-references.

```markdown
# Agent Task: [Task Name]

## Your Role
[senior QA engineer / SDET / backend dev] — complete this independently.

## Feature Context
[Full description — do not abbreviate]

## Source Code
[Paste full relevant code]

## Confirmed Scenarios
[Full Gherkin — do not reference "scenarios above"]

## Confirmed Edge Cases
Q1: [question] → A: [answer]
Q2: [question] → A: [answer — or: unanswered, skip and flag]

## Your Task
[Exactly what to generate — file path, layer, functions/endpoints]

## Tech Stack
Language / Framework / Mock library / Test runner

## Rules
- Write every test completely — no placeholders
- One assertion focus per unit test
- Mock all external I/O
- Naming: follow conventions for the target layer (see qa-test-gen skill)
- Tests are independent and can run in any order

## Definition of Done
- [ ] Every function/endpoint listed has coverage
- [ ] Every confirmed edge case has a test
- [ ] All mocks explicitly defined
- [ ] No placeholder comments remain
- [ ] Test data uses factory pattern, cleanup included
```
