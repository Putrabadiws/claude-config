---
paths:
  - "**/*.go"
---

# Go Code Style (Auto-loaded for .go files)

## Formatting
- Use `gofmt` / `goimports`
- Tabs for indentation

## Naming
- Exported: `PascalCase`
- Unexported: `camelCase`
- Interfaces: `-er` suffix for single method
- Errors: `Err` prefix (`ErrNotFound`)

## Patterns
- Always check errors: `if err != nil { return fmt.Errorf("context: %w", err) }`
- Context as first parameter
- Constructor functions: `NewXxx()`

## DNS Resolver Specific (Aman)
- Redis key patterns: `dns-blocked:{domain}`, `trust-domain:{ulid}:{domain}`
- Use `slog` for structured logging
