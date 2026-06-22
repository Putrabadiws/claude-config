---
name: style-laravel-react
description: Laravel React (Inertia) starter kit style - Inertia pages, useForm, Wayfinder/Ziggy routing, shadcn/ui, layouts. Covers Laravel 12 and 13 variants.
user-invocable: false
---

<!-- Source: laravel/react-starter-kit. Laravel 13 facts from `main`; Laravel 12 facts from
     tag v1.0.0. Generic starter-kit conventions, not extracted from a Bangor repo. -->

# Laravel React Starter Kit Style Guide (Inertia)

Builds on:
- **`style-laravel`** — backend (controllers, models, validation, migrations). Note: Inertia
  apps return **page props**, not API Resources/JSON, so skip the API-Resource parts.
- **`style-react`** — base React/TS conventions, **except** this stack overrides filenames to
  kebab-case and replaces Axios/React Query with Inertia. The TypeScript type-safety rules
  from `style-react` still fully apply.

This skill covers the **Inertia bridge** — how Laravel and React talk — and the two starter-kit
versions you'll encounter.

## Version Matrix

Always check `composer.json` (`laravel/framework`) to know which version a project is on.

| | Laravel 12 (`v1.0.0`) | Laravel 13 (`main`) |
|---|---|---|
| PHP | `^8.2` | `^8.3` |
| Inertia (PHP + JS) | 2.x | 3.x |
| Routing helper | **tightenco/ziggy** — global `route()` | **laravel/wayfinder** — typed imports |
| Auth | built-in auth controllers | **laravel/fortify** + 2FA + passkeys |
| Toasts | none by default | **sonner** + `use-flash-toast` |
| React Compiler | no | yes (babel plugin) |
| Vite | `^6` | `^8` |
| Tests | PHPUnit 11 | PHPUnit 12 |
| React / TS / Tailwind | 19 / 5.7 / 4 | 19 / 5.7 / 4 |
| Lint | Pint + ESLint + Prettier | + `lint:check`, `types:check` scripts |

Shared across both: kebab-case filenames, `resources/js` layout, Inertia pages, `useForm`,
shadcn/ui + Radix, Tailwind 4, Vite, `@/` → `resources/js`.

## Directory Structure

```
resources/js/
├── app.tsx                 # Inertia entry — createInertiaApp, resolves pages/*
├── ssr.tsx                 # SSR entry (build:ssr)
├── pages/                  # Inertia pages, resolved BY NAME (no router file)
│   ├── dashboard.tsx       #   ← Inertia::render('dashboard')
│   ├── welcome.tsx
│   ├── auth/login.tsx ...
│   └── settings/profile.tsx
├── components/             # App components (kebab-case): nav-user.tsx, app-sidebar.tsx
│   └── ui/                 # shadcn/ui primitives: button.tsx, dialog.tsx, input.tsx ...
├── layouts/                # app-layout.tsx, auth-layout.tsx
│   ├── app/                #   app-sidebar-layout.tsx, app-header-layout.tsx
│   ├── auth/               #   auth-split-layout.tsx, auth-card-layout.tsx ...
│   └── settings/layout.tsx
├── hooks/                  # use-appearance.tsx, use-mobile.tsx, use-clipboard.ts ...
├── lib/utils.ts            # cn() class-merge helper
└── types/                  # shared types: index.ts (SharedData/PageProps), global.d.ts

routes/                     # web.php, settings.php, console.php  (auth.php on L13/Fortify)
app/Http/
├── Controllers/            # return Inertia::render(...)
└── Middleware/HandleInertiaRequests.php   # shares auth/flash/ziggy with every page
```

## Modular Structure (`resources/js/modules/`)

For apps on the backend **modular monolith** (`Modules/<Domain>/` — see the
`style-laravel` skill), group the matching frontend per feature under
`resources/js/modules/`. The backend module stays **PHP-only**; the frontend
lives centrally here, not co-located inside `Modules/`.

```
resources/js/
├── pages/                      # App-level Inertia pages (dashboard, welcome, auth/*)
├── modules/
│   ├── product/
│   │   ├── pages/              # Inertia pages for this feature
│   │   │   └── index.tsx       #   ← Inertia::render('product::index')
│   │   ├── components/         # Feature-only components
│   │   ├── hooks/              # Feature-only hooks
│   │   └── index.ts            # Public surface — cross-feature imports go here only
│   └── sales/
├── components/                 # Shared/global components (+ ui/ shadcn primitives)
├── layouts/  hooks/  lib/  types/
```

Widen the Inertia resolver to scan both roots, with a `module::page` name
convention so app-level pages keep their short names:

```ts
// resources/js/app.tsx
const pages = {
  ...import.meta.glob("./pages/**/*.tsx"),
  ...import.meta.glob("./modules/*/pages/**/*.tsx"),
};

createInertiaApp({
  // "product::index" → ./modules/product/pages/index.tsx
  // "dashboard"      → ./pages/dashboard.tsx  (unchanged)
  resolve: (name) => {
    const path = name.includes("::")
      ? `./modules/${name.replace("::", "/pages/")}.tsx`
      : `./pages/${name}.tsx`;
    return resolvePageComponent(path, pages);
  },
  // ...
});
```

```php
// Modules\Product\Controllers\ProductController — render the namespaced page
return Inertia::render('product::index', [
    'products' => ProductResource::collection($products),
]);
```

**Boundaries**: a feature imports another feature only through its `index.ts`,
never a deep path — mirrors the backend module-boundary rule. Truly shared
UI/hooks stay in top-level `components/` / `hooks/`.

## Naming

**kebab-case for every file** — components, hooks, pages, layouts. This is the starter kit's
convention and **overrides `style-react`'s PascalCase file rule** for this stack.

```
app-sidebar.tsx      nav-user.tsx       use-mobile.tsx      pages/settings/profile.tsx
```

The exported component is still PascalCase; only the filename is kebab-case.

```tsx
// resources/js/components/nav-user.tsx
export function NavUser() { /* ... */ }
```

## Inertia Page Pattern

Controllers render a page by name and pass props. No JSON, no API Resource, no client fetch.

```php
// app/Http/Controllers/Settings/ProfileController.php
use Inertia\Inertia;
use Inertia\Response;

public function edit(Request $request): Response
{
    return Inertia::render('settings/profile', [
        'mustVerifyEmail' => $request->user() instanceof MustVerifyEmail,
        'status'          => $request->session()->get('status'),
    ]);
}
```

```tsx
// resources/js/pages/settings/profile.tsx — props match what the controller passed
import { Head, useForm, usePage } from "@inertiajs/react";
import AppLayout from "@/layouts/app-layout";
import type { SharedData } from "@/types";

interface ProfileProps {
  mustVerifyEmail: boolean;
  status?: string;
}

export default function Profile({ mustVerifyEmail, status }: ProfileProps) {
  const { auth } = usePage<SharedData>().props; // shared data (every page)

  const { data, setData, patch, processing, errors } = useForm({
    name: auth.user.name,
    email: auth.user.email,
  });

  const submit = (e: React.FormEvent) => {
    e.preventDefault();
    patch("/settings/profile"); // L13: patch(ProfileController.update().url) via Wayfinder
  };

  return (
    <AppLayout>
      <Head title="Profile" />
      <form onSubmit={submit}>
        <input value={data.name} onChange={(e) => setData("name", e.target.value)} />
        {errors.name && <p className="text-red-600">{errors.name}</p>}
        <button disabled={processing}>Save</button>
      </form>
    </AppLayout>
  );
}
```

## Forms — `useForm` (not react-hook-form/Axios)

`useForm` owns the form state, submits via Inertia, and surfaces server-side validation errors
straight back into `errors` (keyed by field) after a failed request. No manual error wiring.

```tsx
const { data, setData, post, processing, errors, reset } = useForm({ email: "", password: "" });

post("/login", { onFinish: () => reset("password") });
// errors.email / errors.password are populated from Laravel's validator on 422
```

Server side stays as standard `style-laravel` Form Requests — validation failures redirect back
with errors, which Inertia maps into `errors`.

## Routing — typed, never hardcoded

```tsx
// ── Laravel 13: Wayfinder generates typed helpers from your routes/controllers
import { Link } from "@inertiajs/react";
import { dashboard } from "@/routes";
import ProfileController from "@/actions/App/Http/Controllers/Settings/ProfileController";

<Link href={dashboard()}>Dashboard</Link>;
form.patch(ProfileController.update().url);

// ── Laravel 12: Ziggy global route() helper (types in resources/js/types/global.d.ts)
<Link href={route("dashboard")}>Dashboard</Link>;
form.post(route("login"));
```

Programmatic navigation: `router.visit(...)` / `router.post(...)` from `@inertiajs/react`,
fed the same typed helper, never a string literal.

## Layouts

Layouts wrap pages; nested under `layouts/{app,auth,settings}`. Two ways to apply:

```tsx
// Inline (most pages in this kit)
return <AppLayout breadcrumbs={breadcrumbs}><Head title="..." /> ... </AppLayout>;

// Persistent layout — survives Inertia visits without remounting (preserves scroll/state)
Dashboard.layout = (page: React.ReactNode) => <AppLayout>{page}</AppLayout>;
```

## shadcn/ui + Tailwind 4

- Primitives live in `components/ui/` (generated by the shadcn CLI). **Compose them; don't fork.**
- Merge classes with `cn()` from `@/lib/utils`; variants with `class-variance-authority`.
- Tailwind 4 (CSS-first config in `resources/css/app.css`, no `tailwind.config.js` by default).
- Icons: `lucide-react`. Toasts (L13): `sonner` via `use-flash-toast`.

```tsx
import { cn } from "@/lib/utils";
import { Button } from "@/components/ui/button";

<Button className={cn("w-full", isActive && "ring-2")} variant="outline">Save</Button>;
```

## Shared Data & Flash

`HandleInertiaRequests::share()` injects data into every page — read it with `usePage()`.

```php
// app/Http/Middleware/HandleInertiaRequests.php
public function share(Request $request): array
{
    return [
        ...parent::share($request),
        'auth'  => ['user' => $request->user()],
        'flash' => ['success' => fn () => $request->session()->get('success')],
        // L12 also shares 'ziggy' => fn () => [...] for the route() helper
    ];
}
```

```tsx
const { auth, flash } = usePage<SharedData>().props;
// L13: use-flash-toast subscribes to flash and fires a sonner toast automatically
```

## Auth

- **L13**: `laravel/fortify` drives login/registration/password/email-verification, plus
  two-factor (`two-factor-challenge.tsx`, `manage-two-factor.tsx`) and passkeys
  (`passkey-*.tsx`, `input-otp`). Don't hand-roll auth controllers — configure Fortify.
- **L12**: plain auth controllers under `app/Http/Controllers/Auth` with matching
  `pages/auth/*.tsx`. No 2FA/passkeys out of the box.

## Testing

PHPUnit feature tests with Inertia assertions — assert the component name and props, not HTML.

```php
use Inertia\Testing\AssertableInertia as Assert;

$this->actingAs($user)
    ->get('/settings/profile')
    ->assertInertia(fn (Assert $page) => $page
        ->component('settings/profile')
        ->has('mustVerifyEmail')
    );
```

Frontend gates: `npm run types:check` + `npm run lint` (L13 also has `lint:check`). PHP:
`vendor/bin/pint`. Test files end in `Test.php`.

## Tooling / Scripts

```bash
composer dev          # concurrent: php serve + queue + pail logs + vite
composer test         # PHPUnit
vendor/bin/pint       # PHP formatter

npm run dev           # vite dev server
npm run build         # production build  (build:ssr for SSR)
npm run lint          # eslint --fix
npm run format        # prettier --write resources/
npm run types:check   # tsc --noEmit  (L13)
```
