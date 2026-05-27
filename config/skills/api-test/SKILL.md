---
name: api-test
description: Test API endpoints - curl commands, health checks, API debugging, service availability checks. Do NOT use for load testing, security scanning, or full E2E test suites (use qa-test-gen).
argument-hint: [platform] [endpoint]
allowed-tools: Bash(curl *)
---

# API Testing

## Current Context
!`kubectl config current-context 2>/dev/null || echo "No context set"`

## Port Forward Setup

```bash
# Generic pattern
kubectl port-forward -n $NS svc/<service> <local-port>:<service-port> &

# Example
kubectl port-forward -n <namespace> svc/<service> 8080:8080 &
```

## Service Endpoints

Document each service's port and health endpoint here. Example shape:

| Service | Port | Health Check |
|---------|------|--------------|
| `<service>` | `<port>` | `/actuator/health` or `/health` |

```bash
# Health check
curl -s http://localhost:<port>/actuator/health | jq

# Authenticated GET
curl -s http://localhost:<port>/api/v1/<resource> \
  -H "Authorization: Bearer $TOKEN" | jq

# POST with JSON body
curl -X POST http://localhost:<port>/api/v1/<resource> \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"key": "value"}' | jq
```

## Auth Patterns

### Get Keycloak Token
```bash
# Password grant
curl -X POST "http://<keycloak>/realms/<realm>/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=password" \
  -d "client_id=<client>" \
  -d "username=<user>" \
  -d "password=<pass>" | jq -r '.access_token'
```

### Use Token
```bash
TOKEN="<paste-token>"
curl -s http://localhost:<port>/api/v1/endpoint \
  -H "Authorization: Bearer $TOKEN" | jq
```

## Common Tests

```bash
# Check if service responds
curl -s -o /dev/null -w "%{http_code}\n" http://localhost:<port>/actuator/health

# Response time
curl -s -o /dev/null -w "Time: %{time_total}s\n" http://localhost:<port>/actuator/health

# Headers only
curl -I http://localhost:<port>/actuator/health

# Verbose (debug)
curl -v http://localhost:<port>/actuator/health

# POST with JSON
curl -X POST http://localhost:<port>/api/endpoint \
  -H "Content-Type: application/json" \
  -d '{"key": "value"}' | jq
```

## Troubleshooting

| Issue | Check |
|-------|-------|
| Connection refused | Port forward running? Service up? |
| 401 Unauthorized | Token expired? Correct realm/client? |
| 403 Forbidden | User has required role? |
| 404 Not Found | Correct path? API version? |
| 500 Internal Error | Check service logs |
| Timeout | Service overloaded? Check resources |
