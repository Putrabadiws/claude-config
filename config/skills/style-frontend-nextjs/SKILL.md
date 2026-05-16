---
name: style-frontend-nextjs
description: Next.js frontend style - Zustand, NextAuth, useAxios, modules pattern.
user-invocable: false
---

Base React patterns are in the `style-react` skill. This skill covers Next.js-specific patterns only.

# Next.js Frontend Style Guide

Codebase-specific patterns for Next.js dashboards.

## Prettier/ESLint Overrides

Extends `style-react` defaults. Key differences:
- `trailingComma: "es5"`, `endOfLine: "lf"`
- `no-console`: only allows `warn`, `error` (no `info`)
- Extends: `next/core-web-vitals` or `mantine + next/recommended + jest/recommended` depending on project

## Project Structure

```
src/
  app/              # Next.js App Router (route groups + layout.jsx, when used)
  pages/            # Pages Router (NextAuth API routes; or used for all pages in simpler apps)
  modules/          # Feature modules (page-level business logic)
  components/       # Shared reusable components
  services/         # API service hooks + SERVICE config
  hooks/            # Custom hooks (useAxios, useProfile, etc.)
  store/            # Zustand stores + Providers (ReactQuery, NextAuth, i18n)
  constants/        # Query keys, feature constants
  utils/            # Utility functions
  styles/           # Mantine theme, globals.css, CSS Modules
  types/            # TypeScript interfaces (chatbot-dashboard)
  i18n/             # i18next config
  public/locales/   # Translation JSONs ({en,id}/{namespace}.json)
```

### Routing variants

- App Router with route groups + Pages Router for auth API only — when leveraging RSC + NextAuth
- Pages Router (traditional `pages/` file routing) — for simpler apps

## Module Pattern

Feature modules group page-level components together:

```
src/modules/profile/
  index.jsx           # Main module export
  ProfileList.jsx     # Sub-component
  ProfileForm.jsx     # Sub-component
  ModalDelete.jsx     # Feature-specific modal
  constants.js        # Feature constants
```

Page file imports the module:

```javascript
// App Router: src/app/(admin-page)/profile/page.jsx
import ProfileModule from "@/modules/profile";
export default function ProfilePage() {
  return <ProfileModule />;
}

// Pages Router: src/pages/profile/index.jsx
import ProfileModule from "@/modules/profile";
export default function ProfilePage() {
  return <ProfileModule />;
}
```

## API Layer

### SERVICE config (build-time from process.env)

```javascript
const BASE_URL = process.env.NEXT_PUBLIC_API_BASE_URL;

const SERVICE = {
  version: "/api/v1",
  license: `${BASE_URL}/license`,
  user: `${BASE_URL}/user`,
};
export default SERVICE;
```

### Tenant-scoped URLs (multi-tenant apps)

```javascript
export const useService = () => {
  const { tenant_id } = useProfile();
  const BASE_URL = process.env.NEXT_PUBLIC_API_BASE_URL;
  return {
    incident: `${BASE_URL}/${tenant_id}/api/v1`,
    dashboard: `${BASE_URL}/${tenant_id}/api/v1/dashboard`,
    file: `${BASE_URL}/file/api/v1`,
  };
};
```

### Service hook pattern

```javascript
import useAxios from "@/hooks/useAxios";
import SERVICE from ".";

const useProfileService = () => {
  const axios = useAxios(SERVICE.license);

  const fetchListProfile = async () => {
    const { data: dataResponse } = await axios.get(`${SERVICE.version}/profile`, {
      params: { page: 1, size: 1000 },
    });
    return dataResponse?.data?.rows?.reverse() || [];
  };

  const addProfile = async ({ params }) => {
    const { data: result } = await axios.post(`${SERVICE.version}/profile`, params);
    return result;
  };

  return { fetchListProfile, addProfile };
};

export default useProfileService;
```

## useAxios Hook

NextAuth session integration with dual token system (Keycloak for verification, backend token for API):

```javascript
"use client";
import axios from "axios";
import { useSession } from "next-auth/react";
import { tokenStorage, performLogout } from "@/services/auth";

const useAxios = (baseURL) => {
  const { data } = useSession() || {};
  const keycloakToken = data?.user?.access_token;

  if (!baseURL) return axios;
  const axiosInstance = axios.create({ baseURL });

  axiosInstance.interceptors.request.use((config) => {
    const isTokenVerify = config.url?.includes("/verify/sso/token");
    if (isTokenVerify && keycloakToken) {
      config.headers.Authorization = `Bearer ${keycloakToken}`;
    } else {
      const backendToken = tokenStorage.getAccessToken();
      if (backendToken) config.headers.Authorization = `Bearer ${backendToken}`;
    }
    return config;
  });

  axiosInstance.interceptors.response.use(
    (response) => response,
    async (error) => {
      if (error?.response?.status === 401 && !error?.config?._retry) {
        error.config._retry = true;
        tokenStorage.clearTokens();
        performLogout();
      }
      return Promise.reject(error);
    }
  );

  return axiosInstance;
};
```

### Token storage utility

```javascript
const tokenStorage = {
  getAccessToken: () => localStorage.getItem("accessToken"),
  setAccessToken: (token) => localStorage.setItem("accessToken", token),
  clearTokens: () => localStorage.removeItem("accessToken"),
};
```

## State Management (Zustand)

### Simple store

```javascript
import { create } from "zustand";

export const useProfileStore = create((set) => ({
  selectedProfile: null,
  companyId: null,
  setSelectedProfile: (profile) => set({ selectedProfile: profile }),
  setCompanyId: (id) => set({ companyId: id }),
}));
```

### TypeScript store

```typescript
import { create } from "zustand";

interface ToastState {
  toast: { show: boolean; variant: string; message: string };
  successToast: (message: string) => void;
  errorToast: (message: string) => void;
  hideToast: () => void;
}

const useToastStore = create<ToastState>()((set) => ({
  toast: { show: false, variant: "", message: "" },
  successToast: (message) => set(() => ({ toast: { show: true, variant: "success", message } })),
  errorToast: (message) => set(() => ({ toast: { show: true, variant: "error", message } })),
  hideToast: () => set(() => ({ toast: { show: false, variant: "", message: "" } })),
}));
```

### Store with persist

```javascript
import { create } from "zustand";
import { persist, createJSONStorage } from "zustand/middleware";

const useStore = create(
  persist(
    (set) => ({ /* state + actions */ }),
    { name: "store-key", storage: createJSONStorage(() => localStorage) }
  )
);
```

## Authentication

- NextAuth configured in `pages/api/auth/[...nextauth].js` (Pages Router required, even in App Router repos)
- Keycloak provider with automatic token refresh
- Dual token flow: Keycloak SSO token (from NextAuth session) + backend-specific token (from `/verify/sso/token`)
- Auth guard component wraps protected pages, redirects by role

### Auth status store

```javascript
export const AuthStatus = {
  INITIALIZING: "initializing",
  AUTHENTICATED: "authenticated",
  TOKEN_REFRESHING: "refreshing",
  UNAUTHENTICATED: "unauthenticated",
  ERROR: "error",
};

export const useAuthStore = create((set, get) => ({
  status: AuthStatus.INITIALIZING,
  isTokenReady: false,
  setStatus: (status) => set({ status }),
  setTokenReady: (ready) => set({ isTokenReady: ready }),
  isAuthenticated: () => get().status === AuthStatus.AUTHENTICATED,
}));
```

### Pages Router auth bypass

```javascript
// Mark page as public (no auth required)
SignInPage.noAuth = true;
SignInPage.layout = "layoutNoSidebar";
export default SignInPage;
```

## "use client" Directive

Required for any component using hooks, event handlers, or browser APIs:

```javascript
"use client";

import { useState } from "react";

const InteractiveComponent = ({ items }) => {
  const [selected, setSelected] = useState(null);
  return <div onClick={() => setSelected(items[0])}>{/* ... */}</div>;
};
```

Server Components (default in App Router) for static content and layouts.

## React Query

### Centralized query keys

```javascript
// constants/queryKey.js
export const QUERY_KEY = {
  LIST_PROFILE: "LIST_PROFILE",
  TRUSTED_DOMAIN: "TRUSTED_DOMAIN",
  TOTAL_ACTIVITIES: "TOTAL_ACTIVITIES",
  DASHBOARD: "DASHBOARD",
};
```

### Query with conditional fetching

```javascript
import { useQuery } from "@tanstack/react-query";
import { QUERY_KEY } from "@/constants/queryKey";

const { data, isLoading } = useQuery({
  queryKey: [QUERY_KEY.TOTAL_ACTIVITIES, profileId, filter],
  queryFn: () => fetchActivities({ id: profileId, filter }),
  enabled: Boolean(profileId),
});
```

### Mutation with toast + cache invalidation

```javascript
import { useMutation, useQueryClient } from "@tanstack/react-query";

const queryClient = useQueryClient();
const { successToast, errorToast } = useToastStore();

const mutation = useMutation({
  mutationFn: deleteProfile,
  onSuccess: (response) => {
    successToast(response.message || "Deleted successfully");
    queryClient.invalidateQueries({ queryKey: [QUERY_KEY.LIST_PROFILE] });
  },
  onError: (error) => {
    errorToast(error?.response?.data?.message || "Failed to delete");
  },
});
```

### Infinite query

```javascript
const { data, fetchNextPage, hasNextPage, isFetchingNextPage } = useInfiniteQuery({
  queryKey: [QueryKey.AGENTS],
  queryFn: ({ pageParam = 1 }) => fetchAgents(pageParam),
  initialPageParam: 1,
  getNextPageParam: (lastPage, allPages) =>
    lastPage._metadata.page < lastPage._metadata.total_page ? allPages.length + 1 : undefined,
});
```

## TypeScript Patterns

### Interface definitions (in `types/`)

```typescript
// types/AgentType.types.ts
export interface AgentResponseType {
  success: boolean;
  message: string;
  data: Agent[];
  _metadata: { page: number; total_page: number };
}

export interface CreateAgentType {
  name: string;
  description: string;
  subscribed: boolean;
}
```

### Typed service methods

```typescript
const fetchAgents = async (page: number): Promise<AgentResponseType> => {
  const response: AxiosResponse<AgentResponseType> = await axiosInstance.get(
    `${AGENT}/access?page=${page}&size=40`
  );
  return response.data;
};
```

### Component props

```typescript
interface Props {
  children: React.ReactNode;
  className?: string;
  isActive?: boolean;
}

export default function Card({ children, className = "", isActive = false }: Props) {
  return <div className={`base ${isActive ? "active" : ""} ${className}`}>{children}</div>;
}
```

## Mantine Theme

- Dark mode forced: `forceColorScheme="dark"` on `MantineProvider`
- Custom color palettes in `styles/theme.js`
- CSS Modules for Mantine component overrides (navlink.module.css, tabs.module.css)
- Custom font sizes: `bxs` (12px), `bsm` (14px), `bmd` (16px), etc.

```javascript
// Usage
<Text fz="bsm" fw={700} c="text.0">{title}</Text>
<Button variant="filled" size="md">{t("common:save")}</Button>
```

## i18n

```javascript
import { useTranslation } from "react-i18next";

const Dashboard = () => {
  const { t } = useTranslation("dashboard");
  return <h1>{t("title")}</h1>;
};
```

- Translations: `public/locales/{en,id}/{namespace}.json`
- Namespaces in config: `common`, `profile`, `dashboard`, `history`, etc.
- useAxios sets `Accept-Language` header from `i18n.language` when localization is needed

## Testing

- Runner: Jest (use `jest.fn()`, not `vi.fn()`) -- see `style-react` for RTL patterns
- Optional: Storybook for component documentation
- Add Jest + RTL when writing tests
- Form validation: react-hook-form + yup (same pattern as `style-react`, add `yupResolver`)
- Custom validation functions return `null` (valid) or error message string

## Unsaved Changes Guard

Zustand store tracks dirty state, modal warns before navigation:

```javascript
const { isDirty, setShowLeaveModal } = useUnsavedChangesStore();

const handleTabChange = (targetTab) => {
  if (isDirty) {
    setShowLeaveModal(true);
  } else {
    router.push(`${pathname}?tab=${targetTab}`);
  }
};
```

## Common Utilities

- `transformObjIntoParams(params)` — `qs.stringify` with null stripping
- `formatDateTime(time)` — dayjs-based date/time formatting
- `formatNumber(num)` — number display formatting
- `getColorBgByName(name)` — generate avatar color from name string hash
- `getInitialNames(fullName)` — extract initials from full name
- `safeRequest(fn)` — try/catch wrapper returning `{ error }` on failure
