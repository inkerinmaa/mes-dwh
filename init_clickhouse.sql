-- ClickHouse Historian — DDL only
-- Apply once after `docker compose up -d`:
--   docker exec -i clickhouse-db clickhouse-client \
--     --user nik --password mysecretpassword --multiquery \
--     < ~/projects/dwh/init_clickhouse.sql
-- Then load test data:
--   docker exec -i clickhouse-db clickhouse-client \
--     --user nik --password mysecretpassword --multiquery \
--     < ~/projects/dwh/seed_clickhouse.sql

CREATE DATABASE IF NOT EXISTS historian;

-- 5-minute production metrics per line/order
-- basalt_kg, binder_kg, wool_kg, waste_kg — raw material and output per interval
-- speed_mpm — line speed in metres/minute
-- efficiency — OEE-style percentage (0-100)
CREATE TABLE IF NOT EXISTS historian.production_metrics
(
    ts           DateTime,
    line_id      UInt8,
    order_number String,
    basalt_kg    Float32,
    binder_kg    Float32,
    wool_kg      Float32,
    waste_kg     Float32,
    speed_mpm    Float32,
    efficiency   Float32
)
ENGINE = MergeTree()
PARTITION BY toYYYYMM(ts)
ORDER BY (line_id, ts)
SETTINGS index_granularity = 8192;

-- 5-minute waste breakdown per line/order
-- trimming_kg — saw/trimming waste; startup_kg — startup losses; rejected_kg — quality rejects
-- total_kg — sum of all waste categories; waste_pct — total_kg / (total_kg + wool_kg) * 100
CREATE TABLE IF NOT EXISTS historian.waste_metrics
(
    ts           DateTime,
    line_id      UInt8,
    order_number String,
    trimming_kg  Float32,
    startup_kg   Float32,
    rejected_kg  Float32,
    total_kg     Float32,
    waste_pct    Float32
)
ENGINE = MergeTree()
PARTITION BY toYYYYMM(ts)
ORDER BY (line_id, ts)
SETTINGS index_granularity = 8192;

-- 15-minute energy consumption per line/order
-- gas_m3 — natural gas (m³)
-- elec_kwh — electricity (kWh)
-- water_m3 — process water (m³)
CREATE TABLE IF NOT EXISTS historian.energy_metrics
(
    ts           DateTime,
    line_id      UInt8,
    order_number String,
    gas_m3       Float32,
    elec_kwh     Float32,
    water_m3     Float32
)
ENGINE = MergeTree()
PARTITION BY toYYYYMM(ts)
ORDER BY (line_id, ts)
SETTINGS index_granularity = 8192;

-- 1-minute per-unit process snapshots (EAV: line_id + unit + param → value)
-- unit values: 'curing', 'acon', 'binder' (Lines 1–2); 'main', 'package' (Lines 3–6)
-- param values per unit — see seed_clickhouse.sql for the full list
CREATE TABLE IF NOT EXISTS historian.process_snapshots
(
    ts       DateTime,
    line_id  UInt8,
    unit     LowCardinality(String),
    param    LowCardinality(String),
    value    Float32
)
ENGINE = MergeTree()
PARTITION BY toYYYYMM(ts)
ORDER BY (line_id, unit, param, ts)
SETTINGS index_granularity = 8192;
