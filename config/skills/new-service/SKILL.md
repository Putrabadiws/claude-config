---
name: new-service
description: Scaffold new microservice with structure, configs, boilerplate. Types: spring, fastapi, nextjs, react.
disable-model-invocation: true
argument-hint: [service-name] [type: spring|fastapi|nextjs|react]
allowed-tools: Read, Glob
---

# New Service Scaffolding

## Requested
- Service name: `$0`
- Type: `$1`

## Service Types

| Type | Stack | Use Case |
|------|-------|----------|
| `spring` | Java 17, Spring Boot 3.3, Maven | Backend API services |
| `fastapi` | Python 3.11, FastAPI, SQLAlchemy | AI/ML services, lightweight APIs |
| `nextjs` | Next.js 15, React 19, Mantine | Admin dashboards |
| `react` | React 18, Vite, Mantine | Embeddable UIs, SPAs |

## Templates

Reference the conventions and style guides:
- Spring Boot: See [style-spring skill](../style-spring/SKILL.md)
- FastAPI: See [style-python skill](../style-python/SKILL.md)
- Next.js/React: See [style-react skill](../style-react/SKILL.md)

---

## Spring Boot Service

### Structure
```
service-name/
├── src/main/java/com/example/servicename/
│   ├── ServiceNameApplication.java
│   ├── controllers/
│   ├── services/
│   │   └── impl/
│   ├── repositories/
│   ├── models/
│   ├── dto/
│   │   ├── request/
│   │   └── response/
│   ├── components/
│   ├── config/
│   ├── security/
│   └── exceptions/
├── src/main/resources/
│   ├── application.properties
│   └── db/changelog/
├── src/test/java/
├── pom.xml
├── Dockerfile
├── docker-compose.yml
└── CLAUDE.md
```

### Quick Start
```bash
# Using Spring Initializr
curl https://start.spring.io/starter.zip \
  -d type=maven-project \
  -d language=java \
  -d bootVersion=3.3.0 \
  -d baseDir=$0 \
  -d groupId=com.example \
  -d artifactId=$0 \
  -d name=$0 \
  -d packageName=com.example.$0 \
  -d javaVersion=17 \
  -d dependencies=web,data-jpa,postgresql,lombok,validation,actuator \
  -o $0.zip && unzip $0.zip && rm $0.zip
```

---

## FastAPI Service

### Structure
```
service-name/
├── app/
│   ├── __init__.py
│   ├── main.py
│   ├── api/
│   │   └── v1/
│   │       ├── __init__.py
│   │       ├── router.py
│   │       └── endpoints/
│   ├── core/
│   │   ├── config.py
│   │   ├── database.py
│   │   └── security.py
│   ├── models/
│   ├── schemas/
│   ├── services/
│   └── repositories/
├── tests/
├── alembic/
├── pyproject.toml
├── requirements.txt
├── Dockerfile
├── docker-compose.yml
└── CLAUDE.md
```

### Quick Start
```bash
mkdir $0 && cd $0
python -m venv venv
source venv/bin/activate        # macOS/Linux
source venv/Scripts/activate    # Windows (Git Bash)
pip install fastapi uvicorn sqlalchemy asyncpg pydantic-settings alembic
```

---

## Next.js Service

### Structure
```
service-name/
├── src/
│   ├── app/
│   │   ├── layout.tsx
│   │   ├── page.tsx
│   │   └── (routes)/
│   ├── components/
│   ├── hooks/
│   ├── services/
│   ├── store/
│   └── types/
├── public/
├── package.json
├── next.config.js
├── tailwind.config.js
├── tsconfig.json
├── Dockerfile
└── CLAUDE.md
```

### Quick Start
```bash
npx create-next-app@latest $0 --typescript --tailwind --eslint --app --src-dir
cd $0
npm install @mantine/core @mantine/hooks @tabler/icons-react
```

---

## React/Vite Service

### Structure
```
service-name/
├── src/
│   ├── main.tsx
│   ├── App.tsx
│   ├── components/
│   ├── hooks/
│   ├── services/
│   ├── store/
│   └── types/
├── public/
├── package.json
├── vite.config.ts
├── tsconfig.json
├── Dockerfile
└── CLAUDE.md
```

### Quick Start
```bash
npm create vite@latest $0 -- --template react-ts
cd $0
npm install @mantine/core @mantine/hooks @tabler/icons-react
```

---

## Post-Creation Checklist

- [ ] Update `CLAUDE.md` with service-specific guidance
- [ ] Configure database connection
- [ ] Setup Dockerfile
- [ ] Add to main module as submodule (if applicable)
- [ ] Create CI pipeline
- [ ] Add to Helm chart (if applicable)
- [ ] Update platform docs (ARCHITECTURE.md, DEPLOYMENTS.md)
