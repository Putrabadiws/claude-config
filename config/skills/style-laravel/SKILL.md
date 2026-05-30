---
name: style-laravel
description: Laravel/PHP code style - controllers, models, requests, resources, services, validation.
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

## Directory Structure (DDD)

Organized by **bounded context / domain** instead of technical type — for larger apps
with rich business logic. Follows the Spatie "Laravel beyond CRUD" `Domain` + `App` split.

Map both namespaces in `composer.json` so they autoload from `src/`:

```json
"autoload": {
    "psr-4": {
        "App\\": "src/App/",
        "Domain\\": "src/Domain/",
        "Support\\": "src/Support/"
    }
}
```

```
src/
├── Domain/                     # Pure business logic — no HTTP, no framework glue
│   ├── Invoicing/              # One bounded context per folder
│   │   ├── Actions/            # Single-purpose use cases (CreateInvoiceAction)
│   │   ├── Models/             # Eloquent models for this domain
│   │   ├── Data/               # DTOs (spatie/laravel-data objects)
│   │   ├── Events/             # Domain events
│   │   ├── Listeners/
│   │   ├── Exceptions/         # Domain-specific exceptions
│   │   ├── QueryBuilders/      # Custom Eloquent query builders
│   │   ├── States/             # State machines (spatie/laravel-model-states)
│   │   ├── Rules/              # Validation rules owned by the domain
│   │   └── Enums/
│   └── Ordering/               # Another bounded context
│       └── ...
├── App/                        # Application layer — entry points into the domain
│   ├── Http/
│   │   ├── Controllers/        # Thin; call Domain Actions
│   │   ├── Requests/           # Form Requests
│   │   ├── Resources/          # API Resources
│   │   └── Middleware/
│   └── Console/                # Artisan commands
└── Support/                    # Cross-cutting helpers shared by all domains

database/                       # Stays at project root (migrations/factories/seeders)
routes/                         # Stays at project root
```

**Dependency rule**: `App` depends on `Domain`; `Domain` never depends on `App`.
Controllers/Requests/Resources stay in `App`; business rules live in `Domain`.
Keep `app/` empty (or delete it) once everything moves under `src/`.

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

## Artisan Scaffolding

```bash
php artisan make:model User -mfsc      # model + migration + factory + seeder + controller
php artisan make:request StoreUserRequest
php artisan make:resource UserResource
php artisan make:controller UserController --api
php artisan make:service UserService   # if a custom generator exists; else create manually
```
