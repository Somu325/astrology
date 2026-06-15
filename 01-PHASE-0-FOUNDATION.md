# Phase 0 — Foundation & Infrastructure Baseline

**Depends on:** Nothing (this is the starting point)  
**Unlocks:** Phase 1A, 1B, 1C, 1D, 1E (all can be started in parallel after Phase 0 is done)  
**Estimated Scope:** 1–2 days  

---

## Pre-Phase Checklist

> This is Phase 0. There are no prior phases to verify. Begin directly.

- [ ] All contributors have confirmed they have read `ARCHITECTURE.md` and `FRS.md` in full.
- [ ] All contributors have confirmed their local machines meet the tool requirements below.

---

## Required Tools — Local Machine

Every developer must have these installed and verified before writing any code.

| Tool | Minimum Version | Verify Command | Expected Output |
|------|-----------------|----------------|-----------------|
| Git | 2.40+ | `git --version` | `git version 2.x.x` |
| Docker Desktop | 4.28+ | `docker --version` | `Docker version 2x.x` |
| Docker Compose | v2 (bundled) | `docker compose version` | `Docker Compose version v2.x` |
| Node.js | 20 LTS | `node --version` | `v20.x.x` |
| pnpm | 9.x | `pnpm --version` | `9.x.x` |
| Python | 3.12.x | `python3 --version` | `Python 3.12.x` |
| pip | 24.x | `pip --version` | `pip 24.x` |
| protoc | 26.x | `protoc --version` | `libprotoc 26.x` |

**Action:** Install any missing tools. Do not proceed until all `verify` commands pass.

---

## Task 0.1 — Repository Structure

### 0.1.1 — Create the monorepo root

Create the exact directory structure defined in `ARCHITECTURE.md §11`. No files go inside service folders yet — only the directories.

```
/astro-platform
├── services/
│   ├── calc-engine/
│   │   ├── proto/
│   │   └── src/
│   ├── report-engine/
│   │   ├── templates/
│   │   └── src/
│   ├── llm-interface/
│   │   ├── prompts/
│   │   └── src/
│   └── main-backend/
│       └── src/
│           ├── routes/
│           ├── workers/
│           ├── db/
│           └── lib/
├── apps/
│   └── web/
│       ├── app/
│       ├── components/
│       └── lib/
├── packages/
│   └── shared-types/
├── proto/
├── infra/
└── docs/
```

**Deliverable:** Run `find . -type d | head -50` from repo root and confirm all directories exist.

### 0.1.2 — Create root `.gitignore`

The `.gitignore` at repo root must contain at minimum:

```
# Environment files
.env
.env.local
.env.*.local
**/.env

# Python
__pycache__/
*.py[cod]
*.egg-info/
.venv/
venv/
dist/

# Node
node_modules/
.next/
.turbo/
dist/
build/

# Docker
*.log

# OS
.DS_Store
Thumbs.db

# IDE
.idea/
.vscode/
*.swp

# Ephemeris data (large binary files)
*.se1

# Generated protobuf files
*_pb2.py
*_pb2_grpc.py
*_pb2.pyi
*.pb.go

# Secrets
*.pem
*.key
*.p12
```

**Deliverable:** `.gitignore` file exists at repo root. `git status` shows no ignored files tracked.

### 0.1.3 — Initialize Git

```bash
git init
git add .gitignore
git commit -m "chore: initialize repository with directory structure"
```

**Deliverable:** `git log --oneline` shows the initial commit.

---

## Task 0.2 — Shared Protobuf Definitions

The canonical `.proto` file lives in `/proto/` (shared). Every service that needs it copies the generated output — they never modify the source `.proto`.

### 0.2.1 — Create the canonical proto file

Create `/proto/astro_calculation.proto` with the exact content from `ARCHITECTURE.md §3.2`:

```protobuf
syntax = "proto3";

package astro.calculation.v1;

option go_package = "github.com/your-org/astro-platform/proto/gen/go;astropb";

service AstroCalculationService {
  rpc CalculateNatalChart (NatalChartRequest) returns (NatalChartResponse);
  rpc CalculateTransits (TransitRequest) returns (TransitResponse);
  rpc CalculateSynastry (SynastryRequest) returns (SynastryResponse);
  rpc BatchCalculate (stream NatalChartRequest) returns (stream NatalChartResponse);
}

message NatalChartRequest {
  double latitude = 1;
  double longitude = 2;
  int64 birth_timestamp_utc = 3;
  string house_system = 4;
  string ayanamsa = 5;
  repeated string requested_points = 6;
}

message PlanetPosition {
  string planet = 1;
  double longitude = 2;
  double latitude = 3;
  double speed = 4;
  bool is_retrograde = 5;
  string sign = 6;
  int32 house = 7;
  double degree_in_sign = 8;
  string nakshatra = 9;
  int32 nakshatra_pada = 10;
}

message HouseCusp {
  int32 house_number = 1;
  double longitude = 2;
  string sign = 3;
  double degree_in_sign = 4;
}

message Aspect {
  string planet_a = 1;
  string planet_b = 2;
  string aspect_type = 3;
  double orb = 4;
  bool is_applying = 5;
}

message ArabicLot {
  string name = 1;
  double longitude = 2;
  string sign = 3;
  int32 house = 4;
}

message NatalChartResponse {
  repeated PlanetPosition planets = 1;
  repeated HouseCusp houses = 2;
  repeated Aspect aspects = 3;
  repeated ArabicLot lots = 4;
  string chart_system = 5;
  int64 calculated_at = 6;
}

message TransitRequest {
  NatalChartRequest natal = 1;
  int64 transit_timestamp_utc = 2;
  repeated string requested_points = 3;
}

message TransitResponse {
  repeated PlanetPosition transit_planets = 1;
  repeated Aspect transiting_aspects = 2;
  int64 calculated_at = 3;
}

message SynastryRequest {
  NatalChartRequest chart_a = 1;
  NatalChartRequest chart_b = 2;
}

message SynastryResponse {
  NatalChartResponse chart_a = 1;
  NatalChartResponse chart_b = 2;
  repeated Aspect inter_chart_aspects = 3;
}
```

**Deliverable:** File exists at `/proto/astro_calculation.proto`. Validate it parses: `protoc --proto_path=proto proto/astro_calculation.proto` exits with code 0.

### 0.2.2 — Create proto generation script

Create `/proto/generate.sh`:

```bash
#!/usr/bin/env bash
set -e

PROTO_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(dirname "$PROTO_DIR")"

echo "Generating Python stubs..."
python3 -m grpc_tools.protoc \
  --proto_path="$PROTO_DIR" \
  --python_out="$ROOT_DIR/services/calc-engine/src/generated" \
  --grpc_python_out="$ROOT_DIR/services/calc-engine/src/generated" \
  --pyi_out="$ROOT_DIR/services/calc-engine/src/generated" \
  "$PROTO_DIR/astro_calculation.proto"

echo "Generating TypeScript stubs..."
# (Add grpc-tools TypeScript generation here in Phase 1B)

echo "Done."
```

Make it executable: `chmod +x /proto/generate.sh`

**Deliverable:** Script exists and is executable (`ls -la proto/generate.sh` shows `x` bit).

---

## Task 0.3 — Shared TypeScript Types Package

### 0.3.1 — Initialize shared-types package

```bash
cd packages/shared-types
pnpm init
```

Create `packages/shared-types/package.json`:

```json
{
  "name": "@astro-platform/shared-types",
  "version": "0.1.0",
  "private": true,
  "main": "./src/index.ts",
  "types": "./src/index.ts",
  "scripts": {
    "typecheck": "tsc --noEmit"
  },
  "devDependencies": {
    "typescript": "^5.4.0",
    "zod": "^3.23.0"
  }
}
```

### 0.3.2 — Create shared Zod schemas matching FRS §9 data models

Create `packages/shared-types/src/index.ts`:

```typescript
import { z } from "zod";

// --- User ---
export const UserSchema = z.object({
  id: z.string().uuid(),
  email: z.string().email(),
  name: z.string().nullable(),
  avatar_url: z.string().url().nullable(),
  plan: z.enum(["free", "pro", "enterprise"]),
  created_at: z.coerce.date(),
  updated_at: z.coerce.date(),
});
export type User = z.infer<typeof UserSchema>;

// --- BirthProfile ---
export const BirthProfileSchema = z.object({
  id: z.string().uuid(),
  user_id: z.string().uuid(),
  label: z.string().min(1).max(100),
  name: z.string().min(1).max(200),
  birth_date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
  birth_time: z.string().regex(/^\d{2}:\d{2}$/).nullable(),
  birth_city: z.string().min(1).max(200),
  latitude: z.number().min(-90).max(90),
  longitude: z.number().min(-180).max(180),
  timezone: z.string().min(1),
  is_primary: z.boolean(),
  created_at: z.coerce.date(),
});
export type BirthProfile = z.infer<typeof BirthProfileSchema>;

// --- ChartResult ---
export const ChartResultSchema = z.object({
  id: z.string().uuid(),
  birth_profile_id: z.string().uuid(),
  house_system: z.string(),
  ayanamsa: z.string().nullable(),
  chart_data: z.record(z.unknown()),
  created_at: z.coerce.date(),
});
export type ChartResult = z.infer<typeof ChartResultSchema>;

// --- Job ---
export const JobStatusSchema = z.enum(["queued", "processing", "complete", "failed"]);
export const JobTypeSchema = z.enum(["report", "llm_interpretation"]);
export const JobSchema = z.object({
  id: z.string(),
  user_id: z.string().uuid(),
  type: JobTypeSchema,
  status: JobStatusSchema,
  birth_profile_id: z.string().uuid(),
  config: z.record(z.unknown()),
  result_url: z.string().url().nullable(),
  error: z.string().nullable(),
  created_at: z.coerce.date(),
  completed_at: z.coerce.date().nullable(),
});
export type Job = z.infer<typeof JobSchema>;

// --- Report ---
export const ReportTypeSchema = z.enum([
  "natal", "career", "relationship", "yearly", "compatibility", "dasha",
]);
export const ReportSchema = z.object({
  id: z.string().uuid(),
  user_id: z.string().uuid(),
  birth_profile_id: z.string().uuid(),
  job_id: z.string(),
  type: ReportTypeSchema,
  version: z.string(),
  storage_url: z.string().url(),
  pdf_url: z.string().url().nullable(),
  share_token: z.string().nullable(),
  share_expires_at: z.coerce.date().nullable(),
  generated_at: z.coerce.date(),
});
export type Report = z.infer<typeof ReportSchema>;

// --- API Envelope ---
export const ApiSuccessSchema = <T extends z.ZodTypeAny>(dataSchema: T) =>
  z.object({ success: z.literal(true), data: dataSchema });

export const ApiErrorSchema = z.object({
  success: z.literal(false),
  error: z.object({ code: z.string(), message: z.string() }),
});
```

**Deliverable:** `cd packages/shared-types && npx tsc --noEmit` exits with code 0.

---

## Task 0.4 — Root Docker Compose (Local Dev Orchestration)

Create `/infra/docker-compose.yml`. This file defines ALL infrastructure dependencies for local development. Application services will be added incrementally in later phases.

```yaml
version: "3.9"

services:

  postgres:
    image: postgres:16-alpine
    container_name: astro_postgres
    restart: unless-stopped
    ports:
      - "5432:5432"
    environment:
      POSTGRES_USER: ${POSTGRES_USER:-astro}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD:-astropassword}
      POSTGRES_DB: ${POSTGRES_DB:-astro_platform}
    volumes:
      - postgres_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER:-astro}"]
      interval: 5s
      timeout: 5s
      retries: 5

  redis:
    image: redis:7-alpine
    container_name: astro_redis
    restart: unless-stopped
    ports:
      - "6379:6379"
    command: redis-server --appendonly yes
    volumes:
      - redis_data:/data
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 5s
      timeout: 5s
      retries: 5

  minio:
    image: minio/minio:latest
    container_name: astro_minio
    restart: unless-stopped
    ports:
      - "9000:9000"
      - "9001:9001"
    environment:
      MINIO_ROOT_USER: ${MINIO_ROOT_USER:-minioadmin}
      MINIO_ROOT_PASSWORD: ${MINIO_ROOT_PASSWORD:-minioadmin}
    command: server /data --console-address ":9001"
    volumes:
      - minio_data:/data
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:9000/minio/health/live"]
      interval: 10s
      timeout: 5s
      retries: 3

volumes:
  postgres_data:
  redis_data:
  minio_data:
```

Create `/infra/.env.example`:

```dotenv
# PostgreSQL
POSTGRES_USER=astro
POSTGRES_PASSWORD=astropassword
POSTGRES_DB=astro_platform

# Redis
# No password in local dev

# MinIO (S3-compatible local storage)
MINIO_ROOT_USER=minioadmin
MINIO_ROOT_PASSWORD=minioadmin
```

**Deliverable:**
1. `cp infra/.env.example infra/.env`
2. `docker compose -f infra/docker-compose.yml up -d`
3. All three services show `healthy` in `docker compose -f infra/docker-compose.yml ps`
4. `docker exec astro_postgres pg_isready` exits 0
5. `docker exec astro_redis redis-cli ping` returns `PONG`
6. `curl -f http://localhost:9000/minio/health/live` returns HTTP 200

---

## Task 0.5 — Root-Level Environment Documentation

Create `/docs/ENV-VARIABLES.md`:

```markdown
# Environment Variables Reference

This document lists all environment variables used across all services.
Each service has its own `.env.example`. This is the master reference.

## Infrastructure (infra/.env)

| Variable | Default | Required | Description |
|----------|---------|----------|-------------|
| POSTGRES_USER | astro | Yes | PostgreSQL username |
| POSTGRES_PASSWORD | astropassword | Yes | PostgreSQL password |
| POSTGRES_DB | astro_platform | Yes | PostgreSQL database name |
| MINIO_ROOT_USER | minioadmin | Yes | MinIO admin username |
| MINIO_ROOT_PASSWORD | minioadmin | Yes | MinIO admin password |

## Calc Engine (services/calc-engine/.env)

(Populated in Phase 1A)

## Main Backend (services/main-backend/.env)

(Populated in Phase 1B)

## Report Engine (services/report-engine/.env)

(Populated in Phase 1C)

## LLM Interface (services/llm-interface/.env)

(Populated in Phase 1D)

## Web App (apps/web/.env.local)

(Populated in Phase 1E)
```

**Deliverable:** File exists at `/docs/ENV-VARIABLES.md`.

---

## Task 0.6 — Root `README.md`

Create `/README.md`:

```markdown
# Astrology Platform

Multi-service astrology platform. See `docs/ARCHITECTURE.md` for system design.

## Quick Start (Local Dev)

### Prerequisites
See Phase 0 tool requirements. All tools must be installed.

### 1. Start infrastructure
\`\`\`bash
cp infra/.env.example infra/.env
docker compose -f infra/docker-compose.yml up -d
\`\`\`

### 2. Verify infrastructure
\`\`\`bash
docker compose -f infra/docker-compose.yml ps
# All services must show: healthy
\`\`\`

### 3. Start individual services
See each service README in `services/*/README.md` and `apps/*/README.md`.

## Services
- `services/calc-engine` — Astrology Calculation Engine (Python, gRPC)
- `services/report-engine` — Report Generation Engine (Python, Celery)
- `services/llm-interface` — LLM Interpretation Interface (Python, Celery)
- `services/main-backend` — Main Backend Server (TypeScript, Fastify)
- `apps/web` — Web Application (TypeScript, Next.js 14)

## Documentation
- `docs/ARCHITECTURE.md` — System architecture
- `docs/FRS.md` — Functional requirements
- `docs/ENV-VARIABLES.md` — All environment variables
```

**Deliverable:** File exists at `/README.md`.

---

## Phase 0 — Completion Checklist

Mark every item before declaring Phase 0 done.

- [ ] All directories from `ARCHITECTURE.md §11` exist in the repo
- [ ] `.gitignore` at root is committed
- [ ] `/proto/astro_calculation.proto` exists and `protoc` validates it without error
- [ ] `/proto/generate.sh` exists and is executable
- [ ] `packages/shared-types/src/index.ts` exists and `tsc --noEmit` passes
- [ ] `/infra/docker-compose.yml` exists
- [ ] `/infra/.env.example` exists
- [ ] `docker compose -f infra/docker-compose.yml up -d` brings up all 3 services healthy
- [ ] PostgreSQL healthcheck passes
- [ ] Redis ping returns PONG
- [ ] MinIO health endpoint returns HTTP 200
- [ ] `/docs/ENV-VARIABLES.md` exists
- [ ] `/README.md` exists
- [ ] Initial git commit exists with all of the above
- [ ] No `.env` files are tracked by git (`git ls-files | grep '\.env'` returns empty)

**Sign-off required from:** Lead developer before Phase 1x begins.
https://github.com/Somu325/astrology.git