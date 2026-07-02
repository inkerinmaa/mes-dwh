-- MES migration: SKU→Products merge + Shift Schedule
-- Run against an existing DB (after init.sql has been applied):
--   docker exec -i postgres-db psql -U mesrwl -d mes < ~/projects/dwh/migrate.sql
--
-- Safe to re-run: uses IF NOT EXISTS / ON CONFLICT guards throughout.

-- ── 1. Add ordering fields to products (absorb skus) ─────────────────────────

ALTER TABLE products
  ADD COLUMN IF NOT EXISTS name             VARCHAR(255),
  ADD COLUMN IF NOT EXISTS name_eng         VARCHAR(255),
  ADD COLUMN IF NOT EXISTS unit             VARCHAR(50)  DEFAULT 'packages',
  ADD COLUMN IF NOT EXISTS pcs_in_pack      INTEGER,
  ADD COLUMN IF NOT EXISTS packs_on_pallet  INTEGER;

-- ── 2. Absorb skus table into products ────────────────────────────────────────
-- For each sku, upsert a product with number = sku.code.
-- If a product with the same number already exists, fill in any missing fields.

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

-- Link existing orders through the old sku → new product mapping
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
  pattern             VARCHAR(50) NOT NULL DEFAULT '4on4off',
  start_time          TIME        NOT NULL DEFAULT '08:00:00',
  reference_date      DATE        NOT NULL DEFAULT CURRENT_DATE,
  reference_shift_id  INTEGER     NOT NULL REFERENCES shifts(id),
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
SELECT 1, '4on4off', '08:00:00'::time, CURRENT_DATE, s.id
FROM shifts s WHERE s.code = 'A'
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
