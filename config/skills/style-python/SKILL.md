---
name: style-python
description: Python/FastAPI code style - async patterns, Pydantic, SQLAlchemy, service structure.
user-invocable: false
---

# Python/FastAPI Style Guide

## Formatting Tools

```toml
# pyproject.toml
[tool.black]
line-length = 100
target-version = ["py311"]

[tool.isort]
profile = "black"
line_length = 100

[tool.ruff]
line-length = 100
target-version = "py311"
```

**Key rules:**
- Line length: 100 characters
- Python 3.11+
- Black + isort + ruff for formatting/linting

## Project Structure

```
service/
├── app/
│   ├── __init__.py
│   ├── main.py              # FastAPI app entry
│   ├── api/
│   │   └── v1/
│   │       ├── __init__.py
│   │       ├── router.py    # Route aggregation
│   │       └── endpoints/   # Route handlers
│   ├── core/
│   │   ├── config.py        # Settings (pydantic-settings)
│   │   ├── security.py      # Auth utilities
│   │   └── database.py      # DB session
│   ├── models/              # SQLAlchemy models
│   ├── schemas/             # Pydantic schemas
│   ├── services/            # Business logic
│   ├── repositories/        # Data access
│   └── utils/               # Helpers
├── tests/
├── alembic/                 # Migrations
├── pyproject.toml
└── requirements.txt
```

## Naming Conventions

```python
# Files: snake_case
alert_service.py
user_repository.py

# Classes: PascalCase
class AlertService:
class UserRepository:
class AlertResponse:  # Pydantic schema

# Functions/methods: snake_case
def get_alert_by_id(alert_id: str) -> Alert:
async def fetch_alerts() -> list[Alert]:

# Variables: snake_case
alert_count = 0
current_user = None

# Constants: UPPER_SNAKE
MAX_RETRIES = 3
DEFAULT_PAGE_SIZE = 20

# Private: leading underscore
def _internal_helper():
_cached_value = None
```

## FastAPI Endpoint Pattern

```python
from fastapi import APIRouter, Depends, HTTPException, status
from app.schemas.alert import AlertCreate, AlertResponse
from app.services.alert_service import AlertService
from app.core.deps import get_current_user, get_alert_service

router = APIRouter(prefix="/alerts", tags=["alerts"])


@router.get("/", response_model=list[AlertResponse])
async def get_alerts(
    page: int = 1,
    size: int = 20,
    service: AlertService = Depends(get_alert_service),
    current_user: User = Depends(get_current_user),
) -> list[AlertResponse]:
    """Get paginated alerts."""
    return await service.get_all(page=page, size=size, user=current_user)


@router.get("/{alert_id}", response_model=AlertResponse)
async def get_alert(
    alert_id: str,
    service: AlertService = Depends(get_alert_service),
) -> AlertResponse:
    """Get alert by ID."""
    alert = await service.get_by_id(alert_id)
    if not alert:
        raise HTTPException(status_code=404, detail="Alert not found")
    return alert


@router.post("/", response_model=AlertResponse, status_code=status.HTTP_201_CREATED)
async def create_alert(
    data: AlertCreate,
    service: AlertService = Depends(get_alert_service),
    current_user: User = Depends(get_current_user),
) -> AlertResponse:
    """Create new alert."""
    return await service.create(data, created_by=current_user.id)
```

## Pydantic Schema Pattern

```python
from pydantic import BaseModel, Field, ConfigDict
from datetime import datetime
from enum import Enum


class AlertSeverity(str, Enum):
    LOW = "low"
    MEDIUM = "medium"
    HIGH = "high"
    CRITICAL = "critical"


class AlertBase(BaseModel):
    title: str = Field(..., min_length=1, max_length=255)
    description: str | None = Field(None, max_length=1000)
    severity: AlertSeverity


class AlertCreate(AlertBase):
    pass


class AlertUpdate(BaseModel):
    title: str | None = None
    description: str | None = None
    severity: AlertSeverity | None = None


class AlertResponse(AlertBase):
    id: str
    created_at: datetime
    updated_at: datetime | None = None

    model_config = ConfigDict(from_attributes=True)
```

## Service Pattern

```python
from app.repositories.alert_repository import AlertRepository
from app.schemas.alert import AlertCreate, AlertResponse


class AlertService:
    def __init__(self, repository: AlertRepository):
        self.repository = repository

    async def get_all(
        self, page: int = 1, size: int = 20, user: User | None = None
    ) -> list[AlertResponse]:
        offset = (page - 1) * size
        alerts = await self.repository.find_all(offset=offset, limit=size)
        return [AlertResponse.model_validate(a) for a in alerts]

    async def get_by_id(self, alert_id: str) -> AlertResponse | None:
        alert = await self.repository.find_by_id(alert_id)
        if alert:
            return AlertResponse.model_validate(alert)
        return None

    async def create(self, data: AlertCreate, created_by: str) -> AlertResponse:
        alert = await self.repository.create(
            title=data.title,
            description=data.description,
            severity=data.severity,
            created_by=created_by,
        )
        return AlertResponse.model_validate(alert)
```

## Repository Pattern

```python
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from app.models.alert import Alert


class AlertRepository:
    def __init__(self, session: AsyncSession):
        self.session = session

    async def find_all(self, offset: int = 0, limit: int = 20) -> list[Alert]:
        query = select(Alert).offset(offset).limit(limit).order_by(Alert.created_at.desc())
        result = await self.session.execute(query)
        return list(result.scalars().all())

    async def find_by_id(self, alert_id: str) -> Alert | None:
        query = select(Alert).where(Alert.id == alert_id)
        result = await self.session.execute(query)
        return result.scalar_one_or_none()

    async def create(self, **kwargs) -> Alert:
        alert = Alert(**kwargs)
        self.session.add(alert)
        await self.session.commit()
        await self.session.refresh(alert)
        return alert
```

## SQLAlchemy Model Pattern

```python
from sqlalchemy import Column, String, DateTime, Enum
from sqlalchemy.sql import func
from app.core.database import Base
import enum


class AlertSeverity(enum.Enum):
    LOW = "low"
    MEDIUM = "medium"
    HIGH = "high"
    CRITICAL = "critical"


class Alert(Base):
    __tablename__ = "alerts"

    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    title = Column(String(255), nullable=False)
    description = Column(String(1000))
    severity = Column(Enum(AlertSeverity), nullable=False)
    created_at = Column(DateTime, server_default=func.now())
    updated_at = Column(DateTime, onupdate=func.now())
    created_by = Column(String, nullable=False)
```

## Settings Pattern (pydantic-settings)

```python
from pydantic_settings import BaseSettings
from functools import lru_cache


class Settings(BaseSettings):
    app_name: str = "Fates"
    debug: bool = False

    # Database
    postgres_host: str = "localhost"
    postgres_port: int = 5432
    postgres_db: str = "fates"
    postgres_user: str
    postgres_password: str

    # Redis
    redis_host: str = "localhost"
    redis_port: int = 6379
    redis_password: str | None = None

    @property
    def database_url(self) -> str:
        return f"postgresql+asyncpg://{self.postgres_user}:{self.postgres_password}@{self.postgres_host}:{self.postgres_port}/{self.postgres_db}"

    class Config:
        env_file = ".env"
        case_sensitive = False


@lru_cache
def get_settings() -> Settings:
    return Settings()
```

## Async Patterns

```python
# Prefer async for I/O operations
async def fetch_data():
    async with httpx.AsyncClient() as client:
        response = await client.get(url)
        return response.json()

# Use asyncio.gather for concurrent operations
results = await asyncio.gather(
    fetch_alerts(),
    fetch_users(),
    fetch_companies(),
)

# Celery tasks: sync function with asyncio.run()
@celery_app.task
def process_document(doc_id: str):
    asyncio.run(_process_document_async(doc_id))

async def _process_document_async(doc_id: str):
    # Async implementation
    pass
```

## Type Hints

```python
# Always use type hints
def calculate_score(alerts: list[Alert], threshold: float = 0.5) -> float:
    ...

# Use | for union types (Python 3.10+)
def get_user(user_id: str) -> User | None:
    ...

# Use generic types
from collections.abc import Sequence, Mapping

def process_items(items: Sequence[str]) -> Mapping[str, int]:
    ...
```

## Error Handling

```python
from fastapi import HTTPException, status


class NotFoundError(Exception):
    def __init__(self, resource: str, id: str):
        self.resource = resource
        self.id = id
        super().__init__(f"{resource} not found: {id}")


# In endpoint
async def get_alert(alert_id: str):
    alert = await service.get_by_id(alert_id)
    if not alert:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Alert not found: {alert_id}",
        )
    return alert
```
