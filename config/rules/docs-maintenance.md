# Documentation Maintenance

When making code changes, ALWAYS check if documentation needs updating.
Update docs in the SAME commit as code changes.

## Triggers

| Change Type | Update |
|-------------|--------|
| New/modified API endpoints | `docs/api/` |
| Schema changes | `docs/database/` |
| New service/component | `docs/architecture/` |
| Changed data flow | `docs/data-flows/` |
| New integration | `docs/architecture/communication-patterns.md` |
| Config changes | `docs/configuration/` |
| Deployment changes | `docs/deployment/` |
| Dev setup changes | `docs/development/` |
| Security changes | `docs/security/` |
| New issues/fixes | `docs/troubleshooting/` |
| Mobile app changes | `docs/mobile/` |
| Redis key changes | `docs/database/redis-keys.md` |

## Rules

- If in submodule, docs are at `../docs/`
- Each doc directory has a `README.md` entry point — update it if adding/removing files
- Keep docs comprehensive and detailed — match existing depth
- Don't ask permission, just update if relevant
- If unsure which doc to update, check `docs/README.md` for the directory map

## After Every Code Change

1. List which doc directories might be affected
2. Update the specific file(s) within those directories
3. Summarize doc changes at end of response

## Documentation Structure

Docs are organized by topic in subdirectories under `docs/`:

| Directory | Content |
|-----------|---------|
| `architecture/` | System design, identity model, service boundaries |
| `api/` | REST API reference per domain |
| `database/` | Schemas, indices, key/value layouts |
| `data-flows/` | Sequence diagrams for data flows |
| `configuration/` | Environment variables per service |
| `deployment/` | Docker, Kubernetes, CI/CD, scaling |
| `security/` | Authentication, authorization |
| `development/` | Local setup, building, testing, coding standards |
| `troubleshooting/` | Per-domain operational debugging |
| `release-notes/` | Release notes per version |
| `research/` | Investigations, prototypes |
