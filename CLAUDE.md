# DWH — Data Layer

## Stack
- PostgreSQL 18 — transactional MES data (orders, users, machine states, events)
- ClickHouse 25.9.7 — OLAP historian (production metrics, energy, waste time-series)
- NATS 2.10 — message broker with JetStream persistence (line state events)
- CloudBeaver — web DB client for PostgreSQL + ClickHouse (port 8978)
- pgAdmin 4 — PostgreSQL admin UI (port 5050)
- docker compose in `/home/nik/projects/dwh/`

## Connection details

| Service | URL / Host | Credentials |
|---------|-----------|-------------|
| PostgreSQL | `localhost:5432` db `mes` | `mesrwl` / `HzG03x45efVB3jAwg3kSOI88KdA9QNAa` |
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

# PostgreSQL — apply schema then test data
docker exec -i postgres-db psql -U mesrwl -d mes < ~/projects/dwh/init.sql
docker exec -i postgres-db psql -U mesrwl -d mes < ~/projects/dwh/seed.sql

# ClickHouse historian — apply schema then test data (run once each)
docker exec -i clickhouse-db clickhouse-client \
  --user nik --password mysecretpassword --multiquery \
  < ~/projects/dwh/init_clickhouse.sql
docker exec -i clickhouse-db clickhouse-client \
  --user nik --password mysecretpassword --multiquery \
  < ~/projects/dwh/seed_clickhouse.sql

# Wipe and re-seed ClickHouse historian (all four tables)
docker exec -i clickhouse-db clickhouse-client \
  --user nik --password mysecretpassword \
  --query "TRUNCATE TABLE historian.production_metrics; TRUNCATE TABLE historian.energy_metrics; TRUNCATE TABLE historian.waste_metrics; TRUNCATE TABLE historian.process_snapshots;"

# Seed only process_snapshots (without re-seeding everything)
awk '/^-- ── Process snapshots/,0' ~/projects/dwh/seed_clickhouse.sql | \
  docker exec -i clickhouse-db clickhouse-client \
  --user nik --password mysecretpassword --multiquery
```

## Files

| File | Purpose |
|------|---------|
| `init.sql` | PostgreSQL DDL — `CREATE TABLE IF NOT EXISTS` + indexes. No data. |
| `seed.sql` | PostgreSQL test data — idempotent (`ON CONFLICT … DO NOTHING`). Includes 6 production lines, 9 materials, April 2026 orders. |
| `init_clickhouse.sql` | ClickHouse DDL — creates `historian` database + 3 tables (production_metrics, energy_metrics, waste_metrics). |
| `seed_clickhouse.sql` | ClickHouse test data — April 2026 production, energy, waste metrics (~38k rows). **Not idempotent** — run once. |
| `import-production-plan.sh` | Imports a `;`-delimited production-plan CSV into `orders`. See "Production plan CSV import" below. |
| `production_plan_sample.csv` | Small sample CSV matching the real export format, for testing the import script. |

## Schema (`init.sql`)

### Core tables

| Table | Key columns | Notes |
|-------|-------------|-------|
| `users` | `keycloak_id`, `email`, `username`, `full_name`, `role`, `last_login`, `last_alert_ack_at` | Upserted on every login; `keycloak_id` is JWT `sub` |
| `uom` | `code`, `name`, `name_eng`, `type` | Unit of measure reference (kg, t, m², m³, pcs, L, m, g); `name_eng` is the English display name |
| `skus` | `code`, `name`, `name_eng`, `description`, `unit` | Product SKU catalogue; `name_eng` is the English display name |
| `production_lines` | `id` (1–6), `name`, `description`, `status` | 6 production lines: Line 1, Line 2, Briquette, Wired Matts, Rockfon, Grodan |
| `materials` | `code`, `name`, `name_eng`, `unit`, `stock_quantity` | Raw material inventory; `name_eng` is the English display name |

### Orders

| Table | Key columns | Notes |
|-------|-------------|-------|
| `orders` | `order_number`, `sku_id`, `production_line_id`, `volume`, `uom_id`, `status`, `priority`, `due_date`, `cage`, `cage_size`, `produced_volume`, `pkg_produced`, `created_by_id` | Status: `created` → `running` → `paused` → `running` → `completed` / `cancelled` |
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
| `products` | `number` (unique), `description`, `description_eng`, `sku`, `code`, `package_code`, `initial_code`, `instruction`, `length`, `width`, `thickness`, `density` | Product master record; `description_eng` is the English display description |
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
| SKUs | 10 | Mineral wool product SKUs |
| Production lines | 6 | Line 1, Line 2, Briquette (id 3), Wired Matts (id 4), Rockfon (id 5), Grodan (id 6) — uses `ON CONFLICT DO UPDATE` |
| Materials | 9 | Basalt Fibre, Phenol Binder, PE Shrink Film, Stretch Wrap, Pallet, Basalt Rock, Volcanic Tuff, Petroleum Coke, PP Film Roll |
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
| `material` | `sku_id` (resolved via `skus.code = material`) |
| `planned_order_start_time` | `planned_start_at` |
| `planned_order_finish_time` | `planned_complete_at` |
| `total_planned_order_qty` | `volume` |

All rows in a run go to the same `production_line_id = $LINE`. When `$LINE` is Wired Matts (id 4, the default), `cage=true` and `uom_id` is set to `pkg` automatically — matching the New Order form's behavior — with `cage_size = skus.pcs_in_pack` (falls back to 50 if unset). For any other line, `cage=false` and `uom_id`/`cage_size` take their schema defaults. `status='created'`, `priority='Medium'` always. Rows whose `material` doesn't match any `skus.code` are silently skipped (the `INSERT … SELECT … WHERE s.code = …` returns zero rows). Idempotent on `order_number` (`ON CONFLICT DO NOTHING`) — safe to re-run on a partially-imported file.

## Rules
- `init.sql` is DDL only — no data, no `INSERT` statements
- `seed.sql` is idempotent test data — `ON CONFLICT … DO NOTHING` on every INSERT
- Always run `init.sql` before `seed.sql`
- `seed_clickhouse.sql` is NOT idempotent — run once; truncate tables before re-seeding
- Never commit passwords — they are dev-only values
