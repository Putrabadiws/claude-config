# Convention Doc Format

When generating or updating convention docs — any doc that defines standards, rules, or best practices, regardless of location.

## Structure

1. **Context** — explain what this doc governs: how it works, its structure, key mechanisms, etc. Keep it concise and focused — only what's needed to understand and apply the rules.
2. **Standard and Rules** — the main section. Explain each rule clearly enough to be actionable — what to avoid, what to do instead, and why. Use code examples where the correct pattern isn't obvious from the description alone. End every rule with an explicit severity line.

Additional sections are allowed when genuinely needed (e.g. examples, exceptions, migration notes). Keep them as tight as the rules section.

## Severity Marking

Every rule must be clearly marked as blocker or optional — no ambiguity.

- **Blocker** — must fix before merge. Mark explicitly: `is a **blocker** — must fix before merge`
- **Optional** — recommended but not blocking. Close with: `Not a blocker — approve with comment suggesting [what to suggest].`

## Rules for Writing Rules

### Explain before prescribing

Write a short prose explanation of what the rule prevents and why, before stating what to do instead.

### Use code examples for non-obvious rules

Include `// ❌ Wrong` and `// ✅ Correct` blocks when the correct pattern isn't immediately obvious from the prose. Skip examples for rules that are self-evident from the description alone.

### Do not invent rules

Only document rules that are explicitly agreed by the team or clearly reflected in existing codebase patterns. Do not add rules derived from personal preference.
