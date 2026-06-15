# Astrology Platform

Multi-service astrology platform. See `ARCHITECTURE.md` for system design.

## Quick Start (Local Dev)

### Prerequisites
See Phase 0 tool requirements. All tools must be installed.

### 1. Start infrastructure (With Docker)
```bash
cp infra/.env.example infra/.env
docker compose -f infra/docker-compose.yml up -d
```

### 1.b Start infrastructure (Natively via Homebrew)
If Docker is not supported or installed on your machine:
```bash
# 1. Install PostgreSQL 16, Redis, and MinIO
brew install postgresql@16 redis minio

# 2. Start PostgreSQL and Redis background services
brew services start postgresql@16
brew services start redis

# 3. Create role 'astro' and database 'astro_platform' inside PostgreSQL
psql postgres -c "CREATE USER astro WITH PASSWORD 'astropassword' SUPERUSER;"
psql postgres -c "CREATE DATABASE astro_platform OWNER astro;"

# 4. Start MinIO locally
mkdir -p ~/minio_data
export MINIO_ROOT_USER=minioadmin
export MINIO_ROOT_PASSWORD=minioadmin
nohup minio server ~/minio_data --console-address ":9001" > ~/minio.log 2>&1 &
```

### 2. Verify infrastructure
* **Docker**: Run `docker compose -f infra/docker-compose.yml ps` (services must show `healthy`).
* **Native**: Verify services are active and listening:
  * PostgreSQL: `pg_isready` (exits 0)
  * Redis: `redis-cli ping` (returns `PONG`)
  * MinIO: `curl -f http://localhost:9000/minio/health/live` (returns HTTP 200)

### 3. Start individual services
See each service README in `services/*/README.md` and `apps/*/README.md`.

## Services
- `services/calc-engine` — Astrology Calculation Engine (Python, gRPC)
- `services/report-engine` — Report Generation Engine (Python, Celery)
- `services/llm-interface` — LLM Interpretation Interface (Python, Celery)
- `services/main-backend` — Main Backend Server (TypeScript, Fastify)
- `apps/web` — Web Application (TypeScript, Next.js 14)

## Documentation
- `ARCHITECTURE.md` — System architecture
- `FRS.md` — Functional requirements
- `docs/ENV-VARIABLES.md` — All environment variables
- `Gemini.md` — LLM/Gemini instructions for codebase
- `Agents.md` — Subagent roles & collaboration
- `PROJECT-STRUCTURE.md` — Monorepo folders & responsibilities
- `AI-STATE.md` — Living AI Handoff Ledger & active task checklists

## AI Agent Integration & Session Handoffs
This codebase is configured to work seamlessly with different AI coding assistants (GitHub Copilot, Cursor, Windsurf, Claude Code, etc.).

1. **Check Environment Health**: Run the environment diagnostic check:
   ```bash
   bash scripts/ai-diagnostic.sh
   ```
2. **Coordinate Progress**: When switching between AI tools or ending a development session, always read and update the active checklists in `AI-STATE.md` to preserve session context and coordinate next steps.

