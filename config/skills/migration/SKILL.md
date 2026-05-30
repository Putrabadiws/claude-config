---
name: migration
description: Database migrations - Liquibase, Alembic, schema changes, rollback, migration status.
disable-model-invocation: true
argument-hint: [action: status|create|run|rollback] [service]
allowed-tools: Bash(./mvnw *), Bash(alembic *), Bash(liquibase *), Read, Glob
---

# Database Migration Guide

## Requested Action
Action: `$0` | Service: `$1`

## Current Context
!`git branch --show-current 2>/dev/null`
!`ls -la src/main/resources/db/changelog/ 2>/dev/null | tail -5 || ls -la alembic/versions/ 2>/dev/null | tail -5 || echo "No migration folder found"`

## Overview

| Stack | Tool | Location |
|-------|------|----------|
| Java/Spring | Liquibase | `src/main/resources/db/changelog/` |
| Python/FastAPI | Alembic | `alembic/versions/` |
| Node/TypeScript | Prisma / Knex | `prisma/migrations/` or `migrations/` |

## Templates

- **Liquibase**: [templates/liquibase-changeset.xml](templates/liquibase-changeset.xml)
- **Alembic**: [templates/alembic-migration.py](templates/alembic-migration.py)

---

## Liquibase (Java/Spring)

### Create New Migration

1. Create file in `src/main/resources/db/changelog/changes/`
2. Use template from [templates/liquibase-changeset.xml](templates/liquibase-changeset.xml)
3. Add include to master changelog

### Commands

```bash
# Run migrations (happens automatically on startup)
./mvnw spring-boot:run

# Manual run
./mvnw liquibase:update

# Rollback last N changes
./mvnw liquibase:rollback -Dliquibase.rollbackCount=1

# Generate SQL (dry run)
./mvnw liquibase:updateSQL

# Status
./mvnw liquibase:status
```

---

## Alembic (Python/FastAPI)

### Create New Migration

```bash
cd backend-fates
source venv/bin/activate        # macOS/Linux
source venv/Scripts/activate    # Windows (Git Bash)

# Auto-generate from model changes
alembic revision --autogenerate -m "add documents table"

# Empty migration (manual)
alembic revision -m "add custom index"
```

Use template from [templates/alembic-migration.py](templates/alembic-migration.py) as reference.

### Commands

```bash
alembic current          # Current revision
alembic history          # Migration history
alembic upgrade head     # Upgrade to latest
alembic upgrade +1       # Upgrade one step
alembic downgrade -1     # Downgrade one step
alembic upgrade head --sql  # Show SQL (dry run)
```

---

## Best Practices

### DO
- Always include rollback/downgrade
- Test migrations on dev before staging/prod
- Use meaningful changeset IDs (ticket number + description)
- One logical change per migration
- Backup database before production migrations

### DON'T
- Modify existing changesets (create new ones)
- Delete migration files
- Skip migrations in sequence
- Run untested migrations in production

---

## Troubleshooting

### Liquibase

| Issue | Solution |
|-------|----------|
| Checksum mismatch | `./mvnw liquibase:clearCheckSums` |
| Lock stuck | `DELETE FROM databasechangeloglock WHERE locked = true;` |

### Alembic

| Issue | Solution |
|-------|----------|
| Multiple heads | `alembic merge heads -m "merge"` |
| Revision not found | Check `alembic_version` table |

---

## Emergency Rollback

```bash
# Liquibase
./mvnw liquibase:rollback -Dliquibase.rollbackCount=1

# Alembic
alembic downgrade -1

# Manual restore
pg_restore -h <host> -U <user> -d <db> <backup-file>
```
