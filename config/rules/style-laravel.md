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

## Modular Monolith (`Modules/`)
Applies to feature-first apps using the `Modules/<Domain>/` layout (see skill for the full tree).
- One module per domain; per-module `Controllers/ Requests/ Resources/ Models/ Actions/ Services/ Policies/ Data/ Enums/ Routes/ Providers/ Tests/`
- Migrations/factories/seeders stay **central** in root `database/` — not per module
- Hand-rolled PSR-4: `"Modules\\": "Modules/"` in `composer.json`; register each module provider explicitly in `bootstrap/providers.php` (no auto-discovery)
- Module `ServiceProvider` loads its own routes (`loadRoutesFrom`) + policies; does **not** `loadMigrationsFrom`
- **Actions-first**: one use case = one `execute()`; Service only to coordinate multiple Actions, never for plain CRUD
- Module boundaries: cross-module work goes through the owning module's Action/Service — never query another module's Models directly

## Artisan
- Scaffold with `php artisan make:*` (`make:controller`, `make:model -mfsc`, `make:request`, `make:resource`)
- Modular: no `module:make` — generate then move into the module and fix the namespace; `composer dump-autoload` after adding a module
