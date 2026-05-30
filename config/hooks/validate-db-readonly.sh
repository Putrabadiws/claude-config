#!/bin/bash
# Validates that database commands are read-only
# Used by db-analyst agent and general DB safety
# Exit 2 = block command, Exit 0 = allow command
source "$(dirname "$0")/path-bootstrap.sh"

# Check if jq is available
if ! command -v jq &> /dev/null; then
  echo "Warning: jq not found, skipping validation" >&2
  exit 0
fi

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

if [ -z "$COMMAND" ]; then
  exit 0
fi

# Early exit: Skip if command doesn't involve database tools
# Check the actual command binary (first token of each piped/chained segment), not arguments/descriptions
# This prevents false positives when DB keywords appear in heredocs, strings, or descriptions
# e.g., `glab mr create --description "...test psql..."` should NOT trigger this hook
CMD_TOKENS=$(echo "$COMMAND" | tr '|&;' '\n' | sed 's/^[[:space:]]*//' | awk '{print $1}' | tr '\n' ' ')
IS_DB_TOOL=false
if echo "$CMD_TOKENS" | grep -qiE '\b(psql|redis-cli|mongo|mongosh)\b'; then
  IS_DB_TOOL=true
fi
# For curl, check the full command for DB port patterns (port is in args, not the binary name)
if echo "$CMD_TOKENS" | grep -qiE '\bcurl\b' && echo "$COMMAND" | grep -qiE '(\b9200\b|\b9300\b|opensearch|elasticsearch)'; then
  IS_DB_TOOL=true
fi
if [ "$IS_DB_TOOL" = false ]; then
  exit 0
fi

# For piped commands (curl ... | python3/jq/etc), only validate the DB portion before the pipe
# This avoids false positives from Python .replace(), json processing, etc.
DB_COMMAND="$COMMAND"
if echo "$COMMAND" | grep -qE '\|'; then
  DB_COMMAND=$(echo "$COMMAND" | sed 's/|.*//')
fi

# Block SQL write operations (case-insensitive)
# Covers: INSERT, UPDATE, DELETE, DROP, CREATE, ALTER, TRUNCATE, REPLACE, MERGE, GRANT, REVOKE
if echo "$DB_COMMAND" | grep -qiE '\b(INSERT|UPDATE|DELETE|DROP|CREATE|ALTER|TRUNCATE|REPLACE|MERGE|GRANT|REVOKE)\b'; then
  echo "⛔ SQL write blocked — SELECT only" >&2
  exit 2
fi

# Block Redis write commands
# SET variants, DELETE, FLUSH, LIST/SET/HASH modifications
if echo "$COMMAND" | grep -qiE '\b(SET|SETNX|SETEX|PSETEX|MSET|DEL|UNLINK|FLUSHDB|FLUSHALL|EXPIRE|EXPIREAT|PEXPIRE|RENAME|RENAMENX|LPUSH|RPUSH|LPOP|RPOP|LSET|LREM|SADD|SREM|SPOP|SMOVE|ZADD|ZREM|ZINCRBY|HSET|HSETNX|HMSET|HDEL|HINCRBY|INCR|DECR|INCRBY|DECRBY|APPEND)\b'; then
  echo "⛔ Redis write blocked — read-only (GET/KEYS/SCAN/HGET/SMEMBERS)" >&2
  exit 2
fi

# Block OpenSearch/Elasticsearch write operations
if echo "$COMMAND" | grep -qiE '(-X\s*(PUT|POST|DELETE)|_bulk|_delete|_update|_reindex|_create)'; then
  echo "⛔ OpenSearch write blocked — GET/_search/_cat only" >&2
  exit 2
fi

# Block MongoDB write operations
if echo "$COMMAND" | grep -qiE '\.(insert|update|delete|remove|drop|createIndex|dropIndex|createCollection)\s*\('; then
  echo "⛔ MongoDB write blocked — find/aggregate only" >&2
  exit 2
fi

exit 0
