-- MES database schema — DDL only
-- Apply once after `docker compose up -d`:
--   docker exec -i postgres-db psql -U mesrwl -d mes < ~/projects/mes-dwh/init.sql
-- Then load test data:
--   docker exec -i postgres-db psql -U mesrwl -d mes < ~/projects/mes-dwh/seed.sql

-- ── Core lookup tables (no FK deps) ──────────────────────────────────────────

CREATE TABLE IF NOT EXISTS shifts (
    id          SERIAL      PRIMARY KEY,
    code        CHAR(1)     NOT NULL UNIQUE CHECK (code IN ('A','B','C','D')),
    name        VARCHAR(50) NOT NULL,
    color       VARCHAR(20) NOT NULL DEFAULT '#6366f1',
    sort_order  SMALLINT    NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS users (
    id                 SERIAL PRIMARY KEY,
    keycloak_id        VARCHAR(255) UNIQUE NOT NULL,
    email              VARCHAR(255),
    username           VARCHAR(255),
    full_name          VARCHAR(255),
    role               VARCHAR(20)  NOT NULL DEFAULT 'viewer',
    last_login         TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    last_alert_ack_at  TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS uom (
    id         SERIAL PRIMARY KEY,
    code       VARCHAR(20)  UNIQUE NOT NULL,
    name       VARCHAR(100) NOT NULL,
    name_eng   VARCHAR(100),
    type       VARCHAR(50)  NOT NULL,
    created_at TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS production_lines (
    id                    SERIAL PRIMARY KEY,
    name                  VARCHAR(100) NOT NULL,
    description           TEXT,
    status                VARCHAR(50)  DEFAULT 'active',
    order_control_enabled BOOLEAN      NOT NULL DEFAULT TRUE,
    manual_waste_enabled  BOOLEAN      NOT NULL DEFAULT TRUE
);

CREATE TABLE IF NOT EXISTS materials (
    id             SERIAL PRIMARY KEY,
    code           VARCHAR(50)    UNIQUE NOT NULL,
    name           VARCHAR(255)   NOT NULL,
    name_eng       VARCHAR(255),
    uom            VARCHAR(50)    NOT NULL,
    stock_quantity DECIMAL(10, 3) DEFAULT 0
);

-- ── Master Data ───────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS product_groups (
    id        SERIAL PRIMARY KEY,
    name      TEXT NOT NULL,
    name_eng  TEXT
);

-- Production-line equipment units (curing, ACON, binder, saws, packaging, etc.)
CREATE TABLE IF NOT EXISTS units (
    id            SERIAL PRIMARY KEY,
    name          TEXT NOT NULL,
    name_eng      TEXT,
    display_order INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS correction_types (
    id        SERIAL PRIMARY KEY,
    name      TEXT NOT NULL,
    name_eng  TEXT
);

CREATE TABLE IF NOT EXISTS setpoints (
    id                  SERIAL PRIMARY KEY,
    product_group_id    INTEGER REFERENCES product_groups(id),
    unit_id             INTEGER REFERENCES units(id),
    correction_type_id  INTEGER REFERENCES correction_types(id),
    uom_id              INTEGER REFERENCES uom(id),
    name                TEXT NOT NULL,
    name_eng            TEXT,
    value               TEXT,
    comment             TEXT,
    display_order       INTEGER NOT NULL DEFAULT 0,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    modified_at         TIMESTAMPTZ,
    modified_by         INTEGER REFERENCES users(id)
);

CREATE TABLE IF NOT EXISTS products (
    id                   SERIAL PRIMARY KEY,
    number               VARCHAR(50)    NOT NULL UNIQUE,
    group_id             INTEGER        REFERENCES product_groups(id),
    name                 VARCHAR(255),
    name_eng             VARCHAR(255),
    cover_code           VARCHAR(50),
    package_code         VARCHAR(50),
    sequence             INTEGER,
    production_instruction TEXT,
    uom_id               INTEGER        REFERENCES uom(id),
    cut_direction        TEXT,
    pcs_in_pack          INTEGER,
    packs_in_package     INTEGER,
    length               NUMERIC(10,3),
    width                NUMERIC(10,3),
    thickness            NUMERIC(10,3),
    density              NUMERIC(10,3),
    layers               INTEGER,
    grinding_waste       NUMERIC(10,3),
    norm_waste           NUMERIC(10,3),
    grinding_waste_ow    NUMERIC(10,3),
    category             TEXT,
    comment              TEXT,
    direct_recycle_mode  INTEGER,
    info_1               TEXT,
    info_2               TEXT,
    info_3               TEXT,
    info_4               TEXT,
    info_5               TEXT,
    info_6               TEXT,
    product_line_width   NUMERIC(10,3),
    edge_trim_width      NUMERIC(10,3),
    wet_edge_trim_mode   NUMERIC(10,3),
    wet_edge_trim_width  NUMERIC(10,3),
    mark                 INTEGER,
    state                INTEGER,
    created_at           TIMESTAMPTZ    NOT NULL DEFAULT NOW(),
    modified_at          TIMESTAMPTZ,
    modified_by          INTEGER REFERENCES users(id)
);

-- ── Shift schedule (references shifts + users) ────────────────────────────────

CREATE TABLE IF NOT EXISTS shift_schedule (
    id                  INTEGER     PRIMARY KEY DEFAULT 1,
    pattern             VARCHAR(50) NOT NULL DEFAULT '2on2off2night2off',
    start_time          TIME        NOT NULL DEFAULT '08:00:00',
    timezone            TEXT        NOT NULL DEFAULT 'UTC',
    reference_date      DATE,
    reference_shift_id  INTEGER     REFERENCES shifts(id),
    updated_at          TIMESTAMPTZ,
    updated_by_id       INTEGER     REFERENCES users(id)
);

CREATE TABLE IF NOT EXISTS shift_references (
    shift_id        INTEGER NOT NULL PRIMARY KEY REFERENCES shifts(id) ON DELETE CASCADE,
    reference_date  DATE    NOT NULL,
    UNIQUE (reference_date)
);

-- ── Orders ────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS orders (
    id                  SERIAL PRIMARY KEY,
    order_number        VARCHAR(100) UNIQUE NOT NULL,
    product_id          INTEGER REFERENCES products(id),
    production_line_id  INTEGER REFERENCES production_lines(id),
    volume              DECIMAL(12, 3) NOT NULL,
    uom_id              INTEGER REFERENCES uom(id),
    status              VARCHAR(50)  NOT NULL DEFAULT 'created'
                            CHECK (status IN ('created','running','paused','completed','cancelled')),
    priority            VARCHAR(50)  DEFAULT 'Medium',
    due_date            DATE,
    planned_start_at    TIMESTAMPTZ,
    planned_complete_at TIMESTAMPTZ,
    start_at            TIMESTAMPTZ,
    complete_at         TIMESTAMPTZ,
    seq_order           INTEGER,
    comment             TEXT,
    produced_volume     DECIMAL(12, 3) NOT NULL DEFAULT 0,
    pkg_produced        INTEGER        NOT NULL DEFAULT 0,
    waste_quantity      DECIMAL(12, 3),
    good_quantity       DECIMAL(12, 3),
    shift_id            INTEGER REFERENCES shifts(id),
    created_by_id       INTEGER REFERENCES users(id),
    tx                  INTEGER        NOT NULL DEFAULT 0,
    created_at          TIMESTAMPTZ  DEFAULT NOW(),
    updated_at          TIMESTAMPTZ  DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS order_production_entries (
    id              SERIAL PRIMARY KEY,
    order_id        INTEGER       NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    quantity        NUMERIC(12,3) NOT NULL CHECK (quantity > 0),
    shift_id        INTEGER REFERENCES shifts(id),
    production_date DATE,
    entered_at      TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
    entered_by_id   INTEGER REFERENCES users(id)
);

CREATE INDEX IF NOT EXISTS ope_order_idx ON order_production_entries(order_id);

CREATE TABLE IF NOT EXISTS order_shift_productions (
    id          SERIAL PRIMARY KEY,
    order_id    INTEGER        NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    shift_id    INTEGER        NOT NULL REFERENCES shifts(id),
    date        DATE           NOT NULL DEFAULT CURRENT_DATE,
    produced    NUMERIC(12,3)  NOT NULL DEFAULT 0,
    UNIQUE (order_id, shift_id, date)
);

-- ── Product attribute catalog ─────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS binder_types (
    id       INTEGER PRIMARY KEY,
    name     TEXT NOT NULL,
    name_eng TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS pkf_groups (
    id       INTEGER PRIMARY KEY,
    name     TEXT NOT NULL,
    name_eng TEXT NOT NULL
);

-- Per-product attribute definitions with default values
-- value_type: 'text' | 'integer' | 'numeric' | 'binder_type' | 'pkf_group'
-- For FK types (binder_type, pkf_group) default_value stores the FK id as text
CREATE TABLE IF NOT EXISTS product_attributes (
    id            SERIAL PRIMARY KEY,
    product_id    INTEGER NOT NULL REFERENCES products(id),
    name          TEXT,                   -- display label in Russian
    name_eng      TEXT,                   -- display label in English
    value_type    TEXT NOT NULL DEFAULT 'text',
    default_value TEXT,
    sort_order    INTEGER NOT NULL DEFAULT 0,
    UNIQUE (product_id, name_eng)
);

-- Per-order attribute overrides (COALESCE with product default on read)
CREATE TABLE IF NOT EXISTS order_attributes (
    id           SERIAL PRIMARY KEY,
    order_id     INTEGER NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    attribute_id INTEGER NOT NULL REFERENCES product_attributes(id),
    value        TEXT NOT NULL,
    UNIQUE (order_id, attribute_id)
);

-- ── Logging & telemetry ───────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS logs (
    id      SERIAL PRIMARY KEY,
    type    VARCHAR(20)  NOT NULL,
    message TEXT         NOT NULL,
    level   VARCHAR(10)  NOT NULL,
    ts      TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS logs_ts_idx    ON logs(ts DESC);
CREATE INDEX IF NOT EXISTS logs_type_idx  ON logs(type);
CREATE INDEX IF NOT EXISTS logs_level_idx ON logs(level);

-- Each row is a state-change event. Duration is computed as LEAD(ts) OVER (...) - ts.
CREATE TABLE IF NOT EXISTS machine_states (
    id                 SERIAL PRIMARY KEY,
    production_line_id INTEGER NOT NULL REFERENCES production_lines(id),
    state              VARCHAR(20) NOT NULL CHECK (state IN ('running', 'warning', 'stopped')),
    ts                 TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS machine_states_line_ts_idx ON machine_states(production_line_id, ts DESC);

-- Retain only the last 30 days of machine state data (cleanup on every insert)
CREATE OR REPLACE FUNCTION fn_machine_states_retention() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    DELETE FROM machine_states WHERE ts < NOW() - INTERVAL '30 days';
    RETURN NULL;
END;
$$;
DROP TRIGGER IF EXISTS trg_machine_states_retention ON machine_states;
CREATE TRIGGER trg_machine_states_retention
    AFTER INSERT ON machine_states
    FOR EACH STATEMENT EXECUTE FUNCTION fn_machine_states_retention();

CREATE TABLE IF NOT EXISTS production_events (
    id               SERIAL PRIMARY KEY,
    line_id          INTEGER NOT NULL REFERENCES production_lines(id),
    order_id         INTEGER REFERENCES orders(id),
    machine_state_id INTEGER REFERENCES machine_states(id),
    event_type       VARCHAR(50) NOT NULL
                     CHECK (event_type IN ('downtime_unplanned','downtime_planned','changeover',
                                           'quality_hold','maintenance','operator_note','safety')),
    severity         VARCHAR(20) NOT NULL DEFAULT 'info'
                     CHECK (severity IN ('info','warning','critical')),
    title            VARCHAR(200) NOT NULL,
    description      TEXT,
    start_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    end_at           TIMESTAMPTZ,
    created_by_id    INTEGER REFERENCES users(id),
    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS production_events_line_idx  ON production_events(line_id, created_at DESC);
CREATE INDEX IF NOT EXISTS production_events_state_idx ON production_events(machine_state_id)
    WHERE machine_state_id IS NOT NULL;

-- ── Users & notifications ─────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS user_notification_prefs (
    user_id  INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    log_type VARCHAR(20) NOT NULL
             CHECK (log_type IN ('USER', 'PROCESS', 'APP', 'EQUIPMENT', 'INTEGRATION')),
    enabled  BOOLEAN NOT NULL DEFAULT true,
    PRIMARY KEY (user_id, log_type)
);

-- ── Settings ──────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS settings (
    key            VARCHAR(100) PRIMARY KEY,
    value          TEXT         NOT NULL,
    previous_value TEXT,
    changed_by_id  INTEGER REFERENCES users(id),
    changed_at     TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

-- ── Production entries (manual quantity additions per order) ─────────────────
CREATE TABLE IF NOT EXISTS order_production_entries (
    id              SERIAL PRIMARY KEY,
    order_id        INTEGER      NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    quantity        NUMERIC(12,3) NOT NULL CHECK (quantity > 0),
    shift_id        INTEGER      REFERENCES shifts(id),
    production_date DATE,
    entered_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    entered_by_id   INTEGER      REFERENCES users(id)
);
CREATE INDEX IF NOT EXISTS ope_order_idx ON order_production_entries(order_id);

-- ── Reporting schema ──────────────────────────────────────────────────────────
-- External services connect to this schema with the mes_reports_ro role.
-- They get SELECT-only access; the public schema is not visible to them.

CREATE SCHEMA IF NOT EXISTS mes_reports;

-- Role for external read-only access (separate service / ERP adapter).
-- Password intentionally weak here — change in production.
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'mes_reports_ro') THEN
        CREATE ROLE mes_reports_ro LOGIN PASSWORD 'F51MBO02g25Os4WLmkc4Z8J3' NOINHERIT;
    END IF;
END $$;

GRANT CONNECT ON DATABASE mes TO mes_reports_ro;
GRANT USAGE ON SCHEMA mes_reports TO mes_reports_ro;

-- ── View: mes_reports.orders ──────────────────────────────────────────────────
-- One row per order. All production KPIs flat, ready to consume.

CREATE OR REPLACE VIEW mes_reports.orders AS
SELECT
    o.order_number,
    o.status,
    pl.id                                               AS line_id,
    pl.name                                             AS line_name,
    p.number                                            AS product_number,
    p.name                                              AS product_name,
    p.name_eng                                          AS product_name_eng,
    p.cover_code                                        AS product_cover_code,
    p.package_code                                      AS product_package_code,
    p.length                                            AS product_length,
    p.width                                             AS product_width,
    p.thickness                                         AS product_thickness,
    p.density                                           AS product_density,
    o.priority,
    o.volume                                            AS planned_volume,
    u.code                                              AS uom_code,
    u.name                                              AS uom_name,
    o.planned_start_at,
    o.planned_complete_at,
    o.start_at,
    o.complete_at,
    ROUND(
        EXTRACT(EPOCH FROM (COALESCE(o.complete_at, NOW()) - o.start_at)) / 3600.0
    , 2)                                                AS duration_hours,
    COALESCE(o.produced_volume, 0)                      AS produced_volume,
    COALESCE(
        (SELECT SUM(e.quantity) FROM order_production_entries e WHERE e.order_id = o.id), 0
    )                                                   AS manual_entries_total,
    COALESCE(o.pkg_produced, 0)                         AS pkg_produced,
    COALESCE(o.waste_quantity, 0)                       AS waste_quantity,
    COALESCE(o.good_quantity, 0)                        AS good_quantity,
    CASE
        WHEN o.volume > 0 AND o.produced_volume IS NOT NULL
        THEN ROUND((o.produced_volume / o.volume * 100)::numeric, 1)
    END                                                 AS progress_pct,
    o.comment,
    o.created_at
FROM orders o
LEFT JOIN production_lines pl ON pl.id = o.production_line_id
LEFT JOIN products          p  ON p.id  = o.product_id
LEFT JOIN uom               u  ON u.id  = o.uom_id;

-- ── View: mes_reports.order_shift_productions ─────────────────────────────────
-- Per-shift production breakdown. Join to mes_reports.orders on order_number.

CREATE OR REPLACE VIEW mes_reports.order_shift_productions AS
SELECT
    o.order_number,
    s.code      AS shift_code,
    s.name      AS shift_name,
    s.color     AS shift_color,
    osp.date,
    osp.produced,
    u.code      AS uom_code
FROM order_shift_productions osp
JOIN orders  o ON o.id  = osp.order_id
JOIN shifts  s ON s.id  = osp.shift_id
JOIN uom     u ON u.id  = o.uom_id;

-- Grant SELECT on current and future views in mes_reports to the RO role
GRANT SELECT ON ALL TABLES IN SCHEMA mes_reports TO mes_reports_ro;
ALTER DEFAULT PRIVILEGES IN SCHEMA mes_reports
    GRANT SELECT ON TABLES TO mes_reports_ro;
