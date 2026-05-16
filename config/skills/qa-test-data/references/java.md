# Java/Spring Test Data Patterns

## Factory Pattern (JUnit 5)

```java
// testutil/factories/UserFactory.java
public class UserFactory {
    public static User build() {
        return build(Map.of());
    }

    public static User build(Map<String, Object> overrides) {
        String id = UUID.randomUUID().toString();
        User user = new User();
        user.setId((String) overrides.getOrDefault("id", id));
        user.setEmail((String) overrides.getOrDefault("email",
            "test-" + id.substring(0, 8) + "@example.com"));
        user.setRole((String) overrides.getOrDefault("role", "USER"));
        user.setActive((Boolean) overrides.getOrDefault("active", true));
        return user;
    }

    public static User create(UserRepository repo) {
        return create(repo, Map.of());
    }

    public static User create(UserRepository repo, Map<String, Object> overrides) {
        User user = build(overrides);
        return repo.save(user);
    }
}
```

## Factory Usage in Tests

```java
@SpringBootTest
@Transactional  // auto-rollback after each test
class AlertServiceTest {

    @Autowired private UserRepository userRepository;
    @Autowired private AlertRepository alertRepository;

    @Test
    @DisplayName("should create alert for user")
    void shouldCreateAlertForUser() {
        User user = UserFactory.create(userRepository);
        Alert alert = AlertFactory.create(alertRepository,
            Map.of("userId", user.getId(), "companyId", "company-123"));

        // test uses user and alert — fully isolated via @Transactional
        assertThat(alert.getUserId()).isEqualTo(user.getId());
    }
}
```

## Cleanup: Transaction Rollback (Preferred)

```java
@SpringBootTest
@Transactional  // Spring rolls back after each test
class AlertServiceTest {
    // No manual cleanup needed — Spring handles it
}
```

## Parallel Safety

```java
// JUnit: UUID per test is sufficient with @Transactional
String testId = UUID.randomUUID().toString().substring(0, 8);
String email = "test-" + testId + "@example.com";
```

---

## Go (testify)

### Factory Pattern

```go
// testutil/factories/user.go
package factories

import (
    "fmt"
    "testing"
    "github.com/google/uuid"
    "github.com/stretchr/testify/require"
)

type UserFactory struct {
    DB *sql.DB
}

func (f *UserFactory) Create(t *testing.T, overrides map[string]interface{}) *User {
    t.Helper()
    id := uuid.New().String()
    email := fmt.Sprintf("test-%s@example.com", id[:8])

    user := &User{ID: id, Email: email, Role: "user", Active: true}
    // apply overrides...

    _, err := f.DB.Exec(`INSERT INTO users (id, email, role, active) VALUES ($1, $2, $3, $4)`,
        user.ID, user.Email, user.Role, user.Active)
    require.NoError(t, err)

    t.Cleanup(func() {
        f.DB.Exec(`DELETE FROM users WHERE id = $1`, user.ID)
    })

    return user
}
```
