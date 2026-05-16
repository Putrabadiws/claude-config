# Go Test Reference (testify + miniredis)

## Table of Contents

- [Unit Tests](#unit-tests)
- [Integration Tests](#integration-tests)
- [Error Assertions](#error-assertions)

Patterns and best practices for Go unit tests, integration tests, and error assertions.

## Unit Tests

**Owner**: Dev (reviews AI draft)
**Rules**: Table-driven for multiple cases, `t.Helper()` on all helpers, `defer` cleanup, testify/assert (non-fatal)

```go
// Pure unit test — simple function
func TestIsBlocked_MalwareDomain_ReturnsTrue(t *testing.T) {
    result := IsBlocked("malware.example.com", []string{"malware"})
    assert.True(t, result)
}

func TestIsBlocked_SafeDomain_ReturnsFalse(t *testing.T) {
    result := IsBlocked("safe.example.com", []string{"malware"})
    assert.False(t, result)
}
```

```go
// Table-driven tests — preferred for multiple input/output combinations
func TestParseSNI(t *testing.T) {
    tests := []struct {
        name      string
        sni       string
        wantUlid  string
        wantSubId string
        wantErr   bool
    }{
        {
            name:     "valid profile ID without subscriber",
            sni:      "ABC123.p.dot.dns.example.com",
            wantUlid: "ABC123",
            wantErr:  false,
        },
        {
            name:    "empty SNI returns error",
            sni:     "",
            wantErr: true,
        },
        {
            name:    "malformed SNI returns error",
            sni:     "no-dots",
            wantErr: true,
        },
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            ulid, subId, err := ParseSNI(tt.sni)
            if tt.wantErr {
                assert.Error(t, err)
                return
            }
            assert.NoError(t, err)
            assert.Equal(t, tt.wantUlid, ulid)
            assert.Equal(t, tt.wantSubId, subId)
        })
    }
}
```

```go
// Handler test — Fiber + httptest
func TestLivezHandler_ReturnsOK(t *testing.T) {
    h := NewLivezHandler(nil, 50, 2)
    app := fiber.New()
    app.Get("/livez", h.Handle)

    req := httptest.NewRequest("GET", "/livez", nil)
    resp, err := app.Test(req)

    assert.NoError(t, err)
    assert.Equal(t, http.StatusOK, resp.StatusCode)
}
```

```go
// Mock with testify/mock — interface-based
type MockBlocklistRepo struct {
    mock.Mock
}

func (m *MockBlocklistRepo) IsBlocked(domain string) (bool, string) {
    args := m.Called(domain)
    return args.Bool(0), args.String(1)
}

func TestResolveQuery_BlockedDomain_Returns403(t *testing.T) {
    repo := new(MockBlocklistRepo)
    repo.On("IsBlocked", "evil.com.").Return(true, "malware")

    resolver := NewDnsResolver(repo, nil)
    result, _ := resolver.ResolveQuery("evil.com.", dns.TypeA, "ULID123")

    assert.Equal(t, 403, result.HttpStatus)
    repo.AssertExpectations(t)
}
```

```go
// Miniredis — in-memory Redis for tests requiring real Redis commands/pipelines
func newTestRedisConn(t *testing.T) (*redis.Client, *miniredis.Miniredis) {
    t.Helper()
    mr, err := miniredis.Run()
    require.NoError(t, err)
    client := redis.NewClient(&redis.Options{Addr: mr.Addr()})
    t.Cleanup(func() { mr.Close() })
    return client, mr
}

func TestQpsLimiter_ExceedsLimit_ReturnsTrue(t *testing.T) {
    client, _ := newTestRedisConn(t)
    limiter := NewQpsLimiter(client, 2) // limit: 2 qps

    assert.False(t, limiter.IsLimited("device-1")) // 1st — ok
    assert.False(t, limiter.IsLimited("device-1")) // 2nd — ok
    assert.True(t, limiter.IsLimited("device-1"))  // 3rd — limited
}
```

**Go test best practices:**
- **Table-driven by default** — use `[]struct` + `t.Run` for 3+ cases. Easier to add cases, clearer failure output.
- **`t.Helper()`** on every helper function — so failures point to the calling test, not the helper.
- **`t.Cleanup()`** over `defer`** — `t.Cleanup` runs even if the test panics and works correctly with subtests.
- **`t.Parallel()`** — add to independent tests for faster runs. Don't use if tests share mutable state (miniredis, global vars).
- **`require` vs `assert`** — use `require` (fatal) for setup preconditions, `assert` (non-fatal) for actual test assertions. If setup fails, subsequent assertions are meaningless.
- **Miniredis over mocking Redis** — when testing code that uses Redis pipelines or Lua scripts, miniredis is more reliable than mocking individual commands.
- **No `init()` in test files** — use `TestMain(m *testing.M)` if you need global setup/teardown.

---

## Integration Tests

Use miniredis for Redis-dependent code; use testcontainers or Docker Compose for Postgres-dependent code.

```go
// Integration test — resolver with miniredis backing real Redis pipelines
func TestResolveQuery_BlockedDomain_ReturnsBlockedResponse(t *testing.T) {
    client, mr := newTestRedisConn(t)

    // Seed test data — simulates real Redis state
    populateUlid(mr, "device-abc", "ULID123")
    populateBlockedDomain(mr, "evil.example.com.", "malware")

    resolver := NewDnsResolver(client, config)
    result, err := resolver.ResolveQuery("evil.example.com.", dns.TypeA, "ULID123")

    require.NoError(t, err)
    assert.Equal(t, 403, result.HttpStatus)
    assert.Equal(t, "malware", result.BlockCategory)
}

// Integration test — Fiber handler with full middleware chain
func TestQueryHandler_ValidRequest_ReturnsResponse(t *testing.T) {
    client, mr := newTestRedisConn(t)
    populateUlid(mr, "test-device", "ULID-TEST")

    app := fiber.New()
    handler := NewQueryHandler(NewDnsResolver(client, config))
    app.Get("/dns-query", handler.Handle)

    req := httptest.NewRequest("GET", "/dns-query?dns=AAABAAAB...&ulid=ULID-TEST", nil)
    resp, err := app.Test(req)

    require.NoError(t, err)
    assert.Equal(t, http.StatusOK, resp.StatusCode)
    assert.Equal(t, "application/dns-message", resp.Header.Get("Content-Type"))
}
```

**Go integration test best practices:**
- **Miniredis for Redis** — real Redis commands/pipelines without Docker. Use `t.Cleanup` to close.
- **`require` for setup assertions** — if `miniredis.Run()` fails, stop immediately instead of cascading nil panics.
- **Build tags for slow tests** — use `//go:build integration` to separate from fast unit tests, run with `go test -tags integration ./...`
- **`testcontainers-go` for Postgres** — when you need real SQL. Slower but catches query/migration issues mocks can't.

---

## Error Assertions

```go
// Bad — catches any error, doesn't verify type or message
_, err := resolver.ResolveQuery("", dns.TypeA, "")
assert.Error(t, err)

// Good — verify error type with errors.Is/As or message content
_, err := resolver.ResolveQuery("", dns.TypeA, "")
assert.ErrorContains(t, err, "invalid domain")

// Best — verify custom error type and fields
var validErr *ValidationError
require.ErrorAs(t, err, &validErr)
assert.Equal(t, "domain", validErr.Field)

// Handler error — verify HTTP status + response body
resp, _ := app.Test(httptest.NewRequest("GET", "/dns-query?dns=invalid", nil))
assert.Equal(t, http.StatusBadRequest, resp.StatusCode)
body, _ := io.ReadAll(resp.Body)
assert.Contains(t, string(body), "invalid query")
```
