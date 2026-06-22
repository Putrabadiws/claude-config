---
paths:
  - "**/*.tsx"
  - "**/*.jsx"
  - "**/*.ts"
  - "**/*.mts"
---

# React/TypeScript Style (Auto-loaded for .tsx/.jsx files)

> Quick reference only. For full patterns — component/hook structure, state management,
> testing, conditional rendering, forms, and `❌`/`✅` TypeScript examples — see the
> **`style-react`** skill. Stack-specific extensions: **`style-frontend-nextjs`**,
> **`style-frontend-vite`**, **`style-laravel-react`** (Inertia).

## Formatting
- Double quotes `"`
- 2-space indentation
- Semicolons required

## Naming
- Components: `PascalCase.tsx`
- Hooks: `useXxx.ts`
- Utils: `camelCase.ts`
- Event handlers: `handleXxx`

## Patterns
- Functional components with hooks
- Early returns for loading/error states
- `react-hook-form` for forms
- React Query for server state

## TypeScript Type Safety
- No `as any`, `as unknown as`, or `@ts-ignore`/`@ts-expect-error` to silence the compiler
- Define an `interface`/`type` for any unclear or repeated shape — no inline anonymous blobs
- Narrow with type guards (`typeof`, `in`, `instanceof`, custom `is` predicates), not casts
- Prefer `satisfies` over `as` to validate a value against a type without widening
- Data from external sources (API, `localStorage`, URL params) → parse with a validation library (zod/yup), don't trust + cast
- Each type reflects a real shape/contract; comment non-obvious ones with what they model and why

## Imports Order
1. React
2. Third-party (@mantine, @tabler)
3. Internal (@/)
4. Relative (./)

## Modular Structure (feature-first)
- Larger SPAs: organize by feature under `src/modules/<feature>/{components,hooks,api,store,types}` + `index.ts`
- Import another feature only through its `index.ts`, never a deep path
- Promote code to top-level `components/`/`hooks/` only once 2+ features share it
