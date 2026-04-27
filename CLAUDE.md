# DWH — Data Layer

## Stack
- PostgreSQL 18 — transactional MES data
- ClickHouse 25.9.7 — reserved for OLAP / time-series (OPC UA telemetry)
- docker compose in `/home/nik/projects/dwh/`

## Connection details (both services)
- Host: `localhost`
- User: `nik` / Password: `mysecretpassword` / Database: `mydb`
- Postgres port: `5432` | ClickHouse HTTP: `8123`, TCP: `9000`

## Commands
```bash
docker compose up -d          # start
docker compose down           # stop
docker compose down -v        # wipe volumes
psql -h localhost -U nik -d mydb -f init.sql   # manual schema init
```

## Schema (`init.sql`)
Tables: `users`, `skus`, `production_lines`, `materials`, `orders`

- `orders.status` enum values: `queued`, `in_progress`, `completed`, `cancelled`
- `orders.sequence` is computed at query time (not stored) via `ROW_NUMBER()` window function
- `users.keycloak_id` is the JWT `sub` claim — unique constraint, upserted on login

## Rules
- `init.sql` is the single source of truth for the schema — apply it manually after `docker compose up`
- Seed data (10 SKUs, 3 production lines, 5 materials) is idempotent (`ON CONFLICT DO NOTHING`)
- ClickHouse is provisioned but not wired to the API yet
- Never commit passwords — they are dev-only values
