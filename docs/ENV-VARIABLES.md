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
