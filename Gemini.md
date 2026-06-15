# Gemini AI Core Development Guide — Astrology Platform

This document serves as the master instruction set for Gemini-based models (such as Antigravity) developing or modifying components in this codebase. It defines the system context, programming standards, design aesthetics, and prompting strategies for each service.

---

## 1. Architectural Context & Service Architecture

The platform is designed as a modular monorepo. Each service must remain strictly decoupled, stateless where possible, and only communicate via designated protocols.

```
┌──────────────────────────────────────────────────────────────────┐
│                           Web Client                             │
│                  Next.js 14 App Router, Tailwind                 │
└────────────────────────────────┬─────────────────────────────────┘
                                 │ REST (HTTP/2) / WebSockets
                                 ▼
┌──────────────────────────────────────────────────────────────────┐
│                       Main Backend Server                        │
│                 TypeScript / Fastify / Drizzle ORM               │
└──────────┬──────────────────────┬──────────────────────┬─────────┘
           │ gRPC                 │ BullMQ               │ BullMQ
           ▼                      ▼                      ▼
┌────────────────────┐  ┌──────────────────┐  ┌────────────────────┐
│ Calculation Engine │  │  Report Engine   │  │   LLM Interface    │
│ Python/pyswisseph  │  │ Python / Celery  │  │  Python / Celery   │
└──────────▲─────────┘  └─────────┬────────┘  └──────────┬─────────┘
           │                      │                      │
           └────── gRPC (Direct) ─┴────── gRPC (Direct) ─┘
```

### Protocol Matrix
- **Main Backend ──> Calculation Engine**: gRPC (`astro_calculation.proto`)
- **Main Backend ──> Report / LLM Engines**: BullMQ (Redis-backed queues)
- **Report / LLM Engines ──> Calculation Engine**: gRPC (Direct communication bypassing backend)
- **Engines ──> Main Backend**: Webhooks with signature headers (`x-webhook-secret`)

---

## 2. Astrology Domain & Calculation Requirements

Astrology calculations are mathematically intensive and rely on the Swiss Ephemeris. Developers must adhere to these mathematical definitions:

### 2.1 Swiss Ephemeris (`pyswisseph`)
- Primary ephemeris data files (`.se1`) must be mounted as read-only.
- All calculations must accept a decimal UTC timestamp, latitude, longitude, and house system.
- Planetary speed must be computed (degrees/day) along with retrograde status (speed < 0).

### 2.2 House Systems
- **Tropical / Western**: Placidus (default), Whole Sign, Koch, Equal House, Campanus, Regiomontanus.
- **Sidereal / Vedic**: Whole Sign or KP house cusps. Ayanamsa must be supported:
  - Lahiri (default for Vedic/Jyotish)
  - Raman
  - Fagan-Bradley
  - KP (Krishnamurti)

### 2.3 Calculations & Aspects
- **Planets**: Sun, Moon, Mercury, Venus, Mars, Jupiter, Saturn, Uranus, Neptune, Pluto, North Node (Rahu), South Node (Ketu), Ascendant (ASC), and Midheaven (MC).
- **Aspects**: standard orb ranges must be used:
  - **Conjunction**: 8° orb
  - **Opposition**: 8° orb
  - **Trine**: 6° orb
  - **Square**: 6° orb
  - **Sextile**: 4° orb
  - **Quincunx**: 2° orb
- **Vimshottari Dasha**: Computed using Moon's longitude relative to Nakshatra boundaries (13°20' per Nakshatra).

---

## 3. UI/UX Design Aesthetics & Styling System

All frontend applications (Next.js web and React Native mobile) must look premium, modern, and visually stunning. **Do not write basic or generic UIs.**

### 3.1 Styling System Core Rules
- **Typography**: Use modern sans-serif fonts such as Google Fonts' **Inter** or **Outfit**. Avoid default system serifs.
- **Color Palettes**: Avoid basic red, green, and blue. Use sophisticated HSL-based harmonious colors. Sleek dark modes and subtle gradients are preferred.
- **Glassmorphism**: Use backdrop filters, subtle semi-transparent borders, and blurred background meshes to create a premium feel.
  ```css
  background: rgba(255, 255, 255, 0.05);
  backdrop-filter: blur(12px);
  border: 1px solid rgba(255, 255, 255, 0.1);
  ```
- **Micro-Animations**: Add hover transitions, fade-ins, and scale changes (e.g., `transition-all duration-300 hover:scale-[1.02]`).
- **No Placeholders**: Never use plain color boxes or text placeholders for charts. If a chart wheel is required, generate SVGs dynamically or render dummy SVG assets using real planet calculations.

---

## 4. Token Budget & LLM Serialization Strategy

When writing serialization logic for sending charts to the LLM (Claude/GPT-4):

### 4.1 Token Minimization
LLMs perform better on clean, structured text than raw JSON.
- **Bad (JSON payload)**: Sending 100+ aspect pairings, latitude/longitude, database metadata keys, speed values, and full house coordinates in JSON. (Wastes 3k+ tokens).
- **Good (Structured Text)**:
  ```
  PLANETARY POSITIONS
  Sun: 15°32' Aries (House 1) - direct
  Moon: 27°08' Scorpio (House 8) - direct
  ASC: 02°15' Aries | MC: 01°44' Capricorn
  ASPECTS (orb ≤ 6°)
  Sun conjunct Mercury (2°09')
  Moon square Saturn (1°44')
  ```
- Save up to 40-60% of LLM token cost by dynamically filtering the positions to the scope of the request (e.g., filtering out minor aspects, focusing on the 10th house/Saturn for career reports).

### 4.2 Prompt Management
- Prompt templates must be stored as external YAML files. Do not hardcode prompts in source files.
- The Python/Node LLM connector must count tokens using a local encoder (`tiktoken`) before making calls to avoid rate limits or truncation.

---

## 5. Mono-repo Constraints & Coding Guidelines

To preserve code quality, Gemini must follow these guidelines:

### 5.1 Service Decoupling
- Never import code directly across services. (e.g., `services/report-engine` cannot import helper functions from `services/calc-engine` directly).
- Use local packages (`packages/shared-types`) for sharing TypeScript/Zod schemas.

### 5.2 Environment Variables & Secrets
- Never commit `.env` or hardcoded tokens.
- Add new environment variables to the service's `.env.example` and the master `/docs/ENV-VARIABLES.md` before coding.

### 5.3 API Response Contracts
All API endpoints must wrap responses in a standard envelope:
- **Success**: `{ "success": true, "data": ... }`
- **Error**: `{ "success": false, "error": { "code": "ERROR_CODE", "message": "Human-readable description" } }`

---

## 6. Definition of Done Checklist

Before presenting code to the user as complete, ensure:
1. Code compiles and typechecks without errors (`tsc --noEmit` or Python linters).
2. Code runs successfully inside Docker containers or local node environments.
3. Edge cases (invalid coordinates, null birth times, leap years) are covered.
4. Structured logging is used. No debug `console.log` statements are left.
5. Verification commands (e.g., curl, test scripts) are provided and execute successfully.

---

## 7. Structured Logging Standards

All services must use clean, structured logging instead of raw console statements.

### 7.1 Node.js / TypeScript Standards (Main Backend)
- **Library**: `pino` (native to Fastify).
- **Format**: Structured JSON in production for searchability (e.g. Datadog, ELK). Pretty printing is enabled in development for readability.
- **Log Levels**: Use appropriate levels:
  - `logger.debug()` for transient, granular debugging (SQL queries, cache lookups).
  - `logger.info()` for lifecycle events (server boot, successful payments, completed jobs).
  - `logger.warn()` for degradations (cache miss, transient retries).
  - `logger.error()` for failures that require action (gRPC connection down, DB constraint violations).

### 7.2 Python Standards (Calc, Report, LLM Engines)
- **Library**: Python standard library `logging` module, wrapped in our custom `/utils/logger.py` module.
- **Format**: Outputs standard human-readable format in local development and structured JSON in production when `JSON_LOGGING=true`.
- **Usage**:
  ```python
  from utils.logger import get_logger
  
  logger = get_logger("service-name")
  logger.info("Service initialized", extra={"port": 50051})
  logger.error("Failed to execute calculation", exc_info=True)
  ```

