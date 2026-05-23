#!/bin/bash
# Tests for validate-db-readonly.sh
# Run: bash ~/.claude/hooks/validate-db-readonly.test.sh

source "$HOME/.claude/_lib/test-helpers.sh"
HOOK="$(_test_script_dir "$0")/validate-db-readonly.sh"
_require_executable "$HOOK"

# Allow-cases (must NOT block — non-DB or read-only DB)
run_test "allow non-DB command"                    'ls /tmp' 0
run_test "allow psql SELECT"                       'psql -c "SELECT * FROM users"' 0
run_test "allow redis-cli GET"                     'redis-cli GET mykey' 0
run_test "allow redis-cli KEYS"                    'redis-cli KEYS "user:*"' 0
run_test "allow curl GET to opensearch"            'curl -X GET http://localhost:9200/_cat/indices' 0
run_test "allow MR description mentioning DROP"    'glab mr create --description "we replaced DROP TABLE with soft delete"' 0

# Block-cases (must block, rc=2 — DB write operations)
run_test "block psql INSERT"                       'psql -c "INSERT INTO users VALUES (1)"' 2
run_test "block psql UPDATE"                       'psql -c "UPDATE users SET x=1"' 2
run_test "block psql DELETE"                       'psql -c "DELETE FROM users"' 2
run_test "block psql DROP TABLE"                   'psql -c "DROP TABLE users"' 2
run_test "block redis-cli SET"                     'redis-cli SET key value' 2
run_test "block redis-cli DEL"                     'redis-cli DEL key' 2
run_test "block redis-cli FLUSHALL"                'redis-cli FLUSHALL' 2
run_test "block opensearch DELETE"                 'curl -X DELETE http://localhost:9200/index/_doc/1' 2
run_test "block opensearch POST _bulk"             'curl -X POST http://localhost:9200/_bulk -d @file' 2
run_test "block mongo insert"                      'mongosh --eval "db.users.insert({x:1})"' 2

# Edge cases
run_test "empty command"                           '' 0
run_test "psql with pipe to python"                'psql -c "SELECT id FROM users" | python3 -c "import sys; print(sys.stdin.read().replace(\"a\",\"b\"))"' 0

# Regression: curl to non-DB endpoint must not trigger IS_DB_TOOL via substring port match.
# `2592000` (Keycloak clientSessionMaxLifespan) contains substring `9200` — must be skipped
# by \b9200\b anchoring. If this regresses, downstream SQL/Redis keyword checks fire on the
# echo banners that follow the first pipe (sed strips per-line, not whole command).
run_test "allow curl Keycloak with 2592000 lifespan" 'curl -X PUT https://sso.example.com/admin/realms/foo -d {"attributes":{"clientSessionMaxLifespan":"2592000"}}; echo "=== Update poc-test realm ==="' 0
run_test "allow curl with port-like substring 192000" 'curl -X GET https://api.example.com/x?ttl=192000' 0

summary
