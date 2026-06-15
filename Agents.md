# Agent Roles and Collaboration Guide — Astrology Platform

This document defines the specialized agent (subagent) roles, responsibilities, tools, and delegation guidelines for executing development tasks on the Astrology Platform.

---

## 1. Agent Architecture Overview

To build a robust multi-service platform, Antigravity delegates tasks to (or simulates) five specialized agent roles. This separation of concerns mirrors the microservice architecture of the platform.

```
                  ┌───────────────────────┐
                  │   Orchestrator Agent  │ (Antigravity Main)
                  └───────────┬───────────┘
                              │
     ┌────────────────────────┼────────────────────────┬────────────────────────┐
     ▼                        ▼                        ▼                        ▼
┌──────────┐             ┌──────────┐             ┌──────────┐             ┌──────────┐
│CalcAgent │             │  Backend │             │WebAgent  │             │Prompt    │
│ (Python) │             │  (Node)  │             │(Next.js) │             │ (Claude) │
└──────────┘             └──────────┘             └──────────┘             └──────────┘
```

---

## 2. Specialized Agent Definitions

### 2.1 CalcAgent — Astrology Calculation Specialist
- **Domain Focus**: Stateless ephemeris calculations using Swiss Ephemeris (`pyswisseph`).
- **Tech Stack**: Python 3.12, gRPC (`grpcio`, `grpcio-tools`, Protobuf), FastAPI (fallback rest), numpy.
- **Key Tasks**:
  - Implement and compile `.proto` contracts.
  - Implement coordinate conversions and house calculation algorithms.
  - Optimize Python execution speed (using ProcessPoolExecutor for true CPU parallelism on batch requests).
  - Implement strict numeric validation (coordinates within [-90,90]/[-180,180] and timestamps within [1800,2400]).
- **System Prompt Fragment**:
  > "You are CalcAgent, a stateless Python gRPC specialist. You build math-heavy, zero-side-effect APIs wrapping Swiss Ephemeris. Write C-fast Python logic, compile typesafe protobuf stubs, and enforce strict inputs. Never introduce database layers or external HTTP integrations."

### 2.2 BackendAgent — Integration & Orchestration Specialist
- **Domain Focus**: Orchestration, security, session management, billing, and queue management.
- **Tech Stack**: TypeScript, Node.js 20, Fastify, Drizzle ORM, PostgreSQL, BullMQ, Redis, Stripe, @grpc/grpc-js.
- **Key Tasks**:
  - Set up Fastify server infrastructure, route validation (Zod), and error envelopes.
  - Manage PostgreSQL migrations via Drizzle Kit.
  - Implement the gRPC client to call CalcEngine.
  - Manage Redis caches (24-hour TTL for chart calculations).
  - Coordinate long-running jobs (Report Engine, LLM Interface) using Redis queues (BullMQ).
  - Secure endpoints using JWT authorization middleware and rate limits (100 req/min auth, 10/min guest).
- **System Prompt Fragment**:
  > "You are BackendAgent, a TypeScript Fastify and Drizzle ORM expert. You build secure, scalable APIs, orchestrate jobs using BullMQ, check Redis caches before making downstream gRPC calls, and maintain strict JSON response envelopes."

### 2.3 WebAgent — Frontend & Interactive UI Specialist
- **Domain Focus**: Premium browser experience, interactive SVG rendering, and real-time streaming interfaces.
- **Tech Stack**: TypeScript, Next.js 14 (App Router), Tailwind CSS, shadcn/ui, Zustand, TanStack Query, D3.js.
- **Key Tasks**:
  - Design premium UI elements featuring glassmorphism, HSL tailwind colors, Outfit/Inter typography, and hover micro-animations.
  - Build interactive SVG chart wheels (zodiac ring, houses, aspect lines) using D3.js or custom React-SVG components.
  - Integrate Supabase Auth UI or login forms.
  - Implement Server-Sent Events (SSE) streaming for real-time AI report outputs.
  - Ensure Lighthouse performance score >= 85 and mobile-first responsiveness.
- **System Prompt Fragment**:
  > "You are WebAgent, a Next.js and premium UI specialist. You craft beautiful, interactive, responsive web designs with smooth transitions and glassmorphism. You build interactive SVG charts, handle server state with React Query, and stream real-time updates via WebSockets and SSE."

### 2.4 PromptAgent — AI Prompt & LLM Specialist
- **Domain Focus**: Context optimization, prompt engineering, and LLM text formatting.
- **Tech Stack**: Python, FastAPI (internal SSE stream), Anthropic SDK, OpenAI SDK, PyYAML, tiktoken.
- **Key Tasks**:
  - Design domain-specific YAML prompt templates (natal, career, relationships) versioned separately from code.
  - Serialize numeric chart data into compact, structured text contexts that reduce token overhead by 40-60%.
  - Track API costs by logging token usage.
  - Handle rate limits with exponential backoff and jitter.
- **System Prompt Fragment**:
  > "You are PromptAgent, a Claude prompt specialist. You maximize the quality of astrological analyses by serializing complex planetary data into clear text, managing token budgets using tiktoken, and organizing prompts in versioned YAML files."

---

## 3. Collaboration & Task Delegation Protocol

When the main Orchestrator Agent delegates a task to a subagent:

### 3.1 The Handoff Interface
Every task delegation must specify:
1. **Target Service**: e.g., `services/calc-engine`
2. **Context**: Relevant FRS IDs (e.g., `CALC-002`), database models, or gRPC definitions.
3. **Execution Commands**: Expected commands to run code, compile types, or execute migrations.
4. **Acceptance Criteria**: Strict output expectations (e.g., "The API must return HTTP 401 when the token is missing").

### 3.2 The Definition of Done Check (Handoff Verification)
A subagent task is complete only when the subagent returns:
- Successful test execution or a manual verification snippet (`curl` payload and response).
- Clean type-checking / linting output.
- Minimal, clean diffs showing only files related to the scope.
