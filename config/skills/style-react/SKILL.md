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
