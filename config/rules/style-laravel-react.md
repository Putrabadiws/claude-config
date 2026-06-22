---
paths:
  - "resources/js/**/*.tsx"
  - "resources/js/**/*.ts"
---

<!-- Laravel React (Inertia) starter kit. Covers both Laravel 12 (tag v1.0.0: Inertia 2,
     Ziggy, built-in auth) and Laravel 13 (main: Inertia 3, Wayfinder, Fortify). Check the
     project's composer.json to know which version applies. Generic starter-kit conventions,
     not extracted from a Bangor repo.
     Path-scoped to resources/js so it won't fire on src/-based SPA repos. NOTE: style-react.md
     (globs all .tsx) also loads here — the overrides below win for this stack. -->

# Laravel React Starter Kit Style (Inertia — auto-loaded under resources/js)

> **Overrides `style-react` for this stack.** Key differences from the SPA React guide:
> - Filenames are **kebab-case** (`app-layout.tsx`, `use-mobile.tsx`), not PascalCase
> - Data comes from **Inertia props + `useForm`** — no Axios, no React Query
> - Routing via **Wayfinder** (L13) or **Ziggy `route()`** (L12) — never hardcode URLs

## Filenames
- kebab-case for everything: components, hooks, pages, layouts (`nav-user.tsx`, `use-clipboard.ts`)
- Page components live in `resources/js/pages/`, resolved by Inertia name
  (`pages/dashboard.tsx` ← `Inertia::render('dashboard')`)

## Data
- Server data arrives as **page props** from controllers — type them, don't `any`
- Forms: `useForm` from `@inertiajs/react` (`data/setData/post/processing/errors`) — not react-hook-form/Axios
- Shared data (auth user, flash) via `usePage()`

## Routing (never hardcode paths)
- **L13**: import typed helpers from Wayfinder (`@/routes`, `@/actions/...`)
- **L12**: global Ziggy `route('name')` helper

## UI
- shadcn/ui primitives in `components/ui/` — compose, don't fork
- `cn()` from `@/lib/utils` for class merging; Tailwind 4 utilities; icons from `lucide-react`

## Imports
- `@/` alias → `resources/js/`

## Modular Structure (`resources/js/modules/`)
For apps on the backend modular monolith (`Modules/<X>` — see `style-laravel`):
- Group frontend per feature in `resources/js/modules/<x>/{pages,components,hooks}` + `index.ts`; backend module stays PHP-only
- Widen the Inertia resolver to also glob `./modules/*/pages`, with a `module::page` name convention so app pages keep short names
- Controllers render namespaced pages: `Inertia::render('product::index')`
- Cross-feature imports go through the feature's `index.ts`; shared UI/hooks stay top-level
