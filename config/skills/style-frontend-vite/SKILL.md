---
name: style-frontend-vite
description: React+Vite frontend style - Redux, Keycloak auth, useAxios, service hooks.
user-invocable: false
---

Base React patterns are in the `style-react` skill. This skill covers Vite-specific patterns only.

# React + Vite Frontend Style Guide

Patterns for Vite-based frontends, covering two common shapes: a Redux-based admin dashboard and a Zustand-based embeddable widget.

## Prettier/ESLint Overrides

Extends `style-react` defaults. Key differences:
- `trailingComma: "es5"`, `endOfLine: "lf"`
- `quotes` adds `avoidEscape: true`
- ESLint rules are otherwise identical to `style-react`

## Project Structure

### Redux-based admin dashboard

```
src/
  api/              # SERVICE config + useXxxService hooks
  components/       # Reusable components
  pages/            # Route-level page components
  store/slices/     # Redux Toolkit slices
  utils/hooks/      # useAxios, usePagination, etc.
  constants/        # Query keys, enums
  i18n/             # i18next config + locales/{en,id}/
  style/            # Global styles, Mantine theme, Tailwind config
  routes/           # PrivateRoute, RoleBasedRoute
```

### Zustand-based widget

```
src/
  Widget/           # Main widget components
  components/       # Reusable components
  store/            # Zustand stores (NOT Redux)
  utils/            # useFetch, SSE stream, encryption
  style/            # Tailwind with a component prefix (e.g. `cbt-`)
```

Component folder structure follows `style-react` conventions (PascalCase, optional `.module.css`, `__tests__/`, barrel export).

## API Layer

### SERVICE config (runtime from localStorage)

```javascript
const env = JSON.parse(localStorage.getItem("env"));
const BASE_URL = `${env?.["VITE_BASE_URL"]}`;

const SERVICE = {
  backend: `${BASE_URL}/backend/api/v1`,
  user: `${BASE_URL}/user/api/v1`,
  minio: `${BASE_URL}/minio/api/v1/s3`,
  // ... per microservice
};
export default SERVICE;
```

### Service hook pattern

```javascript
import useAxios from "@/utils/hooks/useAxios";
import SERVICE from ".";
import { transformObjIntoParams } from "@/utils/transformObjIntoParams";

const useItemService = () => {
  const axios = useAxios(SERVICE.backend);

  const fetchItems = async (date, params, payload) => {
    const { data } = await axios.post(
      `/item/${date.startDate}/${date.endDate}?${transformObjIntoParams(params)}`,
      payload
    );
    return data;
  };

  const fetchItemById = async (id) => {
    const { data } = await axios.get(`/item/data/${id}`);
    return data.data[0];
  };

  return { fetchItems, fetchItemById };
};

export default useItemService;
```

## useAxios Hook

Keycloak token from `localStorage.authToken`, multi-tenancy via Company-Id header:

```javascript
const useAxios = (baseURL) => {
  if (!baseURL) return {};
  const axiosInstance = axios.create({ baseURL });

  // Request: inject token + Company-Id
  axiosInstance.interceptors.request.use((config) => {
    const { token } = JSON.parse(localStorage.getItem("authToken"));
    if (token) config.headers.Authorization = `Bearer ${token}`;

    const activeCompany = JSON.parse(localStorage.getItem("active"));
    if (activeCompany && !activeCompany?.label?.includes("All")) {
      config.headers["Company-Id"] = activeCompany?.id;
    }
    return config;
  });

  // Response: retry on 401
  axiosInstance.interceptors.response.use(
    (response) => response,
    async (error) => {
      if (error.response?.status === 401 && !error.config._retry) {
        error.config._retry = true;
        // Retry with refreshed token from localStorage
      }
      return Promise.reject(error);
    }
  );

  return axiosInstance;
};
```

## State Management

### Redux Toolkit + Persist

```javascript
import { createSlice } from "@reduxjs/toolkit";

const userSlice = createSlice({
  name: "user",
  initialState: { profile: null, token: null },
  reducers: {
    setUser: (state, action) => { state.profile = action.payload; },
    clearUser: (state) => { state.profile = null; state.token = null; },
  },
});

export const { setUser, clearUser } = userSlice.actions;
export default userSlice.reducer;
```

Usage: `dispatch(setUser(data))`, `useSelector((state) => state.user.profile)`

Persist whitelist configured in `store/store.js` — only persist slices that need it (user, filters, settings).

### Zustand (frontend-chatbot)

```javascript
import { create } from "zustand";
import { persist, createJSONStorage } from "zustand/middleware";

const useChatbotStore = create(
  persist(
    (set) => ({
      historyChat: [],
      chatStatus: "idle",
      setChatStatus: (data) => set(() => ({ chatStatus: data })),
    }),
    { name: "chatbot-storage", storage: createJSONStorage(() => localStorage) }
  )
);
```

## Authentication

- `@react-keycloak/web` wraps the app with `ReactKeycloakProvider`
- `initOptions: { onLoad: "login-required" }`
- Token stored in `localStorage.authToken` via `onTokens` callback
- BroadcastChannel syncs logout across browser tabs
- Role from `keycloak.idTokenParsed.role1`

## Routing

React Router v6 with lazy loading + route guards:

```javascript
const AlertPage = lazy(() => import("@/pages/Alert/Alert"));

<Route path="/alert" element={
  <Suspense fallback={<Loading />}>
    <PrivateRoute>
      <RoleBasedRoute allowedRoles={["SuperAdmin", "Admin", "Analyst"]}>
        <AlertPage />
      </RoleBasedRoute>
    </PrivateRoute>
  </Suspense>
} />
```

## Styling

- **Tailwind CSS** for utility classes
- **Mantine v7** for UI components (Button, Modal, Select, Tabs, etc.)
- **CSS Modules** (`.module.css`) for scoped component styles
- Mantine theme in `style/theme.js` with custom color palettes
- Mantine props: `<Text c="text.0" fw={500} fz="sm">`
- frontend-chatbot uses Tailwind prefix `cbt-` for widget isolation

## i18n

Same `useTranslation` pattern as `style-react`. Differences:
- Translation files: `src/i18n/locales/{en,id}/{namespace}.json` (not `public/locales/`)
- Namespaces: `common`, `alert`, `notification`, `profile`, `dashboard`, etc.

## Testing

- Runner: Vitest (use `vi.fn()`, not `jest.fn()`) -- see `style-react` for RTL patterns
- Test location: `ComponentName/__tests__/ComponentName.test.jsx`
- Pre-commit hook runs tests via Husky

## Common Utilities

- `transformObjIntoParams(params)` — `qs.stringify` with null stripping
- `formatDate(time)` — `dayjs(time).format("DD MMM YYYY HH:mm:ss")`
- `formatNumber(num)` — `num.toLocaleString("id-ID")`
- `snakeToTitleCase(str)` — convert SNAKE_CASE to Title Case
- `useTooltipState()` — tooltip styling with dark mode detection
