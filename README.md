# MES Data Warehouse

Docker Compose stack providing the data layer for the Manufacturing Execution System (MES).

## Services

| Service | Image | Port | Purpose |
|---------|-------|------|---------|
| PostgreSQL | `postgres:18` | 5432 | Transactional business data (orders, users, SKUs, materials) |
| ClickHouse | `clickhouse/clickhouse-server:25.9.7` | 8123 (HTTP), 9000 (TCP) | OLAP analytics, time-series telemetry |

**Credentials (both services):** user `nik` / password `mysecretpassword` / database `mydb`

## Quick Start

```bash
# Start all services
docker compose up -d

# Stop
docker compose down

# Wipe volumes and start fresh
docker compose down -v && docker compose up -d
```

## Database Schema

The schema is auto-applied by the API on startup (`CREATE TABLE IF NOT EXISTS`). To apply it manually:

```bash
psql -h localhost -U nik -d mydb -f init.sql
```

### Tables

| Table | Description |
|-------|-------------|
| `users` | MES users, synced from Keycloak JWT on first login |
| `skus` | Product SKUs — what gets manufactured |
| `production_lines` | Physical production lines (Line 1, 2, 3) |
| `materials` | Raw materials with stock quantities |
| `orders` | Production work orders (linked to SKU, line, created-by user) |

### Order lifecycle

```
queued → in_progress → completed
              ↓
          cancelled
```

The `sequence` column is computed at query time via `ROW_NUMBER()` — first active order is "In Progress", second is "Next", rest are "Next+N".

## ClickHouse

Currently unused — reserved for future time-series telemetry (OPC UA process data: temperature, pressure, cycle time) and historical KPI analytics.
