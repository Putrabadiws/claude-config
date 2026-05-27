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

## Service Patterns
- Namespace Redis keys by entity, e.g. `<entity>:{id}:{field}`
- Use `slog` for structured logging
