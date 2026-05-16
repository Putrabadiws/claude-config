# Java/Spring Boot Test Reference (JUnit 5 + Mockito)

Patterns and best practices for Java unit tests, integration tests, and error assertions.

## Unit Tests

**Owner**: Dev (reviews AI draft)
**Rules**: One assertion focus per test, mock all I/O, no inter-test dependencies

```java
// Integration test pattern — BaseControllerTests
@SpringBootTest
@AutoConfigureMockMvc(addFilters = false)
class AlertControllerTest extends BaseControllerTests {

    @MockBean
    private AlertServices alertServices;

    @Test
    @DisplayName("should return alerts for company")
    void shouldReturnAlertsForCompany() {
        // Mock AuthContextHolder for company context
        mockAuthContext("company-123", "ANALYST");

        when(alertServices.getAlerts(any(), any()))
            .thenReturn(new MessageResponseWithData<>(true, "Success", alertList));

        mockMvc.perform(get("/api/v1/alerts")
                .header("Company-Id", "company-123"))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.success").value(true))
            .andExpect(jsonPath("$.data").isArray());
    }
}

// Pure unit test — no Spring context
@ExtendWith(MockitoExtension.class)
class AlertServiceTest {

    @Mock
    private AlertRepository alertRepository;

    @InjectMocks
    private AlertServicesImpl alertServices;

    @Test
    @DisplayName("should emit event when alert created")
    void shouldEmitEventWhenAlertCreated() {
        when(alertRepository.save(any())).thenReturn(savedAlert);

        alertServices.createAlert(requestDTO);

        verify(alertRepository).save(any());
        verify(rabbitTemplate).convertAndSend(eq("alert.created"), any());
    }
}
```

---

## Integration Tests

```java
@SpringBootTest
@AutoConfigureMockMvc(addFilters = false)
@Transactional
class AlertIntegrationTest extends BaseControllerTests {

    @Autowired
    private AlertRepository alertRepository;

    @Test
    @DisplayName("should persist alert and return 201")
    void shouldPersistAlertAndReturn201() {
        mockAuthContext("company-123", "ADMIN");

        mockMvc.perform(post("/api/v1/alerts")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(createAlertRequest)))
            .andExpect(status().isCreated());

        // Verify side effect: DB state
        List<Alert> alerts = alertRepository.findAll();
        assertThat(alerts).hasSize(1);
        assertThat(alerts.get(0).getCompanyId()).isEqualTo("company-123");
    }
}
```

---

## Error Assertions

```java
// Bad — doesn't verify the right exception
assertThrows(Exception.class, () -> service.validate(""));

// Good — verifies type and message
ValidationException ex = assertThrows(ValidationException.class,
    () -> service.validate(""));
assertThat(ex.getMessage()).contains("email is required");
```
