-- MES incremental migrations
-- Safe to re-run on an existing DB: uses IF NOT EXISTS / ON CONFLICT guards.
--   docker exec -i postgres-db psql -U mesrwl -d mes < ~/projects/mes-dwh/migrate.sql

-- ── 1. Add ordering fields to products (absorb skus) ─────────────────────────

ALTER TABLE products
  ADD COLUMN IF NOT EXISTS name             VARCHAR(255),
  ADD COLUMN IF NOT EXISTS name_eng         VARCHAR(255),
  ADD COLUMN IF NOT EXISTS unit             VARCHAR(50)  DEFAULT 'packages',
  ADD COLUMN IF NOT EXISTS pcs_in_pack      INTEGER,
  ADD COLUMN IF NOT EXISTS packs_on_pallet  INTEGER;

-- ── 2. Absorb skus table into products ────────────────────────────────────────

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'skus') THEN
    INSERT INTO products (number, name, name_eng, description, description_eng,
                          unit, pcs_in_pack, packs_on_pallet,
                          length, width, thickness, density)
    SELECT s.code, s.name, s.name_eng, s.description, s.name_eng,
           s.unit, s.pcs_in_pack, s.packs_on_pallet,
           s.length, s.width, s.thickness, s.density
    FROM skus s
    ON CONFLICT (number) DO UPDATE SET
      name             = COALESCE(products.name,            EXCLUDED.name),
      name_eng         = COALESCE(products.name_eng,        EXCLUDED.name_eng),
      unit             = COALESCE(products.unit,            EXCLUDED.unit),
      pcs_in_pack      = COALESCE(products.pcs_in_pack,     EXCLUDED.pcs_in_pack),
      packs_on_pallet  = COALESCE(products.packs_on_pallet, EXCLUDED.packs_on_pallet);
  END IF;
END $$;

-- ── 3. Add product_id FK to orders ────────────────────────────────────────────

ALTER TABLE orders ADD COLUMN IF NOT EXISTS product_id INTEGER REFERENCES products(id);

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns
             WHERE table_name = 'orders' AND column_name = 'sku_id') THEN
    UPDATE orders o
    SET product_id = p.id
    FROM skus s
    JOIN products p ON p.number = s.code
    WHERE o.sku_id = s.id
      AND o.product_id IS NULL;
  END IF;
END $$;

-- ── 4. Drop old sku_id column and skus table ──────────────────────────────────

ALTER TABLE orders DROP COLUMN IF EXISTS sku_id;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'skus') THEN
    DROP TABLE skus;
  END IF;
END $$;

-- ── 5. Shift schedule tables ──────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS shifts (
  id          SERIAL      PRIMARY KEY,
  code        CHAR(1)     NOT NULL UNIQUE CHECK (code IN ('A','B','C','D')),
  name        VARCHAR(50) NOT NULL,
  color       VARCHAR(20) NOT NULL DEFAULT '#6366f1',
  sort_order  SMALLINT    NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS shift_schedule (
  id                  INTEGER     PRIMARY KEY DEFAULT 1,
  pattern             VARCHAR(50) NOT NULL DEFAULT '2on2off2night2off',
  start_time          TIME        NOT NULL DEFAULT '08:00:00',
  reference_date      DATE,
  reference_shift_id  INTEGER     REFERENCES shifts(id),
  updated_at          TIMESTAMPTZ,
  updated_by_id       INTEGER     REFERENCES users(id)
);

ALTER TABLE orders ADD COLUMN IF NOT EXISTS shift_id INTEGER REFERENCES shifts(id);

-- ── 6. Seed shifts ────────────────────────────────────────────────────────────

INSERT INTO shifts (code, name, color, sort_order) VALUES
  ('A', 'Shift A', '#3b82f6', 0),
  ('B', 'Shift B', '#10b981', 1),
  ('C', 'Shift C', '#f59e0b', 2),
  ('D', 'Shift D', '#ef4444', 3)
ON CONFLICT (code) DO NOTHING;

INSERT INTO shift_schedule (id, pattern, start_time, reference_date, reference_shift_id)
VALUES (1, '2on2off2night2off', '08:00:00'::time, NULL, NULL)
ON CONFLICT (id) DO NOTHING;

-- ── 7. Per-shift production tracking ─────────────────────────────────────────

CREATE TABLE IF NOT EXISTS order_shift_productions (
    id          SERIAL PRIMARY KEY,
    order_id    INTEGER        NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    shift_id    INTEGER        NOT NULL REFERENCES shifts(id),
    date        DATE           NOT NULL DEFAULT CURRENT_DATE,
    produced    NUMERIC(12,3)  NOT NULL DEFAULT 0,
    UNIQUE (order_id, shift_id, date)
);

-- ── 8. Day/Night shift pattern support ───────────────────────────────────────

-- Allow null reference_date / reference_shift_id (new pattern uses shift_references instead)
ALTER TABLE shift_schedule ALTER COLUMN reference_date     DROP NOT NULL;
ALTER TABLE shift_schedule ALTER COLUMN reference_shift_id DROP NOT NULL;

-- Per-shift anchor dates for 2on2off2night2off pattern
CREATE TABLE IF NOT EXISTS shift_references (
    shift_id        INTEGER NOT NULL PRIMARY KEY REFERENCES shifts(id) ON DELETE CASCADE,
    reference_date  DATE    NOT NULL,
    UNIQUE (reference_date)
);

-- Seed shift_references if not already set (2-day spacing so every day has 1 day + 1 night shift)
INSERT INTO shift_references (shift_id, reference_date)
SELECT s.id, CURRENT_DATE + (s.sort_order * 2)
FROM shifts s
ON CONFLICT (shift_id) DO NOTHING;

-- ── 9. Production line status correction ─────────────────────────────────────

UPDATE production_lines SET status = 'inactive'
WHERE id IN (3, 5, 6)          -- Briquette, Rockfon, Grodan
  AND status = 'active';

-- ── 10. Shift schedule timezone + cage shift attribution ──────────────────────

ALTER TABLE shift_schedule ADD COLUMN IF NOT EXISTS timezone TEXT NOT NULL DEFAULT 'UTC';
ALTER TABLE cages          ADD COLUMN IF NOT EXISTS shift_id INTEGER REFERENCES shifts(id);

-- ── 11. Products refactor + new master-data tables ────────────────────────────

-- New lookup tables
CREATE TABLE IF NOT EXISTS product_groups (
    id        SERIAL PRIMARY KEY,
    name      TEXT NOT NULL,
    name_eng  TEXT
);

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
    unit_id             INTEGER REFERENCES units(id),
    correction_type_id  INTEGER REFERENCES correction_types(id),
    uom_id              INTEGER REFERENCES uom(id),
    name                TEXT NOT NULL,
    name_eng            TEXT,
    comment             TEXT,
    display_order       INTEGER NOT NULL DEFAULT 0,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    modified_at         TIMESTAMPTZ,
    modified_by         INTEGER REFERENCES users(id)
);

-- Add new columns to products
ALTER TABLE products ADD COLUMN IF NOT EXISTS group_id             INTEGER REFERENCES product_groups(id);
ALTER TABLE products ADD COLUMN IF NOT EXISTS sequence             INTEGER;
ALTER TABLE products ADD COLUMN IF NOT EXISTS production_instruction TEXT;
ALTER TABLE products ADD COLUMN IF NOT EXISTS packs_in_package     INTEGER;
ALTER TABLE products ADD COLUMN IF NOT EXISTS layers               INTEGER;
ALTER TABLE products ADD COLUMN IF NOT EXISTS grinding_waste       NUMERIC(10,3);
ALTER TABLE products ADD COLUMN IF NOT EXISTS norm_waste           NUMERIC(10,3);
ALTER TABLE products ADD COLUMN IF NOT EXISTS grinding_waste_ow    NUMERIC(10,3);
ALTER TABLE products ADD COLUMN IF NOT EXISTS store_location       TEXT;
ALTER TABLE products ADD COLUMN IF NOT EXISTS direct_recycle_mode  INTEGER;
ALTER TABLE products ADD COLUMN IF NOT EXISTS info_1               TEXT;
ALTER TABLE products ADD COLUMN IF NOT EXISTS info_2               TEXT;
ALTER TABLE products ADD COLUMN IF NOT EXISTS info_3               TEXT;
ALTER TABLE products ADD COLUMN IF NOT EXISTS info_4               TEXT;
ALTER TABLE products ADD COLUMN IF NOT EXISTS info_5               TEXT;
ALTER TABLE products ADD COLUMN IF NOT EXISTS info_6               TEXT;
ALTER TABLE products ADD COLUMN IF NOT EXISTS product_line_width   NUMERIC(10,3);
ALTER TABLE products ADD COLUMN IF NOT EXISTS edge_trim_width      NUMERIC(10,3);
ALTER TABLE products ADD COLUMN IF NOT EXISTS wet_edge_trim_mode   NUMERIC(10,3);
ALTER TABLE products ADD COLUMN IF NOT EXISTS mark                 INTEGER;
ALTER TABLE products ADD COLUMN IF NOT EXISTS state                INTEGER;

-- Copy packs_on_pallet → packs_in_package, rename code → cover_code, instruction → production_instruction
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='products' AND column_name='packs_on_pallet') THEN
        UPDATE products SET packs_in_package = packs_on_pallet WHERE packs_in_package IS NULL;
        ALTER TABLE products DROP COLUMN packs_on_pallet;
    END IF;
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='products' AND column_name='code') THEN
        ALTER TABLE products RENAME COLUMN code TO cover_code;
    END IF;
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='products' AND column_name='instruction') THEN
        UPDATE products SET production_instruction = instruction WHERE production_instruction IS NULL;
        ALTER TABLE products DROP COLUMN instruction;
    END IF;
    -- Drop redundant columns (sku = number, description → name already set, initial_code unused)
    ALTER TABLE products DROP COLUMN IF EXISTS sku;
    ALTER TABLE products DROP COLUMN IF EXISTS description;
    ALTER TABLE products DROP COLUMN IF EXISTS description_eng;
    ALTER TABLE products DROP COLUMN IF EXISTS initial_code;
END $$;

-- Drop old setpoint tables (data was mostly empty / not yet used in production)
DROP TABLE IF EXISTS ul_sp          CASCADE;
DROP TABLE IF EXISTS consumables_sp CASCADE;
DROP TABLE IF EXISTS bundler_sp     CASCADE;
DROP TABLE IF EXISTS tahu_sp        CASCADE;
DROP TABLE IF EXISTS saws_sp        CASCADE;
DROP TABLE IF EXISTS general_sp     CASCADE;

-- machine_states 30-day retention trigger
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

-- ── Section 12: rename store_location → category, add comment, order row colors ─

DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='products' AND column_name='store_location') THEN
        ALTER TABLE products RENAME COLUMN store_location TO category;
    END IF;
END $$;
ALTER TABLE products ADD COLUMN IF NOT EXISTS comment TEXT;

INSERT INTO settings (key, value) VALUES
    ('order_color_running',   '#bbf7d0'),
    ('order_color_completed', '#bfdbfe'),
    ('order_color_queued',    '#fef08a')
ON CONFLICT (key) DO NOTHING;

-- ── Section 13: per-line order control and manual waste settings ──────────────
ALTER TABLE production_lines ADD COLUMN IF NOT EXISTS order_control_enabled BOOLEAN NOT NULL DEFAULT TRUE;
ALTER TABLE production_lines ADD COLUMN IF NOT EXISTS manual_waste_enabled  BOOLEAN NOT NULL DEFAULT TRUE;

-- ── Section 14: wet_edge_trim_width, binder types, pkf groups, product/order attributes ──
ALTER TABLE products ADD COLUMN IF NOT EXISTS wet_edge_trim_width NUMERIC(10,3);

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

CREATE TABLE IF NOT EXISTS product_attributes (
    id            SERIAL PRIMARY KEY,
    product_id    INTEGER NOT NULL REFERENCES products(id),
    name          TEXT,
    name_eng      TEXT,
    value_type    TEXT NOT NULL DEFAULT 'text',
    default_value TEXT,
    sort_order    INTEGER NOT NULL DEFAULT 0,
    UNIQUE (product_id, name_eng)
);

CREATE TABLE IF NOT EXISTS order_attributes (
    id           SERIAL PRIMARY KEY,
    order_id     INTEGER NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    attribute_id INTEGER NOT NULL REFERENCES product_attributes(id),
    value        TEXT NOT NULL,
    UNIQUE (order_id, attribute_id)
);

INSERT INTO binder_types (id, name, name_eng) VALUES
    (1,   'МДИ',  'MDI'),
    (2,   'ПМДИ', 'PMDI'),
    (3,   'ТДИ',  'TDI'),
    (100, 'ПУФ',  'PUF')
ON CONFLICT (id) DO NOTHING;

-- ── 15. Add tx (reschedule counter) to orders ────────────────────────────────
ALTER TABLE orders ADD COLUMN IF NOT EXISTS tx INTEGER NOT NULL DEFAULT 0;

-- ── Seed (re-run safe) ────────────────────────────────────────────────────────

INSERT INTO pkf_groups (id, name, name_eng) VALUES
    (1, 'Общестроительная изоляция', 'General Building Insulation'),
    (2, 'Техническая изоляция',      'Technical Insulation'),
    (3, 'Фасадная изоляция',         'Facade Insulation'),
    (4, 'Кровельная изоляция',       'Roof Insulation')
ON CONFLICT (id) DO NOTHING;

INSERT INTO product_attributes (product_id, name, name_eng, value_type, default_value, sort_order)
SELECT p.id, v.name, v.name_eng, v.value_type, v.default_value, v.sort_order
FROM products p
CROSS JOIN (VALUES
    ('Скорость пилы разрезки', 'Dividing sawblade speed', 'integer',     '80',     1),
    ('Скорость гранулятора',   'Granulator speed',        'integer',     '90',     2),
    ('Код рецепта',            'Label1 Res. code',        'text',        '254637', 3),
    ('Тип связующего',         'Binder type',             'binder_type', '100',    4),
    ('Норматив GW1, кг/ч',     'Budget GW1 kg/h',         'numeric',     '6700',   5),
    ('Группа ПКФ',             'PKF Group',               'pkf_group',   '1',      6)
) AS v(name, name_eng, value_type, default_value, sort_order)
WHERE p.number IN ('216094', '216095')
ON CONFLICT (product_id, name_eng) DO NOTHING;

-- ── 16. Products/materials/setpoints schema evolution ────────────────────────

-- products: rename unit → uom, add cut_direction
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns
             WHERE table_name = 'products' AND column_name = 'unit') THEN
    ALTER TABLE products RENAME COLUMN unit TO uom;
  END IF;
END $$;
ALTER TABLE products ADD COLUMN IF NOT EXISTS cut_direction TEXT;

-- materials: rename unit → uom
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns
             WHERE table_name = 'materials' AND column_name = 'unit') THEN
    ALTER TABLE materials RENAME COLUMN unit TO uom;
  END IF;
END $$;

-- setpoints: add product group association and value column
ALTER TABLE setpoints ADD COLUMN IF NOT EXISTS product_group_id INTEGER REFERENCES product_groups(id);
ALTER TABLE setpoints ADD COLUMN IF NOT EXISTS value TEXT;

-- uom: rename pkg → pcs (pieces/plates), add pallet
UPDATE uom SET code = 'pcs', name_eng = 'pcs' WHERE code = 'pkg';
INSERT INTO uom (code, name, name_eng, type) VALUES ('pal', 'Паллета', 'Pallet', 'count')
ON CONFLICT (code) DO NOTHING;

-- ── Seed: equipment units ─────────────────────────────────────────────────────
INSERT INTO units (id, name, name_eng, display_order) VALUES
    (1, 'Куринг',       'Curing',     10),
    (2, 'Кон. автомат', 'ACON',       20),
    (3, 'Связующее',    'Binder',     30),
    (4, 'Пилы',         'Saws',       40),
    (5, 'Упаковка',     'Packaging',  50),
    (6, 'Паллетайзер',  'Unitloader', 60)
ON CONFLICT (id) DO NOTHING;

-- ── Seed: setpoints per product group ─────────────────────────────────────────
INSERT INTO setpoints (id, product_group_id, unit_id, correction_type_id, name, name_eng, value, display_order) VALUES
    -- Wired Matts (group 1)
    (1,  1, 1, 1, 'Температура куринга',   'Curing temperature', '240',  10),
    (2,  1, 1, 1, 'Скорость конвейера',    'Conveyor speed',     '3.5',  20),
    (3,  1, 2, 1, 'Ширина полотна',        'Web width',          '7200', 30),
    (4,  1, 3, 1, 'Дозировка связующего',  'Binder dosing',      '12.5', 40),
    -- Slabs (group 2)
    (5,  2, 1, 1, 'Температура куринга',   'Curing temperature', '220',  10),
    (6,  2, 1, 1, 'Скорость конвейера',    'Conveyor speed',     '4.2',  20),
    (7,  2, 4, 1, 'Длина реза',            'Cut length',         '1200', 30),
    (8,  2, 4, 1, 'Ширина реза',           'Cut width',          '600',  40),
    -- Rolls (group 3)
    (9,  3, 1, 1, 'Температура куринга',   'Curing temperature', '200',  10),
    (10, 3, 1, 1, 'Скорость конвейера',    'Conveyor speed',     '5.0',  20),
    (11, 3, 2, 1, 'Ширина полотна',        'Web width',          '1200', 30)
ON CONFLICT (id) DO NOTHING;

-- ── 17. Drop orphaned store_location column ───────────────────────────────────
ALTER TABLE products DROP COLUMN IF EXISTS store_location;

-- ── 18. mes_reports schema ────────────────────────────────────────────────────

CREATE SCHEMA IF NOT EXISTS mes_reports;

DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'mes_reports_ro') THEN
        CREATE ROLE mes_reports_ro LOGIN PASSWORD 'F51MBO02g25Os4WLmkc4Z8J3' NOINHERIT;
    END IF;
END $$;

GRANT CONNECT ON DATABASE mes TO mes_reports_ro;
GRANT USAGE ON SCHEMA mes_reports TO mes_reports_ro;

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
    o.cage,
    o.cage_size,
    o.planned_start_at,
    o.planned_complete_at,
    o.start_at,
    o.complete_at,
    ROUND(
        EXTRACT(EPOCH FROM (COALESCE(o.complete_at, NOW()) - o.start_at)) / 3600.0
    , 2)                                                AS duration_hours,
    COALESCE(o.produced_volume, 0)                      AS produced_volume,
    COALESCE(
        (SELECT SUM(c.packages) FROM cages c WHERE c.order_number = o.order_number), 0
    )                                                   AS produced_packages,
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

GRANT SELECT ON ALL TABLES IN SCHEMA mes_reports TO mes_reports_ro;
ALTER DEFAULT PRIVILEGES IN SCHEMA mes_reports
    GRANT SELECT ON TABLES TO mes_reports_ro;

-- ── 19. Remove cage concept, add order_production_entries ─────────────────────

-- Drop reporting view first (depends on cage columns and cages table)
DROP VIEW IF EXISTS mes_reports.orders;

-- Drop cage columns from orders
ALTER TABLE orders DROP COLUMN IF EXISTS cage;
ALTER TABLE orders DROP COLUMN IF EXISTS cage_size;

-- Drop cages table
DROP TABLE IF EXISTS cages;

-- Manual production entries (replaces cage tracking)
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

-- Recreate mes_reports.orders without cage columns (now uses order_production_entries)
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

GRANT SELECT ON ALL TABLES IN SCHEMA mes_reports TO mes_reports_ro;

-- ── 20. products.uom VARCHAR → products.uom_id FK ─────────────────────────────
-- Map 'packages' → pcs (they are the same physical unit; 'packages' was a
-- workaround before the uom table existed).

ALTER TABLE products ADD COLUMN IF NOT EXISTS uom_id INTEGER REFERENCES uom(id);

UPDATE products p
SET uom_id = u.id
FROM uom u
WHERE u.code = CASE p.uom WHEN 'packages' THEN 'pcs' ELSE p.uom END
  AND p.uom_id IS NULL;

ALTER TABLE products DROP COLUMN IF EXISTS uom;

-- ── 21. Add produced_correction_enabled to production_lines ──────────────────

ALTER TABLE production_lines
  ADD COLUMN IF NOT EXISTS produced_correction_enabled BOOLEAN NOT NULL DEFAULT TRUE;

-- ── 22. Add event_types table; drop hardcoded CHECK on production_events ──────

CREATE TABLE IF NOT EXISTS event_types (
    id        SERIAL PRIMARY KEY,
    name      VARCHAR(50)  UNIQUE NOT NULL,
    name_eng  VARCHAR(100) NOT NULL
);

INSERT INTO event_types (name, name_eng) VALUES
    ('downtime_unplanned', 'Unplanned Downtime'),
    ('downtime_planned',   'Planned Downtime'),
    ('changeover',         'Changeover'),
    ('quality_hold',       'Quality Hold'),
    ('maintenance',        'Maintenance'),
    ('operator_note',      'Operator Note'),
    ('safety',             'Safety')
ON CONFLICT (name) DO NOTHING;

ALTER TABLE production_events
    DROP CONSTRAINT IF EXISTS production_events_event_type_check;
