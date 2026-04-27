-- MES database schema
-- Run once to bootstrap: psql -h localhost -U nik -d mydb -f init.sql

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
    type       VARCHAR(50)  NOT NULL,
    created_at TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS skus (
    id          SERIAL PRIMARY KEY,
    code        VARCHAR(50)  UNIQUE NOT NULL,
    name        VARCHAR(255) NOT NULL,
    description TEXT,
    unit        VARCHAR(50)  DEFAULT 'packages'
);

CREATE TABLE IF NOT EXISTS production_lines (
    id          SERIAL PRIMARY KEY,
    name        VARCHAR(100) NOT NULL,
    description TEXT,
    status      VARCHAR(50)  DEFAULT 'active'
);

CREATE TABLE IF NOT EXISTS materials (
    id             SERIAL PRIMARY KEY,
    code           VARCHAR(50)    UNIQUE NOT NULL,
    name           VARCHAR(255)   NOT NULL,
    unit           VARCHAR(50)    NOT NULL,
    stock_quantity DECIMAL(10, 3) DEFAULT 0
);

CREATE TABLE IF NOT EXISTS orders (
    id                 SERIAL PRIMARY KEY,
    order_number       VARCHAR(100) UNIQUE NOT NULL,
    sku_id             INTEGER REFERENCES skus(id),
    production_line_id INTEGER REFERENCES production_lines(id),
    volume             DECIMAL(12, 3) NOT NULL,
    uom_id             INTEGER REFERENCES uom(id),
    status             VARCHAR(50)  NOT NULL DEFAULT 'created'
                           CHECK (status IN ('created','running','paused','completed','cancelled')),
    priority             VARCHAR(50)  DEFAULT 'Medium',
    due_date             DATE,
    planned_start_at     TIMESTAMPTZ,
    planned_complete_at  TIMESTAMPTZ,
    start_at             TIMESTAMPTZ,
    complete_at          TIMESTAMPTZ,
    comment              TEXT,
    cage               BOOLEAN      NOT NULL DEFAULT false,
    cage_size          INTEGER      NOT NULL DEFAULT 50,
    produced_volume    DECIMAL(12, 3) NOT NULL DEFAULT 0,
    pkg_produced       INTEGER        NOT NULL DEFAULT 0,
    created_by_id      INTEGER REFERENCES users(id),
    created_at         TIMESTAMPTZ  DEFAULT NOW(),
    updated_at         TIMESTAMPTZ  DEFAULT NOW()
);

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

-- Each row is a state-change event. Duration is computed dynamically as
-- LEAD(ts) OVER (...) - ts, or NOW() - ts for the still-active segment.
CREATE TABLE IF NOT EXISTS machine_states (
    id                 SERIAL PRIMARY KEY,
    production_line_id INTEGER NOT NULL REFERENCES production_lines(id),
    state              VARCHAR(20) NOT NULL CHECK (state IN ('running', 'warning', 'stopped')),
    ts                 TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS machine_states_line_ts_idx ON machine_states(production_line_id, ts DESC);

CREATE TABLE IF NOT EXISTS cages (
    id               SERIAL PRIMARY KEY,
    order_number     VARCHAR(100) NOT NULL REFERENCES orders(order_number) ON DELETE CASCADE,
    cage_guid        UUID         NOT NULL DEFAULT gen_random_uuid(),
    cage_size        INTEGER      NOT NULL DEFAULT 50,
    packages         INTEGER      NOT NULL,
    completed_at     TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    completed_by_id  INTEGER REFERENCES users(id)
);

-- Per-user notification preferences (which log types appear in the Alerts panel)
CREATE TABLE IF NOT EXISTS user_notification_prefs (
    user_id  INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    log_type VARCHAR(20) NOT NULL
             CHECK (log_type IN ('USER', 'PROCESS', 'APP', 'EQUIPMENT', 'INTEGRATION')),
    enabled  BOOLEAN NOT NULL DEFAULT true,
    PRIMARY KEY (user_id, log_type)
);

-- Application settings (key-value store with change history)
CREATE TABLE IF NOT EXISTS settings (
    key            VARCHAR(100) PRIMARY KEY,
    value          TEXT         NOT NULL,
    previous_value TEXT,
    changed_by_id  INTEGER REFERENCES users(id),
    changed_at     TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

INSERT INTO settings (key, value) VALUES
    ('timeline_auto_refresh_enabled',     'true'),
    ('timeline_refresh_interval_seconds', '60')
ON CONFLICT (key) DO NOTHING;

-- Seed: UOMs
INSERT INTO uom (code, name, type) VALUES
    ('kg',  'Kilogram',      'weight'),
    ('t',   'Tonne',         'weight'),
    ('g',   'Gram',          'weight'),
    ('pkg', 'Packages',       'count'),
    ('m',   'Meter',         'length'),
    ('m2',  'Square Meter',  'area'),
    ('m3',  'Cubic Meter',   'volume'),
    ('L',   'Liter',         'volume')
ON CONFLICT (code) DO NOTHING;

-- Seed: SKUs
INSERT INTO skus (code, name, description, unit) VALUES
    ('SKU-A100', 'Product Alpha 100',   'Standard alpha product, 100g variant', 'packages'),
    ('SKU-A200', 'Product Alpha 200',   'Standard alpha product, 200g variant', 'packages'),
    ('SKU-B150', 'Product Beta 150',    'Beta product line, 150g variant',      'packages'),
    ('SKU-B300', 'Product Beta 300',    'Beta product line, 300g variant',      'packages'),
    ('SKU-C400', 'Product Charlie 400', 'Charlie product, 400g variant',        'packages'),
    ('SKU-C500', 'Product Charlie 500', 'Charlie product, 500g variant',        'packages'),
    ('SKU-D100', 'Product Delta 100',   'Delta product line, 100g variant',     'packages'),
    ('SKU-D250', 'Product Delta 250',   'Delta product line, 250g variant',     'packages'),
    ('SKU-E350', 'Product Echo 350',    'Echo product, 350g variant',           'packages'),
    ('SKU-E500', 'Product Echo 500',    'Echo product, 500g variant',           'packages')
ON CONFLICT (code) DO NOTHING;

-- Seed: production lines
INSERT INTO production_lines (id, name, description, status) VALUES
    (1, 'Wired Matts', 'Primary production line',   'active'),
    (2, 'Line 2', 'Secondary production line', 'active'),
    (3, 'Line 3', 'Packaging line',            'active')
ON CONFLICT (id) DO NOTHING;

-- Seed: raw materials
INSERT INTO materials (code, name, unit, stock_quantity) VALUES
    ('MAT-001', 'Raw Material A', 'kg',   5000),
    ('MAT-002', 'Raw Material B', 'kg',   3200),
    ('MAT-003', 'Packaging Film', 'm2',  12000),
    ('MAT-004', 'Cardboard Box',  'pcs',  8500),
    ('MAT-005', 'Label Sheet',    'pcs', 25000)
ON CONFLICT (code) DO NOTHING;

-- Seed: machine state events (one row per state-change; duration computed dynamically)
-- Guard: only insert when the table is empty so re-running init.sql is safe
INSERT INTO machine_states (production_line_id, state, ts)
SELECT v.line_id, v.state, NOW() + v.offset_interval
FROM (VALUES
    -- Line 1 (Primary — ~87% running)
    (1, 'running',  INTERVAL '-480 minutes'),
    (1, 'running',  INTERVAL '-410 minutes'),
    (1, 'warning',  INTERVAL '-355 minutes'),
    (1, 'running',  INTERVAL '-340 minutes'),
    (1, 'warning',  INTERVAL '-260 minutes'),
    (1, 'running',  INTERVAL '-250 minutes'),
    (1, 'stopped',  INTERVAL '-185 minutes'),
    (1, 'running',  INTERVAL '-173 minutes'),
    (1, 'warning',  INTERVAL  '-83 minutes'),
    (1, 'running',  INTERVAL  '-63 minutes'),
    -- Line 2 (Secondary — ~78% running)
    (2, 'running',  INTERVAL '-480 minutes'),
    (2, 'warning',  INTERVAL '-420 minutes'),
    (2, 'running',  INTERVAL '-395 minutes'),
    (2, 'stopped',  INTERVAL '-325 minutes'),
    (2, 'running',  INTERVAL '-310 minutes'),
    (2, 'running',  INTERVAL '-255 minutes'),
    (2, 'warning',  INTERVAL '-215 minutes'),
    (2, 'running',  INTERVAL '-195 minutes'),
    (2, 'stopped',  INTERVAL '-115 minutes'),
    (2, 'running',  INTERVAL '-105 minutes'),
    -- Wired Matts (Packaging — ~92% running)
    (3, 'running',  INTERVAL '-480 minutes'),
    (3, 'running',  INTERVAL '-390 minutes'),
    (3, 'warning',  INTERVAL '-315 minutes'),
    (3, 'running',  INTERVAL '-303 minutes'),
    (3, 'running',  INTERVAL '-218 minutes'),
    (3, 'stopped',  INTERVAL '-148 minutes'),
    (3, 'running',  INTERVAL '-140 minutes'),
    (3, 'running',  INTERVAL  '-60 minutes')
) AS v(line_id, state, offset_interval)
WHERE NOT EXISTS (SELECT 1 FROM machine_states LIMIT 1);
