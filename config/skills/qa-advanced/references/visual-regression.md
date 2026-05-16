# Visual Regression Testing

## Playwright Screenshot Comparison

```python
# tests/ui/portal/test_visual.py
def test_dashboard_renders_correctly(page, login_user, base_url):
    page.goto(f"{base_url}/dashboard")
    page.wait_for_load_state("networkidle")

    # Mask dynamic content to prevent false failures
    page.locator('[data-testid="last-updated"]').evaluate(
        "el => el.style.visibility = 'hidden'")
    page.locator('[data-testid="live-counter"]').evaluate(
        "el => el.style.visibility = 'hidden'")

    expect(page).to_have_screenshot("dashboard.png", full_page=True, max_diff_pixel_ratio=0.02)
```

```typescript
// playwright.config.ts — if using TS directly
export default defineConfig({
  expect: {
    toHaveScreenshot: {
      maxDiffPixelRatio: 0.02,
      animations: 'disabled',
    },
  },
});
```

## Baseline management

```bash
# Update baselines after intentional UI changes
pytest --update-snapshots tests/ui/

# Always commit updated snapshots with the MR that changed the UI
git add tests/ui/**/*.png
git commit -m "chore: update visual baselines for new dashboard layout"
```

## What to cover

- Key page layouts (dashboard, detail views, forms)
- Component states (empty, loading, error, populated)
- Responsive breakpoints (Desktop 1920x1080, iPad Pro 11 834x1194, iPhone 13 390x844) — Orion
- Dark mode if supported

## When NOT to use visual regression

- Highly dynamic pages (real-time data, live charts) — mask or skip
- Pages with third-party embeds — unstable baseline
- Admin/internal tools where pixel perfection is low priority
