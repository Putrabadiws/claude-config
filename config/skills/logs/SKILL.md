---
name: logs
description: View and analyze logs - kubectl logs, pod logs, error analysis, debugging, troubleshooting failures.
argument-hint: [namespace] [deployment-or-pod]
allowed-tools: Bash(kubectl logs *), Bash(kubectl get *), Bash(kubectl describe *), Bash(grep *)
---

# Log Analysis

## Current Context
!`kubectl config current-context 2>/dev/null || echo "No context set"`

## Target
- Namespace: `$0`
- Deployment: `$1`

## Quick Commands

```bash
# Basic logs
kubectl logs -n $0 deployment/$1 --tail=100

# Follow logs
kubectl logs -n $0 deployment/$1 -f --tail=50

# Previous container (after crash)
kubectl logs -n $0 deployment/$1 --previous

# Since time
kubectl logs -n $0 deployment/$1 --since=5m
kubectl logs -n $0 deployment/$1 --since=1h

# All containers in pod
kubectl logs -n $0 deployment/$1 --all-containers=true

# With timestamps
kubectl logs -n $0 deployment/$1 --timestamps=true
```

## Filter Patterns

```bash
# Errors only
kubectl logs -n $NS deployment/$DEPLOY --tail=500 | grep -i error

# Exceptions
kubectl logs -n $NS deployment/$DEPLOY --tail=500 | grep -i -A5 exception

# Specific keyword
kubectl logs -n $NS deployment/$DEPLOY --tail=500 | grep -i "<keyword>"

# Exclude noise
kubectl logs -n $NS deployment/$DEPLOY --tail=500 | grep -v "health\|actuator\|GET / "

# Count errors
kubectl logs -n $NS deployment/$DEPLOY --tail=1000 | grep -c -i error
```

## Common Error Patterns

### Java/Spring Boot
```bash
# Stack traces
kubectl logs -n $NS deployment/$DEPLOY | grep -A20 "Exception\|Error"

# Connection issues
kubectl logs -n $NS deployment/$DEPLOY | grep -i "connection\|timeout\|refused"

# OOM
kubectl logs -n $NS deployment/$DEPLOY | grep -i "OutOfMemory\|heap"
```

### Python/FastAPI
```bash
# Tracebacks
kubectl logs -n $NS deployment/$DEPLOY | grep -A10 "Traceback"

# Import errors
kubectl logs -n $NS deployment/$DEPLOY | grep -i "ImportError\|ModuleNotFound"
```

### Common Issues

| Error | Likely Cause | Check |
|-------|--------------|-------|
| `Connection refused` | Service not ready / wrong port | `kubectl get svc -n $NS` |
| `Timeout` | Network/DNS issue | `kubectl exec ... -- curl <target>` |
| `OOMKilled` | Memory limit exceeded | `kubectl describe pod` → resources |
| `CrashLoopBackOff` | App crash on startup | `kubectl logs --previous` |
| `ImagePullBackOff` | Wrong image / registry auth | `kubectl describe pod` → events |

## Pod Status Check

```bash
# Pod status
kubectl get pods -n $NS -l app=$DEPLOY

# Pod details (events at bottom)
kubectl describe pod -n $NS -l app=$DEPLOY

# Resource usage
kubectl top pods -n $NS

# Recent events
kubectl get events -n $NS --sort-by='.lastTimestamp' | tail -20
```

## Multi-Pod Logs

```bash
# All pods of deployment
kubectl logs -n $NS -l app=$DEPLOY --tail=50

# Specific pod
POD=$(kubectl get pods -n $NS -l app=$DEPLOY -o jsonpath='{.items[0].metadata.name}')
kubectl logs -n $NS $POD --tail=100
```

## Log Aggregation (if Loki/ELK available)

```bash
# Stern (multi-pod tailing)
stern -n $NS $DEPLOY --tail=50

# Kubetail
kubetail $DEPLOY -n $NS
```

## Platform-Specific

### Orion
- Main API logs: `deployment/ib-backend-mdr`
- Alert ingestion: `deployment/ib-insert-alert-from-event`
- Common errors: OpenSearch connection, RabbitMQ timeouts

### Aman
- DNS resolver: `deployment/dns-resolver-core-golang`
- License mgmt: `deployment/dns-license-management`
- Common errors: Redis connection, ULID validation

### Bron AI
- AI core: `deployment/backend-aegis`
- RAG pipeline: `deployment/backend-fates`
- Celery workers: `deployment/backend-fates-worker`
- Common errors: Gemini API rate limits, Qdrant connection
