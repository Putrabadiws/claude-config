---
paths:
  - "**/*.java"
---

# Java/Spring Code Style (Auto-loaded for .java files)

## Formatting
- 4-space indentation
- 120 char line length

## Naming
- Services: `XxxServices` (interface), `XxxServicesImpl` (impl)
- DTOs: `XxxRequestDTO`, `XxxResponseDTO`
- Controllers: `XxxController`

## Patterns
- Use `@RequiredArgsConstructor` for DI
- Pagination: 1-indexed in API, convert to 0-indexed for Spring Data
- Response: `MessageResponse`, `MessageResponseWithData<T>`

## Lombok
- `@Data`, `@Builder`, `@Slf4j`, `@RequiredArgsConstructor`
