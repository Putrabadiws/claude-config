---
name: frontend-perf-audit
description: Audit frontend performance - bundle size, build analysis, React rendering, Web Vitals, image optimization.
argument-hint: [focus-area (optional): bundle|rendering|vitals|images|all]
allowed-tools: Bash(npm *), Bash(npx *), Bash(du *), Read, Glob, Grep
---

# Frontend Performance Audit

## Detect Project Type
!`ls next.config.mjs next.config.js vite.config.js vite.config.ts 2>/dev/null | head -1 || echo "unknown"`

## 1. Build Analysis

Always audit production builds, never dev.

### Next.js
```bash
# Build with analysis output
npm run build

# Check build output sizes (Next.js prints route sizes)
# Look for: routes > 100kB, First Load JS > 200kB

# Bundle analyzer (if @next/bundle-analyzer installed)
ANALYZE=true npm run build
```

### Vite
```bash
npm run build

# Check dist size
du -sh dist/
du -sh dist/assets/*.js | sort -rh | head -20

# If rollup-plugin-visualizer configured
# Open stats.html after build
```

### What to look for
- **First Load JS** (Next.js): should be < 200kB per route
- **Individual chunks** > 100kB: candidate for code splitting
- **Duplicate dependencies**: same lib bundled multiple times
- **Dev-only imports**: React DevTools, console logs, test utils in production

## 2. Mantine Bundle Optimization

Our projects use Mantine v7/v8. Check for bundle bloat:

```bash
# Check if optimizePackageImports is configured (Next.js)
grep -r "optimizePackageImports" next.config.mjs next.config.js 2>/dev/null

# Check for barrel imports (bad: imports entire package)
grep -rn "from \"@mantine/core\"" src/ --include="*.jsx" --include="*.tsx" | head -20

# Good: specific imports (tree-shakeable)
# import { Button } from "@mantine/core";  -- OK with optimizePackageImports
# Bad: import * as Mantine from "@mantine/core";
```

**Expected**: `optimizePackageImports` includes `@mantine/core` and `@mantine/hooks` in `next.config.mjs`.

## 3. Code Splitting & Lazy Loading

### Next.js App Router
- Route-level splitting is automatic (each `page.jsx` is a separate chunk)
- Check for heavy client components that could be deferred:

```bash
# Find large "use client" files
grep -rl "\"use client\"" src/ --include="*.jsx" --include="*.tsx" | while read f; do
  size=$(wc -c < "$f")
  if [ "$size" -gt 10000 ]; then
    echo "$size $f"
  fi
done | sort -rn | head -10

# Check dynamic imports usage
grep -rn "dynamic(" src/ --include="*.jsx" --include="*.tsx" | head -10
grep -rn "React.lazy" src/ --include="*.jsx" --include="*.tsx" | head -10
```

### Vite (React Router)
```bash
# Check lazy route loading
grep -rn "lazy(" src/ --include="*.jsx" --include="*.tsx" | head -10
grep -rn "React.lazy" src/ --include="*.jsx" --include="*.tsx" | head -10

# Routes without lazy loading = bundled in main chunk
grep -rn "import.*from.*pages/" src/routes/ --include="*.jsx" --include="*.tsx" | head -10
```

**Rule**: Heavy modules (charts, editors, modals with complex content) should use `next/dynamic` or `React.lazy`.

## 4. React Rendering Performance

### Find potential re-render issues

```bash
# Components subscribing to entire Zustand store (causes re-render on any state change)
grep -rn "useProfileStore()" src/ --include="*.jsx" --include="*.tsx" | head -10
grep -rn "useAuthStore()" src/ --include="*.jsx" --include="*.tsx" | head -10
# Better: useProfileStore((s) => s.selectedProfile) -- selector pattern

# Inline object/array/function props (new reference every render)
grep -rn "style={{" src/ --include="*.jsx" --include="*.tsx" | wc -l
# High count = potential issue, especially in lists

# Missing key prop in lists
grep -rn "\.map(" src/ --include="*.jsx" --include="*.tsx" -A 2 | grep -v "key=" | head -10
```

### React Query optimization

```bash
# Queries without enabled flag (may fire before data is ready)
grep -rn "useQuery" src/ --include="*.jsx" --include="*.tsx" -A 5 | grep -B 3 "queryFn" | grep -v "enabled" | head -10

# Queries with short/no staleTime (re-fetches aggressively)
grep -rn "staleTime" src/ --include="*.jsx" --include="*.tsx" | head -10
# Default staleTime is 0 — consider setting higher for rarely-changing data

# Excessive invalidations
grep -rn "invalidateQueries" src/ --include="*.jsx" --include="*.tsx" | head -10
```

## 5. Image Optimization

### Next.js
```bash
# Check for <img> tags instead of next/image (misses optimization)
grep -rn "<img " src/ --include="*.jsx" --include="*.tsx" | head -10

# Check next/image usage
grep -rn "from \"next/image\"" src/ --include="*.jsx" --include="*.tsx" | head -10

# Check allowed image domains in next.config
grep -A 10 "images" next.config.mjs next.config.js 2>/dev/null

# Images without explicit width/height (causes CLS)
grep -rn "<Image" src/ --include="*.jsx" --include="*.tsx" -A 3 | grep -v "width\|height\|fill" | head -10
```

### General
```bash
# Large images in public/
find public/ -name "*.png" -o -name "*.jpg" -o -name "*.jpeg" -o -name "*.gif" 2>/dev/null | while read f; do
  size=$(wc -c < "$f")
  if [ "$size" -gt 200000 ]; then
    echo "$(($size / 1024))KB $f"
  fi
done | sort -rn

# Check for WebP/AVIF usage (preferred over PNG/JPG)
find public/ -name "*.webp" -o -name "*.avif" 2>/dev/null | wc -l
find public/ -name "*.png" -o -name "*.jpg" 2>/dev/null | wc -l
```

## 6. Web Vitals

### Targets (Google Core Web Vitals)
| Metric | Good | Needs Improvement | Poor |
|--------|------|-------------------|------|
| **LCP** (Largest Contentful Paint) | < 2.5s | 2.5s - 4.0s | > 4.0s |
| **CLS** (Cumulative Layout Shift) | < 0.1 | 0.1 - 0.25 | > 0.25 |
| **INP** (Interaction to Next Paint) | < 200ms | 200ms - 500ms | > 500ms |

### Common fixes
- **LCP**: Preload hero images, reduce JS blocking, use `priority` on above-fold `<Image>`
- **CLS**: Set explicit `width`/`height` on images/video, avoid layout-shifting loaders, reserve space for async content
- **INP**: Debounce expensive handlers, avoid synchronous state updates in event handlers, break up long tasks

### Check for CLS culprits
```bash
# Dynamic content without reserved space
grep -rn "isLoading\|loading" src/ --include="*.jsx" --include="*.tsx" -A 3 | grep -v "Skeleton\|placeholder\|min-h\|minHeight" | head -10

# Font loading (can cause layout shift)
grep -rn "font" src/styles/ --include="*.css" --include="*.js" | head -5
# Next.js: use next/font for zero-CLS font loading
grep -rn "next/font" src/ --include="*.jsx" --include="*.tsx" --include="*.js" | head -5
```

## 7. Dependency Audit

```bash
# Check for heavy dependencies
npx depcheck --json 2>/dev/null | head -30

# Unused dependencies (candidates for removal)
npx depcheck 2>/dev/null | head -20

# Check node_modules size of key packages
du -sh node_modules/@mantine 2>/dev/null
du -sh node_modules/framer-motion 2>/dev/null
du -sh node_modules/lodash 2>/dev/null
du -sh node_modules/moment 2>/dev/null

# moment.js should be replaced with dayjs (we already use dayjs)
grep -rn "from \"moment\"" src/ --include="*.jsx" --include="*.tsx" --include="*.js" | head -5
```

## Summary Checklist

After running the audit, report findings in this format:

| Area | Status | Finding | Action |
|------|--------|---------|--------|
| Build size | OK/WARN/FAIL | First Load JS: XXkB | - |
| Mantine imports | OK/WARN | optimizePackageImports configured | - |
| Code splitting | OK/WARN | X heavy components not lazy-loaded | Use next/dynamic |
| React rendering | OK/WARN | X store subscriptions without selectors | Add selectors |
| Images | OK/WARN | X images without next/image | Migrate to Image |
| CLS risk | OK/WARN | X loaders without skeleton/placeholder | Add min-height |
| Dependencies | OK/WARN | X unused deps, moment.js found | Remove/replace |
