# Astrology Platform — Functional Requirements Specification (FRS)

**Version:** 1.0  
**Status:** MVP Definition  
**Phase Scope:** Phase 1 — Web App MVP  
**Document Owner:** Architect  

---

## 1. Purpose

This document defines the functional requirements for each service in the astrology platform. Requirements are tagged by phase:

- `[P1]` — Phase 1 (MVP / Web-first)
- `[P2]` — Phase 2 (Production hardening)
- `[P3]` — Phase 3 (Mobile + advanced features)

Each requirement has a unique ID: `SVC-NNN` where SVC is the service code.

---

## 2. Service Codes

| Code | Service |
|------|---------|
| CALC | Astrology Calculation Engine |
| RPT | Report Generation Engine |
| LLM | LLM Interpretation Interface |
| MAIN | Main Backend Server |
| WEB | Web Application |
| MOB | Mobile Application |

---

## 3. Functional Requirements: Calculation Engine (CALC)

### 3.1 Core Calculation Functions

**CALC-001 [P1]** — The engine SHALL accept birth data (latitude, longitude, UTC timestamp, house system, ayanamsa) and return a complete natal chart object.

**CALC-002 [P1]** — The natal chart response SHALL include positions for: Sun, Moon, Mercury, Venus, Mars, Jupiter, Saturn, Uranus, Neptune, Pluto, North Node (Rahu), South Node (Ketu), Ascendant, MC.

**CALC-003 [P1]** — Each planetary position SHALL include: zodiac longitude (degrees), zodiac sign, degree within sign, house number, speed (degrees/day), retrograde flag.

**CALC-004 [P1]** — The engine SHALL support at minimum these house systems: Placidus, Whole Sign, Koch, Equal House.

**CALC-005 [P1]** — The engine SHALL compute aspects between all planet pairs using standard orb tables (conjunction 8°, opposition 8°, trine 6°, square 6°, sextile 4°, quincunx 2°).

**CALC-006 [P1]** — The engine SHALL calculate all 12 house cusps.

**CALC-007 [P2]** — The engine SHALL support Vedic (Jyotish) calculations including: Lahiri and Raman ayanamsa, nakshatra (with pada), navamsa (D9), and Saptamsa (D7) divisional charts.

**CALC-008 [P2]** — The engine SHALL support KP (Krishnamurti Paddhati) chart system with sub-lord calculations.

**CALC-009 [P2]** — The engine SHALL calculate current and upcoming planetary transits relative to a natal chart for a given date range.

**CALC-010 [P2]** — The engine SHALL support synastry calculations: overlay of two natal charts, inter-chart aspects.

**CALC-011 [P2]** — The engine SHALL calculate Vedic Vimshottari Dasha periods (main, sub, sub-sub) for a given birth data.

**CALC-012 [P2]** — The engine SHALL calculate Arabic Lots (Parts): Part of Fortune, Part of Spirit, Part of Eros, and others on request.

**CALC-013 [P2]** — The engine SHALL support batch calculation: process multiple chart requests in a single streaming gRPC connection.

**CALC-014 [P3]** — The engine SHALL support Hellenistic chart techniques: bonification/maltreatment, sect (diurnal/nocturnal), triplicity rulers.

**CALC-015 [P3]** — The engine SHALL support Solar Return and Lunar Return charts.

### 3.2 Protocol Requirements

**CALC-016 [P1]** — The engine SHALL expose a gRPC interface defined by the canonical `.proto` file in `/proto/`.

**CALC-017 [P1]** — The engine SHALL expose a REST/JSON fallback endpoint at `/api/v1/calculate` for development and debugging only.

**CALC-018 [P1]** — The engine SHALL be fully stateless: no database connections, no session storage, no in-process cache.

**CALC-019 [P1]** — The engine SHALL return results within 500ms for a single natal chart calculation (p95).

**CALC-020 [P2]** — The engine SHALL return results within 100ms for a single natal chart (p95) after optimization phase.

### 3.3 Validation

**CALC-021 [P1]** — The engine SHALL reject requests where latitude is outside [-90, 90] or longitude is outside [-180, 180].

**CALC-022 [P1]** — The engine SHALL reject requests where birth_timestamp_utc is outside the range [year 1800, year 2400].

**CALC-023 [P1]** — The engine SHALL return a structured error response (gRPC status code + message) for invalid input, not an unhandled exception.

---

## 4. Functional Requirements: Report Generation Engine (RPT)

### 4.1 Report Types

**RPT-001 [P1]** — The engine SHALL generate a Natal Chart Overview report: personality overview, key placements, dominant elements and modalities.

**RPT-002 [P2]** — The engine SHALL generate a Career & Vocation report emphasizing 10th house, 2nd house, Midheaven, Saturn, Mars.

**RPT-003 [P2]** — The engine SHALL generate a Relationships report emphasizing 7th house, Venus, Moon, 5th house.

**RPT-004 [P2]** — The engine SHALL generate a Yearly Forecast (Solar Return) report for a given year.

**RPT-005 [P2]** — The engine SHALL generate a Compatibility report for two birth data inputs (synastry + composite).

**RPT-006 [P3]** — The engine SHALL generate a Dasha Timeline report showing planetary periods for the next 20 years.

**RPT-007 [P3]** — The engine SHALL generate a Transit Report for current and upcoming planetary transits for the next 30/90/365 days.

### 4.2 Report Structure

**RPT-008 [P1]** — All reports SHALL be returned as structured JSON following the canonical Report Schema (see §9).

**RPT-009 [P1]** — Each report JSON SHALL contain: report_id, report_type, version, generated_at, sections[], metadata.

**RPT-010 [P1]** — Each section in a report SHALL contain: section_id, title, content (structured), and optionally highlights[].

**RPT-011 [P2]** — The engine SHALL optionally produce a PDF version of any report, stored to object storage.

### 4.3 Decoupling Requirements

**RPT-012 [P1]** — The Report Engine SHALL NOT make any HTTP calls to the Main Backend Server.

**RPT-013 [P1]** — The Report Engine SHALL obtain all chart data directly from the Calculation Engine via gRPC.

**RPT-014 [P1]** — The Report Engine SHALL consume jobs from a Redis/BullMQ queue, not via direct HTTP invocation from Main Backend.

**RPT-015 [P1]** — On job completion, the Report Engine SHALL POST a webhook to the Main Backend callback URL included in the job payload.

**RPT-016 [P1]** — The Report Engine SHALL store completed report JSON/PDF to object storage (S3-compatible) and include the storage URL in the webhook payload.

### 4.4 Resilience

**RPT-017 [P1]** — The Report Engine SHALL retry failed jobs up to 3 times with exponential backoff before marking as failed.

**RPT-018 [P1]** — The Report Engine SHALL be resumable: if a worker crashes mid-report, the job SHALL be re-queued automatically.

---

## 5. Functional Requirements: LLM Interpretation Interface (LLM)

### 5.1 Interpretation Types

**LLM-001 [P1]** — The interface SHALL generate a natural language interpretation of a natal chart (full interpretation).

**LLM-002 [P1]** — The interface SHALL support scoped interpretations by topic: personality, career, relationships, finances, spirituality.

**LLM-003 [P2]** — The interface SHALL generate natural language interpretations of transit reports ("what does Saturn conjunct your natal Sun mean for you right now?").

**LLM-004 [P2]** — The interface SHALL generate compatibility narrative from synastry data.

**LLM-005 [P3]** — The interface SHALL support a conversational Q&A mode: user asks a specific astrological question, interface answers using chart context.

### 5.2 Serialization Requirements

**LLM-006 [P1]** — The interface SHALL serialize chart data using the structured text format (not raw JSON) before sending to LLM.

**LLM-007 [P1]** — The interface SHALL filter chart data to only include fields relevant to the requested interpretation type before serialization.

**LLM-008 [P1]** — The interface SHALL count tokens in the serialized context using tiktoken before sending to LLM, and truncate if over budget.

**LLM-009 [P1]** — The interface SHALL use versioned prompt templates (YAML files) that can be updated without a code deployment.

**LLM-010 [P2]** — The interface SHALL support multiple LLM providers (Anthropic Claude, OpenAI GPT-4) with a configurable default.

### 5.3 Output Requirements

**LLM-011 [P1]** — LLM responses SHALL be streamed (SSE) when triggered by a real-time client request.

**LLM-012 [P1]** — LLM responses SHALL be stored as text artifacts to object storage for non-real-time (async) jobs.

**LLM-013 [P1]** — The interface SHALL include a structured JSON wrapper around LLM output: { interpretation_id, type, model_used, prompt_version, generated_at, content }.

**LLM-014 [P2]** — The interface SHALL detect and re-try on LLM API rate limit errors with jitter backoff.

**LLM-015 [P2]** — The interface SHALL log token usage per request for cost tracking.

---

## 6. Functional Requirements: Main Backend Server (MAIN)

### 6.1 Authentication & User Management

**MAIN-001 [P1]** — The server SHALL implement user registration via email + password.

**MAIN-002 [P1]** — The server SHALL implement user login returning a JWT access token + refresh token.

**MAIN-003 [P1]** — The server SHALL support Google OAuth login.

**MAIN-004 [P1]** — The server SHALL validate JWT on all protected endpoints.

**MAIN-005 [P1]** — The server SHALL support user profile management: name, email, profile picture.

**MAIN-006 [P1]** — The server SHALL allow users to store multiple birth profiles (self + family + friends), each with: name, birth date, birth time (HH:MM), birth location (city name + lat/lng).

**MAIN-007 [P2]** — The server SHALL support password reset via email.

**MAIN-008 [P2]** — The server SHALL support magic link (passwordless email) login.

### 6.2 Chart Management

**MAIN-009 [P1]** — The server SHALL accept a chart calculation request from the client, validate inputs, forward to Calculation Engine via gRPC, and return results.

**MAIN-010 [P1]** — The server SHALL cache chart calculation results by (latitude, longitude, timestamp, house_system) with a TTL of 24 hours in Redis.

**MAIN-011 [P1]** — The server SHALL store chart results in the database linked to the user's birth profile.

**MAIN-012 [P1]** — The server SHALL return a list of a user's saved charts.

**MAIN-013 [P1]** — The server SHALL allow deletion of saved charts.

### 6.3 Report Management

**MAIN-014 [P1]** — The server SHALL accept a report generation request (report type + birth profile ID), enqueue a job in BullMQ, and return a job_id to the client.

**MAIN-015 [P1]** — The server SHALL expose a job status endpoint: GET /jobs/:job_id → { status, progress, result_url }.

**MAIN-016 [P1]** — The server SHALL push job status updates to connected clients via WebSocket.

**MAIN-017 [P1]** — The server SHALL receive completion webhooks from Report Engine and LLM Interface, update job status in DB, and push WebSocket notification.

**MAIN-018 [P1]** — The server SHALL store report metadata in DB (report_id, type, user_id, status, storage_url, generated_at).

**MAIN-019 [P1]** — The server SHALL generate pre-signed URLs for clients to access report artifacts directly from object storage (not proxied through Main Backend).

**MAIN-020 [P2]** — The server SHALL support report sharing: generate a public shareable link with optional expiry.

### 6.4 Billing & Subscriptions

**MAIN-021 [P2]** — The server SHALL integrate with Stripe for subscription management.

**MAIN-022 [P2]** — The server SHALL enforce usage limits per plan tier (e.g., Free: 1 natal chart, 0 reports; Pro: unlimited charts, 5 reports/month).

**MAIN-023 [P2]** — The server SHALL handle Stripe webhook events: subscription created, cancelled, payment failed.

**MAIN-024 [P2]** — The server SHALL expose a billing portal link (Stripe Customer Portal).

### 6.5 API Requirements

**MAIN-025 [P1]** — All API endpoints SHALL return JSON with a consistent envelope: { success, data, error }.

**MAIN-026 [P1]** — All protected endpoints SHALL require Bearer JWT in Authorization header.

**MAIN-027 [P1]** — The server SHALL implement rate limiting: 100 requests/minute per authenticated user, 10/minute for unauthenticated.

**MAIN-028 [P1]** — The server SHALL expose API docs at /docs (Fastify Swagger).

**MAIN-029 [P2]** — The server SHALL emit structured logs (JSON) for all requests and errors.

---

## 7. Functional Requirements: Web Application (WEB)

### 7.1 Public Pages

**WEB-001 [P1]** — The app SHALL display a public landing/marketing page.

**WEB-002 [P1]** — The app SHALL display a features/pricing page.

**WEB-003 [P1]** — The app SHALL provide a guest chart calculator: user enters birth data, sees natal chart wheel, no account required.

**WEB-004 [P1]** — Guest chart results SHALL NOT be saved; user is prompted to sign up to save.

### 7.2 Authentication Flows

**WEB-005 [P1]** — The app SHALL provide a signup page (email + password + Google OAuth).

**WEB-006 [P1]** — The app SHALL provide a login page.

**WEB-007 [P1]** — The app SHALL handle JWT refresh tokens silently without user re-login.

**WEB-008 [P1]** — The app SHALL redirect unauthenticated users to /login when accessing protected routes.

### 7.3 Dashboard

**WEB-009 [P1]** — Authenticated users SHALL see a dashboard with: their birth profiles, saved charts, recent reports.

**WEB-010 [P1]** — The dashboard SHALL provide a "New Chart" CTA that opens the chart calculator.

### 7.4 Chart Calculator & Display

**WEB-011 [P1]** — The chart form SHALL collect: name (optional), date of birth, time of birth (with "unknown" option), birth city (with geocoding autocomplete), house system (dropdown).

**WEB-012 [P1]** — The chart form SHALL geocode the city name to lat/lng using a geocoding API.

**WEB-013 [P1]** — On submission, the app SHALL call Main Backend → return natal chart data → render chart wheel.

**WEB-014 [P1]** — The chart wheel SHALL be an interactive SVG rendering of the natal chart: zodiac ring, house divisions, planet glyphs, aspect lines.

**WEB-015 [P1]** — Clicking a planet in the chart wheel SHALL show a tooltip/panel with planet details (sign, house, degree, speed).

**WEB-016 [P1]** — The chart SHALL display a tabular planet list below/beside the wheel.

**WEB-017 [P1]** — The chart SHALL display an aspect grid.

**WEB-018 [P2]** — The chart SHALL support toggling between Western and Vedic (South Indian / North Indian) chart styles.

**WEB-019 [P2]** — The chart SHALL support toggling between house systems from a dropdown.

### 7.5 Report Generation

**WEB-020 [P1]** — From the chart view, user SHALL be able to request an AI interpretation (triggers LLM Interface job).

**WEB-021 [P1]** — While the interpretation is being generated, the app SHALL show a progress indicator.

**WEB-022 [P1]** — The AI interpretation SHALL stream into the page via SSE once generation begins.

**WEB-023 [P2]** — User SHALL be able to request a full structured report (triggers Report Engine job).

**WEB-024 [P2]** — The app SHALL notify the user (in-app + email) when a long-form report is ready.

**WEB-025 [P2]** — User SHALL be able to download a report as PDF.

### 7.6 Birth Profile Management

**WEB-026 [P1]** — User SHALL be able to add, edit, and delete birth profiles from a Profiles page.

**WEB-027 [P1]** — Each profile stores: name, date of birth, time of birth, city, lat/lng.

**WEB-028 [P2]** — User SHALL be able to mark one profile as "primary" (default for dashboard display).

### 7.7 Non-Functional Web Requirements

**WEB-029 [P1]** — The app SHALL be fully responsive (mobile-first design using Tailwind breakpoints).

**WEB-030 [P1]** — Lighthouse performance score SHALL be ≥ 85 on desktop.

**WEB-031 [P1]** — Core Web Vitals: LCP < 2.5s, CLS < 0.1, INP < 200ms.

**WEB-032 [P1]** — The app SHALL handle API errors gracefully: display user-facing error messages, never show raw error objects.

**WEB-033 [P2]** — The app SHALL support dark mode (Tailwind dark: variant).

---

## 8. Functional Requirements: Mobile App (MOB) [Phase 3]

**MOB-001 [P3]** — The mobile app SHALL replicate all P1 web features: auth, chart calculator, chart display, AI interpretation.

**MOB-002 [P3]** — The mobile app SHALL render the natal chart wheel natively using react-native-svg.

**MOB-003 [P3]** — The mobile app SHALL support biometric authentication (Face ID / fingerprint).

**MOB-004 [P3]** — The mobile app SHALL support push notifications for: report ready, daily horoscope, transit alerts.

**MOB-005 [P3]** — The mobile app SHALL work offline for viewing previously loaded charts (cached in MMKV).

**MOB-006 [P3]** — The mobile app SHALL be available on iOS (App Store) and Android (Play Store).

---

## 9. Data Models

### 9.1 User

```typescript
interface User {
  id: string;           // UUID
  email: string;
  name: string | null;
  avatar_url: string | null;
  plan: "free" | "pro" | "enterprise";
  created_at: Date;
  updated_at: Date;
}
```

### 9.2 BirthProfile

```typescript
interface BirthProfile {
  id: string;           // UUID
  user_id: string;      // FK → User
  label: string;        // "Me", "Mom", "Partner", etc.
  name: string;
  birth_date: string;   // ISO date: "1990-06-15"
  birth_time: string | null; // "14:30" or null if unknown
  birth_city: string;
  latitude: number;
  longitude: number;
  timezone: string;     // IANA timezone: "Asia/Kolkata"
  is_primary: boolean;
  created_at: Date;
}
```

### 9.3 ChartResult

```typescript
interface ChartResult {
  id: string;
  birth_profile_id: string;
  house_system: string;
  ayanamsa: string | null;
  chart_data: JSON;     // Raw calculation result from Calculation Engine
  created_at: Date;
}
```

### 9.4 Job

```typescript
interface Job {
  id: string;           // BullMQ job ID
  user_id: string;
  type: "report" | "llm_interpretation";
  status: "queued" | "processing" | "complete" | "failed";
  birth_profile_id: string;
  config: JSON;         // Report type, options, etc.
  result_url: string | null;
  error: string | null;
  created_at: Date;
  completed_at: Date | null;
}
```

### 9.5 Report

```typescript
interface Report {
  id: string;
  user_id: string;
  birth_profile_id: string;
  job_id: string;
  type: "natal" | "career" | "relationship" | "yearly" | "compatibility" | "dasha";
  version: string;      // Report template version
  storage_url: string;  // S3 URL (JSON)
  pdf_url: string | null;
  share_token: string | null;
  share_expires_at: Date | null;
  generated_at: Date;
}
```

### 9.6 Canonical Report JSON Schema

```json
{
  "report_id": "uuid",
  "report_type": "natal",
  "version": "1.2",
  "generated_at": "2026-06-15T10:30:00Z",
  "birth_profile": { ... },
  "sections": [
    {
      "section_id": "personality_overview",
      "title": "Personality Overview",
      "content": {
        "summary": "...",
        "key_placements": [...]
      },
      "highlights": ["Sun in Aries", "Moon in Scorpio"],
      "llm_interpretation": "..." 
    }
  ],
  "metadata": {
    "chart_system": "placidus",
    "llm_model": "claude-sonnet-4-6",
    "prompt_version": "natal_v2.1"
  }
}
```

---

## 10. API Contract Summary (Main Backend)

### Authentication

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| POST | /auth/register | No | Create account |
| POST | /auth/login | No | Login, get JWT |
| POST | /auth/refresh | No | Refresh access token |
| POST | /auth/logout | Yes | Invalidate refresh token |
| GET | /auth/me | Yes | Get current user |

### Birth Profiles

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| GET | /profiles | Yes | List all profiles |
| POST | /profiles | Yes | Create profile |
| PUT | /profiles/:id | Yes | Update profile |
| DELETE | /profiles/:id | Yes | Delete profile |

### Charts

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| POST | /charts/calculate | No | Guest chart calculation |
| POST | /charts | Yes | Calculate + save chart |
| GET | /charts | Yes | List saved charts |
| GET | /charts/:id | Yes | Get single chart |
| DELETE | /charts/:id | Yes | Delete chart |

### Jobs & Reports

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| POST | /jobs/interpret | Yes | Start LLM interpretation |
| POST | /jobs/report | Yes | Start report generation |
| GET | /jobs/:id | Yes | Get job status |
| GET | /reports | Yes | List user reports |
| GET | /reports/:id | Yes | Get report metadata + signed URL |

### Real-time

| Protocol | Path | Description |
|----------|------|-------------|
| WebSocket | /ws | Job status updates, notifications |
| SSE | /stream/:job_id | Stream LLM tokens for interpretation |

### Internal (Service-to-Service Only)

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| POST | /internal/webhooks/job-complete | API Key | Receive job completion from engines |

---

## 11. Non-Functional Requirements

| ID | Category | Requirement |
|----|----------|-------------|
| NFR-001 | Performance | Natal chart calculation: p95 < 500ms end-to-end (client to Main Backend to Calc Engine) |
| NFR-002 | Performance | Main Backend API responses: p95 < 200ms (excluding calculation calls) |
| NFR-003 | Availability | Core services (Main Backend, Calc Engine): 99.9% uptime target |
| NFR-004 | Scalability | System shall handle 1,000 concurrent users in Phase 1; 10,000 in Phase 2 |
| NFR-005 | Security | All external traffic over TLS 1.3 |
| NFR-006 | Security | User birth data (PII) shall be encrypted at rest |
| NFR-007 | Security | No service other than Main Backend shall be accessible from the public internet |
| NFR-008 | Compliance | GDPR: users can request data export and deletion |
| NFR-009 | Compliance | Birthdates are PII; stored with explicit user consent |
| NFR-010 | Observability | All services emit structured JSON logs; all errors include trace IDs |
| NFR-011 | DX | All services include a local dev `docker-compose.yml` |
| NFR-012 | DX | All services include environment variable documentation in `.env.example` |

---

*FRS Version 1.0 | June 2026 | Phase 1 (MVP Web) scope*
