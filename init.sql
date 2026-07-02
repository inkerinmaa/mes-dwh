-- MES database schema — DDL only
-- Apply once after `docker compose up -d`:
--   docker exec -i postgres-db psql -U mesrwl -d mes < ~/projects/dwh/init.sql
-- Then load test data:
--   docker exec -i postgres-db psql -U mesrwl -d mes < ~/projects/dwh/seed.sql

-- ── Shifts (referenced by orders, defined before orders table) ───────────────

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

-- ── Core ──────────────────────────────────────────────────────────────────────

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
    id          SERIAL PRIMARY KEY,
    name        VARCHAR(100) NOT NULL,
    description TEXT,
    status      VARCHAR(50)  DEFAULT 'active'
);

CREATE TABLE IF NOT EXISTS materials (
    id             SERIAL PRIMARY KEY,
    code           VARCHAR(50)    UNIQUE NOT NULL,
    name           VARCHAR(255)   NOT NULL,
    name_eng       VARCHAR(255),
    unit           VARCHAR(50)    NOT NULL,
    stock_quantity DECIMAL(10, 3) DEFAULT 0
);

-- ── Orders ────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS orders (
    id                 SERIAL PRIMARY KEY,
    order_number       VARCHAR(100) UNIQUE NOT NULL,
    product_id         INTEGER REFERENCES products(id),
    production_line_id INTEGER REFERENCES production_lines(id),
    volume             DECIMAL(12, 3) NOT NULL,
    uom_id             INTEGER REFERENCES uom(id),
    status             VARCHAR(50)  NOT NULL DEFAULT 'created'
                           CHECK (status IN ('created','running','paused','completed','cancelled')),
    priority           VARCHAR(50)  DEFAULT 'Medium',
    due_date           DATE,
    planned_start_at   TIMESTAMPTZ,
    planned_complete_at TIMESTAMPTZ,
    start_at           TIMESTAMPTZ,
    complete_at        TIMESTAMPTZ,
    seq_order          INTEGER,
    comment            TEXT,
    cage               BOOLEAN      NOT NULL DEFAULT false,
    cage_size          INTEGER      NOT NULL DEFAULT 50,
    produced_volume    DECIMAL(12, 3) NOT NULL DEFAULT 0,
    pkg_produced       INTEGER        NOT NULL DEFAULT 0,
    waste_quantity     DECIMAL(12, 3),
    good_quantity      DECIMAL(12, 3),
    shift_id           INTEGER REFERENCES shifts(id),
    created_by_id      INTEGER REFERENCES users(id),
    created_at         TIMESTAMPTZ  DEFAULT NOW(),
    updated_at         TIMESTAMPTZ  DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS cages (
    id               SERIAL PRIMARY KEY,
    order_number     VARCHAR(100) NOT NULL REFERENCES orders(order_number) ON DELETE CASCADE,
    cage_guid        UUID         NOT NULL DEFAULT gen_random_uuid(),
    cage_size        INTEGER      NOT NULL DEFAULT 50,
    packages         INTEGER      NOT NULL,
    completed_at     TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    completed_by_id  INTEGER REFERENCES users(id)
);

CREATE TABLE IF NOT EXISTS order_shift_productions (
    id          SERIAL PRIMARY KEY,
    order_id    INTEGER        NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    shift_id    INTEGER        NOT NULL REFERENCES shifts(id),
    date        DATE           NOT NULL DEFAULT CURRENT_DATE,
    produced    NUMERIC(12,3)  NOT NULL DEFAULT 0,
    UNIQUE (order_id, shift_id, date)
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

-- Each row is a state-change event. Duration is computed dynamically as
-- LEAD(ts) OVER (...) - ts, or NOW() - ts for the active segment.
CREATE TABLE IF NOT EXISTS machine_states (
    id                 SERIAL PRIMARY KEY,
    production_line_id INTEGER NOT NULL REFERENCES production_lines(id),
    state              VARCHAR(20) NOT NULL CHECK (state IN ('running', 'warning', 'stopped')),
    ts                 TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS machine_states_line_ts_idx ON machine_states(production_line_id, ts DESC);

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

-- ── Master Data ───────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS products (
    id               SERIAL PRIMARY KEY,
    number           VARCHAR(50)   NOT NULL UNIQUE,
    name             VARCHAR(255),
    name_eng         VARCHAR(255),
    description      TEXT,
    description_eng  TEXT,
    sku              VARCHAR(50),
    code             VARCHAR(50),
    package_code     VARCHAR(50),
    initial_code     VARCHAR(50),
    instruction      TEXT,
    unit             VARCHAR(50)   DEFAULT 'packages',
    pcs_in_pack      INTEGER,
    packs_on_pallet  INTEGER,
    length           NUMERIC(10,3),
    width            NUMERIC(10,3),
    thickness        NUMERIC(10,3),
    density          NUMERIC(10,3),
    created_at       TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
    modified_at      TIMESTAMPTZ,
    modified_by      INTEGER REFERENCES users(id)
);

CREATE TABLE IF NOT EXISTS general_sp (
    id                      SERIAL PRIMARY KEY,
    product_id              INTEGER NOT NULL UNIQUE REFERENCES products(id) ON DELETE CASCADE,
    package                 VARCHAR(50),
    abc_cat                 VARCHAR(10),
    waste_suply             NUMERIC(10,3),
    remark                  TEXT,
    info                    TEXT,
    labelling               VARCHAR(100),
    state                   VARCHAR(50),
    data_check              BOOLEAN,
    drum_pressure           NUMERIC(10,3),
    saw_cross               NUMERIC(10,3),
    labelling_state         VARCHAR(50),
    product_type            VARCHAR(50),
    split_in_pair_113_114   BOOLEAN,
    product_turn_pos_122    VARCHAR(50),
    weight_limit_max_perc   NUMERIC(10,3),
    weight_limit_min_perc   NUMERIC(10,3),
    flexi_turn              BOOLEAN,
    flexi_width             NUMERIC(10,3),
    energy_class            VARCHAR(20),
    binder_type             VARCHAR(50),
    pkf_group               VARCHAR(50),
    created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    modified_at             TIMESTAMPTZ,
    modified_by             INTEGER REFERENCES users(id)
);

CREATE TABLE IF NOT EXISTS saws_sp (
    id                  SERIAL PRIMARY KEY,
    product_id          INTEGER NOT NULL UNIQUE REFERENCES products(id) ON DELETE CASCADE,
    trimming_waste_ows  NUMERIC(10,3),
    plates_in_pkg       INTEGER,
    cut_direction       VARCHAR(50),
    layers              INTEGER,
    waste_std           NUMERIC(10,3),
    trimming_waste_ow   NUMERIC(10,3),
    sheet_width         NUMERIC(10,3),
    cut_width           NUMERIC(10,3),
    raw_edge_width      NUMERIC(10,3),
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    modified_at         TIMESTAMPTZ,
    modified_by         INTEGER REFERENCES users(id)
);

CREATE TABLE IF NOT EXISTS tahu_sp (
    id                      SERIAL PRIMARY KEY,
    product_id              INTEGER NOT NULL UNIQUE REFERENCES products(id) ON DELETE CASCADE,
    tahu_finish_pack_height NUMERIC(10,3),
    tahu_output_height      NUMERIC(10,3),
    tahu_side_welding       NUMERIC(10,3),
    tahu_film_width         NUMERIC(10,3),
    tahu_vacuum             NUMERIC(10,3),
    tahu_use_shrink_heat    BOOLEAN,
    tahu_smart_date         BOOLEAN,
    tahu_foil_code          VARCHAR(50),
    created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    modified_at             TIMESTAMPTZ,
    modified_by             INTEGER REFERENCES users(id)
);

CREATE TABLE IF NOT EXISTS bundler_sp (
    id                       SERIAL PRIMARY KEY,
    product_id               INTEGER NOT NULL UNIQUE REFERENCES products(id) ON DELETE CASCADE,
    bundler_packs_per_bundle INTEGER,
    bundler_comp_length      NUMERIC(10,3),
    bundler_output_length    NUMERIC(10,3),
    product_turn_pos_608     VARCHAR(50),
    group_product_pos_608    VARCHAR(50),
    created_at               TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    modified_at              TIMESTAMPTZ,
    modified_by              INTEGER REFERENCES users(id)
);

CREATE TABLE IF NOT EXISTS consumables_sp (
    id                   SERIAL PRIMARY KEY,
    product_id           INTEGER NOT NULL UNIQUE REFERENCES products(id) ON DELETE CASCADE,
    bundle_plastic_code  VARCHAR(50),
    hooder_plastic_code  VARCHAR(50),
    wrapper_plastic_code VARCHAR(50),
    check_layers         INTEGER,
    created_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    modified_at          TIMESTAMPTZ,
    modified_by          INTEGER REFERENCES users(id)
);

CREATE TABLE IF NOT EXISTS ul_sp (
    id                          SERIAL PRIMARY KEY,
    product_id                  INTEGER NOT NULL UNIQUE REFERENCES products(id) ON DELETE CASCADE,
    ul_product_per_layer        INTEGER,
    ul_pallet_layers            INTEGER,
    ul_layers_interlocked       BOOLEAN,
    ul_pack_orientation         VARCHAR(50),
    ul_direction_base_layer     VARCHAR(50),
    ul_miwo_feet                INTEGER,
    ul_miwo_dim                 VARCHAR(50),
    ul_pallet_dim               VARCHAR(50),
    ul_pallet_dim_perpendicular VARCHAR(50),
    ul_pallet_height            NUMERIC(10,3),
    ul_cross_turning            BOOLEAN,
    ul_use_hooding              BOOLEAN,
    ul_use_glue                 BOOLEAN,
    ul_use_wrapping             BOOLEAN,
    created_at                  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    modified_at                 TIMESTAMPTZ,
    modified_by                 INTEGER REFERENCES users(id)
);
