# Astrology Platform — Architecture Document

**Version:** 1.0  
**Status:** MVP Design  
**Role:** Senior Software Architect + Prompt Engineer  
**Coding Strategy:** Vibe Coding (AI-Assisted Development)  
**Primary Priority:** Web App → MVP Phase 1

---

## 1. System Overview

The platform is a multi-service astrology system composed of six independently deployable services. Each service owns exactly one domain of responsibility. They communicate via purpose-selected protocols based on latency, coupling, and data volume requirements. No service knows about another service's internal implementation.

```
Services:
  1. Calculation Engine     — Raw ephemeris computation (Python, stateless)
  2. Report Generation Engine — Structured report assembly (Python/Node)
  3. LLM Interpretation Interface — Chart → natural language (Python)
  4. Main Backend Server    — Auth, users, billing, orchestration (Node.js)
  5. Web App                — Browser client (Next.js)
  6. Mobile App             — Cross-platform client (React Native) [Phase 3]
```

---

## 2. Tech Stack Per Service

---

### 2.1 Astrology Calculation Engine

**Responsibility:** Stateless ephemeris calculations only. No auth, no persistence, no business logic.

| Layer | Choice | Justification |
|-------|--------|---------------|
| Language | Python 3.12 | Swiss Ephemeris has first-class Python bindings (`pyswisseph`) |
| Framework | FastAPI + Uvicorn (ASGI) | High-performance async Python; gRPC layer added via `grpcio` |
| Protocol Layer | gRPC (primary) + REST fallback | Binary protocol, schema contracts, streaming support |
| Ephemeris Library | `pyswisseph` (Swiss Ephemeris) | Industry standard, covers all required chart systems |
| Serialization | Protocol Buffers (protobuf) | Compact binary format, ~3-5x faster than JSON for numeric data |
| Containerization | Docker + uvicorn workers | Stateless; trivially horizontally scalable |
| Caching | None at service level (handled by Main Backend) | Engine stays pure and stateless |

**Key Libraries:**
```
pyswisseph>=2.10
grpcio>=1.62
grpcio-tools>=1.62
protobuf>=4.25
fastapi>=0.111 (REST fallback only)
uvicorn[standard]
numpy (coordinate transforms)
```

**Supported Chart Systems (MVP → Full):**
- Western: Placidus, Whole Sign, Koch, Equal, Campanus, Regiomontanus
- Sidereal: Lahiri, Raman, KP (Krishnamurti Paddhati), Fagan-Bradley
- Vedic (Jyotish): D1-D60 divisional charts, Ashtakavarga
- Hellenistic: Lots, bonification, sect

---

### 2.2 Report Generation Engine

**Responsibility:** Assembles structured astrology reports from raw calculation data. Fully independent — never routes through Main Backend for chart data.

| Layer | Choice | Justification |
|-------|--------|---------------|
| Language | Python 3.12 | Consistent with Calculation Engine; rich data processing |
| Framework | FastAPI (internal API) | Lightweight, async, OpenAPI docs auto-generated |
| Task Queue Consumer | Celery + Redis | Consumes jobs from Main Backend's queue; decoupled |
| Report Templates | Jinja2 + structured JSON schemas | Templated reports, versioned, extensible |
| Data Source | Calls Calculation Engine directly via gRPC | Bypasses Main Backend completely |
| Storage | S3-compatible (MinIO locally, AWS S3 prod) | Reports stored as JSON/PDF artifacts |
| Serialization | JSON (reports are human-readable structures) | Report content is text-heavy; JSON is appropriate |

**Key Libraries:**
```
fastapi>=0.111
celery>=5.3
redis>=5.0
grpcio>=1.62 (to call Calculation Engine)
jinja2>=3.1
boto3 (S3 storage)
reportlab or weasyprint (PDF generation, Phase 2)
```

**Report Types (phased):**
- Phase 1: Natal chart summary, basic interpretations
- Phase 2: Career, relationships, yearly forecast
- Phase 3: Compatibility (synastry), Dasha timeline, transit reports

---

### 2.3 LLM Interpretation Interface

**Responsibility:** Takes structured chart data (from Calculation Engine), serializes it into an LLM-optimized context string, queries an LLM, and returns natural language interpretation.

| Layer | Choice | Justification |
|-------|--------|---------------|
| Language | Python 3.12 | Best AI/ML ecosystem; native Anthropic/OpenAI SDKs |
| Framework | FastAPI (internal) | Lightweight API surface; handles SSE streaming |
| LLM Provider | Anthropic Claude (primary), OpenAI GPT-4 (fallback) | Anthropic: superior structured reasoning; easy swap |
| Context Serialization | Custom structured text serializer (see §6) | JSON is wasteful for LLM tokens; structured text saves ~40% tokens |
| Streaming | Server-Sent Events (SSE) via FastAPI | Streams LLM tokens to Main Backend → Web/Mobile clients |
| Queue | Celery consumer (async jobs) | Long-running LLM calls should not block HTTP threads |
| Prompt Storage | YAML prompt templates | Version-controlled, hot-swappable prompts |

**Key Libraries:**
```
fastapi>=0.111
anthropic>=0.25
openai>=1.25
celery>=5.3
redis>=5.0
pyyaml (prompt templates)
tiktoken (token counting before sending)
```

---

### 2.4 Main Backend Server

**Responsibility:** Auth, user management, billing, job queuing, routing, session management. The only service exposed to the public internet (behind a gateway).

| Layer | Choice | Justification |
|-------|--------|---------------|
| Language | TypeScript (Node.js 20 LTS) | Fast dev velocity; rich ecosystem; native async |
| Framework | Fastify v4 | 2-3x faster than Express; schema validation built-in; great TypeScript support |
| Auth | Supabase Auth or Clerk | Managed auth with JWT; avoids auth complexity in MVP |
| Database | PostgreSQL 16 (via Supabase or self-hosted) | Relational; handles users, billing, jobs, history |
| ORM | Drizzle ORM | Typesafe, lightweight, excellent PostgreSQL support; better than Prisma for performance |
| Job Queue | BullMQ (Redis-backed) | Reliable job queuing; tracks job status; supports retry |
| Cache | Redis (Upstash for serverless, or self-hosted) | Rate limiting, session cache, chart result cache (TTL-based) |
| Billing | Stripe | Industry standard; supports subscriptions and one-time payments |
| API Gateway | None initially; Caddy or Kong in Phase 2 | MVP: Fastify handles routing; add gateway when traffic grows |
| Real-time | Socket.io (WebSocket) | Job status push, streaming LLM responses to client |

**Key Libraries:**
```
fastify>=4.27
@fastify/websocket
bullmq>=5.3
drizzle-orm>=0.30
postgres (pg driver)
ioredis
stripe>=15
zod (schema validation)
@anthropic-ai/sdk (proxy pass-through if needed)
```

---

### 2.5 Web App

**Responsibility:** Browser-based client. MVP priority.

| Layer | Choice | Justification |
|-------|--------|---------------|
| Language | TypeScript | Type safety; better DX for vibe coding with AI |
| Framework | Next.js 14 (App Router) | SSR, SSG, API routes, file-based routing; best-in-class React |
| Styling | Tailwind CSS + shadcn/ui | Rapid UI; consistent design system; AI-friendly component generation |
| State Management | Zustand | Lightweight; simple API; perfect for MVP |
| Data Fetching | TanStack Query (React Query) | Server state management, caching, background refetch |
| Forms | React Hook Form + Zod | Typesafe forms; minimal re-renders |
| Charts/Visuals | D3.js + custom SVG components | Natal chart rendering, aspect lines |
| Real-time | Native EventSource (SSE) + Socket.io client | LLM streaming + job status |
| Hosting | Vercel (MVP) | Zero-config Next.js deployment; edge network |
| Auth | Supabase Auth UI or Clerk components | Pre-built auth flows |

**Key Libraries:**
```
next>=14.2
react>=18.3
typescript>=5.4
tailwindcss>=3.4
shadcn/ui (component library)
@tanstack/react-query>=5.35
zustand>=4.5
react-hook-form>=7.51
zod>=3.23
d3>=7.9 (chart rendering)
socket.io-client>=4.7
```

---

### 2.6 Mobile App [Phase 3]

**Responsibility:** Native-quality cross-platform mobile client.

| Layer | Choice | Justification |
|-------|--------|---------------|
| Framework | React Native + Expo | Maximum code sharing with Web App (TypeScript, Zod, Zustand); Expo simplifies deployment |
| Navigation | Expo Router | File-based routing; mirrors Next.js mental model |
| Styling | NativeWind (Tailwind for RN) | Consistent with web styling; AI-friendly |
| Charts | react-native-svg + custom components | Native SVG rendering for chart wheels |
| State/Data | Same as Web (Zustand + React Query) | Full code sharing for business logic |
| Push Notifications | Expo Notifications + FCM | Transit alerts, report ready notifications |
| Offline | MMKV + React Query persistence | Offline chart viewing; local cache |

---

## 3. Inter-Service Communication Matrix

### 3.1 Protocol Decisions

| From → To | Protocol | Justification |
|-----------|----------|---------------|
| Main Backend → Calculation Engine | gRPC | Binary protobuf; strongly typed; ~5x faster than REST for numeric chart data; supports streaming for multi-chart requests |
| Main Backend → Report Engine | BullMQ (Redis message queue) | Reports are async long-running jobs; fire-and-forget; queue handles retries and backpressure |
| Main Backend → LLM Interface | BullMQ (Redis message queue) | LLM calls can take 10-60s; must be async; queue prevents HTTP timeout failures |
| Report Engine → Calculation Engine | gRPC (direct) | Report Engine calls Calc Engine directly — this is the key decoupling mechanism; bypasses Main Backend entirely |
| LLM Interface → Calculation Engine | gRPC (direct) | LLM Interface may need fresh chart data without going through Main Backend |
| Main Backend → Web App | REST (HTTP/2) + WebSocket | REST for request-response; WebSocket for job progress and LLM token streaming |
| Main Backend → Mobile App | REST (HTTP/2) + WebSocket | Identical to Web App interface |
| Web App → Main Backend | REST + WebSocket | Standard client-server; TLS only |
| Mobile App → Main Backend | REST + WebSocket | Same as Web; handled by same Fastify server |
| LLM Interface → Main Backend | Webhook (HTTP POST) | Job completion notification; LLM Interface POSTs result back to Main Backend callback URL |
| Report Engine → Main Backend | Webhook (HTTP POST) | Same as above; decoupled completion callback |

### 3.2 Protocol Detail: gRPC for Calculation Engine

The Calculation Engine uses gRPC as its primary protocol. This is the single most important protocol decision in the architecture.

**Why gRPC over REST:**
- Protobuf encoding is 3-5x smaller than JSON for numeric planetary data (degrees, minutes, seconds, declination values)
- Strong schema contract via `.proto` files — prevents silent contract breaks
- Native streaming support for batch chart calculations (calculate 100 charts in one connection)
- Auto-generated type-safe clients in Python, TypeScript, Go
- Supports deadline/timeout propagation across service boundaries

**Sample `.proto` schema (Calculation Engine):**
```protobuf
syntax = "proto3";

package astro.calculation.v1;

service AstroCalculationService {
  rpc CalculateNatalChart (NatalChartRequest) returns (NatalChartResponse);
  rpc CalculateTransits (TransitRequest) returns (TransitResponse);
  rpc CalculateSynastry (SynastryRequest) returns (SynastryResponse);
  rpc BatchCalculate (stream NatalChartRequest) returns (stream NatalChartResponse);
}

message NatalChartRequest {
  double latitude = 1;
  double longitude = 2;
  int64 birth_timestamp_utc = 3; // Unix epoch
  string house_system = 4;       // "placidus", "whole_sign", "kp", "lahiri", etc.
  string ayanamsa = 5;           // for sidereal only
  repeated string requested_points = 6; // ["sun","moon","asc","mc","rahu","ketu"]
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
  string nakshatra = 9;         // for Vedic
  int32 nakshatra_pada = 10;    // for Vedic
}

message NatalChartResponse {
  repeated PlanetPosition planets = 1;
  repeated HouseCusp houses = 2;
  repeated Aspect aspects = 3;
  repeated ArabicLot lots = 4;  // for Hellenistic
  string chart_system = 5;
  int64 calculated_at = 6;
}
```

---

## 4. Making the Calculation Engine Native-Fast

### 4.1 Performance Architecture

The Calculation Engine is the most performance-critical service. Three layers of speed optimization:

**Layer 1: Protocol (gRPC + Protobuf)**
- Binary wire format; no JSON parsing overhead
- HTTP/2 multiplexing — multiple chart requests over one connection
- Bidirectional streaming for batch requests

**Layer 2: Python Runtime Optimization**
- Run multiple Uvicorn workers (1 per CPU core)
- Use `asyncio` for I/O concurrency within each worker
- `pyswisseph` calls are C-extension calls — already near-native speed
- Avoid Python GIL issues: ephemeris calls are CPU-bound but short (<5ms per planet); use `concurrent.futures.ProcessPoolExecutor` for true parallelism on batch requests

**Layer 3: Stateless Horizontal Scaling**
- Zero shared state → trivially scale to N replicas behind a gRPC load balancer
- Kubernetes HPA (Horizontal Pod Autoscaler) based on CPU metrics
- Ephemeris data files (`.se1` files) mounted as a read-only volume — no disk I/O per request

**Layer 4: Optional — Cython/Rust acceleration**
- Phase 2 optimization: wrap hot coordinate transform functions in Cython or a Rust PyO3 extension
- Not needed for MVP; pyswisseph is already C-backed

### 4.2 MCP-Style Protocol Design

For vibe coding: the Calculation Engine's gRPC interface can also be exposed as an MCP (Model Context Protocol) tool server in Phase 2. This allows the LLM Interpretation Interface to call the Calculation Engine directly as a tool, rather than pre-serializing data.

```python
# MCP tool registration (Phase 2)
@mcp_server.tool()
async def calculate_natal_chart(
    latitude: float,
    longitude: float, 
    birth_timestamp_utc: int,
    house_system: str = "placidus"
) -> dict:
    """Calculate a complete natal chart for given birth data."""
    return await grpc_calculate(...)
```

---

## 5. Report Engine Decoupling Strategy

The Report Engine is fully autonomous. It never routes through Main Backend to get chart data.

### 5.1 Data Flow

```
Main Backend
    │
    │  1. Enqueue job via BullMQ
    │     { job_type: "life_report", user_id, birth_data, report_config }
    ▼
Redis Queue
    │
    │  2. Report Engine consumes job
    ▼
Report Generation Engine (Celery worker)
    │
    │  3. Directly calls Calculation Engine via gRPC
    │     (NO Main Backend involvement)
    ▼
Calculation Engine
    │
    │  4. Returns raw chart data
    ▼
Report Engine
    │
    │  5. Applies report templates + interpretation rules
    │  6. Assembles structured report JSON
    │  7. Stores report to S3
    │
    │  8. POSTs completion webhook to Main Backend
    │     { job_id, status: "complete", report_url: "s3://..." }
    ▼
Main Backend
    │
    │  9. Updates DB, notifies client via WebSocket
    ▼
Web/Mobile App
```

### 5.2 Why This Architecture

- Report Engine can be deployed, scaled, and updated independently
- A Main Backend outage does not affect in-progress report generation
- Report Engine can be given different computational resources than Main Backend
- New report types can be added without touching Main Backend code

---

## 6. LLM Interface: Chart Serialization Strategy

### 6.1 The Problem

A full natal chart contains 10+ planets × (longitude, latitude, speed, sign, house, degree, nakshatra, navamsa) + 12 house cusps + 100+ aspects. Sending raw JSON to an LLM wastes tokens and degrades interpretation quality due to noise.

### 6.2 Serialization Pipeline

```python
# Step 1: Filter to interpretation-relevant data only
def filter_chart_for_llm(raw_chart: dict, interpretation_type: str) -> dict:
    """
    For a 'career' report: emphasize 10th house, Saturn, Mars, Mercury.
    For a 'relationships' report: emphasize 7th house, Venus, Moon.
    Domain filtering reduces token count by ~60%.
    """
    ...

# Step 2: Serialize to structured natural-language context
def serialize_to_llm_context(chart: dict) -> str:
    """
    Output format (NOT JSON — LLMs perform better on structured text):
    
    NATAL CHART CONTEXT
    ===================
    Native: [Name], born [Date] at [Time] UTC in [Location]
    Chart System: Placidus | Tropical
    
    PLANETARY POSITIONS
    -------------------
    Sun: 15°32' Aries (House 1) — direct
    Moon: 27°08' Scorpio (House 8) — direct
    Mercury: 22°41' Pisces (House 12) — retrograde ℞
    ...
    
    HOUSE CUSPS
    -----------
    ASC: 02°15' Aries | MC: 01°44' Capricorn
    2H: 28°00' Aries | 3H: 21°00' Taurus | ...
    
    KEY ASPECTS (orb ≤ 6°)
    ----------------------
    Sun conjunct Mercury (2°09') — applying
    Moon square Saturn (1°44') — separating
    ...
    
    VEDIC ADDITIONS (if Jyotish mode)
    -----------------------------------
    Moon Nakshatra: Jyeshtha Pada 3
    Atmakaraka: Saturn
    Current Dasha: Saturn-Mercury (2022-2025)
    """
```

### 6.3 Prompt Architecture

Each interpretation type has a YAML prompt template:

```yaml
# prompts/natal_interpretation.yaml
system: |
  You are a master astrologer trained in both Western and Vedic traditions.
  Interpret charts with psychological depth and practical insight.
  Avoid generic statements. Reference specific placements in your response.
  Output format: { summary, strengths, challenges, themes, advice }

user_template: |
  Please interpret the following natal chart for a {interpretation_type} reading.
  
  {chart_context}
  
  Focus particularly on: {focus_areas}
  Tone: {tone}  # "clinical", "spiritual", "conversational"
  Length: {length_tokens} words
```

### 6.4 Token Budget Management

```python
def prepare_llm_payload(chart: dict, prompt_config: dict) -> dict:
    context = serialize_to_llm_context(chart)
    token_count = count_tokens(context)  # tiktoken
    
    if token_count > MAX_CONTEXT_TOKENS:
        context = compress_context(context, budget=MAX_CONTEXT_TOKENS)
    
    return {
        "model": "claude-sonnet-4-6",
        "max_tokens": prompt_config["length_tokens"],
        "system": render_template(prompt_config["system"]),
        "messages": [{"role": "user", "content": render_template(...)}]
    }
```

---

## 7. Scalability Strategy Per Service

| Service | Scaling Strategy | Scale Trigger | Limits |
|---------|-----------------|---------------|--------|
| Calculation Engine | Horizontal (stateless pods) | CPU > 70% | Scale to 50+ pods; no coordination needed |
| Report Engine | Celery workers (horizontal) | Queue depth > 100 | Add workers; jobs are independent |
| LLM Interface | Celery workers | Queue depth > 20 | LLM rate limits are the real ceiling |
| Main Backend | Horizontal (stateless Fastify) | Request latency > 200ms | Session state in Redis; DB is the bottleneck |
| Web App | CDN + Edge (Vercel) | N/A | Static assets at edge; SSR at Vercel edge |
| Mobile App | CDN for assets | N/A | Same backend as web |

**Database Scaling:**
- Phase 1: Single PostgreSQL instance (Supabase or Railway)
- Phase 2: Read replicas for reporting queries
- Phase 3: PgBouncer connection pooling; consider TimescaleDB for transit history

**Redis Scaling:**
- Phase 1: Single Redis instance (Upstash free tier for dev)
- Phase 2: Redis Cluster for queue + cache separation

---

## 8. Infrastructure & Deployment

### 8.1 Phase 1 (MVP) — Minimal Infrastructure

```
Vercel              → Web App (Next.js)
Railway / Render    → Main Backend (Fastify)
Railway / Render    → Calculation Engine (FastAPI + gRPC)
Supabase            → PostgreSQL + Auth
Upstash             → Redis (Queue + Cache)
Cloudflare R2       → Object storage (report artifacts)
```

**Total MVP infrastructure cost: ~$0-50/month (free tiers)**

### 8.2 Phase 2 — Production Infrastructure

```
Vercel              → Web App
AWS ECS Fargate     → Main Backend (auto-scaling)
AWS ECS Fargate     → Calculation Engine (auto-scaling)
AWS ECS Fargate     → Report Engine (Celery workers)
AWS ECS Fargate     → LLM Interface (Celery workers)
AWS RDS PostgreSQL  → Database (Multi-AZ)
AWS ElastiCache     → Redis Cluster
AWS S3              → Report storage
AWS CloudFront      → CDN
```

### 8.3 Docker Configuration

Each service has its own `Dockerfile` and `docker-compose.yml` for local development. A root-level `docker-compose.yml` orchestrates all services locally.

---

## 9. Security Architecture

- All inter-service gRPC calls use mTLS (mutual TLS) in production
- Main Backend is the only externally exposed service (all others are internal network only)
- JWT tokens verified on every Main Backend request; never forwarded to internal services
- Internal services use API keys for service-to-service auth (not user JWTs)
- Chart data in transit: encrypted via TLS; at rest: encrypted via S3 server-side encryption
- PII (birth data) stored separately from calculation results; separated by design

---

## 10. Vibe Coding Guidelines

When using AI (Claude, Cursor, Copilot) to generate code for this platform:

### Context to include in every prompt:
```
"This is service [X] in a multi-service astrology platform.
Service responsibilities: [paste from this doc]
Communication protocol: [gRPC/REST/Queue]
Tech stack: [paste relevant section]
This service is stateless and must not import or reference other services directly.
Output only [language] code. Include type annotations."
```

### Per-service prompt starters:

**Calculation Engine:**
> "You are coding a stateless Python gRPC service that wraps pyswisseph for astrology calculations. Generate a [function/endpoint/proto] that [task]. No business logic. Return raw numerical data only. Use protobuf types."

**Main Backend:**
> "You are coding a Fastify TypeScript backend for an astrology platform. This is the orchestration layer. Generate [task]. Use Drizzle ORM for DB, BullMQ for queuing, Zod for validation. Auth is handled by Supabase JWT middleware already in place."

**Web App:**
> "You are coding a Next.js 14 App Router component for an astrology web app. Use Tailwind + shadcn/ui. State via Zustand. Data fetching via React Query. Generate [component name] that [behavior]. The component should call [API endpoint]."

---

## 11. File & Folder Structure

```
/astro-platform
├── services/
│   ├── calc-engine/          # Python, gRPC, pyswisseph
│   │   ├── proto/
│   │   ├── src/
│   │   ├── Dockerfile
│   │   └── pyproject.toml
│   ├── report-engine/        # Python, Celery, Jinja2
│   │   ├── templates/
│   │   ├── src/
│   │   └── Dockerfile
│   ├── llm-interface/        # Python, Celery, Anthropic SDK
│   │   ├── prompts/
│   │   ├── src/
│   │   └── Dockerfile
│   └── main-backend/         # TypeScript, Fastify
│       ├── src/
│       │   ├── routes/
│       │   ├── workers/
│       │   ├── db/
│       │   └── lib/
│       └── Dockerfile
├── apps/
│   ├── web/                  # Next.js 14
│   │   ├── app/
│   │   ├── components/
│   │   └── lib/
│   └── mobile/               # React Native + Expo [Phase 3]
├── packages/
│   └── shared-types/         # Shared TypeScript types (zod schemas)
├── proto/                    # Shared protobuf definitions
├── infra/
│   ├── docker-compose.yml    # Local dev
│   └── terraform/            # Phase 2
└── docs/
    ├── ARCHITECTURE.md       # This file
    ├── FRS.md
    └── SCOPE.md
```

---

*Last Updated: June 2026 | Version 1.0 | Next Review: After Phase 1 completion*
