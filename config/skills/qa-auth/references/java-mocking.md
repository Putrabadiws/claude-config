# Java Auth Mocking — Spring Boot Services

## BaseControllerTests Pattern

Used by: Corvus, Orion, Aman Spring Boot services. Disables security filters and provides a MockServer for Keycloak JWKS.

```java
// Used by: Corvus, Orion, Aman Spring Boot services
@SpringBootTest
@AutoConfigureMockMvc(addFilters = false)  // Disable security filters
public abstract class BaseControllerTests {

    @Autowired
    protected MockMvc mockMvc;

    // MockServer for Keycloak JWKS at port 3001
    protected static ClientAndServer mockServer;

    @BeforeAll
    static void startMockServer() {
        mockServer = ClientAndServer.startClientAndServer(3001);
        // Configure JWKS endpoint response
        mockServer.when(request().withPath("/realms/mdr-dev/protocol/openid-connect/certs"))
            .respond(response().withBody(DUMMY_JWKS_JSON));
    }

    protected void mockAuthContext(String companyId, String role) {
        // Mock AuthContextHolder to return test company/user
        // Implementation varies by service
    }
}
```

## Pure Unit Test Auth Mocking

Use Mockito `mockStatic` for `AuthContextHolder` in unit tests that don't need Spring context.

```java
@ExtendWith(MockitoExtension.class)
class AlertServiceTest {

    @BeforeEach
    void setupAuth() {
        // Mock static AuthContextHolder
        try (var mocked = mockStatic(AuthContextHolder.class)) {
            mocked.when(AuthContextHolder::getCurrentCompany)
                .thenReturn("test-company-123");
            mocked.when(AuthContextHolder::getPrincipal)
                .thenReturn(new TestPrincipal("user-123", "ANALYST"));
        }
    }
}
```

## Multi-Tenant Cross-Access Test

Verify tenant isolation at the controller level using `mockAuthContext`.

```java
@Test
@DisplayName("should reject cross-tenant access")
void shouldRejectCrossTenantAccess() throws Exception {
    mockAuthContext("company-A", "ANALYST");

    mockMvc.perform(get("/api/v1/alerts")
            .header("Company-Id", "company-B"))
        .andExpect(status().isForbidden());
}
```
