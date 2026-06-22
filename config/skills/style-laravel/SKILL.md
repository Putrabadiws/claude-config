---
name: style-laravel
description: Laravel/PHP code style - controllers, models, requests, resources, services, actions, validation. Covers Standard and modular-monolith (Modules/) layouts.
user-invocable: false
---

<!-- Source: Laravel framework + PSR-12 defaults (not extracted from a Bangor repo).
     Reconcile against a real Laravel codebase once one exists. -->

# Laravel/PHP Style Guide

## Formatting

- **Standard**: PSR-12
- **Indentation**: 4 spaces
- **Line length**: soft 120 characters
- **Strict types**: `declare(strict_types=1);` at top of class files
- **Braces**: same line for control structures, next line for classes/methods (PSR-12)

```php
<?php

declare(strict_types=1);

namespace App\Http\Controllers;

class UserController extends Controller
{
    public function index(): JsonResponse
    {
        return UserResource::collection(User::paginate())->response();
    }
}
```

## Directory Structure (Standard)

Default Laravel layout — organized by technical type. Use for small/medium apps.

```
app/
├── Http/
│   ├── Controllers/        # Thin controllers (resource controllers)
│   ├── Requests/           # Form Request validation (StoreUserRequest)
│   ├── Resources/          # API Resources (UserResource)
│   └── Middleware/
├── Models/                 # Eloquent models (singular: User)
├── Services/               # Business logic
├── Actions/                # Single-purpose action classes (optional)
├── Jobs/                   # Queued jobs
├── Events/ Listeners/      # Domain events
└── Exceptions/             # Custom exceptions + Handler
database/
├── migrations/             # snake_case, plural tables
├── factories/              # Model factories
└── seeders/
routes/
├── web.php
└── api.php
```

## Directory Structure (Modular Monolith)

NestJS-inspired, **feature-first** layout — each business domain is a
self-contained module under `Modules/`. Use when the app has several distinct
domains that each own controllers, routes, models, and business logic, and you
want clear per-module ownership and self-registered routing.

```
Modules/
├── Product/
│   ├── Controllers/        # Thin; inject an Action, return a Resource
│   ├── Requests/           # Form Requests (StoreProductRequest)
│   ├── Resources/          # API Resources (ProductResource)
│   ├── Models/             # Modules\Product\Models\Product
│   ├── Actions/            # One use case per class (CreateProductAction)
│   ├── Services/           # Only when coordinating multiple Actions
│   ├── Policies/           # ProductPolicy
│   ├── Data/               # DTOs
│   ├── Enums/
│   ├── Routes/             # Per-module api.php / web.php
│   ├── Providers/          # ProductServiceProvider (registers routes/policies)
│   └── Tests/              # Per-module feature/unit tests
├── Sales/
└── Inventory/

database/                   # migrations/factories/seeders stay CENTRAL at root
routes/                     # global route files (modules load their own via providers)
```

**Migrations are central** — they live in root `database/migrations`, not per
module. Module providers do **not** call `loadMigrationsFrom`.

### PSR-4 wiring (hand-rolled)

No `nwidart/laravel-modules` — map the namespace yourself in `composer.json`:

```json
"autoload": {
    "psr-4": {
        "App\\": "app/",
        "Modules\\": "Modules/"
    }
}
```

There is **no provider auto-discovery** — register every module provider
explicitly in `bootstrap/providers.php` (Laravel 11+) or the `providers` array
in `config/app.php` (≤10):

```php
// bootstrap/providers.php
return [
    App\Providers\AppServiceProvider::class,
    Modules\Product\Providers\ProductServiceProvider::class,
    Modules\Sales\Providers\SalesServiceProvider::class,
];
```

Run `composer dump-autoload` after adding a module so the PSR-4 map picks it up.

### Module ServiceProvider

Each module wires its own routes and policies — the piece the Standard
layout doesn't need:

```php
<?php

declare(strict_types=1);

namespace Modules\Product\Providers;

use Illuminate\Support\Facades\Gate;
use Illuminate\Support\ServiceProvider;
use Modules\Product\Models\Product;
use Modules\Product\Policies\ProductPolicy;

class ProductServiceProvider extends ServiceProvider
{
    public function boot(): void
    {
        // Per-module routes; no loadMigrationsFrom — migrations stay central.
        $this->loadRoutesFrom(__DIR__ . '/../Routes/api.php');

        Gate::policy(Product::class, ProductPolicy::class);
    }
}
```

## Naming Conventions

```php
// Classes: PascalCase
class UserController {}
class OrderItem {}                  // Model: singular

// Form Requests: PascalCase + Request suffix
class StoreUserRequest {}
class UpdateUserRequest {}

// API Resources: PascalCase + Resource suffix
class UserResource {}

// Methods / variables: camelCase
public function findActiveUsers(): Collection {}
$activeUsers = ...;

// Constants: UPPER_SNAKE
public const DEFAULT_PER_PAGE = 20;

// DB tables: snake_case plural   -> users, order_items
// DB columns: snake_case         -> created_at, company_id
// Routes: kebab-case             -> /api/order-items
```

## Controller Pattern

Keep controllers thin — validate with a Form Request, delegate work to a service, return a Resource.

```php
<?php

declare(strict_types=1);

namespace App\Http\Controllers;

use App\Http\Controllers\Controller;
use App\Http\Requests\StoreUserRequest;
use App\Http\Resources\UserResource;
use App\Services\UserService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;

class UserController extends Controller
{
    public function __construct(private readonly UserService $userService)
    {
    }

    public function index(): AnonymousResourceCollection
    {
        return UserResource::collection($this->userService->paginate());
    }

    public function show(User $user): UserResource   // route model binding
    {
        return new UserResource($user);
    }

    public function store(StoreUserRequest $request): JsonResponse
    {
        $user = $this->userService->create($request->validated());

        return (new UserResource($user))
            ->response()
            ->setStatusCode(201);
    }
}
```

## Form Request (Validation)

```php
<?php

declare(strict_types=1);

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

class StoreUserRequest extends FormRequest
{
    public function authorize(): bool
    {
        return $this->user()->can('create', User::class);
    }

    /** @return array<string, mixed> */
    public function rules(): array
    {
        return [
            'name'  => ['required', 'string', 'max:255'],
            'email' => ['required', 'email', 'unique:users,email'],
            'role'  => ['required', 'string', 'in:admin,analyst,viewer'],
        ];
    }
}
```

## Service Pattern

Business logic lives in services, not controllers or models. Wrap multi-write operations in transactions.

```php
<?php

declare(strict_types=1);

namespace App\Services;

use App\Models\User;
use Illuminate\Contracts\Pagination\LengthAwarePaginator;
use Illuminate\Support\Facades\DB;

class UserService
{
    public function paginate(int $perPage = 20): LengthAwarePaginator
    {
        return User::query()
            ->with('roles')          // eager-load to avoid N+1
            ->latest()
            ->paginate($perPage);
    }

    /** @param array<string, mixed> $data */
    public function create(array $data): User
    {
        return DB::transaction(fn (): User => User::create($data));
    }
}
```

## Eloquent Model Pattern

```php
<?php

declare(strict_types=1);

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class User extends Model
{
    /** @var list<string> */
    protected $fillable = ['name', 'email', 'role'];

    /** @var list<string> */
    protected $hidden = ['password', 'remember_token'];

    /** @return array<string, string> */
    protected function casts(): array
    {
        return [
            'email_verified_at' => 'datetime',
            'is_active'         => 'boolean',
        ];
    }

    public function company(): BelongsTo
    {
        return $this->belongsTo(Company::class);
    }

    public function orders(): HasMany
    {
        return $this->hasMany(Order::class);
    }
}
```

Prefer `$fillable` (allowlist) over `$guarded = []`. Never mass-assign unfiltered request input.

## API Resource (Response Shape)

```php
<?php

declare(strict_types=1);

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class UserResource extends JsonResource
{
    /** @return array<string, mixed> */
    public function toArray(Request $request): array
    {
        return [
            'id'        => $this->id,
            'name'      => $this->name,
            'email'     => $this->email,
            'company'   => new CompanyResource($this->whenLoaded('company')),
            'createdAt' => $this->created_at,
        ];
    }
}
```

## Migration Pattern

```php
<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('users', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('company_id')->constrained()->cascadeOnDelete();
            $table->string('name');
            $table->string('email')->unique();
            $table->boolean('is_active')->default(true);
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('users');
    }
};
```

## Error Handling

- Throw domain exceptions; let Laravel's handler render them.
- Use `findOrFail` / route model binding for 404s instead of manual null checks.
- Register custom rendering in `bootstrap/app.php` (Laravel 11+) or `app/Exceptions/Handler.php` (≤10).

```php
// Custom exception
namespace App\Exceptions;

use Exception;

class UserNotActiveException extends Exception
{
    public function render(): JsonResponse
    {
        return response()->json(['message' => 'User is not active'], 422);
    }
}
```

## Testing

- Framework: Pest (preferred) or PHPUnit. Test files end in `Test.php`.
- Use `RefreshDatabase` for DB tests; model factories for data.
- Cover happy path + validation failures + auth/authorization edge cases.

```php
<?php

use App\Models\User;

it('creates a user', function (): void {
    $payload = ['name' => 'Jane', 'email' => 'jane@example.com', 'role' => 'admin'];

    $this->postJson('/api/users', $payload)
        ->assertCreated()
        ->assertJsonPath('data.email', 'jane@example.com');

    expect(User::where('email', 'jane@example.com')->exists())->toBeTrue();
});

it('rejects invalid email', function (): void {
    $this->postJson('/api/users', ['name' => 'Jane', 'email' => 'nope'])
        ->assertStatus(422)
        ->assertJsonValidationErrors(['email']);
});
```

## Modular Monolith Patterns

Applies to the `Modules/` layout above. In a modular monolith, **Actions are
the default** unit of business logic (not Services).

### Actions-first

One use case = one Action class with a single `execute()`. Reach for a Service
only when you need to coordinate multiple Actions; never create a Service for
plain CRUD.

```php
<?php

declare(strict_types=1);

namespace Modules\Product\Actions;

use Illuminate\Support\Facades\DB;
use Modules\Product\Models\Product;

class CreateProductAction
{
    /** @param array<string, mixed> $data */
    public function execute(array $data): Product
    {
        return DB::transaction(fn (): Product => Product::create($data));
    }
}
```

Controllers inject the Action and stay thin:

```php
public function store(StoreProductRequest $request, CreateProductAction $action): ProductResource
{
    return new ProductResource($action->execute($request->validated()));
}
```

### Module boundaries

A module must not reach into another module's Models or build queries against
them. Cross-module work goes through the **owning module's Action/Service**, so
each domain stays the single owner of its data.

```php
// ❌ Sales reaching directly into Inventory's internals
$item = InventoryItem::where('product_id', $id)->first();
$item->decrement('stock', $qty);

// ✅ Sales calls Inventory's Action
$adjustStock->execute($id, -$qty);   // Modules\Inventory\Actions\AdjustInventoryStockAction
```

### Repository pattern

Don't add repositories/interfaces by default — query Eloquent directly or wrap
it in an Action. Introduce a repository only on real need (multiple data
sources, an external API replacing the DB, genuinely complex query reuse).

## Artisan Scaffolding

There is no `module:make` (hand-rolled PSR-4). Create module files by hand or
generate into the default location and move them into the module, fixing the
namespace:

```bash
php artisan make:controller ProductController --api   # then move to Modules/Product/Controllers
php artisan make:request StoreProductRequest          # then move to Modules/Product/Requests
```

For the **Standard** layout:

```bash
php artisan make:model User -mfsc      # model + migration + factory + seeder + controller
php artisan make:request StoreUserRequest
php artisan make:resource UserResource
php artisan make:controller UserController --api
php artisan make:service UserService   # if a custom generator exists; else create manually
```
