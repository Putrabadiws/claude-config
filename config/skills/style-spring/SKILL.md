---
name: style-spring
description: Java/Spring Boot code style - controllers, services, repositories, DTOs, validation.
user-invocable: false
---

# Java/Spring Boot Style Guide

## Formatting

- **Indentation**: 4 spaces
- **Line length**: 120 characters max
- **Braces**: Same line for methods/classes

```java
public class AlertController {

    @GetMapping("/alerts")
    public ResponseEntity<List<Alert>> getAlerts() {
        return ResponseEntity.ok(alertService.findAll());
    }
}
```

## Package Structure

```
com.example.<service>/
├── controllers/          # REST endpoints
├── services/             # Business logic
│   ├── AlertServices.java       # Interface
│   └── impl/
│       └── AlertServicesImpl.java
├── repositories/         # JPA repositories
├── models/               # JPA entities
├── dto/
│   ├── request/          # Request DTOs
│   └── response/         # Response DTOs
├── components/           # Shared components
├── config/               # Configuration classes
├── security/             # Auth filters
└── exceptions/           # Custom exceptions
```

## Naming Conventions

```java
// Classes: PascalCase
public class AlertController {}
public class AlertServices {}        // Interface with 's'
public class AlertServicesImpl {}    // Implementation

// Methods: camelCase
public Alert findById(String id) {}
public List<Alert> findAllByCompany(String companyId) {}

// Variables: camelCase
private final AlertServices alertServices;
private String alertId;

// Constants: UPPER_SNAKE
public static final String DEFAULT_PAGE_SIZE = "20";
private static final int MAX_RETRIES = 3;

// DTOs: PascalCase with suffix
public class AlertRequestDTO {}
public class AlertResponseDTO {}
public class PageMetadataResponse {}
```

## Controller Pattern

```java
@RestController
@RequestMapping("/api/v1/alerts")
@RequiredArgsConstructor
@PreAuthorize("hasAnyAuthority('Admin', 'Analyst', 'Supervisor')")
public class AlertController {

    private final AlertServices alertServices;

    @GetMapping
    public ResponseEntity<MessageResponseWithData<AlertResponseDTO>> getAlerts(
            @RequestParam(defaultValue = "1") int page,
            @RequestParam(defaultValue = "20") int size) {

        var alerts = alertServices.findAll(page, size);
        return ResponseEntity.ok(MessageResponseWithData.success(alerts));
    }

    @GetMapping("/{id}")
    public ResponseEntity<MessageResponseWithData<AlertResponseDTO>> getAlert(
            @PathVariable String id) {

        var alert = alertServices.findById(id);
        return ResponseEntity.ok(MessageResponseWithData.success(alert));
    }

    @PostMapping
    public ResponseEntity<MessageResponse> createAlert(
            @Valid @RequestBody AlertRequestDTO request) {

        alertServices.create(request);
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(MessageResponse.success("Alert created"));
    }
}
```

## Service Pattern

```java
// Interface
public interface AlertServices {
    List<AlertResponseDTO> findAll(int page, int size);
    AlertResponseDTO findById(String id);
    void create(AlertRequestDTO request);
}

// Implementation
@Service
@RequiredArgsConstructor
@Slf4j
public class AlertServicesImpl implements AlertServices {

    private final AlertRepository alertRepository;
    private final AlertMapper alertMapper;

    @Override
    public List<AlertResponseDTO> findAll(int page, int size) {
        var pageable = PageRequest.of(page - 1, size);  // 1-indexed to 0-indexed
        var alerts = alertRepository.findAll(pageable);
        return alerts.map(alertMapper::toResponse).getContent();
    }

    @Override
    public AlertResponseDTO findById(String id) {
        var alert = alertRepository.findById(id)
                .orElseThrow(() -> new NotFoundException("Alert not found: " + id));
        return alertMapper.toResponse(alert);
    }

    @Override
    @Transactional
    public void create(AlertRequestDTO request) {
        var alert = alertMapper.toEntity(request);
        alertRepository.save(alert);
        log.info("Created alert: {}", alert.getId());
    }
}
```

## Repository Pattern

```java
@Repository
public interface AlertRepository extends JpaRepository<Alert, String> {

    List<Alert> findByCompanyId(String companyId);

    @Query("SELECT a FROM Alert a WHERE a.severity = :severity AND a.status = :status")
    List<Alert> findBySeverityAndStatus(
            @Param("severity") String severity,
            @Param("status") String status);

    @Query(value = "SELECT * FROM alerts WHERE created_at > :date", nativeQuery = true)
    List<Alert> findRecentAlerts(@Param("date") LocalDateTime date);
}
```

## DTO Pattern

```java
// Request DTO with validation
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class AlertRequestDTO {

    @NotBlank(message = "Title is required")
    private String title;

    @NotNull(message = "Severity is required")
    private AlertSeverity severity;

    @Size(max = 1000, message = "Description max 1000 characters")
    private String description;
}

// Response DTO
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class AlertResponseDTO {
    private String id;
    private String title;
    private AlertSeverity severity;
    private String description;
    private LocalDateTime createdAt;
}
```

## Standard Response Format

```java
// Base response
@Data
@AllArgsConstructor
public class MessageResponse {
    private boolean success;
    private String message;

    public static MessageResponse success(String message) {
        return new MessageResponse(true, message);
    }
}

// Response with data
@Data
@AllArgsConstructor
public class MessageResponseWithData<T> {
    private boolean success;
    private String message;
    private List<T> data;

    public static <T> MessageResponseWithData<T> success(List<T> data) {
        return new MessageResponseWithData<>(true, "Success", data);
    }
}
```

## Exception Handling

```java
// Custom exception
public class NotFoundException extends RuntimeException {
    public NotFoundException(String message) {
        super(message);
    }
}

// Global handler
@RestControllerAdvice
public class GlobalExceptionHandler {

    @ExceptionHandler(NotFoundException.class)
    public ResponseEntity<MessageResponse> handleNotFound(NotFoundException ex) {
        return ResponseEntity.status(HttpStatus.NOT_FOUND)
                .body(new MessageResponse(false, ex.getMessage()));
    }

    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ResponseEntity<MessageResponse> handleValidation(MethodArgumentNotValidException ex) {
        var errors = ex.getBindingResult().getFieldErrors().stream()
                .map(FieldError::getDefaultMessage)
                .collect(Collectors.joining(", "));
        return ResponseEntity.badRequest()
                .body(new MessageResponse(false, errors));
    }
}
```

## Common Annotations

```java
// Lombok
@Data                    // Getters, setters, toString, equals, hashCode
@Builder                 // Builder pattern
@RequiredArgsConstructor // Constructor for final fields
@Slf4j                   // Logger

// Spring
@Service                 // Service bean
@Repository              // Repository bean
@RestController          // REST controller
@Transactional           // Transaction boundary

// Validation
@NotNull, @NotBlank, @NotEmpty
@Size(min = 1, max = 100)
@Email, @Pattern(regexp = "...")
@Valid                   // Trigger validation
```

## Pagination

```java
// Controller (1-indexed for users)
@GetMapping
public ResponseEntity<?> getAlerts(
        @RequestParam(defaultValue = "1") int page,
        @RequestParam(defaultValue = "20") int size) {
    // ...
}

// Service (convert to 0-indexed for Spring Data)
var pageable = PageRequest.of(page - 1, size, Sort.by("createdAt").descending());
var result = repository.findAll(pageable);
```
