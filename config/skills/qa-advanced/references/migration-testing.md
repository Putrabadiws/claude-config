# Database Migration Testing

## Why it matters

Migrations that work in dev frequently break in production due to:
- Table locks on large tables
- Default values applied differently
- Index creation timing
- Rollback assumptions

## Liquibase (Java/Spring — Orion, Corvus, Aman)

```java
// tests/integration/migrations/AddDeviceBlockedColumnTest.java
@SpringBootTest
class AddDeviceBlockedColumnTest {

    @Autowired private JdbcTemplate jdbc;

    @Test
    @DisplayName("should add blocked column with correct default")
    void shouldAddBlockedColumnWithCorrectDefault() {
        // Verify column exists with correct default
        var result = jdbc.queryForObject(
            "SELECT column_default FROM information_schema.columns " +
            "WHERE table_name = 'devices' AND column_name = 'blocked'",
            String.class);
        assertThat(result).contains("false");
    }

    @Test
    @DisplayName("should not break existing rows")
    void shouldNotBreakExistingRows() {
        var devices = jdbc.queryForList("SELECT blocked FROM devices");
        assertThat(devices).allSatisfy(row ->
            assertThat(row.get("blocked")).isEqualTo(false));
    }
}
```

## Alembic (Python/FastAPI — Bron AI backend-fates)

```python
# tests/integration/test_migrations.py
def test_migration_adds_blocked_column(engine):
    from alembic.command import downgrade, upgrade
    from alembic.config import Config

    alembic_cfg = Config("alembic.ini")

    # Rollback to previous
    downgrade(alembic_cfg, "-1")
    inspector = inspect(engine)
    cols = [c["name"] for c in inspector.get_columns("devices")]
    assert "blocked" not in cols

    # Apply migration
    upgrade(alembic_cfg, "+1")
    cols = [c["name"] for c in inspector.get_columns("devices")]
    assert "blocked" in cols

def test_rollback_removes_column_cleanly(engine):
    from alembic.command import downgrade
    alembic_cfg = Config("alembic.ini")
    downgrade(alembic_cfg, "-1")

    inspector = inspect(engine)
    cols = [c["name"] for c in inspector.get_columns("devices")]
    assert "blocked" not in cols
```

## Migration test checklist

- [ ] Column/table created correctly
- [ ] Default values applied to existing rows
- [ ] Rollback works cleanly
- [ ] Migration runs on non-empty table without lock timeout
- [ ] Indexes created correctly
- [ ] Foreign key constraints applied correctly
