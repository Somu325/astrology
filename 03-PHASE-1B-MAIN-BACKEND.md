# Phase 1B — Main Backend Server

**Depends on:** Phase 0 ✓, Phase 1A ✓ (gRPC endpoint must be running and tested)  
**Unlocks:** Phase 1C, Phase 1D (both need the queue), Phase 1E (Web App needs this API)  
**FRS Coverage:** MAIN-001 through MAIN-019, MAIN-025 through MAIN-028  
**Estimated Scope:** 5–7 days  

---

## Pre-Phase Verification Checklist

> Do not write a single line of code until every item below is confirmed.

- [ ] Phase 0 completion checklist is signed off
- [ ] Phase 1A completion checklist is signed off
- [ ] Calc Engine gRPC is reachable: start `python3 src/main.py` in `services/calc-engine/`, then run `grpcurl -plaintext localhost:50051 list` and confirm `astro.calculation.v1.AstroCalculationService` is listed
- [ ] If `grpcurl` is not installed: `brew install grpcurl` (macOS) or `go install github.com/fullstorydev/grpcurl/cmd/grpcurl@latest`
- [ ] Docker infra is running: `docker compose -f infra/docker-compose.yml ps` — all 3 services healthy
- [ ] PostgreSQL accessible: `psql postgresql://astro:astropassword@localhost:5432/astro_platform -c "\l"` lists databases
- [ ] Redis accessible: `redis-cli -h localhost ping` returns `PONG`
- [ ] Node.js 20 LTS: `node --version` → `v20.x.x`
- [ ] pnpm 9.x: `pnpm --version` → `9.x.x`
- [ ] `services/main-backend/` directory exists and is empty

---

## Task 1B.1 — Node.js Project Bootstrap

### 1B.1.1 — Initialize the package

```bash
cd services/main-backend
pnpm init
```

### 1B.1.2 — Create `package.json`

Replace generated `package.json` with:

```json
{
  "name": "@astro-platform/main-backend",
  "version": "0.1.0",
  "private": true,
  "type": "module",
  "scripts": {
    "dev": "tsx watch src/server.ts",
    "build": "tsc",
    "start": "node dist/server.js",
    "db:generate": "drizzle-kit generate",
    "db:migrate": "tsx src/db/migrate.ts",
    "db:studio": "drizzle-kit studio",
    "typecheck": "tsc --noEmit",
    "test": "vitest run",
    "test:watch": "vitest"
  },
  "dependencies": {
    "fastify": "^4.27.0",
    "@fastify/cors": "^9.0.0",
    "@fastify/helmet": "^11.0.0",
    "@fastify/swagger": "^8.14.0",
    "@fastify/swagger-ui": "^3.0.0",
    "@fastify/websocket": "^8.3.0",
    "@fastify/rate-limit": "^9.1.0",
    "@fastify/jwt": "^8.0.0",
    "bullmq": "^5.3.0",
    "drizzle-orm": "^0.30.0",
    "postgres": "^3.4.0",
    "ioredis": "^5.3.0",
    "@grpc/grpc-js": "^1.10.0",
    "@grpc/proto-loader": "^0.7.0",
    "zod": "^3.23.0",
    "stripe": "^15.0.0",
    "dotenv": "^16.4.0"
  },
  "devDependencies": {
    "typescript": "^5.4.0",
    "tsx": "^4.11.0",
    "drizzle-kit": "^0.21.0",
    "@types/node": "^20.0.0",
    "vitest": "^1.6.0"
  }
}
```

```bash
pnpm install
```

**Deliverable:** `pnpm install` completes with no errors. `node_modules/fastify` exists.

### 1B.1.3 — Create `tsconfig.json`

```json
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "ESNext",
    "moduleResolution": "bundler",
    "lib": ["ES2022"],
    "outDir": "dist",
    "rootDir": "src",
    "strict": true,
    "noUncheckedIndexedAccess": true,
    "exactOptionalPropertyTypes": true,
    "esModuleInterop": true,
    "resolveJsonModule": true,
    "skipLibCheck": true,
    "paths": {
      "@/*": ["./src/*"]
    }
  },
  "include": ["src/**/*"],
  "exclude": ["node_modules", "dist"]
}
```

**Deliverable:** `pnpm typecheck` exits 0 (no source files yet — this just confirms tsconfig is valid).

### 1B.1.4 — Create `.env.example`

Create `services/main-backend/.env.example`:

```dotenv
# Server
PORT=3000
HOST=0.0.0.0
NODE_ENV=development
LOG_LEVEL=info

# Database (PostgreSQL)
DATABASE_URL=postgresql://astro:astropassword@localhost:5432/astro_platform

# Redis
REDIS_URL=redis://localhost:6379

# JWT
JWT_SECRET=replace_with_64_char_random_string
JWT_ACCESS_TOKEN_EXPIRY=15m
JWT_REFRESH_TOKEN_EXPIRY=30d

# Supabase Auth (or replace with custom JWT config)
SUPABASE_URL=
SUPABASE_ANON_KEY=
SUPABASE_SERVICE_ROLE_KEY=

# gRPC — Calculation Engine
CALC_ENGINE_GRPC_HOST=localhost
CALC_ENGINE_GRPC_PORT=50051

# BullMQ / Redis queue
QUEUE_REDIS_URL=redis://localhost:6379

# Object Storage (MinIO locally, AWS S3 in prod)
S3_ENDPOINT=http://localhost:9000
S3_REGION=us-east-1
S3_BUCKET=astro-reports
S3_ACCESS_KEY=minioadmin
S3_SECRET_KEY=minioadmin

# Internal service webhook auth
INTERNAL_WEBHOOK_SECRET=replace_with_32_char_random_string

# Rate limiting
RATE_LIMIT_AUTHENTICATED=100
RATE_LIMIT_UNAUTHENTICATED=10
RATE_LIMIT_WINDOW_MS=60000

# CORS allowed origins (comma-separated)
CORS_ORIGINS=http://localhost:3001
```

Copy to `.env`: `cp .env.example .env`

**Deliverable:** `.env` file exists with all variables. Update `/docs/ENV-VARIABLES.md` with main-backend section.

---

## Task 1B.2 — Database Schema

### 1B.2.1 — Create Drizzle schema file

Create `services/main-backend/src/db/schema.ts`:

```typescript
import {
  pgTable,
  uuid,
  varchar,
  text,
  boolean,
  timestamp,
  doublePrecision,
  jsonb,
  pgEnum,
  index,
} from "drizzle-orm/pg-core";

// --- Enums ---
export const planEnum = pgEnum("plan", ["free", "pro", "enterprise"]);
export const jobTypeEnum = pgEnum("job_type", ["report", "llm_interpretation"]);
export const jobStatusEnum = pgEnum("job_status", [
  "queued", "processing", "complete", "failed",
]);
export const reportTypeEnum = pgEnum("report_type", [
  "natal", "career", "relationship", "yearly", "compatibility", "dasha",
]);

// --- Users table ---
export const users = pgTable("users", {
  id: uuid("id").primaryKey().defaultRandom(),
  email: varchar("email", { length: 320 }).notNull().unique(),
  name: varchar("name", { length: 200 }),
  avatar_url: text("avatar_url"),
  plan: planEnum("plan").notNull().default("free"),
  password_hash: varchar("password_hash", { length: 255 }),  // null if OAuth-only
  refresh_token_hash: varchar("refresh_token_hash", { length: 255 }),
  created_at: timestamp("created_at", { withTimezone: true }).notNull().defaultNow(),
  updated_at: timestamp("updated_at", { withTimezone: true }).notNull().defaultNow(),
}, (t) => ({
  email_idx: index("users_email_idx").on(t.email),
}));

// --- Birth profiles table ---
export const birth_profiles = pgTable("birth_profiles", {
  id: uuid("id").primaryKey().defaultRandom(),
  user_id: uuid("user_id").notNull().references(() => users.id, { onDelete: "cascade" }),
  label: varchar("label", { length: 100 }).notNull(),
  name: varchar("name", { length: 200 }).notNull(),
  birth_date: varchar("birth_date", { length: 10 }).notNull(),     // ISO: YYYY-MM-DD
  birth_time: varchar("birth_time", { length: 5 }),                // HH:MM or null
  birth_city: varchar("birth_city", { length: 200 }).notNull(),
  latitude: doublePrecision("latitude").notNull(),
  longitude: doublePrecision("longitude").notNull(),
  timezone: varchar("timezone", { length: 100 }).notNull(),
  is_primary: boolean("is_primary").notNull().default(false),
  created_at: timestamp("created_at", { withTimezone: true }).notNull().defaultNow(),
}, (t) => ({
  user_idx: index("birth_profiles_user_idx").on(t.user_id),
}));

// --- Chart results table ---
export const chart_results = pgTable("chart_results", {
  id: uuid("id").primaryKey().defaultRandom(),
  birth_profile_id: uuid("birth_profile_id").notNull().references(() => birth_profiles.id, { onDelete: "cascade" }),
  house_system: varchar("house_system", { length: 50 }).notNull(),
  ayanamsa: varchar("ayanamsa", { length: 50 }),
  chart_data: jsonb("chart_data").notNull(),
  created_at: timestamp("created_at", { withTimezone: true }).notNull().defaultNow(),
}, (t) => ({
  profile_idx: index("chart_results_profile_idx").on(t.birth_profile_id),
}));

// --- Jobs table ---
export const jobs = pgTable("jobs", {
  id: varchar("id", { length: 255 }).primaryKey(),       // BullMQ job ID (string)
  user_id: uuid("user_id").notNull().references(() => users.id, { onDelete: "cascade" }),
  type: jobTypeEnum("type").notNull(),
  status: jobStatusEnum("status").notNull().default("queued"),
  birth_profile_id: uuid("birth_profile_id").notNull().references(() => birth_profiles.id),
  config: jsonb("config").notNull().default({}),
  result_url: text("result_url"),
  error: text("error"),
  created_at: timestamp("created_at", { withTimezone: true }).notNull().defaultNow(),
  completed_at: timestamp("completed_at", { withTimezone: true }),
}, (t) => ({
  user_idx: index("jobs_user_idx").on(t.user_id),
  status_idx: index("jobs_status_idx").on(t.status),
}));

// --- Reports table ---
export const reports = pgTable("reports", {
  id: uuid("id").primaryKey().defaultRandom(),
  user_id: uuid("user_id").notNull().references(() => users.id, { onDelete: "cascade" }),
  birth_profile_id: uuid("birth_profile_id").notNull().references(() => birth_profiles.id),
  job_id: varchar("job_id", { length: 255 }).references(() => jobs.id),
  type: reportTypeEnum("type").notNull(),
  version: varchar("version", { length: 20 }).notNull(),
  storage_url: text("storage_url").notNull(),
  pdf_url: text("pdf_url"),
  share_token: varchar("share_token", { length: 64 }),
  share_expires_at: timestamp("share_expires_at", { withTimezone: true }),
  generated_at: timestamp("generated_at", { withTimezone: true }).notNull().defaultNow(),
}, (t) => ({
  user_idx: index("reports_user_idx").on(t.user_id),
}));
```

### 1B.2.2 — Create Drizzle config

Create `services/main-backend/drizzle.config.ts`:

```typescript
import type { Config } from "drizzle-kit";
import * as dotenv from "dotenv";
dotenv.config();

export default {
  schema: "./src/db/schema.ts",
  out: "./drizzle",
  dialect: "postgresql",
  dbCredentials: {
    url: process.env["DATABASE_URL"]!,
  },
} satisfies Config;
```

### 1B.2.3 — Create migration runner

Create `services/main-backend/src/db/migrate.ts`:

```typescript
import { drizzle } from "drizzle-orm/postgres-js";
import { migrate } from "drizzle-orm/postgres-js/migrator";
import postgres from "postgres";
import * as dotenv from "dotenv";

dotenv.config();

const connectionString = process.env["DATABASE_URL"];
if (!connectionString) throw new Error("DATABASE_URL is required");

const sql = postgres(connectionString, { max: 1 });
const db = drizzle(sql);

await migrate(db, { migrationsFolder: "./drizzle" });
console.log("Migrations applied successfully.");
await sql.end();
```

### 1B.2.4 — Create database connection module

Create `services/main-backend/src/db/index.ts`:

```typescript
import { drizzle } from "drizzle-orm/postgres-js";
import postgres from "postgres";
import * as schema from "./schema.js";

const connectionString = process.env["DATABASE_URL"];
if (!connectionString) throw new Error("DATABASE_URL environment variable is required");

const sql = postgres(connectionString, {
  max: 10,
  idle_timeout: 30,
  connect_timeout: 10,
});

export const db = drizzle(sql, { schema });
export type DB = typeof db;
```

### 1B.2.5 — Generate and apply migrations

```bash
pnpm db:generate
pnpm db:migrate
```

**Deliverable:**
1. `drizzle/` directory contains at least one `.sql` migration file
2. `pnpm db:migrate` completes without error, outputs `Migrations applied successfully.`
3. `psql postgresql://astro:astropassword@localhost:5432/astro_platform -c "\dt"` lists tables: `users`, `birth_profiles`, `chart_results`, `jobs`, `reports`

---

## Task 1B.3 — Redis & Queue Setup

### 1B.3.1 — Create Redis client module

Create `services/main-backend/src/lib/redis.ts`:

```typescript
import IORedis from "ioredis";

const redisUrl = process.env["REDIS_URL"];
if (!redisUrl) throw new Error("REDIS_URL environment variable is required");

export const redis = new IORedis(redisUrl, {
  maxRetriesPerRequest: null,  // Required for BullMQ
  enableReadyCheck: false,
  lazyConnect: false,
});

redis.on("error", (err) => {
  console.error("[Redis] Connection error:", err.message);
});

redis.on("connect", () => {
  console.log("[Redis] Connected.");
});
```

### 1B.3.2 — Create queue definitions

Create `services/main-backend/src/lib/queues.ts`:

```typescript
import { Queue } from "bullmq";
import { redis } from "./redis.js";

export const reportQueue = new Queue("report-generation", {
  connection: redis,
  defaultJobOptions: {
    attempts: 3,
    backoff: { type: "exponential", delay: 5000 },
    removeOnComplete: { count: 100 },
    removeOnFail: { count: 200 },
  },
});

export const llmQueue = new Queue("llm-interpretation", {
  connection: redis,
  defaultJobOptions: {
    attempts: 3,
    backoff: { type: "exponential", delay: 3000 },
    removeOnComplete: { count: 100 },
    removeOnFail: { count: 200 },
  },
});

export type ReportJobPayload = {
  job_id: string;
  user_id: string;
  birth_profile_id: string;
  report_type: string;
  birth_data: {
    latitude: number;
    longitude: number;
    birth_timestamp_utc: number;
    house_system: string;
    timezone: string;
  };
  callback_url: string;
  callback_secret: string;
};

export type LLMJobPayload = {
  job_id: string;
  user_id: string;
  birth_profile_id: string;
  interpretation_type: string;
  birth_data: {
    latitude: number;
    longitude: number;
    birth_timestamp_utc: number;
    house_system: string;
  };
  stream_url: string;
  callback_url: string;
  callback_secret: string;
};
```

**Deliverable:** `pnpm typecheck` still exits 0. `redis.ts` and `queues.ts` import without runtime error.

---

## Task 1B.4 — gRPC Client for Calculation Engine

Create `services/main-backend/src/lib/calc-client.ts`:

```typescript
/**
 * gRPC client for the Calculation Engine.
 * Wraps the raw gRPC call in a typed Promise.
 */
import * as grpc from "@grpc/grpc-js";
import * as protoLoader from "@grpc/proto-loader";
import path from "path";
import { fileURLToPath } from "url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const PROTO_PATH = path.resolve(__dirname, "../../../../proto/astro_calculation.proto");

const packageDef = protoLoader.loadSync(PROTO_PATH, {
  keepCase: true,
  longs: String,
  enums: String,
  defaults: true,
  oneofs: true,
});

const proto = grpc.loadPackageDefinition(packageDef) as any;

const calcEngineHost = process.env["CALC_ENGINE_GRPC_HOST"] ?? "localhost";
const calcEnginePort = process.env["CALC_ENGINE_GRPC_PORT"] ?? "50051";
const calcAddress = `${calcEngineHost}:${calcEnginePort}`;

const client = new proto.astro.calculation.v1.AstroCalculationService(
  calcAddress,
  grpc.credentials.createInsecure(),
  {
    "grpc.keepalive_time_ms": 10000,
    "grpc.keepalive_timeout_ms": 5000,
    "grpc.max_receive_message_length": 10 * 1024 * 1024,  // 10MB
  }
);

export type NatalChartRequest = {
  latitude: number;
  longitude: number;
  birth_timestamp_utc: number;
  house_system: string;
  ayanamsa?: string;
  requested_points?: string[];
};

export function calculateNatalChart(req: NatalChartRequest): Promise<unknown> {
  return new Promise((resolve, reject) => {
    client.CalculateNatalChart(req, (err: grpc.ServiceError | null, response: unknown) => {
      if (err) {
        reject(err);
      } else {
        resolve(response);
      }
    });
  });
}
```

**Deliverable:** Calc Engine must be running. Then:
```bash
node --input-type=module << 'EOF'
import { calculateNatalChart } from "./src/lib/calc-client.js";
const result = await calculateNatalChart({
  latitude: 17.385, longitude: 78.4867,
  birth_timestamp_utc: 645350400, house_system: "placidus"
});
console.log("planets:", result.planets?.length);
EOF
```
Prints `planets: 12` or more.

---

## Task 1B.5 — Auth Routes

### 1B.5.1 — Create password utilities

Create `services/main-backend/src/lib/auth.ts`:

```typescript
import crypto from "crypto";

/** Hash a password with PBKDF2. Returns base64-encoded hash. */
export async function hashPassword(password: string): Promise<string> {
  const salt = crypto.randomBytes(16).toString("hex");
  return new Promise((resolve, reject) => {
    crypto.pbkdf2(password, salt, 100000, 64, "sha512", (err, derived) => {
      if (err) reject(err);
      else resolve(`${salt}:${derived.toString("hex")}`);
    });
  });
}

/** Verify a password against a stored hash. */
export async function verifyPassword(
  password: string,
  storedHash: string,
): Promise<boolean> {
  const [salt, hash] = storedHash.split(":");
  if (!salt || !hash) return false;
  return new Promise((resolve, reject) => {
    crypto.pbkdf2(password, salt, 100000, 64, "sha512", (err, derived) => {
      if (err) reject(err);
      else resolve(derived.toString("hex") === hash);
    });
  });
}

/** Generate a cryptographically secure random token. */
export function generateToken(byteLength = 32): string {
  return crypto.randomBytes(byteLength).toString("hex");
}
```

### 1B.5.2 — Create auth routes

Create `services/main-backend/src/routes/auth.ts` implementing:

- `POST /auth/register` — FRS MAIN-001: email + password. Validates email format (Zod), password min 8 chars. Hashes password. Creates user. Returns JWT access + refresh tokens.
- `POST /auth/login` — FRS MAIN-002: email + password. Verifies hash. Returns JWT access + refresh tokens.
- `POST /auth/refresh` — Validates refresh token from body. Issues new access token.
- `POST /auth/logout` — Requires auth. Clears refresh token hash in DB.
- `GET /auth/me` — Requires auth. Returns current user object (no password_hash).

All endpoints must:
- Return `{ success: true, data: ... }` on success (FRS MAIN-025)
- Return `{ success: false, error: { code: string, message: string } }` on error
- Never return `password_hash` or `refresh_token_hash` fields to client

**Deliverable (each must be manually tested with curl):**

```bash
# Register
curl -X POST http://localhost:3000/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"testpassword123","name":"Test User"}'
# Expected: {"success":true,"data":{"access_token":"...","refresh_token":"...","user":{...}}}

# Login
curl -X POST http://localhost:3000/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"testpassword123"}'
# Expected: {"success":true,"data":{"access_token":"...","refresh_token":"...","user":{...}}}

# Me (use access_token from login response)
curl http://localhost:3000/auth/me \
  -H "Authorization: Bearer <access_token>"
# Expected: {"success":true,"data":{"id":"...","email":"test@example.com",...}}

# Duplicate register
curl -X POST http://localhost:3000/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"testpassword123"}'
# Expected: {"success":false,"error":{"code":"EMAIL_TAKEN","message":"..."}}

# Wrong password
curl -X POST http://localhost:3000/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"wrongpassword"}'
# Expected: {"success":false,"error":{"code":"INVALID_CREDENTIALS","message":"..."}}

# No auth token
curl http://localhost:3000/auth/me
# Expected: HTTP 401, {"success":false,"error":{"code":"UNAUTHORIZED",...}}
```

---

## Task 1B.6 — Birth Profile Routes

Create `services/main-backend/src/routes/profiles.ts` implementing all 4 endpoints from FRS §10 Birth Profiles table. All require auth.

- `GET /profiles` — Returns all birth profiles for authenticated user. Array ordered by `is_primary DESC, created_at ASC`.
- `POST /profiles` — Creates profile. Validates: `label`, `name`, `birth_date` (YYYY-MM-DD regex), `birth_time` (HH:MM or null), `birth_city`, `latitude` (-90–90), `longitude` (-180–180), `timezone` (non-empty string).
- `PUT /profiles/:id` — Updates profile. Verifies profile belongs to authenticated user. Partial updates allowed.
- `DELETE /profiles/:id` — Deletes profile. Verifies profile belongs to authenticated user.

**Deliverable (each tested with curl using the access_token from Task 1B.5):**

```bash
# Create
curl -X POST http://localhost:3000/profiles \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{"label":"Me","name":"Test User","birth_date":"1990-06-15","birth_time":"14:30","birth_city":"Hyderabad","latitude":17.385,"longitude":78.4867,"timezone":"Asia/Kolkata"}'
# Expected: {"success":true,"data":{"id":"...","label":"Me",...}}

# List
curl http://localhost:3000/profiles \
  -H "Authorization: Bearer <token>"
# Expected: {"success":true,"data":[...array of profiles...]}

# Update
curl -X PUT http://localhost:3000/profiles/<profile_id> \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{"label":"Myself"}'
# Expected: {"success":true,"data":{...updated profile...}}

# Delete
curl -X DELETE http://localhost:3000/profiles/<profile_id> \
  -H "Authorization: Bearer <token>"
# Expected: {"success":true,"data":{"deleted":true}}

# Access another user's profile
# Create a second user, get their token, try to access first user's profile_id
# Expected: {"success":false,"error":{"code":"NOT_FOUND",...}} (not a 403 — don't reveal existence)
```

---

## Task 1B.7 — Chart Routes

Create `services/main-backend/src/routes/charts.ts`.

- `POST /charts/calculate` (no auth) — FRS MAIN-009: Guest chart. Accepts `{ latitude, longitude, birth_timestamp_utc, house_system }`. Validates inputs. Calls Calc Engine via gRPC. Checks Redis cache first by key `chart:<lat>:<lon>:<ts>:<house>`. Returns result. Does NOT save to DB. Sets cache on miss with 24h TTL.
- `POST /charts` (auth) — Same as above but saves to DB linked to `birth_profile_id`. Cache logic same.
- `GET /charts` (auth) — Returns all charts for authenticated user's profiles.
- `GET /charts/:id` (auth) — Returns single chart. Verifies ownership.
- `DELETE /charts/:id` (auth) — Deletes chart. Verifies ownership.

**Deliverable:**

```bash
# Guest chart
curl -X POST http://localhost:3000/charts/calculate \
  -H "Content-Type: application/json" \
  -d '{"latitude":17.385,"longitude":78.4867,"birth_timestamp_utc":645350400,"house_system":"placidus"}'
# Expected: JSON with planets, houses, aspects arrays

# Same request again — must return from cache (verify with server log showing "cache hit")
# same curl as above
# Expected: same JSON, server log shows "Cache hit for chart:..."

# Invalid latitude
curl -X POST http://localhost:3000/charts/calculate \
  -H "Content-Type: application/json" \
  -d '{"latitude":200,"longitude":0,"birth_timestamp_utc":645350400,"house_system":"placidus"}'
# Expected: {"success":false,"error":{"code":"VALIDATION_ERROR",...}}
```

---

## Task 1B.8 — Job & Report Routes

Create `services/main-backend/src/routes/jobs.ts`.

- `POST /jobs/interpret` (auth) — FRS MAIN-014: Validates `birth_profile_id` (must belong to user) and `interpretation_type`. Creates a `Job` row in DB with status `queued`. Enqueues to `llmQueue`. Returns `{ job_id }`.
- `POST /jobs/report` (auth) — Same for `reportQueue`.
- `GET /jobs/:id` (auth) — FRS MAIN-015: Returns job status. Verifies ownership.
- `GET /reports` (auth) — Returns all reports for authenticated user.
- `GET /reports/:id` (auth) — Returns report metadata + signed pre-signed URL (FRS MAIN-019). For local dev with MinIO, generate a MinIO pre-signed URL.

Create `services/main-backend/src/routes/internal.ts`.

- `POST /internal/webhooks/job-complete` (API Key auth via `x-webhook-secret` header matching `INTERNAL_WEBHOOK_SECRET`) — FRS MAIN-017: Receives `{ job_id, status, result_url, error }`. Updates job row in DB. If status is `complete`, creates/updates report row. Pushes WebSocket notification (see Task 1B.9).

**Deliverable:**

```bash
# Start interpret job
curl -X POST http://localhost:3000/jobs/interpret \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{"birth_profile_id":"<valid_profile_id>","interpretation_type":"full"}'
# Expected: {"success":true,"data":{"job_id":"..."}}

# Get job status
curl http://localhost:3000/jobs/<job_id> \
  -H "Authorization: Bearer <token>"
# Expected: {"success":true,"data":{"id":"...","status":"queued",...}}

# Simulate webhook from engine
curl -X POST http://localhost:3000/internal/webhooks/job-complete \
  -H "x-webhook-secret: <INTERNAL_WEBHOOK_SECRET>" \
  -H "Content-Type: application/json" \
  -d '{"job_id":"<job_id>","status":"complete","result_url":"s3://bucket/path.json"}'
# Expected: {"success":true}

# Check job status again
curl http://localhost:3000/jobs/<job_id> -H "Authorization: Bearer <token>"
# Expected: status is now "complete"

# Webhook with wrong secret
curl -X POST http://localhost:3000/internal/webhooks/job-complete \
  -H "x-webhook-secret: wrongsecret" \
  -H "Content-Type: application/json" \
  -d '{"job_id":"x","status":"complete","result_url":"s3://bucket/x.json"}'
# Expected: HTTP 401
```

---

## Task 1B.9 — WebSocket (Job Status Push)

Create `services/main-backend/src/lib/websocket.ts`:

```typescript
/**
 * WebSocket manager for pushing job status updates to clients.
 * Each authenticated WebSocket connection is registered by user_id.
 */
import type { FastifyInstance } from "fastify";
import type { WebSocket } from "@fastify/websocket";

// Map of user_id → Set of active WebSocket connections
const connections = new Map<string, Set<WebSocket>>();

export function registerWebSocket(userId: string, ws: WebSocket): void {
  if (!connections.has(userId)) {
    connections.set(userId, new Set());
  }
  connections.get(userId)!.add(ws);

  ws.on("close", () => {
    connections.get(userId)?.delete(ws);
    if (connections.get(userId)?.size === 0) {
      connections.delete(userId);
    }
  });
}

export function pushToUser(userId: string, payload: unknown): void {
  const userConnections = connections.get(userId);
  if (!userConnections || userConnections.size === 0) return;

  const message = JSON.stringify(payload);
  for (const ws of userConnections) {
    if (ws.readyState === 1) {  // OPEN
      ws.send(message);
    }
  }
}
```

Register the WebSocket route in `services/main-backend/src/routes/ws.ts`:

```typescript
import type { FastifyInstance } from "fastify";
import { registerWebSocket } from "../lib/websocket.js";

export async function wsRoutes(fastify: FastifyInstance) {
  fastify.get("/ws", { websocket: true }, (socket, req) => {
    // @ts-ignore — jwt user injected by middleware
    const userId: string | undefined = req.user?.id;
    if (!userId) {
      socket.close(4001, "Unauthorized");
      return;
    }
    registerWebSocket(userId, socket);
    socket.send(JSON.stringify({ type: "connected", user_id: userId }));
  });
}
```

**Deliverable:**
1. Main server starts with WebSocket plugin registered
2. `wscat -c "ws://localhost:3000/ws" -H "Authorization: Bearer <token>"` connects and receives `{"type":"connected","user_id":"..."}`
3. After simulating the webhook from Task 1B.8, the WebSocket client receives a `job_update` message

---

## Task 1B.10 — Rate Limiting & Swagger Docs

### 1B.10.1 — Rate limiting (FRS MAIN-027)

Configure `@fastify/rate-limit` in server:

- Authenticated users: 100 req/min
- Unauthenticated: 10 req/min
- Window: 60 seconds (from `RATE_LIMIT_WINDOW_MS`)
- Key function: user ID if authenticated, IP address if not

**Deliverable:** Send 11 rapid unauthenticated requests to `/charts/calculate`. The 11th returns HTTP 429.

### 1B.10.2 — Swagger docs (FRS MAIN-028)

Register `@fastify/swagger` and `@fastify/swagger-ui`.

**Deliverable:** `GET http://localhost:3000/docs` opens Swagger UI in browser showing all registered routes.

---

## Task 1B.11 — Main Server Assembly

Create `services/main-backend/src/server.ts`:

```typescript
import Fastify from "fastify";
import cors from "@fastify/cors";
import helmet from "@fastify/helmet";
import swagger from "@fastify/swagger";
import swaggerUi from "@fastify/swagger-ui";
import websocketPlugin from "@fastify/websocket";
import rateLimit from "@fastify/rate-limit";
import jwt from "@fastify/jwt";
import * as dotenv from "dotenv";

dotenv.config();

const server = Fastify({
  logger: {
    level: process.env["LOG_LEVEL"] ?? "info",
    transport:
      process.env["NODE_ENV"] === "development"
        ? { target: "pino-pretty" }
        : undefined,
  },
});

// Plugins
await server.register(helmet);
await server.register(cors, {
  origin: (process.env["CORS_ORIGINS"] ?? "http://localhost:3001").split(","),
  credentials: true,
});
await server.register(jwt, { secret: process.env["JWT_SECRET"]! });
await server.register(websocketPlugin);
await server.register(rateLimit, { /* ... config ... */ });
await server.register(swagger, { /* ... openapi config ... */ });
await server.register(swaggerUi, { routePrefix: "/docs" });

// Routes
import { authRoutes } from "./routes/auth.js";
import { profileRoutes } from "./routes/profiles.js";
import { chartRoutes } from "./routes/charts.js";
import { jobRoutes } from "./routes/jobs.js";
import { internalRoutes } from "./routes/internal.js";
import { wsRoutes } from "./routes/ws.js";

await server.register(authRoutes, { prefix: "/auth" });
await server.register(profileRoutes, { prefix: "/profiles" });
await server.register(chartRoutes, { prefix: "/charts" });
await server.register(jobRoutes, { prefix: "" });
await server.register(internalRoutes, { prefix: "/internal" });
await server.register(wsRoutes);

server.get("/health", async () => ({ status: "ok", service: "main-backend" }));

const port = Number(process.env["PORT"] ?? 3000);
const host = process.env["HOST"] ?? "0.0.0.0";

await server.listen({ port, host });
server.log.info(`Main backend running on ${host}:${port}`);
```

**Deliverable:**
1. `pnpm dev` starts without errors
2. `curl http://localhost:3000/health` returns `{"status":"ok","service":"main-backend"}`
3. `pnpm typecheck` exits 0

---

## Task 1B.12 — Dockerfile

Create `services/main-backend/Dockerfile`:

```dockerfile
FROM node:20-alpine AS builder
WORKDIR /app
COPY package.json pnpm-lock.yaml ./
RUN npm install -g pnpm && pnpm install --frozen-lockfile
COPY . .
RUN pnpm build

FROM node:20-alpine AS runner
WORKDIR /app
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/package.json .
ENV NODE_ENV=production
EXPOSE 3000
CMD ["node", "dist/server.js"]
```

**Deliverable:** `docker build -t astro-main-backend services/main-backend/` completes without error.

---

## Phase 1B — Completion Checklist

- [ ] `pnpm install` completes without errors
- [ ] `pnpm typecheck` exits 0
- [ ] `.env.example` created with all variables
- [ ] `/docs/ENV-VARIABLES.md` updated with main-backend variables
- [ ] Database migrations applied: 5 tables exist in PostgreSQL
- [ ] Redis client connects: server log shows `[Redis] Connected.`
- [ ] gRPC client calls Calc Engine: `POST /charts/calculate` returns planet data
- [ ] `POST /auth/register` creates user and returns tokens
- [ ] `POST /auth/login` with correct credentials returns tokens
- [ ] `POST /auth/login` with wrong password returns INVALID_CREDENTIALS error
- [ ] `GET /auth/me` with valid token returns user (no password_hash)
- [ ] `GET /auth/me` with no token returns 401
- [ ] `POST /profiles` creates profile for authenticated user
- [ ] `PUT /profiles/:id` with another user's profile_id returns NOT_FOUND
- [ ] `POST /charts/calculate` (guest) returns chart data
- [ ] Second identical request returns cache hit (verify in logs)
- [ ] `POST /jobs/interpret` returns job_id and creates queued job in DB
- [ ] `POST /internal/webhooks/job-complete` with correct secret updates job status
- [ ] `POST /internal/webhooks/job-complete` with wrong secret returns 401
- [ ] WebSocket at `/ws` accepts connection with valid JWT
- [ ] WebSocket client receives job_update after webhook fires
- [ ] 11th unauthenticated request returns HTTP 429
- [ ] `GET /docs` shows Swagger UI
- [ ] `GET /health` returns `{"status":"ok"}`
- [ ] Dockerfile builds without error
- [ ] `services/main-backend/README.md` exists

**Sign-off required from:** Lead developer. Phase 1C and 1D may begin after this sign-off.
