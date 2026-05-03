# MES Data Warehouse

Docker Compose stack providing the data layer for the Manufacturing Execution System (MES).

## Services

| Service | Image | Port | Purpose |
|---------|-------|------|---------|
| PostgreSQL | `postgres:18` | 5432 | Transactional business data (orders, users, products, machine states) |
| ClickHouse | `clickhouse/clickhouse-server:25.9.7` | 8123 (HTTP), 9000 (TCP) | OLAP historian — production, energy, waste time-series |
| NATS | `nats:2.10-alpine` | 4222 (client), 8222 (monitoring) | JetStream message broker for line state events |
| CloudBeaver | `dbeaver/cloudbeaver:latest` | 8978 | Web DB client for PostgreSQL + ClickHouse |
| pgAdmin | `dpage/pgadmin4:8` | 5050 | PostgreSQL admin UI |
| NUI | `ghcr.io/nats-nui/nui:latest` | 31311 | NATS web UI |

**PostgreSQL & ClickHouse credentials:** user `nik` / password `mysecretpassword` / database `mydb` (ClickHouse historian db: `historian`)

## Quick Start

```bash
# Start all services
docker compose up -d

# PostgreSQL — apply schema then test data
docker exec -i postgres-db psql -U nik -d mydb < init.sql
docker exec -i postgres-db psql -U nik -d mydb < seed.sql

# ClickHouse historian — DDL (safe to re-run), then seed data (run once)
docker exec -i clickhouse-db clickhouse-client \
  --user nik --password mysecretpassword --multiquery < init_clickhouse.sql
docker exec -i clickhouse-db clickhouse-client \
  --user nik --password mysecretpassword --multiquery < seed_clickhouse.sql

# Stop
docker compose down

# Wipe volumes and start fresh
docker compose down -v && docker compose up -d

# Re-seed ClickHouse (truncate first, then re-run seed)
docker exec -i clickhouse-db clickhouse-client \
  --user nik --password mysecretpassword \
  --query "TRUNCATE TABLE historian.production_metrics; TRUNCATE TABLE historian.energy_metrics; TRUNCATE TABLE historian.waste_metrics;"
docker exec -i clickhouse-db clickhouse-client \
  --user nik --password mysecretpassword --multiquery < seed_clickhouse.sql
```

## Files

| File | Purpose |
|------|---------|
| `init.sql` | PostgreSQL DDL — all `CREATE TABLE IF NOT EXISTS` and indexes. No data. |
| `seed.sql` | PostgreSQL test data — idempotent (`ON CONFLICT … DO NOTHING`). 6 lines, 9 materials, April 2026 orders. |
| `init_clickhouse.sql` | ClickHouse DDL — creates `historian` database and 3 tables. Safe to re-run. |
| `seed_clickhouse.sql` | ClickHouse April 2026 metrics (~39k rows). **Not idempotent** — truncate before re-running. |

## Database Schema

### Core

| Table | Description |
|-------|-------------|
| `users` | MES users synced from Keycloak JWT on first login; `keycloak_id` (JWT `sub`) is the unique key |
| `uom` | Unit of measure reference — kg, t, pcs, m, m², m³, L, g |
| `skus` | Product SKU catalogue — what gets manufactured |
| `production_lines` | 6 physical production lines: Line 1, Line 2, Briquette, Wired Matts, Rockfon, Grodan |
| `materials` | Raw material inventory — basalt rock, volcanic tuff, petroleum coke, binders, films, pallets |

### Orders

| Table | Description |
|-------|-------------|
| `orders` | Production work orders; status: `created` → `running` → `paused` → `completed` / `cancelled`; cage tracking optional |
| `cages` | One row per completed cage; `cage_guid` auto-generated via `gen_random_uuid()` |

### Logging & Telemetry

| Table | Description |
|-------|-------------|
| `machine_states` | Append-only line state log (running / warning / stopped); duration computed via `LEAD(ts)` |
| `production_events` | Operator annotations — downtimes, changeovers, quality holds, etc.; optionally linked to a machine state |
| `logs` | Structured application log written by the backend's `DbLoggerProvider` |

### Notifications & Settings

| Table | Description |
|-------|-------------|
| `user_notification_prefs` | Per-user alert type preferences (USER / PROCESS / APP / EQUIPMENT / INTEGRATION) |
| `settings` | Global application settings; key-value with history (`previous_value`, `changed_by_id`) |

### Master Data

| Table | Description |
|-------|-------------|
| `products` | Product master record — number, description, dimensions, density |
| `general_sp` | General setpoints per product (package type, ABC category, drum pressure, energy class, binder type, …) |
| `saws_sp` | Saw setpoints (trimming waste, plates per package, cut direction, sheet/cut width, …) |
| `tahu_sp` | TAHU packaging setpoints (pack height, film width, foil code, vacuum, smart date, …) |
| `bundler_sp` | Bundler setpoints (packs per bundle, comp/output length, product turn position, …) |
| `consumables_sp` | Consumables reference (bundle/hooder/wrapper plastic codes, check layers) |
| `ul_sp` | Unit load / palletizing setpoints (products per layer, pallet layers, dimensions, hooding, glue, wrapping, …) |

All six `*_sp` tables have `UNIQUE (product_id)` — exactly one row per product, upserted on save.

### Order lifecycle

```
created ──[start]──► running ──[pause]──► paused
   │                    │                   │
   └──[cancel]──►   cancelled ◄──[cancel]───┘
                    running ──[complete]──► completed
```

## Test Data (`seed.sql`)

Five representative mineral wool products with full setpoints:

| Number | Description |
|--------|-------------|
| `PRD-A100` | Rockwool Slab 100 mm (1200 × 600 × 100 mm, density 100 kg/m³) |
| `PRD-A200` | Rockwool Slab 50 mm (1200 × 600 × 50 mm, density 90 kg/m³) |
| `PRD-B150` | Wired Matt 50 mm (2000 × 1200 × 50 mm, density 80 kg/m³) |
| `PRD-B300` | Wired Matt 100 mm (2000 × 1200 × 100 mm, density 100 kg/m³) |
| `PRD-D100` | Flexi Roll 25 mm (7200 × 1200 × 25 mm, density 40 kg/m³) |

## ClickHouse Historian

Database `historian` stores production time-series by order:

| Table | Interval | Lines | Columns |
|-------|----------|-------|---------|
| `production_metrics` | 5 min | 1, 2 | ts, line_id, order_number, basalt_kg, binder_kg, wool_kg, waste_kg, speed_mpm, efficiency |
| `energy_metrics` | 15 min | 1, 2, 3 | ts, line_id, order_number, gas_m3, elec_kwh, water_m3 |
| `waste_metrics` | 5 min | 1, 2 | ts, line_id, order_number, trimming_kg, startup_kg, rejected_kg, total_kg, waste_pct |

### April 2026 test data

| Line | Orders | Type | Rows |
|------|--------|------|------|
| 1 | 9 × 72 h | SKU-B150 / SKU-B300 | 7,776 prod + 2,592 energy + 7,776 waste |
| 2 | 8 × 84 h | SKU-A100 / SKU-A200 | 8,064 prod + 2,688 energy + 8,064 waste |
| 3 | 9 × 72 h | energy only | 2,592 energy |
| **Total** | | | **~39,552** |

## NATS JetStream

Designed for line state event delivery from OPC UA / field devices to the MES backend.

**Subject scheme:** `lines.<lineId>.state`  
**Payload:** `{"lineId": 1, "state": "running"}` — state values: `running`, `warning`, `stopped`

The backend subscribes to these subjects, writes state changes to `machine_states` in PostgreSQL, and broadcasts `MachineStateUpdated` + `StopInserted` via SignalR to connected browsers.

| URL | Purpose |
|-----|---------|
| `nats://localhost:4222` | Client connections |
| `http://localhost:8222/varz` | Server health |
| `http://localhost:8222/jsz` | JetStream stats |
| `http://localhost:31311` | NUI web UI |

## Test Scripts

### `send-line-state.sh`

Publishes a random new state for a line to NATS. The backend `NatsLineStateService` subscribes to `lines.*.state`, writes the row to `machine_states` in PostgreSQL, and broadcasts a SignalR event to the UI.

```bash
# Default line (LINE_ID=1)
./send-line-state.sh

# Specific line
LINE_ID=2 ./send-line-state.sh
LINE_ID=3 ./send-line-state.sh
```

The script:
1. Reads the current state for the line from PostgreSQL
2. Picks a random *different* state (`running` / `warning` / `stopped`)
3. Publishes `{"lineId": N, "state": "..."}` to `lines.N.state` via `natsio/nats-box` Docker container

**Prerequisites:** docker compose stack running (`docker compose up -d`) and the MES backend running.

**Verify the result in Postgres:**

```bash
docker exec postgres-db psql -U nik -d mydb -c \
  "SELECT id, production_line_id, state, ts FROM machine_states ORDER BY ts DESC LIMIT 5;"
```
