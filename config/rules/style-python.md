---
paths:
  - "**/*.py"
---

# Python Code Style (Auto-loaded for .py files)

## Formatting
- Line length: 100
- Use `black`, `isort`, `ruff`

## Naming
- Files: `snake_case.py`
- Classes: `PascalCase`
- Functions/variables: `snake_case`
- Constants: `UPPER_SNAKE`

## Patterns
- Prefer `async def` for I/O operations
- Use `pydantic` for validation
- Use `pydantic-settings` for config
- Celery tasks: sync function with `asyncio.run()` inside

## Async/Worker Patterns
- Vector embeddings: match your store's configured dimension (e.g. 768 / 1536)
- Don't pass DB sessions to Celery tasks — pass IDs and re-fetch inside the task
