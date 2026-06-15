# Astrology Platform — Master Development Phases Index

**Version:** 1.0  
**Source Documents:** ARCHITECTURE.md v1.0, FRS.md v1.0  
**Scope Covered:** Phase 1 MVP (Web) → Phase 2 (Production) → Phase 3 (Mobile)

---

## How To Use This Document Set

Each phase document is self-contained. Before starting any phase, the team **must** complete the verification checklist at the top of that phase document. No exceptions.

A "clean deliverable" means: the item is built, tested, documented, and confirmed working in isolation before the next item depends on it.

---

## Document Map

| File | Contents |
|------|----------|
| `00-MASTER-INDEX.md` | This file. Overview and navigation. |
| `01-PHASE-0-FOUNDATION.md` | Repository, tooling, infra baseline, `.env` scaffolding |
| `02-PHASE-1A-CALC-ENGINE.md` | Calculation Engine — gRPC service, proto, pyswisseph |
| `03-PHASE-1B-MAIN-BACKEND.md` | Main Backend — Fastify, DB schema, auth, routing |
| `04-PHASE-1C-REPORT-ENGINE.md` | Report Engine — Celery, templates, S3, webhook |
| `05-PHASE-1D-LLM-INTERFACE.md` | LLM Interface — serializer, prompts, Anthropic SDK, SSE |
| `06-PHASE-1E-WEB-APP.md` | Web App — Next.js, auth flows, chart wheel, dashboard |
| `07-PHASE-1F-INTEGRATION.md` | Full P1 integration, E2E tests, performance baselines |
| `08-PHASE-2-PRODUCTION.md` | Phase 2 — Billing, advanced reports, prod infra, hardening |
| `09-PHASE-3-MOBILE.md` | Phase 3 — React Native, Expo, push notifications, offline |

---

## Phase Dependency Chain

```
Phase 0 (Foundation)
    │
    ├─── Phase 1A (Calc Engine)     ← No dependencies except Phase 0
    │         │
    │         ▼
    ├─── Phase 1B (Main Backend)    ← Depends on Phase 0; calls 1A
    │         │
    │         ▼
    ├─── Phase 1C (Report Engine)   ← Depends on 1A (gRPC) + 1B (queue/webhook)
    │         │
    │         ▼
    ├─── Phase 1D (LLM Interface)   ← Depends on 1A (gRPC) + 1B (queue/webhook)
    │         │
    │         ▼
    ├─── Phase 1E (Web App)         ← Depends on 1B (REST API + WebSocket)
    │         │
    │         ▼
    └─── Phase 1F (Integration)     ← Depends on all 1A–1E being complete
              │
              ▼
         Phase 2 (Production)       ← Depends on Phase 1F sign-off
              │
              ▼
         Phase 3 (Mobile)           ← Depends on Phase 2 stable API
```

---

## Global Rules (Apply to Every Phase)

1. **No phase begins without completing the previous phase's deliverable checklist.**
2. **Every service must have a working `.env.example` before any code is written.**
3. **Every service must have a `docker-compose.yml` entry before first run.**
4. **No service imports or directly instantiates code from another service.**
5. **All secrets go in environment variables. No hardcoded credentials, ever.**
6. **Every API change must update the API contract section in `FRS.md`.**
7. **Every phase ends with a smoke test of all deliverables in this specific phase.**

---

## Definition of Done (Per Task)

A task is done when ALL of the following are true:

- [ ] Code is written
- [ ] Code runs without error locally
- [ ] The specific behaviour described is demonstrable (curl, test, UI screenshot)
- [ ] Edge cases stated in the task are handled
- [ ] Error responses are tested (not just happy path)
- [ ] `.env.example` updated if a new variable was introduced
- [ ] No `console.log` debug statements left in committed code (use structured logging)

---

*This index is read-only. Add no tasks here — add them to the relevant phase file.*
