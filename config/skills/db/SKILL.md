---
name: db
description: Database operations - PostgreSQL, Redis, OpenSearch queries. Use for psql, redis-cli, cache checks, data inspection. Do NOT use for schema migrations (use migration skill), destructive writes without explicit user request.
argument-hint: [db-type] [namespace] [query]
allowed-tools: Bash(curl *opensearch*), Read, Grep, Glob
---

# Database Operations

## Current Context
!`kubectl config current-context 2>/dev/null || echo "No context set"`

## PostgreSQL

### Connect via kubectl
```bash
NS=<namespace>
kubectl exec -n $NS -it $(kubectl get pods -n $NS -l app=timescale -o jsonpath='{.items[0].metadata.name}') -- psql -U postgres
```

### Common Queries

```sql
-- List databases
\l

-- List tables
\dt

-- Table schema
\d+ table_name

-- Active connections
SELECT pid, usename, application_name, state, query
FROM pg_stat_activity WHERE datname = current_database();

-- Table sizes
SELECT tablename, pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename))
FROM pg_tables WHERE schemaname = 'public' ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC LIMIT 10;

-- Running queries
SELECT pid, now() - pg_stat_activity.query_start AS duration, query, state
FROM pg_stat_activity WHERE state != 'idle' ORDER BY duration DESC;

-- Kill query
SELECT pg_terminate_backend(<pid>);
```

### Service Databases

Document each service's database and key tables here so queries don't require guessing the schema. Example shape:

| Service | Database | Key Tables |
|----------|----------|------------|
| `<service>` | `<db_name>` | `<table1>`, `<table2>`, … |

### Schema Quick Reference

If a service runs a non-default container (e.g. TimescaleDB), pass the container flag:
```bash
kubectl --context $CTX -n $NS exec -c <container> $POD -- psql -U postgres -d <db> -c "..."
```

Capture key tables, columns, PKs and FKs so queries are unambiguous. Example:

```
<table> (id, name, status, created_at/by, updated_at/by)
  PK: id
  UNIQUE: name
  FK: <col> → <other_table>(id)
```

---

## Redis

### Connect via kubectl
```bash
NS=<namespace>
# Get password from configmap first
REDIS_PASS=$(kubectl get configmap cache-config -n $NS -o jsonpath='{.data.REDIS_PASSWORD}')
kubectl exec -n $NS -it $(kubectl get pods -n $NS -l app=cache -o jsonpath='{.items[0].metadata.name}') -- redis-cli -a "$REDIS_PASS"
```

### Common Commands

```bash
# Connection test
PING

# List all keys (careful in prod!)
KEYS *

# Key count
DBSIZE

# Memory usage
INFO memory

# Get key value
GET <key>

# Check key type
TYPE <key>

# TTL
TTL <key>

# Delete key (BLOCKED by hook)
DEL <key>

# Flush database (BLOCKED by hook)
FLUSHDB
```

### Key Patterns

| Service | Key Pattern | Purpose |
|----------|-------------|---------|
| `<service>` | `cache:*`, `session:*` | Cache / sessions |

---

## OpenSearch

### Connect via kubectl
```bash
NS=<namespace>
kubectl exec -n $NS -it $(kubectl get pods -n $NS -l app=opensearch -o jsonpath='{.items[0].metadata.name}') -- curl -s localhost:9200
```

### Common Queries

```bash
# Cluster health
curl -s localhost:9200/_cluster/health?pretty

# List indices
curl -s localhost:9200/_cat/indices?v

# Index stats
curl -s localhost:9200/<index>/_stats?pretty

# Search
curl -s localhost:9200/<index>/_search?pretty -H "Content-Type: application/json" -d '{
  "query": {"match_all": {}},
  "size": 10
}'

# Count documents
curl -s localhost:9200/<index>/_count

# Delete index (BLOCKED by hook)
curl -X DELETE localhost:9200/<index>
```

### Index Patterns

| Service | Index Pattern | Content |
|----------|---------------|---------|
| `<service>` | `<index>-*` | Logs / events (daily rotation: `<index>-YYYYMMDD`) |

---

## Quick Reference

```bash
# One-liner: PostgreSQL query
kubectl exec -n $NS -it $(kubectl get pods -n $NS -l app=timescale -o jsonpath='{.items[0].metadata.name}') -- psql -U postgres -d <db> -c "SELECT count(*) FROM <table>"

# One-liner: Redis GET
kubectl exec -n $NS $(kubectl get pods -n $NS -l app=cache -o jsonpath='{.items[0].metadata.name}') -- redis-cli -a '<pass>' GET <key>

# One-liner: OpenSearch health
kubectl exec -n $NS $(kubectl get pods -n $NS -l app=opensearch -o jsonpath='{.items[0].metadata.name}') -- curl -s localhost:9200/_cluster/health
```
