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

### Platform-Specific

| Platform | Database | Key Tables |
|----------|----------|------------|
| Orion | `ib_soc_mdr` | `alerts`, `cases`, `companies`, `users` |
| Corvus | `corvus` | `reports`, `iocs`, `feeds` |
| Aman | `internet-aman` | `categories`, `category_sources`, `blocklist`, `whitelist_sources`, `whitelists`, `user_categories`, `user_domains`, `parental_apps`, `parental_app_domains`, `user_parental_apps`, `user_parental_app_schedules`, `log_activities` |
| Aman | `dns` | `licenses`, `devices`, `profiles`, `companies`, `company_topups`, `profile_licenses` |
| Bron AI | `fates`, `aegis`, `audit` | `documents`, `agents`, `api_keys` |

### Aman Schema Quick Reference

TimescaleDB pod requires `-c timescale` container flag:
```bash
kubectl --context $CTX -n $NS exec -c timescale $TS_POD -- psql -U postgres -d internet-aman -c "..."
```

Key tables and their columns:

```
categories (id, name, severity, description, created_at/by, updated_at/by)
  PK: id
  UNIQUE: name

category_sources (id, category_id, source_type, end_point, status, content_hash, created_at/by, updated_at/by)
  PK: (id, category_id)
  FK: category_id → categories(id)
  status: 'Active' | 'Inactive'

blocklist (domain, category, category_source_id)
  PK: (domain, category, category_source_id)
  FK: category → categories(id)
  -- same domain can appear in multiple categories/sources

whitelist_sources (id, source_type, end_point, status, content_hash, created_at/by, updated_at/by)

whitelists (domain, whitelist_source_id)
```

Common Aman queries:
```sql
-- List all category sources with category names
SELECT cs.id, cs.source_type, cs.end_point, cs.status, cs.content_hash, c.name AS category, c.severity
FROM category_sources cs JOIN categories c ON cs.category_id = c.id
ORDER BY c.name, cs.id;

-- Blocklist count by category/source
SELECT category, category_source_id, count(*) FROM blocklist
GROUP BY category, category_source_id ORDER BY category, category_source_id;

-- Total unique blocked domains
SELECT count(DISTINCT domain) FROM blocklist;
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

### Platform Key Patterns

| Platform | Key Pattern | Purpose |
|----------|-------------|---------|
| Orion | `alert:*`, `sensor:*`, `company:*` | Cache |
| Aman | `dns-blocked:*`, `trust-domain:*`, `parental:*` | DNS filtering |
| Bron AI | `session:*`, `quota:*`, `metrics:*` | Sessions/quotas |

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

### Platform Indices

| Platform | Index Pattern | Content |
|----------|---------------|---------|
| Orion | `arkime_sessions3-*` | Network sessions |
| Orion | `mdr-alerts-*` | Alert data |
| Aman | `dns_request-*` | DNS query logs (daily: `dns_request-YYYYMMDD`) |
| Aman | `dns_events-*` | DNS on/off events (daily) |
| Aman | `top_queries-*` | Top query aggregations (daily) |
| Bron AI | `bron-metrics-*` | Usage metrics |

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
