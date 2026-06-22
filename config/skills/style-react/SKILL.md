---
name: style-react
description: React/TypeScript code style - components, hooks, Mantine, testing patterns.
user-invocable: false
---

# React/TypeScript Style Guide

## Formatting (Prettier)

```json
{
  "singleQuote": false,
  "tabWidth": 2,
  "semi": true,
  "printWidth": 120,
  "bracketSameLine": false
}
```

**Key rules:**
- Double quotes `"` for strings
- 2-space indentation
- Semicolons required
- 100 char line width

## ESLint Rules

```javascript
// Enforced
"jsx-quotes": [2, "prefer-double"],     // <div className="foo">
"quotes": [2, "double"],                 // const x = "value"
"no-console": ["error", { allow: ["warn", "error", "info"] }]

// Disabled
"react/prop-types": "off",              // PropTypes not required
"max-len": 0,                           // No line length limit
"react/react-in-jsx-scope": "off",      // React 17+ auto-import
```

## Component Structure

```
ComponentName/
├── ComponentName.jsx       # Main component
├── ComponentName.module.css # Scoped styles (optional)
├── __tests__/
│   └── ComponentName.test.jsx
└── index.js               # Re-export (optional)
```

## Modular Structure (feature-first)

For larger SPAs, organize by **feature** under `src/modules/` instead of
scattering everything across global folders. Each module owns its slice of the
app and exposes a public surface via `index.ts`.

```
src/
├── modules/
│   ├── product/
│   │   ├── components/      # Feature components
│   │   ├── hooks/           # Feature hooks (useProducts)
│   │   ├── api/             # API calls / service hooks
│   │   ├── store/           # State slice (Redux) — optional
│   │   ├── types/           # Feature types
│   │   └── index.ts         # Public surface — cross-feature imports go here only
│   └── sales/
├── components/              # Shared/global components only
├── hooks/                   # Shared hooks
├── store/                   # Root store wiring (combines module slices)
└── lib/                     # utils
```

**Boundaries**: import another feature only through its `index.ts`, never a deep
path (`modules/sales/internal/...`). Code shared by 2+ features graduates to
top-level `components/` / `hooks/`; until then it stays in its owning module.

## Component Pattern

```jsx
import { useState, useEffect } from "react";
import styles from "./Alert.module.css";

const Alert = ({ id, severity, onDismiss }) => {
  const [visible, setVisible] = useState(true);

  useEffect(() => {
    // Effect logic
  }, [id]);

  const handleDismiss = () => {
    setVisible(false);
    onDismiss?.(id);
  };

  if (!visible) return null;

  return (
    <div className={styles.alert} data-severity={severity}>
      <span>Alert content</span>
      <button onClick={handleDismiss}>Dismiss</button>
    </div>
  );
};

export default Alert;
```

## Hooks Pattern

```jsx
// Custom hook
const useAlerts = (companyId) => {
  const [alerts, setAlerts] = useState([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);

  const fetchAlerts = async () => {
    setLoading(true);
    try {
      const data = await alertService.getAll(companyId);
      setAlerts(data);
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchAlerts();
  }, [companyId]);

  return { alerts, loading, error, refetch: fetchAlerts };
};
```

## Imports Order

```jsx
// 1. React
import { useState, useEffect } from "react";

// 2. Third-party libraries
import { Button, Modal } from "@mantine/core";
import { IconAlert } from "@tabler/icons-react";

// 3. Internal absolute imports (@/)
import { useAxios } from "@/hooks/useAxios";
import { AlertService } from "@/api/alertService";

// 4. Relative imports
import styles from "./Alert.module.css";
import { formatDate } from "./utils";
```

## Naming Conventions

```jsx
// Components: PascalCase
const AlertList = () => {};
const UserProfile = () => {};

// Hooks: camelCase with 'use' prefix
const useAlerts = () => {};
const useAuth = () => {};

// Event handlers: handle + Event
const handleClick = () => {};
const handleSubmit = () => {};

// Boolean props: is/has/should prefix
<Alert isVisible={true} hasError={false} />

// Files: PascalCase for components, camelCase for utils
AlertList.jsx
useAlerts.js
formatDate.js
```

## TypeScript Type Safety

Applies to all `.ts`/`.tsx` (also enforced by the auto-loaded `style-react` rule).

### 1. No escape hatches

Never silence the type checker. `as any` / `as unknown as` / `@ts-ignore` hide real bugs
and rot silently when the underlying shape changes.

```typescript
// ❌ Wrong — casts away safety, breaks at runtime when shape differs
const user = res.data as any;
const id = (payload as unknown as { id: string }).id;
// @ts-ignore
widget.render();

// ✅ Correct — model the shape, let the compiler check it
interface User { id: string; name: string; }
const user: User = res.data;
```

If a third-party type is genuinely wrong, fix it with module augmentation or a typed wrapper —
not `@ts-ignore`. Use `@ts-expect-error` with a one-line reason only as a last resort.

### 2. Define types for unclear shapes

Any non-trivial or repeated shape gets a named `interface`/`type`. No inline anonymous blobs
that have to be re-read at every call site.

```typescript
// ❌ Wrong
function send(payload: { to: string; body: string; meta: { retries: number } }) {}

// ✅ Correct
interface Message { to: string; body: string; meta: { retries: number }; }
function send(payload: Message) {}
```

### 3. Narrow with type guards, not casts

For runtime checks, narrow the type — `typeof`, `in`, `instanceof`, or a custom `is` predicate.
The cast lies; the guard actually checks.

```typescript
// ❌ Wrong
const msg = (err as ApiError).message;

// ✅ Correct — custom type guard narrows safely
function isApiError(e: unknown): e is ApiError {
  return typeof e === "object" && e !== null && "message" in e;
}
if (isApiError(err)) console.error(err.message); // err is ApiError here
```

### 4. Prefer `satisfies` over `as` for validation

`satisfies` checks a value against a type **without widening** it — you keep the precise literal
type and still get the constraint enforced. `as` just asserts and can mask mismatches.

```typescript
// ❌ Wrong — `as` hides a missing/typo'd key, widens the type
const routes = { home: "/", profile: "/profile" } as Record<Page, string>;

// ✅ Correct — `satisfies` errors on a missing Page, keeps literal keys
const routes = { home: "/", profile: "/profile" } satisfies Record<Page, string>;
routes.home; // type is "/", not string
```

### 5. Validate data from external sources

Anything crossing a trust boundary — API responses, `localStorage`, URL/query params, env,
`postMessage` — is `unknown` at runtime. Parse it with a schema (zod/yup), don't trust-and-cast.

```typescript
// ❌ Wrong — compiles, but a malformed response blows up downstream
const data = (await res.json()) as AgentResponse;

// ✅ Correct — zod parses + validates, throws on bad shape, infers the type
import { z } from "zod";
const AgentResponseSchema = z.object({
  success: z.boolean(),
  data: z.array(z.object({ id: z.string(), name: z.string() })),
});
type AgentResponse = z.infer<typeof AgentResponseSchema>;
const data = AgentResponseSchema.parse(await res.json());
```

### 6. Each type earns its place

Define types that reflect a real shape or contract — not types added just to satisfy the
compiler. Comment non-obvious ones with what they model and *why* (mirrors the global
comment policy for intentional design choices).

```typescript
// ✅ Correct — the comment explains an otherwise cryptic type
// Backend returns page as 1-indexed; total_page is inclusive. Keep snake_case to match wire format.
interface PageMetadata { page: number; total_page: number; }
```

## State Management

```jsx
// Local state: useState
const [count, setCount] = useState(0);

// Server state: React Query
const { data, isLoading } = useQuery(["alerts"], fetchAlerts);

// Global UI state: Redux
const user = useSelector((state) => state.user);
const dispatch = useDispatch();
```

## Testing

```jsx
import { render, screen, fireEvent } from "@testing-library/react";
import Alert from "../Alert";

describe("Alert", () => {
  it("renders alert content", () => {
    render(<Alert severity="high" />);
    expect(screen.getByText(/alert/i)).toBeInTheDocument();
  });

  it("calls onDismiss when dismissed", () => {
    const onDismiss = vi.fn();
    render(<Alert id="1" onDismiss={onDismiss} />);
    fireEvent.click(screen.getByRole("button"));
    expect(onDismiss).toHaveBeenCalledWith("1");
  });
});
```

## Common Patterns

### Conditional Rendering
```jsx
// Prefer early return
if (loading) return <Spinner />;
if (error) return <Error message={error} />;
return <Content data={data} />;

// Inline for simple cases
{isVisible && <Alert />}
{status === "error" ? <Error /> : <Success />}
```

### Lists
```jsx
// Always use key prop
{alerts.map((alert) => (
  <AlertItem key={alert.id} alert={alert} />
))}
```

### Forms
```jsx
// react-hook-form pattern
const { register, handleSubmit, formState: { errors } } = useForm();

<form onSubmit={handleSubmit(onSubmit)}>
  <input {...register("email", { required: true })} />
  {errors.email && <span>Email required</span>}
</form>
```
