---
name: style-go
description: Go code style - handlers, interfaces, error handling, concurrency, DNS patterns.
user-invocable: false
---

# Go Style Guide

## Formatting

- Use `gofmt` / `goimports` (automatic)
- Tabs for indentation
- No line length limit (but keep reasonable)

```bash
# Format code
go fmt ./...
goimports -w .

# Lint
golangci-lint run
```

## Project Structure

```
service/
├── cmd/
│   └── main.go           # Entry point
├── internal/
│   ├── boot/             # Initialization
│   ├── handlers/         # HTTP/RabbitMQ handlers
│   ├── usecases/         # Business logic
│   └── server/           # Server setup
├── contracts/            # Interfaces
├── dto/                  # Data structures
├── pkg/                  # Shared packages
├── configs/              # Configuration
├── go.mod
└── go.sum
```

## Naming Conventions

```go
// Packages: lowercase, single word
package handlers
package usecases

// Files: snake_case
query_handler.go
dns_resolver.go

// Exported (public): PascalCase
type QueryHandler struct {}
func (h *QueryHandler) HandleQuery() {}

// Unexported (private): camelCase
type queryCache struct {}
func (h *QueryHandler) validateInput() {}

// Interfaces: -er suffix for single method
type Reader interface {
    Read(p []byte) (n int, err error)
}

// Interfaces: descriptive for multiple methods
type DNSResolver interface {
    Resolve(domain string) ([]string, error)
    CacheLookup(domain string) (*CacheEntry, bool)
}

// Constants: PascalCase or camelCase based on export
const MaxRetries = 3           // Exported
const defaultTimeout = 30      // Unexported

// Errors: Err prefix
var ErrNotFound = errors.New("not found")
var ErrInvalidInput = errors.New("invalid input")
```

## Error Handling

```go
// Always check errors
result, err := doSomething()
if err != nil {
    return fmt.Errorf("failed to do something: %w", err)
}

// Custom errors
type NotFoundError struct {
    Resource string
    ID       string
}

func (e *NotFoundError) Error() string {
    return fmt.Sprintf("%s not found: %s", e.Resource, e.ID)
}

// Error wrapping (Go 1.13+)
if err != nil {
    return fmt.Errorf("query failed: %w", err)
}

// Check wrapped errors
if errors.Is(err, ErrNotFound) {
    // Handle not found
}
```

## Struct Pattern

```go
// Config struct with tags
type Config struct {
    Host     string        `env:"HOST" default:"localhost"`
    Port     int           `env:"PORT" default:"8080"`
    Timeout  time.Duration `env:"TIMEOUT" default:"30s"`
    Debug    bool          `env:"DEBUG" default:"false"`
}

// Domain struct
type DNSQuery struct {
    Domain    string
    Type      uint16
    ProfileID string
    ClientIP  net.IP
    Timestamp time.Time
}

// Constructor function
func NewDNSQuery(domain string, qtype uint16) *DNSQuery {
    return &DNSQuery{
        Domain:    domain,
        Type:      qtype,
        Timestamp: time.Now(),
    }
}
```

## Interface Pattern

```go
// Define interfaces where they're used (consumer side)
// contracts/resolver.go
type DNSResolver interface {
    Resolve(ctx context.Context, query *DNSQuery) (*DNSResponse, error)
}

// Implementation
// internal/usecases/resolver.go
type resolverImpl struct {
    cache     Cache
    upstream  UpstreamResolver
    blocklist BlocklistChecker
    logger    *slog.Logger
}

func NewResolver(cache Cache, upstream UpstreamResolver, blocklist BlocklistChecker, logger *slog.Logger) DNSResolver {
    return &resolverImpl{
        cache:     cache,
        upstream:  upstream,
        blocklist: blocklist,
        logger:    logger,
    }
}

func (r *resolverImpl) Resolve(ctx context.Context, query *DNSQuery) (*DNSResponse, error) {
    // Implementation
}
```

## Handler Pattern

```go
type QueryHandler struct {
    resolver DNSResolver
    logger   *slog.Logger
}

func NewQueryHandler(resolver DNSResolver, logger *slog.Logger) *QueryHandler {
    return &QueryHandler{
        resolver: resolver,
        logger:   logger,
    }
}

func (h *QueryHandler) HandleDoH(w http.ResponseWriter, r *http.Request) {
    ctx := r.Context()

    // Parse request
    query, err := h.parseRequest(r)
    if err != nil {
        h.logger.Error("failed to parse request", "error", err)
        http.Error(w, "Bad Request", http.StatusBadRequest)
        return
    }

    // Process
    response, err := h.resolver.Resolve(ctx, query)
    if err != nil {
        h.logger.Error("failed to resolve", "error", err, "domain", query.Domain)
        http.Error(w, "Internal Server Error", http.StatusInternalServerError)
        return
    }

    // Write response
    w.Header().Set("Content-Type", "application/dns-message")
    w.Write(response.Bytes())
}
```

## Context Usage

```go
// Always pass context as first parameter
func (s *Service) DoWork(ctx context.Context, input Input) (Output, error) {
    // Check for cancellation
    select {
    case <-ctx.Done():
        return Output{}, ctx.Err()
    default:
    }

    // Use context for timeouts
    ctx, cancel := context.WithTimeout(ctx, 5*time.Second)
    defer cancel()

    return s.doActualWork(ctx, input)
}
```

## Concurrency Patterns

```go
// Goroutine with error handling
errChan := make(chan error, 1)
go func() {
    errChan <- doWork()
}()

select {
case err := <-errChan:
    if err != nil {
        return err
    }
case <-ctx.Done():
    return ctx.Err()
}

// Worker pool
func processItems(ctx context.Context, items []Item, workers int) error {
    jobs := make(chan Item, len(items))
    results := make(chan error, len(items))

    // Start workers
    for i := 0; i < workers; i++ {
        go func() {
            for item := range jobs {
                results <- processItem(ctx, item)
            }
        }()
    }

    // Send jobs
    for _, item := range items {
        jobs <- item
    }
    close(jobs)

    // Collect results
    for range items {
        if err := <-results; err != nil {
            return err
        }
    }
    return nil
}
```

## Testing

```go
func TestResolver_Resolve(t *testing.T) {
    // Arrange
    mockCache := &MockCache{}
    mockUpstream := &MockUpstream{}
    resolver := NewResolver(mockCache, mockUpstream, nil, slog.Default())

    query := &DNSQuery{
        Domain: "example.com",
        Type:   dns.TypeA,
    }

    // Act
    result, err := resolver.Resolve(context.Background(), query)

    // Assert
    if err != nil {
        t.Fatalf("unexpected error: %v", err)
    }
    if result == nil {
        t.Fatal("expected result, got nil")
    }
}

// Table-driven tests
func TestValidateDomain(t *testing.T) {
    tests := []struct {
        name    string
        domain  string
        want    bool
    }{
        {"valid domain", "example.com", true},
        {"valid subdomain", "sub.example.com", true},
        {"empty domain", "", false},
        {"invalid chars", "exam ple.com", false},
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            got := ValidateDomain(tt.domain)
            if got != tt.want {
                t.Errorf("ValidateDomain(%q) = %v, want %v", tt.domain, got, tt.want)
            }
        })
    }
}
```

## Logging (slog)

```go
import "log/slog"

// Create logger
logger := slog.New(slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{
    Level: slog.LevelInfo,
}))

// Use structured logging
logger.Info("request received",
    "method", r.Method,
    "path", r.URL.Path,
    "client_ip", r.RemoteAddr,
)

logger.Error("failed to resolve",
    "error", err,
    "domain", query.Domain,
    "duration_ms", time.Since(start).Milliseconds(),
)
```

## Redis Pattern (Aman)

```go
// Cache interface
type Cache interface {
    Get(ctx context.Context, key string) (string, error)
    Set(ctx context.Context, key string, value string, ttl time.Duration) error
    Delete(ctx context.Context, key string) error
}

// Key patterns
const (
    KeyDNSBlocked    = "dns-blocked:%s"      // dns-blocked:example.com
    KeyTrustDomain   = "trust-domain:%s:%s"  // trust-domain:ulid:domain
    KeyParental      = "parental:%s:%s"      // parental:ulid:domain
    KeyDNSCache      = "%s:%d"               // domain:type
)

func (c *RedisCache) GetBlocked(ctx context.Context, domain string) (string, error) {
    key := fmt.Sprintf(KeyDNSBlocked, domain)
    return c.client.Get(ctx, key).Result()
}
```
