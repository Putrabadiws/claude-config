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

# Example: Orion MDR API
kubectl port-forward -n ib-dev svc/ib-backend-mdr 4004:4004 &
```

## Platform Endpoints

### Orion (XDR)

| Service | Port | Health Check |
|---------|------|--------------|
| ib-backend-mdr | 4004 | `/actuator/health` |
| ib-insert-alert-from-event | 4010 | `/actuator/health` |
| ib-user-management | 4018 | `/actuator/health` |
| ib-company-management | 4007 | `/actuator/health` |
| ib-sensor-management | 4016 | `/actuator/health` |

```bash
# Health check
curl -s http://localhost:4004/actuator/health | jq

# Get alerts (needs auth)
curl -s http://localhost:4004/api/v1/alerts \
  -H "Authorization: Bearer $TOKEN" | jq

# Get companies
curl -s http://localhost:4007/api/v1/companies \
  -H "Authorization: Bearer $TOKEN" | jq
```

### Corvus (Threat Intel)

| Service | Port | Health Check |
|---------|------|--------------|
| corvus-backend | 4000 | `/health` |
| druid-analyst | 3000 | `/api/health` |

```bash
# Health
curl -s http://localhost:4000/health | jq

# Get IOCs
curl -s http://localhost:4000/api/v1/iocs \
  -H "Authorization: Bearer $TOKEN" | jq
```

### Aman (DNS)

| Service | Port | Health Check |
|---------|------|--------------|
| dns-blocklist-management | 28093 | `/actuator/health` |
| dns-license-management | 28092 | `/actuator/health` |
| dns-resolver-core-golang | 20011 | `/health` |

```bash
# Blocklist health
curl -s http://localhost:28093/actuator/health | jq

# License health
curl -s http://localhost:28092/actuator/health | jq

# Test DNS resolution (DoH)
curl -s "http://localhost:20011/api/v2/<ULID>?name=google.com&type=A" \
  -H "Accept: application/dns-json" | jq
```

### Bron AI (Chatbot)

| Service | Port | Health Check |
|---------|------|--------------|
| aegis-orchestrator | 4000 | `/actuator/health` |
| backend-aegis | 8000 | `/docs` (200 OK) |
| backend-fates | 8050 | `/` |
| aegis-access-control | 4001 | `/actuator/health` |

```bash
# Gateway health
curl -s http://localhost:4000/actuator/health | jq

# Aegis docs (confirms running)
curl -s -o /dev/null -w "%{http_code}" http://localhost:8000/docs

# Fates health
curl -s http://localhost:8050/ | jq

# Test chat (needs API key)
curl -X POST http://localhost:4000/api/v1/chat \
  -H "Content-Type: application/json" \
  -H "X-API-Key: $API_KEY" \
  -d '{"message": "hello", "session_id": "test"}' | jq
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
curl -s http://localhost:4004/api/v1/endpoint \
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
