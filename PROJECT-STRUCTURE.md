# Project Structure and Directory Responsibilities Reference

This document maps out the Astrology Platform's monorepo directory layout, specifying the responsibilities, dependencies, and roles of each folder, service, and package.

---

## 1. Directory Tree Overview

```
/astro-platform
├── services/                 # Backend microservices
│   ├── calc-engine/          # Python, gRPC, Swiss Ephemeris (stateless math)
│   ├── report-engine/        # Python, Celery (asynchronous PDF/JSON reports)
│   ├── llm-interface/        # Python, Celery (natural language interpretation)
│   └── main-backend/         # TypeScript, Fastify (gateway, auth, DB, billing)
├── apps/                     # Frontend client applications
│   ├── web/                  # Next.js 14 App Router, Tailwind, Zustand, D3
│   └── mobile/               # React Native, Expo (Phase 3 mobile client)
├── packages/                 # Shared local packages
│   └── shared-types/         # Shared Zod validation schemas & TypeScript types
├── proto/                    # Canonical gRPC / Protocol Buffer definitions
├── infra/                    # Infrastructure setup (docker-compose, environment)
└── docs/                     # Global system documentation
```

---

## 2. Service Responsibilities

### 2.1 Calculation Engine (`services/calc-engine`)
* **Role**: The mathematical core of the platform.
* **Technology**: Python 3.12, gRPC (`grpcio`), Swiss Ephemeris (`pyswisseph`).
* **Responsibilities**:
  * Perform calculations for planets (Sun, Moon, Mercury, Venus, Mars, Jupiter, Saturn, Uranus, Neptune, Pluto, Nodes).
  * Compute houses/cusps (Western: Placidus, Whole Sign, Koch, Equal; Sidereal/Vedic: Lahiri, Raman, KP).
  * Determine geometric aspects between planet pairs based on orb degrees.
  * Compute Vedic Vimshottari Dasha periods and divisional charts (D1-D60).
  * Calculate Arabic Lots (Part of Fortune, Spirit, etc.).
* **Decoupling Constraints**: **100% Stateless**. No database connection, no caching layer, and no internet access needed. Runs as a high-performance gRPC server.

### 2.2 Report Generation Engine (`services/report-engine`)
* **Role**: Heavy-duty, asynchronous report builder.
* **Technology**: Python 3.12, Celery (task worker), Jinja2 templates, S3/MinIO.
* **Responsibilities**:
  * Consume incoming report jobs from Redis.
  * Fetch raw calculation values by making direct gRPC queries to the Calculation Engine.
  * Inject calculation values into structured templates (Jinja2) to build natal, career, or compatibility reports.
  * Save report outputs (JSON and PDF) to S3-compatible cloud storage.
  * Send a signed payload to the Main Backend's webhook callback to flag job completion.
* **Decoupling Constraints**: Bypasses the Main Backend to communicate directly with the Calculation Engine. Never reads or writes PostgreSQL directly.

### 2.3 LLM Interpretation Interface (`services/llm-interface`)
* **Role**: Astrological interpretation generator utilizing generative AI.
* **Technology**: Python 3.12, Celery (task worker), Anthropic Claude / OpenAI SDKs, PyYAML prompts, tiktoken.
* **Responsibilities**:
  * Consume natural-language generation jobs from Redis.
  * Receive calculation charts and serialize them into clean, structured text contexts.
  * Filter minor placements and aspects dynamically according to report focus (e.g., career vs relationship) to save up to 60% of LLM token costs.
  * Query Claude/GPT-4 models using YAML prompt templates.
  * Support real-time Server-Sent Events (SSE) token streaming, or save finalized interpretations as storage assets.
  * Report cost analysis by tracking tiktoken usage.
* **Decoupling Constraints**: Stateless. Does not access databases or session logic directly.

### 2.4 Main Backend Server (`services/main-backend`)
* **Role**: Gateway orchestrator, security layer, and state manager.
* **Technology**: TypeScript, Node.js 20, Fastify, Drizzle ORM, PostgreSQL, Redis, BullMQ, Stripe.
* **Responsibilities**:
  * Handle public HTTP endpoints (auth, profiles, saved charts, Stripe checkout).
  * Enforce rate limits (100 req/min authenticated, 10 req/min guest) via Redis.
  * Orchestrate Postgres migrations and maintain typesafe queries via Drizzle.
  * Run the gRPC client to communicate with the Calculation Engine, caching results for 24 hours in Redis.
  * Enqueue background tasks to BullMQ (which routes them to the Report and LLM engines).
  * Expose internal webhooks to receive job completions and push real-time status alerts via WebSockets (`/ws`).
* **Decoupling Constraints**: The only service exposed to the public internet. Protects all background services behind an internal subnet.

---

## 3. Client & Frontend Responsibilities

### 3.1 Web Application (`apps/web`)
* **Role**: Primary user interface.
* **Technology**: TypeScript, Next.js 14, Tailwind CSS, shadcn/ui, Zustand (client state), TanStack Query (server state), D3.js.
* **Responsibilities**:
  * Display public marketing, landing, and billing screens.
  * Render login/signup forms, managing access/refresh tokens silently.
  * Present a user dashboard displaying birth profiles and saved chart histories.
  * Render high-fidelity, interactive SVG chart wheels (zodiac ring, aspect paths, planet tooltips) with D3.js.
  * Stream live AI responses using EventSource (SSE).
* **Decoupling Constraints**: Communicates only with the Main Backend. Contains no raw database calls.

### 3.2 Mobile Application (`apps/mobile`)
* **Role**: Native mobile client (Phase 3).
* **Technology**: React Native, Expo, NativeWind, react-native-svg, MMKV storage.
* **Responsibilities**:
  * Deliver same core flows as the web client (auth, dashboard, chart wheel).
  * support biometric login, native push alerts (transits, HOROSCOPE daily notifications), and offline cached reading.

---

## 4. Shared Directories

### 4.1 Protocols (`proto`)
* **Role**: Defines the schema contracts for service-to-service communication.
* **Content**: `/proto/astro_calculation.proto`.
* **Responsibilities**:
  * Serve as the single source of truth for all gRPC interfaces and data payloads.
  * Compiled into Python stubs (`calc-engine`) and TypeScript clients (`main-backend`) via `generate.sh`.

### 4.2 Local Packages (`packages/shared-types`)
* **Role**: Code-sharing library for TypeScript services.
* **Content**: `/packages/shared-types/src/index.ts`.
* **Responsibilities**:
  * Define Zod validation schemas matching database models (Users, BirthProfiles, ChartResults, Jobs, Reports).
  * Export TypeScript types dynamically derived from Zod schemas to ensure compile-time consistency between the backend and frontend.

### 4.3 Infrastructure (`infra`)
* **Role**: Configures the local development environment.
* **Content**: `/infra/docker-compose.yml`, `/infra/.env.example`.
* **Responsibilities**:
  * Set up PostgreSQL, Redis, and MinIO locally inside Docker.
  * Define healthchecks to guarantee baseline systems are operational before starting development.
