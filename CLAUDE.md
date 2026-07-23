# DWH — Data Layer

## Stack
- PostgreSQL 18 — transactional MES data (orders, users, machine states, events)
- ClickHouse 25.9.7 — OLAP historian (production metrics, energy, waste time-series)
- NATS 2.10 — message broker with JetStream persistence (line state events)
- CloudBeaver — web DB client for PostgreSQL + ClickHouse (port 8978)
- pgAdmin 4 — PostgreSQL admin UI (port 5050)
- docker compose in `/home/nik/projects/mes-dwh/`

## Connection details

| Service | URL / Host | Credentials |
|---------|-----------|-------------|
| PostgreSQL (app) | `localhost:5432` db `mes` | `mesrwl` / `HzG03x45efVB3jAwg3kSOI88KdA9QNAa` |
| PostgreSQL (reports RO) | `localhost:5432` db `mes`, schema `mes_reports` | `mes_reports_ro` / `F51MBO02g25Os4WLmkc4Z8J3` |
| ClickHouse HTTP | `localhost:8123` db `historian` | `nik` / `mysecretpassword` |
| ClickHouse TCP | `localhost:9000` | `nik` / `mysecretpassword` |
| NATS | `nats://localhost:4222` | anonymous |
| NATS monitoring | `http://localhost:8222` | — |
| NATS UI (NUI) | `http://localhost:31311` | — |
| CloudBeaver | `http://localhost:8978` | set on first launch |
| pgAdmin | `http://localhost:5050` | `nik@local.dev` / `admin` |

## Commands
```bash
docker compose up -d          # start
docker compose down           # stop
docker compose down -v        # wipe volumes

# PostgreSQL — fresh install: apply schema then test data
docker exec -i postgres-db psql -U mesrwl -d mes < ~/projects/mes-dwh/init.sql
docker exec -i postgres-db psql -U mesrwl -d mes < ~/projects/mes-dwh/seed.sql

# PostgreSQL — existing DB: run migrations (safe to re-run)
docker exec -i postgres-db psql -U mesrwl -d mes < ~/projects/mes-dwh/migrate.sql

# ClickHouse historian — apply schema then test data (run once each)
docker exec -i clickhouse-db clickhouse-client \
  --user nik --password mysecretpassword --multiquery \
  < ~/projects/mes-dwh/init_clickhouse.sql
docker exec -i clickhouse-db clickhouse-client \
  --user nik --password mysecretpassword --multiquery \
  < ~/projects/mes-dwh/seed_clickhouse.sql

# Wipe and re-seed ClickHouse historian (all four tables)
docker exec -i clickhouse-db clickhouse-client \
  --user nik --password mysecretpassword \
  --query "TRUNCATE TABLE historian.production_metrics; TRUNCATE TABLE historian.energy_metrics; TRUNCATE TABLE historian.waste_metrics; TRUNCATE TABLE historian.process_snapshots;"

# Seed only process_snapshots (without re-seeding everything)
awk '/^-- ── Process snapshots/,0' ~/projects/mes-dwh/seed_clickhouse.sql | \
  docker exec -i clickhouse-db clickhouse-client \
  --user nik --password mysecretpassword --multiquery
```

## Files

| File | Purpose |
|------|---------|
| `init.sql` | PostgreSQL DDL — `CREATE TABLE IF NOT EXISTS` + indexes. No data. Use for fresh installs. Tables are ordered to satisfy FK deps on first run (no `--single-transaction` hack needed). |
| `migrate.sql` | PostgreSQL incremental migrations — safe to run on an existing DB. Handles: SKU→Products merge, shift tables, `order_shift_productions`, `shift_references`, production line status corrections. Seeds shifts A–D and default `2on2off2night2off` schedule. |
| `seed.sql` | PostgreSQL test data — idempotent (`ON CONFLICT … DO NOTHING`). Includes production lines (Lines 1, 2, Wired Matts active; others inactive), 4 WM products, shift schedule seeding. |
| `init_clickhouse.sql` | ClickHouse DDL — creates `historian` database + 4 tables (production_metrics, energy_metrics, waste_metrics, process_snapshots). |
| `seed_clickhouse.sql` | ClickHouse test data — April 2026 production, energy, waste metrics (~38k rows). **Not idempotent** — run once. |
| `import-production-plan.sh` | Imports a `;`-delimited production-plan CSV into `orders`. See "Production plan CSV import" below. |
| `production_plan_sample.csv` | Small sample CSV matching the real export format, for testing the import script. |

## Schema (`init.sql`)

### Core tables

| Table | Key columns | Notes |
|-------|-------------|-------|
| `users` | `keycloak_id`, `email`, `username`, `full_name`, `role`, `last_login`, `last_alert_ack_at` | Upserted on every login; `keycloak_id` is JWT `sub` |
| `uom` | `code`, `name`, `name_eng`, `type` | Unit of measure reference (kg, t, m², m³, pcs, L, m, g); `name_eng` is the English display name |
| `production_lines` | `id` (1–6), `name`, `description`, `status` | 6 production lines: Line 1, Line 2, Briquette, Wired Matts (id=4), Rockfon, Grodan |
| `materials` | `code`, `name`, `name_eng`, `unit`, `stock_quantity` | Raw material inventory; `name_eng` is the English display name |

### Shifts

| Table | Key columns | Notes |
|-------|-------------|-------|
| `shifts` | `id`, `code` (A/B/C/D), `name`, `color`, `sort_order` | Four production shifts; code and sort_order are immutable; name and color are editable by admins |
| `shift_schedule` | `id=1`, `pattern`, `start_time`, `reference_date`?, `reference_shift_id`? | Single-row config; patterns: `4on4off` (16-day), `dupont` (28-day), `continental` (12-day), `2on2off2night2off` (8-day day/night). Default: `2on2off2night2off` — uses `shift_references` instead of `reference_date`/`reference_shift_id`. |
| `shift_references` | `shift_id` (PK), `reference_date` (UNIQUE) | Per-shift cycle anchor dates for `2on2off2night2off`. Dates must all differ. 2-day spacing (A=today, B=+2, C=+4, D=+6) gives one day-shift + one night-shift per calendar day. |

### Orders

| Table | Key columns | Notes |
|-------|-------------|-------|
| `orders` | `order_number`, `product_id`, `production_line_id`, `volume`, `uom_id`, `status`, `priority`, `due_date`, `cage`, `cage_size`, `produced_volume`, `pkg_produced`, `waste_quantity`, `good_quantity`, `shift_id`, `created_by_id` | Status: `created` → `running` → `paused` → `running` → `completed` / `cancelled`. `shift_id` = shift active when the order was first started. Only one order can be `running` per line at a time. |
| `order_shift_productions` | `order_id`, `shift_id`, `date`, `produced` | Per-shift production accumulator; UNIQUE(order_id, shift_id, date); populated at cage-completion time via UPSERT |
| `cages` | `order_number`, `cage_guid`, `cage_size`, `packages`, `completed_at`, `completed_by_id` | One row per completed cage; `cage_guid` is `gen_random_uuid()` |

### Logging & telemetry

| Table | Key columns | Notes |
|-------|-------------|-------|
| `machine_states` | `production_line_id`, `state` (running/warning/stopped), `ts` | Append-only state-change log; duration computed via `LEAD(ts) OVER (...)` |
| `production_events` | `line_id`, `order_id?`, `machine_state_id?`, `event_type`, `severity`, `title`, `description`, `start_at`, `end_at?` | Operator annotations; `machine_state_id` links to an auto-detected stop |
| `logs` | `type` (USER/PROCESS/APP/EQUIPMENT/INTEGRATION), `message`, `level`, `ts` | App log written by `DbLoggerProvider` |

### Notifications & settings

| Table | Key columns | Notes |
|-------|-------------|-------|
| `user_notification_prefs` | `user_id`, `log_type`, `enabled` | Per-user notification filter preferences |
| `settings` | `key` (PK), `value`, `previous_value`, `changed_by_id`, `changed_at` | Global app settings |

### Master Data

| Table | Key columns | Notes |
|-------|-------------|-------|
| `products` | `number` (unique), `name`, `name_eng`, `description`, `description_eng`, `sku`, `code`, `package_code`, `initial_code`, `instruction`, `length`, `width`, `thickness`, `density`, `pcs_in_pack`, `packs_on_pallet` | Product master record (merged from old `skus` table — `skus` no longer exists) |
| `general_sp` | `product_id` (unique FK), `package`, `abc_cat`, `waste_suply`, `drum_pressure`, `saw_cross`, `product_type`, `energy_class`, `binder_type`, … | General setpoints; one row per product |
| `saws_sp` | `product_id` (unique FK), `trimming_waste_ows`, `plates_in_pkg`, `cut_direction`, `layers`, `sheet_width`, `cut_width`, … | Saw setpoints |
| `tahu_sp` | `product_id` (unique FK), `tahu_finish_pack_height`, `tahu_output_height`, `tahu_side_welding`, `tahu_film_width`, `tahu_foil_code`, … | TAHU (packaging) setpoints |
| `bundler_sp` | `product_id` (unique FK), `bundler_packs_per_bundle`, `bundler_comp_length`, `bundler_output_length`, … | Bundler setpoints |
| `consumables_sp` | `product_id` (unique FK), `bundle_plastic_code`, `hooder_plastic_code`, `wrapper_plastic_code`, `check_layers` | Consumables reference; `hooder_plastic_code` NULL for products without hooding |
| `ul_sp` | `product_id` (unique FK), `ul_product_per_layer`, `ul_pallet_layers`, `ul_pallet_dim`, `ul_pallet_height`, `ul_use_hooding`, `ul_use_glue`, `ul_use_wrapping`, … | Unit load (palletizing) setpoints |

All six `*_sp` tables have a `UNIQUE (product_id)` constraint — one row per product, upserted on save.

## Seed data (`seed.sql`)

Seeded via `ON CONFLICT … DO NOTHING` so the script is safe to re-run on a live DB.

| Section | Count | Notes |
|---------|-------|-------|
| Settings | 5 keys | `timeline_auto_refresh_enabled`, `timeline_refresh_interval_seconds`, `show_efficiency_chart`, `show_stats_cards`, `show_uptime_diagram` |
| UOMs | 8 | kg, t, pcs, m, m², m³, L, g |
| Production lines | 6 | Line 1, Line 2, Briquette (id 3), Wired Matts (id 4), Rockfon (id 5), Grodan (id 6) — uses `ON CONFLICT DO UPDATE` |
| Materials | 9 | Basalt Fibre, Phenol Binder, PE Shrink Film, Stretch Wrap, Pallet, Basalt Rock, Volcanic Tuff, Petroleum Coke, PP Film Roll |
| Shifts | 4 | A (blue), B (green), C (amber), D (red) — seeded in `migrate.sql`, not `seed.sql` |
| Machine states | 46 | Historical state log for all 6 lines (guarded with `WHERE NOT EXISTS`) |
| Products | 5 | PRD-A100 (Slab 100mm), PRD-A200 (Slab 50mm), PRD-B150 (Wired Matt 50mm), PRD-B300 (Wired Matt 100mm), PRD-D100 (Flexi Roll 25mm) |
| Setpoints | 5 rows × 6 tables | All setpoint tables seeded for every product; IDs resolved by `JOIN products p ON p.number = v.num` |

## ClickHouse historian

Database `historian` has three tables:

| Table | Interval | Lines | Purpose |
|-------|----------|-------|---------|
| `production_metrics` | 5 min | 1, 2 | Basalt/binder consumed, wool produced, waste, speed, efficiency |
| `energy_metrics` | 15 min | 1, 2, 3 | Gas (m³), electricity (kWh), water (m³) per interval |
| `waste_metrics` | 5 min | 1, 2 | Trimming, startup, rejected waste breakdown + total + waste % |
| `process_snapshots` | 1 min | 1–6 | EAV format: (ts, line_id, unit, param, value). Lines 1–2: units curing/acon/binder; Lines 3–6: main/package. Queried by `/api/production` endpoint. |

Queries aggregate by `order_number` and are used by `/api/reports/pkf`, `/api/reports/energy`, and `/api/reports/waste`.

## ClickHouse seed data summary

| Segment | Orders | Rows |
|---------|--------|------|
| Line 1 production_metrics | 9 × 72 h | 9 × 864 = 7,776 |
| Line 2 production_metrics | 8 × 84 h | 8 × 1,008 = 8,064 |
| Line 1 energy_metrics | 9 × 72 h | 9 × 288 = 2,592 |
| Line 2 energy_metrics | 8 × 84 h | 8 × 336 = 2,688 |
| Line 3 energy_metrics | 9 × 72 h | 9 × 288 = 2,592 |
| Line 1 waste_metrics | 9 × 72 h | 9 × 864 = 7,776 |
| Line 2 waste_metrics | 8 × 84 h | 8 × 1,008 = 8,064 |
| **Total** | | **~39,552** |

PostgreSQL `orders` table has 26 April 2026 completed orders (9+8+9) linked to the ClickHouse data by `order_number`.

## NATS JetStream

NATS runs on port 4222 with JetStream enabled. Intended subject scheme for line state events:

| Subject | Payload | Consumer |
|---------|---------|----------|
| `lines.<id>.state` | `{"lineId":1,"state":"running"}` | .NET background subscriber → writes `machine_states` in Postgres, broadcasts SignalR |

State values: `running`, `warning`, `stopped`.

NATS monitoring API: `http://localhost:8222/varz` (health), `/jsz` (JetStream stats).
NUI web UI: `http://localhost:31311` — browse subjects, streams, and publish test messages.

## Test script (`send-line-state.sh`)

Publishes a random new state for a line:

```bash
./send-line-state.sh           # LINE_ID defaults to 1
LINE_ID=2 ./send-line-state.sh
```

Flow: script queries Postgres for current state → picks a different one → publishes to `lines.<id>.state` via `natsio/nats-box` Docker → backend `NatsLineStateService` writes to `machine_states` + broadcasts SignalR `MachineStateUpdated`.

Verify:
```bash
docker exec postgres-db psql -U mesrwl -d mes -c \
  "SELECT id, production_line_id, state, ts FROM machine_states ORDER BY ts DESC LIMIT 5;"
```

## Production plan CSV import (`import-production-plan.sh`)

Imports a `;`-delimited production-plan export into `orders`:

```bash
./import-production-plan.sh production_plan_sample.csv          # LINE defaults to 4 (Wired Matts)
./import-production-plan.sh /path/to/real_export.csv
LINE=1 ./import-production-plan.sh /path/to/real_export.csv     # import to a different line
```

Column mapping (by CSV header name, order-independent):

| CSV column | `orders` column |
|------------|------------------|
| `planned_order` | `order_number` |
| `material` | `product_id` (resolved via `products.number = material`) |
| `planned_order_start_time` | `planned_start_at` |
| `planned_order_finish_time` | `planned_complete_at` |
| `total_planned_order_qty` | `volume` |

All rows in a run go to the same `production_line_id = $LINE`. When `$LINE` is Wired Matts (id 4, the default), `cage=true` and `uom_id` is set to `pkg` automatically — matching the New Order form's behavior — with `cage_size = products.pcs_in_pack` (falls back to 50 if unset). For any other line, `cage=false` and `uom_id`/`cage_size` take their schema defaults. `status='created'`, `priority='Medium'` always. Rows whose `material` doesn't match any `products.number` are silently skipped. Idempotent on `order_number` (`ON CONFLICT DO NOTHING`) — safe to re-run on a partially-imported file.

## Reporting schema (`mes_reports`)

A dedicated PostgreSQL schema exposes clean read-only views for external services (ERP adapters, reporting tools, data exports). External apps connect as `mes_reports_ro` — they see only `mes_reports.*` and cannot touch the `public` schema.

### Role

| Role | Password (dev) | Privileges |
|------|---------------|------------|
| `mes_reports_ro` | `F51MBO02g25Os4WLmkc4Z8J3` | `CONNECT` on `mes` DB, `USAGE` on `mes_reports` schema, `SELECT` on all views |

Connection string for an external service:
```
Host=localhost;Port=5432;Database=mes;Username=mes_reports_ro;Password=F51MBO02g25Os4WLmkc4Z8J3;Search Path=mes_reports
```

### Views

#### `mes_reports.orders` — one row per order, all KPIs flat

| Column | Source | Notes |
|--------|--------|-------|
| `order_number` | `orders.order_number` | Natural key |
| `status` | `orders.status` | created / running / paused / completed / cancelled |
| `line_id`, `line_name` | `production_lines` | Production line |
| `product_number`, `product_name`, `product_name_eng` | `products` | Product identity |
| `product_cover_code`, `product_package_code` | `products` | — |
| `product_length/width/thickness/density` | `products` | Physical dimensions |
| `priority` | `orders.priority` | Low / Medium / High / Critical |
| `planned_volume`, `uom_code`, `uom_name` | `orders` + `uom` | Plan quantity |
| `cage`, `cage_size` | `orders` | Cage tracking config |
| `planned_start_at`, `planned_complete_at` | `orders` | Plan dates |
| `start_at`, `complete_at` | `orders` | Actual dates |
| `duration_hours` | computed | `EXTRACT(EPOCH FROM complete_at - start_at) / 3600`, rounded to 2 dp; uses `NOW()` for running orders |
| `produced_volume` | `orders.produced_volume` | COALESCE 0 |
| `produced_packages` | `SUM(cages.packages)` | Correlated subquery |
| `pkg_produced` | `orders.pkg_produced` | COALESCE 0 |
| `waste_quantity`, `good_quantity` | `orders` | COALESCE 0 |
| `progress_pct` | computed | `produced_volume / planned_volume * 100`, 1 dp; NULL when volume = 0 |
| `comment` | `orders.comment` | Operator note |
| `created_at` | `orders.created_at` | — |

#### `mes_reports.order_shift_productions` — per-shift production breakdown

| Column | Notes |
|--------|-------|
| `order_number` | Join key to `mes_reports.orders` |
| `shift_code` | A / B / C / D |
| `shift_name`, `shift_color` | Display fields |
| `date` | Calendar date of the shift |
| `produced` | Packages/volume produced in this shift on this date |
| `uom_code` | Inherited from the order |

### Typical queries

```sql
-- All running orders with produced amounts
SELECT order_number, line_name, product_name,
       planned_volume, produced_volume, progress_pct, uom_code
FROM mes_reports.orders
WHERE status = 'running';

-- Shift breakdown for a specific order
SELECT shift_code, shift_name, date, produced
FROM mes_reports.order_shift_productions
WHERE order_number = '1260007201'
ORDER BY date, shift_code;

-- Completed orders in a date range
SELECT order_number, product_name, start_at, complete_at,
       planned_volume, produced_volume, waste_quantity, duration_hours
FROM mes_reports.orders
WHERE status = 'completed'
  AND complete_at BETWEEN '2026-07-01' AND '2026-07-31';
```

### Adding new views

1. Add `CREATE OR REPLACE VIEW mes_reports.<name> AS ...` to both `init.sql` and `migrate.sql`
2. Add `GRANT SELECT ON ALL TABLES IN SCHEMA mes_reports TO mes_reports_ro;` after the view
3. Apply: `docker exec -i postgres-db psql -U mesrwl -d mes < ~/projects/mes-dwh/migrate.sql`

## Rules
- `init.sql` is DDL only — no data, no `INSERT` statements
- `seed.sql` is idempotent test data — `ON CONFLICT … DO NOTHING` on every INSERT
- Always run `init.sql` before `seed.sql`; for existing DBs run `migrate.sql` instead of `init.sql`
- Any new table must be added to **both** `init.sql` (for fresh installs) and `migrate.sql` (for existing DBs)
- `seed_clickhouse.sql` is NOT idempotent — run once; truncate tables before re-seeding
- Never commit passwords — they are dev-only values
- The `skus` table no longer exists — all product/SKU data lives in `products`
