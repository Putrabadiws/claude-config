---
name: qa-scenario
description: >
  Generate manual test scenarios in a structured spreadsheet-style format. Produces test cases
  with numbered steps, expected results, positive/negative types, device targets, and role assignments.
  Output as Markdown file (.md) with structured tables per test case.
  Triggers: "test scenario", "manual test", "scenario xlsx", "scenario spreadsheet",
  "generate scenario", "test case xlsx", "manual QA scenario".
---

# Manual Test Scenario Generator (XLSX Format)

Generates test scenarios in a standard spreadsheet format that maps cleanly to xlsx columns.

## Spreadsheet Column Structure

| Col | Header | Description | Rules |
|-----|--------|-------------|-------|
| A | NUMBER SCENARIO | Scenario group number | Sequential integer per feature/menu. Only on first row of each scenario group. |
| B | SCENARIO | Feature/menu name | UPPERCASE. Only on first row of each scenario group. E.g. `LOGIN`, `SMART DASHBOARD`, `ALERT`. |
| C | NO CASE | Test case ID | Format: `TC###` (e.g. `TC001`). Only on first row of each test case. Sequential within the sheet. |
| D | CASE | Test case name | Short description with optional newline for detail. Only on first row of each test case. E.g. `Login Fail\n(Without Input Email & Password)` |
| E | TYPE | Test type | `POSITIVE` or `NEGATIVE`. Only on first row of each test case. |
| F | STEP | Step number | Sequential integer starting from 1 per test case. Present on every row. |
| G | (step description) | What to do | Action description. Present on every row. E.g. `Navigate to Login Page`, `Click Button Login` |
| H | EXPECTED RESULT | Expected outcome | Only on first row of each test case. Describes the final expected state after all steps. |
| I | STATUS | Execution status | `PASS`, `FAIL`, or empty. Filled during test execution, leave empty when generating. |
| J | NOTE | Tester notes | Optional. Leave empty when generating. |
| K | TARGET DEVICE | Device scope | `DESKTOP`, `MOBILE`, `TABLET`, or combinations like `DESKTOP, MOBILE AND TABLET`. Only on first row of each test case. |
| L | ROLE | User role | E.g. `ANALYST OR SUPERVISOR`, `SUPERVISOR`, `ADMIN`. Only on first row of each test case. |
| M | PASS | Pass/fail result | `PASS`, `FAIL`, `N/A`, or empty. Filled during execution, leave empty when generating. |

## Row Layout Rules

Each test case spans multiple rows:
- **First row**: Contains cols A-H, K-L (case metadata + first step)
- **Subsequent rows**: Only cols F-G (step number + step description)
- Blank row separates scenario groups (different NUMBER SCENARIO values)

Example structure for one test case:
```
1 | LOGIN | TC001 | Login Fail\n(Without Input Email) | NEGATIVE | 1 | Navigate to Login Page       | Incorrect Email... | | | DESKTOP, MOBILE AND TABLET | ANALYST OR SUPERVISOR |
  |       |       |                                    |          | 2 | Don't input Email            |                    | | |                             |                      |
  |       |       |                                    |          | 3 | Input Password               |                    | | |                             |                      |
  |       |       |                                    |          | 4 | Click Button Login           |                    | | |                             |                      |
```

## Step Description Patterns

Follow these established patterns for step descriptions:

| Action | Pattern | Examples |
|--------|---------|----------|
| Navigation | `Click Menu [MenuName]` | `Click Menu Dashboard`, `Click Menu Alert` |
| Sub-navigation | `Click Menu [SubMenuName]` or `Click Tab [TabName]` | `Click Menu Smart Dashboard`, `Click Tab Custom Range` |
| Button click | `Click Button [ButtonName]` | `Click Button Login`, `Click Button Apply`, `Click Button Create` |
| Icon click | `Click Icon [IconName]` | `Click Icon Calendar`, `Click Icon Edit`, `Click Icon Delete` |
| Input field | `Input [FieldName]` | `Input Username or Email`, `Input Password`, `Input Case Name *` |
| Skip input | `Don't input [FieldName]` | `Don't input Email`, `Don't input Password` |
| Select | `Select [Option/Field]` | `Select Priority *`, `Select Assignee *`, `Select Start Date` |
| Scroll | `Scroll down to [Element]` | `Scroll down to table Latest Alert` |
| Expand | `Expand Page` or `Expand [Element]` | `Expand Page`, `Expand Alert Detail` |
| Verify | `Make sure [condition]` | `Make sure the case is created successfully` |
| Toggle | `Toggle [Element]` | `Toggle Dark Mode`, `Toggle Notification` |
| Search | `Search [keyword/field]` | `Search by keyword`, `Search Alert Name` |
| Filter | `Filter By [FilterType]` | `Filter By Calendar`, `Filter By Status` |
| Upload | `Upload [FileType]` | `Upload File Attachment`, `Upload CSV` |
| Wait | `Wait for [condition]` | `Wait for page to load`, `Wait for data to appear` |

## Test Case Naming Patterns

| Type | Pattern | Examples |
|------|---------|----------|
| Positive - CRUD | `[Action] [Object]` | `Create Case`, `Edit Alert`, `Delete User` |
| Positive - Feature | `[Feature] [Detail]` | `Filter By Calendar`, `Export PDF Report` |
| Negative - Missing input | `[Action] Fail\n(Without Input [Field])` | `Login Fail\n(Without Input Email & Password)` |
| Negative - Invalid input | `[Action] Fail\n(Input [InvalidCondition])` | `Login Fail\n(Input Non-registered Email & Password)` |
| Negative - Wrong data | `[Action] Fail\n([WrongCondition])` | `Create Case Fail\n(Empty Required Field)` |
| Positive - View/Display | `View [Object]` or `Display [Object]` | `View Alert Detail`, `Display Chart` |
| Positive - with context | `[Action]\n([Context])` | `Create Case\n(Table Latest Alert)`, `Filter By Calendar\nCustom Ranges\n(Last Range - Minutes)` |

## Expected Result Patterns

| Category | Pattern | Examples |
|----------|---------|----------|
| Success action | `You've successfully [action]` | `You've successfully created the case` |
| Display result | `Display the desired [result]` | `Display the desired filter result` |
| Error message | `[Exact error text]` | `Incorrect Email Address or Password. Please try again` |
| Navigation | `[Page/Section] is displayed` | `Login Page is displayed`, `Dashboard is displayed` |
| Combined | `[Result1] and [Result2]` | `You've successfully created the case and Make sure the case is created successfully` |
| Data validation | `Data is [state]` | `Data is updated successfully`, `Data is deleted` |

## Generation Workflow

### Step 1: Gather Context
When the user requests test scenarios, ask for:
1. **Platform / product**: Which product or app
2. **Feature/Menu**: Which module or page (e.g. Alert, Case Management, User Management)
3. **Starting TC number**: To continue numbering from existing scenarios (ask or check existing file)
4. **Starting SCENARIO number**: Same as above for scenario group numbering
5. **Roles to cover**: Which user roles (Analyst, Supervisor, Admin, etc.)
6. **Device targets**: Desktop only, or Desktop + Mobile + Tablet
7. **Existing UI**: Any screenshots, Figma links, or UI descriptions to reference

### Step 2: Identify Test Cases
For each feature, generate cases covering:

**Positive cases (functional):**
- Happy path (all required fields, valid data)
- CRUD operations (Create, Read, Update, Delete)
- Filter/Search/Sort operations
- Navigation and page display
- Export/Download operations
- Pagination (if applicable)

**Negative cases (validation):**
- Empty required fields (each field individually + all empty)
- Invalid input formats (wrong email, special chars, etc.)
- Boundary values (max length, min value, etc.)
- Unauthorized access (wrong role)
- Duplicate data (if applicable)

**Edge cases:**
- Concurrent operations
- Large data sets
- Special characters in input
- Session timeout during action

### Step 3: Output Format

Output as a **Markdown (.md) file** written to a path agreed with the user (e.g. `docs/test-scenarios/[platform]-[feature].md`).

The file uses the structure defined below in "Markdown Output Structure".

### Step 4: Summary Table

At the end of the file, include a summary table:

```markdown
## Summary

| Scenario | Total Cases | Positive | Negative |
|----------|-------------|----------|----------|
| LOGIN    | 6           | 1        | 5        |
```

## Output Rules

1. **Markdown file** — one `.md` file per feature or per scenario group
2. **Leave STATUS, NOTE, PASS columns empty** — those are for test execution
3. **TC numbers must be sequential** across the entire file, not per scenario
4. **SCENARIO numbers** are sequential per feature group
5. **Every test case must have at least 2 steps** — navigate to page + perform action
6. **First step is always navigation** — `Navigate to [Page]` or `Click Menu [MenuName]`
7. **Last step of negative cases** should be the action that triggers the error
8. **Expected result uses exact UI text** when known, otherwise descriptive pattern
9. **Asterisk (*) marks required fields** in step descriptions — `Input Case Name *`
10. **File naming**: `[PRODUCT]-[FEATURE]-test-scenarios.md` in lowercase kebab-case (e.g. `myapp-login-test-scenarios.md`)

## Markdown Output Structure

Each scenario group is an H2 heading. Each test case is an H3 with a metadata table and a steps table.

````markdown
# Test Scenarios: [Product] — [Feature]

> **Product:** <product name>
> **Generated:** YYYY-MM-DD
> **Starting TC:** TC###
> **Total Cases:** N

---

## 1. SCENARIO NAME

### TC001 — Case Name (NEGATIVE)

| Field | Value |
|-------|-------|
| **Type** | NEGATIVE |
| **Expected Result** | Incorrect Email Address or Password. Please try again |
| **Target Device** | DESKTOP, MOBILE AND TABLET |
| **Role** | ANALYST OR SUPERVISOR |
| **Status** | |
| **Note** | |
| **Pass** | |

**Steps:**

| # | Step |
|---|------|
| 1 | Navigate to Login Page |
| 2 | Don't input Email |
| 3 | Don't input Password |
| 4 | Click Button Login |

---

### TC002 — Login Fail (Without Input Password) (NEGATIVE)

| Field | Value |
|-------|-------|
| **Type** | NEGATIVE |
| **Expected Result** | Incorrect Email Address or Password. Please try again |
| **Target Device** | DESKTOP, MOBILE AND TABLET |
| **Role** | ANALYST OR SUPERVISOR |
| **Status** | |
| **Note** | |
| **Pass** | |

**Steps:**

| # | Step |
|---|------|
| 1 | Navigate to Login Page |
| 2 | Input Username or Email |
| 3 | Don't input Password |
| 4 | Click Button Login |

---

### TC003 — Login Success (POSITIVE)

| Field | Value |
|-------|-------|
| **Type** | POSITIVE |
| **Expected Result** | Login Success |
| **Target Device** | DESKTOP, MOBILE AND TABLET |
| **Role** | ANALYST OR SUPERVISOR |
| **Status** | |
| **Note** | |
| **Pass** | |

**Steps:**

| # | Step |
|---|------|
| 1 | Navigate to Login Page |
| 2 | Input Username or Email |
| 3 | Input Password |
| 4 | Click Button Login |

---

## Summary

| Scenario | Total Cases | Positive | Negative |
|----------|-------------|----------|----------|
| LOGIN    | 3           | 1        | 2        |
````

## Example: Complete Markdown Output

See the full example in the "Markdown Output Structure" section above. The output file contains:
1. **Header** with platform, date, starting TC, total cases
2. **H2 per scenario group** (numbered: `## 1. LOGIN`)
3. **H3 per test case** with TC ID, case name, and type in heading (`### TC001 — Login Fail (NEGATIVE)`)
4. **Metadata table** — Type, Expected Result, Target Device, Role, Status, Note, Pass
5. **Steps table** — numbered steps with action descriptions
6. **Horizontal rule** (`---`) between test cases
7. **Summary table** at the end

## Integration with qa-workflow

This skill generates **manual test scenarios** (spreadsheet format). For **automated test code**, use:
- `qa-workflow` — full automated test workflow orchestration
- `qa-test-gen` — automated test code generation by layer
- `qa-prompts` — prompt templates for automated test planning

Manual scenarios from this skill can inform automated test generation — the TC IDs and case descriptions serve as traceability links between manual and automated tests.
