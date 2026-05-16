---
paths:
  - "**/*.tsx"
  - "**/*.jsx"
---

# React/TypeScript Style (Auto-loaded for .tsx/.jsx files)

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

## Imports Order
1. React
2. Third-party (@mantine, @tabler)
3. Internal (@/)
4. Relative (./)
