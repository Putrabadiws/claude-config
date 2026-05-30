---
paths:
  - "**/*.php"
---

<!-- Source: Laravel framework + PSR-12 defaults (not extracted from a Bangor repo).
     Reconcile against a real Laravel codebase once one exists. -->

# Laravel/PHP Code Style (Auto-loaded for .php files)

## Formatting
- PSR-12 compliant
- 4-space indentation
- Soft 120 char line length
- `declare(strict_types=1);` at top of class files

## Naming
- Controllers: `XxxController` (singular resource)
- Models: singular PascalCase (`User`, `OrderItem`)
- Form Requests: `XxxRequest` (`StoreUserRequest`, `UpdateUserRequest`)
- API Resources: `XxxResource`
- Migrations/columns: snake_case, plural table names
- Methods/variables: camelCase

## Patterns
- Thin controllers; push business logic into services or actions
- Validate via Form Requests, never inline `$request->validate()` in fat controllers
- Return API Resources for responses, not raw models/arrays
- Use route model binding instead of manual `findOrFail`
- Constructor dependency injection over facades in classes
- Eager-load relations to avoid N+1 (`with()`)

## Artisan
- Scaffold with `php artisan make:*` (`make:controller`, `make:model -mfsc`, `make:request`, `make:resource`)
