-- MES test / development seed data
-- Requires schema to exist first: psql ... < init.sql
-- Safe to re-run: all statements use ON CONFLICT DO NOTHING
-- Apply:
--   docker exec -i postgres-db psql -U mesrwl -d mes < ~/projects/dwh/seed.sql

-- ── Settings ──────────────────────────────────────────────────────────────────

INSERT INTO settings (key, value) VALUES
    ('timeline_auto_refresh_enabled',     'false'),
    ('timeline_refresh_interval_seconds', '60'),
    ('show_efficiency_chart',             'false'),
    ('show_stats_cards',                  'false'),
    ('show_uptime_diagram',               'false'),
    ('order_color_running',               '#bbf7d0'),
    ('order_color_completed',             '#bfdbfe'),
    ('order_color_queued',                '#fef08a')
ON CONFLICT (key) DO NOTHING;

-- ── Units of measure ──────────────────────────────────────────────────────────

INSERT INTO uom (code, name, name_eng, type) VALUES
    ('kg',  'Килограмм',     'Kilogram',     'weight'),
    ('t',   'Тонна',        'Ton',          'weight'),
    ('pcs', 'Пачка',     'pcs',          'count'),
    ('pal', 'Паллета',   'Pallet',       'count'),
    ('m',   'Метр',        'Meter',         'length'),
    ('m2',  'Квадратный метр', 'Square meter', 'area'),
    ('m3',  'Кубический метр',  'Cubic meter', 'volume')
ON CONFLICT (code) DO NOTHING;

-- ── Shifts ────────────────────────────────────────────────────────────────────

INSERT INTO shifts (code, name, color, sort_order) VALUES
    ('A', 'Shift A', '#3b82f6', 0),
    ('B', 'Shift B', '#10b981', 1),
    ('C', 'Shift C', '#f59e0b', 2),
    ('D', 'Shift D', '#ef4444', 3)
ON CONFLICT (code) DO NOTHING;

-- Pattern: 2 day / 2 off / 2 night / 2 off (8-day cycle per shift)
-- reference_date/reference_shift_id unused for this pattern — per-shift dates live in shift_references
INSERT INTO shift_schedule (id, pattern, start_time, timezone, reference_date, reference_shift_id)
VALUES (1, '2on2off2night2off', '08:00:00'::time, 'Europe/Moscow', NULL, NULL)
ON CONFLICT (id) DO NOTHING;

-- Anchor each shift's cycle with dates 2 days apart so every calendar day has
-- exactly one day-period shift and one night-period shift:
--   Shift A: today      (Day-Day cycle starts today)
--   Shift B: today + 2  (Off cycle; Day cycle starts in 2 days)
--   Shift C: today + 4  (Night cycle; Day cycle starts in 4 days)
--   Shift D: today + 6  (Off cycle; Day cycle starts in 6 days)
INSERT INTO shift_references (shift_id, reference_date)
SELECT s.id, CURRENT_DATE + (s.sort_order * 2)
FROM shifts s
ON CONFLICT (shift_id) DO NOTHING;

-- ── Production lines ──────────────────────────────────────────────────────────

INSERT INTO production_lines (id, name, description, status) VALUES
    (1, 'Line 1',      'Line 1',          'active'),
    (2, 'Line 2',      'Line 2',          'active'),
    (3, 'Briquette',   'Briquette line',  'inactive'),
    (4, 'Wired Matts', 'Wired matt line', 'active'),
    (5, 'Rockfon',     'Rockfon line',    'inactive'),
    (6, 'Grodan',      'Grodan line',     'inactive')
ON CONFLICT (id) DO UPDATE
    SET name        = EXCLUDED.name,
        description = EXCLUDED.description,
        status      = EXCLUDED.status;

-- ── Raw materials ─────────────────────────────────────────────────────────────

-- INSERT INTO materials (code, name, name_eng, unit, stock_quantity) VALUES
--     ('MAT-001', 'Basalt Fibre',         'Basalt Fibre',      'kg',    5000),
--     ('MAT-002', 'Phenol Binder',        'Phenol Binder',     'kg',    3200),
--     ('MAT-003', 'PE Shrink Film',       'PE Shrink Film',    'm2',   12000),
--     ('MAT-004', 'Stretch Wrap',         'Stretch Wrap',      'm2',    8500),
--     ('MAT-005', 'Pallet 1200×1000',    'Pallet 1200×1000',  'pcs',     450),
--     ('MAT-006', 'Basalt Rock',          'Basalt Rock',       'kg',   85000),
--     ('MAT-007', 'Volcanic Tuff',        'Volcanic Tuff',     'kg',   24000),
--     ('MAT-008', 'Petroleum Coke',       'Petroleum Coke',    'kg',   18000),
--     ('MAT-009', 'PP Film Roll',         'PP Film Roll',      'm',    45000)
-- ON CONFLICT (code) DO NOTHING;

-- ── Machine state timeline (seed only when table is empty) ────────────────────

INSERT INTO machine_states (production_line_id, state, ts)
SELECT v.line_id, v.state, NOW() + v.offset_interval
FROM (VALUES
    -- Line 1 — Wired Matts (~87% running)
    (1, 'running', INTERVAL '-480 minutes'),
    (1, 'running', INTERVAL '-410 minutes'),
    (1, 'warning', INTERVAL '-355 minutes'),
    (1, 'running', INTERVAL '-340 minutes'),
    (1, 'warning', INTERVAL '-260 minutes'),
    (1, 'running', INTERVAL '-250 minutes'),
    (1, 'stopped', INTERVAL '-185 minutes'),
    (1, 'running', INTERVAL '-173 minutes'),
    (1, 'warning', INTERVAL  '-83 minutes'),
    (1, 'running', INTERVAL  '-63 minutes'),
    -- Line 2 — Slabs (~78% running)
    (2, 'running', INTERVAL '-480 minutes'),
    (2, 'warning', INTERVAL '-420 minutes'),
    (2, 'running', INTERVAL '-395 minutes'),
    (2, 'stopped', INTERVAL '-325 minutes'),
    (2, 'running', INTERVAL '-310 minutes'),
    (2, 'running', INTERVAL '-255 minutes'),
    (2, 'warning', INTERVAL '-215 minutes'),
    (2, 'running', INTERVAL '-195 minutes'),
    (2, 'stopped', INTERVAL '-115 minutes'),
    (2, 'running', INTERVAL '-105 minutes'),
    -- Line 3 — Briquette (~92% running)
    (3, 'running', INTERVAL '-480 minutes'),
    (3, 'running', INTERVAL '-390 minutes'),
    (3, 'warning', INTERVAL '-315 minutes'),
    (3, 'running', INTERVAL '-303 minutes'),
    (3, 'running', INTERVAL '-218 minutes'),
    (3, 'stopped', INTERVAL '-148 minutes'),
    (3, 'running', INTERVAL '-140 minutes'),
    (3, 'running', INTERVAL  '-60 minutes'),
    -- Line 4 — Wired Matts (~85% running)
    (4, 'running', INTERVAL '-480 minutes'),
    (4, 'warning', INTERVAL '-420 minutes'),
    (4, 'running', INTERVAL '-408 minutes'),
    (4, 'running', INTERVAL '-330 minutes'),
    (4, 'stopped', INTERVAL '-275 minutes'),
    (4, 'running', INTERVAL '-263 minutes'),
    (4, 'running', INTERVAL '-120 minutes'),
    (4, 'warning', INTERVAL  '-80 minutes'),
    (4, 'running', INTERVAL  '-65 minutes'),
    -- Line 5 — Rockfon (~90% running)
    (5, 'running', INTERVAL '-480 minutes'),
    (5, 'running', INTERVAL '-380 minutes'),
    (5, 'warning', INTERVAL '-295 minutes'),
    (5, 'running', INTERVAL '-280 minutes'),
    (5, 'stopped', INTERVAL '-165 minutes'),
    (5, 'running', INTERVAL '-155 minutes'),
    (5, 'running', INTERVAL  '-70 minutes'),
    -- Line 6 — Grodan (~82% running)
    (6, 'running', INTERVAL '-480 minutes'),
    (6, 'warning', INTERVAL '-410 minutes'),
    (6, 'running', INTERVAL '-395 minutes'),
    (6, 'stopped', INTERVAL '-310 minutes'),
    (6, 'running', INTERVAL '-290 minutes'),
    (6, 'warning', INTERVAL '-200 minutes'),
    (6, 'running', INTERVAL '-185 minutes'),
    (6, 'running', INTERVAL  '-75 minutes')
) AS v(line_id, state, offset_interval)
WHERE NOT EXISTS (SELECT 1 FROM machine_states LIMIT 1);

-- ── Product groups ────────────────────────────────────────────────────────────

INSERT INTO product_groups (id, name, name_eng) VALUES
    (1, 'Вайред Матс',    'Wired Matts'),
    (2, 'Плиты',          'Slabs'),
    (3, 'Рулоны',         'Rolls')
ON CONFLICT (id) DO NOTHING;

-- ── Correction types ──────────────────────────────────────────────────────────

INSERT INTO correction_types (id, name, name_eng) VALUES
    (1, 'Абсолютная',    'Absolute'),
    (2, 'Относительная', 'Relative')
ON CONFLICT (id) DO NOTHING;

-- ── Equipment units ───────────────────────────────────────────────────────────

INSERT INTO units (id, name, name_eng, display_order) VALUES
    (1, 'Куринг',       'Curing',     10),
    (2, 'Кон. автомат', 'ACON',       20),
    (3, 'Связующее',    'Binder',     30),
    (4, 'Пилы',         'Saws',       40),
    (5, 'Упаковка',     'Packaging',  50),
    (6, 'Паллетайзер',  'Unitloader', 60)
ON CONFLICT (id) DO NOTHING;

-- ── Setpoints per product group ───────────────────────────────────────────────

INSERT INTO setpoints (id, product_group_id, unit_id, correction_type_id, name, name_eng, value, display_order) VALUES
    -- Wired Matts (group 1)
    (1,  1, 1, 1, 'Температура куринга',  'Curing temperature', '240',  10),
    (2,  1, 1, 1, 'Скорость конвейера',   'Conveyor speed',     '3.5',  20),
    (3,  1, 2, 1, 'Ширина полотна',       'Web width',          '7200', 30),
    (4,  1, 3, 1, 'Дозировка связующего', 'Binder dosing',      '12.5', 40),
    -- Slabs (group 2)
    (5,  2, 1, 1, 'Температура куринга',  'Curing temperature', '220',  10),
    (6,  2, 1, 1, 'Скорость конвейера',   'Conveyor speed',     '4.2',  20),
    (7,  2, 4, 1, 'Длина реза',           'Cut length',         '1200', 30),
    (8,  2, 4, 1, 'Ширина реза',          'Cut width',          '600',  40),
    -- Rolls (group 3)
    (9,  3, 1, 1, 'Температура куринга',  'Curing temperature', '200',  10),
    (10, 3, 1, 1, 'Скорость конвейера',   'Conveyor speed',     '5.0',  20),
    (11, 3, 2, 1, 'Ширина полотна',       'Web width',          '1200', 30)
ON CONFLICT (id) DO NOTHING;

-- ── Products ──────────────────────────────────────────────────────────────────

INSERT INTO products (number, group_id, name, name_eng, cover_code, package_code,
                      uom_id, pcs_in_pack, packs_in_package,
                      length, width, thickness, density, layers,
                      norm_waste, edge_trim_width)
SELECT
    p.number, p.group_id, p.name, p.name_eng, p.cover_code, p.package_code,
    (SELECT id FROM uom WHERE code = p.uom_code),
    p.pcs_in_pack, p.packs_in_package,
    p.length, p.width, p.thickness, p.density, p.layers,
    p.norm_waste, p.edge_trim_width
FROM (VALUES
    ('WM-105', 1, 'ВАЙРЕД МАТ 105', 'Wired Mat 105',
     'WM-105', 'PAK-SL-105', 'pcs', 1, 7,
     1000.0, 7000.0, 25.0, 105.0, 1, 3.0, 5.0),
    ('WM-100', 1, 'ВАЙРЕД МАТ 100', 'Wired Mat 100',
     'WM-100', 'PAK-SL-100', 'pcs', 1, 7,
     1000.0, 7000.0, 25.0, 100.0, 1, 3.0, 5.0),
    ('SL-50',  2, 'ПЛИТА 50',       'Slab 50mm',
     'SL-050', 'PAK-SL-050', 'pcs', 4, 8,
     1200.0, 600.0, 50.0, 80.0, 2, 2.5, 4.0)
) AS p(number, group_id, name, name_eng, cover_code, package_code, uom_code,
       pcs_in_pack, packs_in_package, length, width, thickness, density, layers,
       norm_waste, edge_trim_width)
ON CONFLICT (number) DO UPDATE SET
    name              = EXCLUDED.name,
    name_eng          = EXCLUDED.name_eng,
    cover_code        = EXCLUDED.cover_code,
    package_code      = EXCLUDED.package_code,
    uom_id            = EXCLUDED.uom_id,
    pcs_in_pack       = EXCLUDED.pcs_in_pack,
    packs_in_package  = EXCLUDED.packs_in_package,
    length            = EXCLUDED.length,
    width             = EXCLUDED.width,
    thickness         = EXCLUDED.thickness,
    density           = EXCLUDED.density,
    layers            = EXCLUDED.layers,
    norm_waste        = EXCLUDED.norm_waste,
    edge_trim_width   = EXCLUDED.edge_trim_width;


-- ── General setpoints ─────────────────────────────────────────────────────────

-- INSERT INTO general_sp (product_id, package, abc_cat, waste_suply, remark, info,
--     labelling, state, data_check, drum_pressure, saw_cross, labelling_state,
--     product_type, split_in_pair_113_114, product_turn_pos_122,
--     weight_limit_max_perc, weight_limit_min_perc,
--     flexi_turn, flexi_width, energy_class, binder_type, pkf_group)
-- SELECT id, package, abc_cat, waste_suply, remark, info,
--     labelling, state, data_check, drum_pressure, saw_cross, labelling_state,
--     product_type, split_in_pair, turn_pos,
--     wt_max, wt_min, flexi_turn, flexi_width, energy_class, binder_type, pkf_group
-- FROM (VALUES
--     ('PRD-A100', 'Shrink',  'A', 2.5, 'Standard slab',       'Line 2 product',
--      'Auto',       'Active', true,  3.5,  1202.0, 'Auto',   'Slab',   false, 'Pos1',  105.0,  95.0, false, 0.0,   'A+', 'Phenol', 'PKF-A'),
--     ('PRD-A200', 'Shrink',  'A', 2.0, 'Thin slab',           'Line 2 product',
--      'Auto',       'Active', true,  3.2,   602.0, 'Auto',   'Slab',   false, 'Pos1',  105.0,  95.0, false, 0.0,   'A+', 'Phenol', 'PKF-A'),
--     ('PRD-B150', 'Wired',   'B', 3.0, 'Standard wired matt', 'Line 1 product',
--      'Manual',     'Active', true,  4.0,  2002.0, 'Manual', 'Matt',   true,  'Pos2',  108.0,  92.0, false, 0.0,   'A',  'Phenol', 'PKF-B'),
--     ('PRD-B300', 'Wired',   'B', 3.5, 'Heavy wired matt',    'Line 1 product',
--      'Manual',     'Active', true,  4.5,  2002.0, 'Manual', 'Matt',   true,  'Pos2',  108.0,  92.0, false, 0.0,   'A',  'Phenol', 'PKF-B'),
--     ('PRD-D100', 'Roll',    'C', 1.5, 'Flexi roll',          'Line 2 product',
--      'Auto',       'Active', false, 2.0,   null,  'Auto',   'Roll',   false, 'Pos3',  110.0,  90.0, true,  1200.0,'A',  'Urea',   'PKF-C')
-- ) AS v(num, package, abc_cat, waste_suply, remark, info,
--        labelling, state, data_check, drum_pressure, saw_cross, labelling_state,
--        product_type, split_in_pair, turn_pos, wt_max, wt_min, flexi_turn, flexi_width,
--        energy_class, binder_type, pkf_group)
-- JOIN products p ON p.number = v.num
-- ON CONFLICT (product_id) DO NOTHING;

-- ── Saws setpoints ────────────────────────────────────────────────────────────

-- INSERT INTO saws_sp (product_id, trimming_waste_ows, plates_in_pkg, cut_direction,
--     layers, waste_std, trimming_waste_ow, sheet_width, cut_width, raw_edge_width)
-- SELECT p.id, tw_ows, plates, cut_dir, layers, waste_std, tw_ow, sheet_w, cut_w, raw_e
-- FROM (VALUES
--     ('PRD-A100', 10.0, 4, 'Length', 2,  8.0, 12.0, 1210.0, 600.5,  5.0),
--     ('PRD-A200', 10.0, 6, 'Length', 2,  8.0, 12.0, 1210.0, 600.5,  5.0),
--     ('PRD-B150', 15.0, 2, 'Width',  1, 12.0, 18.0, 2010.0,1200.5,  5.0),
--     ('PRD-B300', 15.0, 1, 'Width',  1, 12.0, 18.0, 2010.0,1200.5,  5.0),
--     ('PRD-D100',  5.0, 1, 'Length', 1,  4.0,  6.0, 7210.0,1200.5, 10.0)
-- ) AS v(num, tw_ows, plates, cut_dir, layers, waste_std, tw_ow, sheet_w, cut_w, raw_e)
-- JOIN products p ON p.number = v.num
-- ON CONFLICT (product_id) DO NOTHING;

-- ── TAHU setpoints ────────────────────────────────────────────────────────────

-- INSERT INTO tahu_sp (product_id, tahu_finish_pack_height, tahu_output_height,
--     tahu_side_welding, tahu_film_width, tahu_vacuum,
--     tahu_use_shrink_heat, tahu_smart_date, tahu_foil_code)
-- SELECT p.id, fin_h, out_h, side_w, film_w, vacuum, shrink, smart_dt, foil
-- FROM (VALUES
--     ('PRD-A100', 402.0, 405.0, 15.0, 1250.0, 0.8, true,  true,  'F-PE-120'),
--     ('PRD-A200', 202.0, 205.0, 12.0, 1250.0, 0.7, true,  true,  'F-PE-120'),
--     ('PRD-B150', 510.0, 515.0, 20.0, 2050.0, 0.9, false, false, 'F-PE-200'),
--     ('PRD-B300', 510.0, 515.0, 20.0, 2050.0, 0.9, false, false, 'F-PE-200'),
--     ('PRD-D100',  null,  null,  null, 1250.0, 0.6, true,  false, 'F-PE-100')
-- ) AS v(num, fin_h, out_h, side_w, film_w, vacuum, shrink, smart_dt, foil)
-- JOIN products p ON p.number = v.num
-- ON CONFLICT (product_id) DO NOTHING;

-- ── Bundler setpoints ─────────────────────────────────────────────────────────

-- INSERT INTO bundler_sp (product_id, bundler_packs_per_bundle, bundler_comp_length,
--     bundler_output_length, product_turn_pos_608, group_product_pos_608)
-- SELECT p.id, packs, comp_l, out_l, turn_pos, grp_pos
-- FROM (VALUES
--     ('PRD-A100', 8,  450.0, 455.0, 'Pos2', 'GrpA'),
--     ('PRD-A200', 12, 230.0, 235.0, 'Pos2', 'GrpA'),
--     ('PRD-B150', 4,  510.0, 515.0, 'Pos1', 'GrpB'),
--     ('PRD-B300', 2,  510.0, 515.0, 'Pos1', 'GrpB'),
--     ('PRD-D100', 6,  380.0, 385.0, 'Pos3', 'GrpC')
-- ) AS v(num, packs, comp_l, out_l, turn_pos, grp_pos)
-- JOIN products p ON p.number = v.num
-- ON CONFLICT (product_id) DO NOTHING;

-- ── Consumables setpoints ─────────────────────────────────────────────────────

-- INSERT INTO consumables_sp (product_id, bundle_plastic_code, hooder_plastic_code,
--     wrapper_plastic_code, check_layers)
-- SELECT p.id, bundle_pl, hooder_pl, wrapper_pl, chk_lay
-- FROM (VALUES
--     ('PRD-A100', 'PL-PE-200', 'HD-PE-150', 'WR-PE-180', 2),
--     ('PRD-A200', 'PL-PE-200', 'HD-PE-150', 'WR-PE-180', 2),
--     ('PRD-B150', 'PL-PP-300', null,        'WR-PE-250', 1),
--     ('PRD-B300', 'PL-PP-300', null,        'WR-PE-250', 1),
--     ('PRD-D100', 'PL-PE-150', 'HD-PE-120', 'WR-PE-150', 3)
-- ) AS v(num, bundle_pl, hooder_pl, wrapper_pl, chk_lay)
-- JOIN products p ON p.number = v.num
-- ON CONFLICT (product_id) DO NOTHING;

-- ── UL (unitloader) setpoints ─────────────────────────────────────────────────

-- INSERT INTO ul_sp (product_id, ul_product_per_layer, ul_pallet_layers, ul_layers_interlocked,
--     ul_pack_orientation, ul_direction_base_layer, ul_miwo_feet,
--     ul_miwo_dim, ul_pallet_dim, ul_pallet_dim_perpendicular,
--     ul_pallet_height, ul_cross_turning, ul_use_hooding, ul_use_glue, ul_use_wrapping)
-- SELECT p.id, per_layer, layers, interlocked, orientation, base_dir, feet,
--        miwo_dim, pallet_dim, pallet_perp, pallet_h, cross_turn, hooding, glue, wrapping
-- FROM (VALUES
--     ('PRD-A100', 4, 6, true,  'Long',  'East', 2, '1200x600', '1200x1000', '1000x800', 1450.0, false, true,  true,  false),
--     ('PRD-A200', 4, 8, true,  'Long',  'East', 2, '1200x600', '1200x1000', '1000x800', 1200.0, false, true,  false, false),
--     ('PRD-B150', 2, 5, false, 'Short', 'North', 0, null,      '2000x1200', '1200x800', 1350.0, true,  false, true,  true),
--     ('PRD-B300', 2, 4, false, 'Short', 'North', 0, null,      '2000x1200', '1200x800', 1200.0, true,  false, true,  true),
--     ('PRD-D100', 1, 4, false, 'Long',  'East',  0, null,      '1200x1000', '1000x800',  900.0, false, true,  false, true)
-- ) AS v(num, per_layer, layers, interlocked, orientation, base_dir, feet,
--        miwo_dim, pallet_dim, pallet_perp, pallet_h, cross_turn, hooding, glue, wrapping)
-- JOIN products p ON p.number = v.num
-- ON CONFLICT (product_id) DO NOTHING;

-- ── April 2026 production orders (26 total — Reports demo data) ───────────────
-- 9 orders on Line 1 (Wired Matts), 8 on Line 2 (Slabs), 9 on Line 3 (Packaging)
-- All completed, volume = pkg, produced_volume = volume

-- INSERT INTO orders
--   (order_number, sku_id, production_line_id, volume, uom_id, status, priority,
--    start_at, complete_at, produced_volume, pkg_produced, cage, cage_size)
-- SELECT
--   v.num, s.id, v.line_id::INTEGER, v.vol::NUMERIC,
--   u.id, 'completed', 'Medium',
--   v.sa, v.ca,
--   v.vol::NUMERIC, v.vol::INTEGER,
--   false, 50
-- FROM (VALUES
--   -- Line 1 — Wired Matts (72 h orders, 2 h changeover)
--   ('ORD-2026-L1-001','SKU-B150',1,1500,'2026-04-01 06:00:00+00'::TIMESTAMPTZ,'2026-04-04 06:00:00+00'::TIMESTAMPTZ),
--   ('ORD-2026-L1-002','SKU-B300',1,1200,'2026-04-04 08:00:00+00','2026-04-07 08:00:00+00'),
--   ('ORD-2026-L1-003','SKU-B150',1,1500,'2026-04-07 10:00:00+00','2026-04-10 10:00:00+00'),
--   ('ORD-2026-L1-004','SKU-B300',1,1200,'2026-04-10 12:00:00+00','2026-04-13 12:00:00+00'),
--   ('ORD-2026-L1-005','SKU-B150',1,1500,'2026-04-13 14:00:00+00','2026-04-16 14:00:00+00'),
--   ('ORD-2026-L1-006','SKU-B300',1,1200,'2026-04-16 16:00:00+00','2026-04-19 16:00:00+00'),
--   ('ORD-2026-L1-007','SKU-B150',1,1500,'2026-04-19 18:00:00+00','2026-04-22 18:00:00+00'),
--   ('ORD-2026-L1-008','SKU-B300',1,1200,'2026-04-22 20:00:00+00','2026-04-25 20:00:00+00'),
--   ('ORD-2026-L1-009','SKU-B150',1,1500,'2026-04-25 22:00:00+00','2026-04-28 22:00:00+00'),
--   -- Line 2 — Slabs (84 h orders, 2 h changeover)
--   ('ORD-2026-L2-001','SKU-A100',2,2000,'2026-04-01 06:00:00+00','2026-04-04 18:00:00+00'),
--   ('ORD-2026-L2-002','SKU-A200',2,2500,'2026-04-04 20:00:00+00','2026-04-08 08:00:00+00'),
--   ('ORD-2026-L2-003','SKU-A100',2,2000,'2026-04-08 10:00:00+00','2026-04-11 22:00:00+00'),
--   ('ORD-2026-L2-004','SKU-A200',2,2500,'2026-04-12 00:00:00+00','2026-04-15 12:00:00+00'),
--   ('ORD-2026-L2-005','SKU-A100',2,2000,'2026-04-15 14:00:00+00','2026-04-19 02:00:00+00'),
--   ('ORD-2026-L2-006','SKU-A200',2,2500,'2026-04-19 04:00:00+00','2026-04-22 16:00:00+00'),
--   ('ORD-2026-L2-007','SKU-A100',2,2000,'2026-04-22 18:00:00+00','2026-04-26 06:00:00+00'),
--   ('ORD-2026-L2-008','SKU-A200',2,2500,'2026-04-26 08:00:00+00','2026-04-29 20:00:00+00'),
--   -- Line 3 — Packaging (72 h orders, 2 h changeover)
--   ('ORD-2026-L3-001','SKU-A100',3,2000,'2026-04-01 06:00:00+00','2026-04-04 06:00:00+00'),
--   ('ORD-2026-L3-002','SKU-A200',3,2500,'2026-04-04 08:00:00+00','2026-04-07 08:00:00+00'),
--   ('ORD-2026-L3-003','SKU-A100',3,2000,'2026-04-07 10:00:00+00','2026-04-10 10:00:00+00'),
--   ('ORD-2026-L3-004','SKU-A200',3,2500,'2026-04-10 12:00:00+00','2026-04-13 12:00:00+00'),
--   ('ORD-2026-L3-005','SKU-A100',3,2000,'2026-04-13 14:00:00+00','2026-04-16 14:00:00+00'),
--   ('ORD-2026-L3-006','SKU-A200',3,2500,'2026-04-16 16:00:00+00','2026-04-19 16:00:00+00'),
--   ('ORD-2026-L3-007','SKU-A100',3,2000,'2026-04-19 18:00:00+00','2026-04-22 18:00:00+00'),
--   ('ORD-2026-L3-008','SKU-A200',3,2500,'2026-04-22 20:00:00+00','2026-04-25 20:00:00+00'),
--   ('ORD-2026-L3-009','SKU-A100',3,2000,'2026-04-25 22:00:00+00','2026-04-28 22:00:00+00')
-- ) AS v(num, sku_code, line_id, vol, sa, ca)
-- JOIN skus s ON s.code = v.sku_code
-- JOIN uom u ON u.code = 'pkg'
-- ON CONFLICT (order_number) DO NOTHING;

-- ── Binder types ───────────────────────────────────────────────────────────────
INSERT INTO binder_types (id, name, name_eng) VALUES
    (1,   'МДИ',   'MDI'),
    (2,   'ПМДИ',  'PMDI'),
    (3,   'ТДИ',   'TDI'),
    (100, 'ПУФ',   'PUF')
ON CONFLICT (id) DO NOTHING;

-- ── PKF groups ─────────────────────────────────────────────────────────────────
INSERT INTO pkf_groups (id, name, name_eng) VALUES
    (1, 'Общестроительная изоляция', 'General Building Insulation'),
    (2, 'Техническая изоляция',      'Technical Insulation'),
    (3, 'Фасадная изоляция',         'Facade Insulation'),
    (4, 'Кровельная изоляция',       'Roof Insulation')
ON CONFLICT (id) DO NOTHING;

-- ── Product attributes for 216094 (id=3) and 216095 (id=4) ───────────────────
INSERT INTO product_attributes (product_id, name, name_eng, value_type, default_value, sort_order) VALUES
    (3, 'Скорость пилы разрезки',  'Dividing sawblade speed', 'integer',     '80',  1),
    (3, 'Скорость гранулятора',    'Granulator speed',        'integer',     '90',  2),
    (3, 'Код рецепта',             'Label1 Res. code',        'text',        '254637', 3),
    (3, 'Тип связующего',          'Binder type',             'binder_type', '100', 4),
    (3, 'Норматив GW1, кг/ч',      'Budget GW1 kg/h',         'numeric',     '6700', 5),
    (3, 'Группа ПКФ',              'PKF Group',               'pkf_group',   '1',   6),
    (4, 'Скорость пилы разрезки',  'Dividing sawblade speed', 'integer',     '80',  1),
    (4, 'Скорость гранулятора',    'Granulator speed',        'integer',     '90',  2),
    (4, 'Код рецепта',             'Label1 Res. code',        'text',        '254637', 3),
    (4, 'Тип связующего',          'Binder type',             'binder_type', '100', 4),
    (4, 'Норматив GW1, кг/ч',      'Budget GW1 kg/h',         'numeric',     '6700', 5),
    (4, 'Группа ПКФ',              'PKF Group',               'pkf_group',   '1',   6)
ON CONFLICT (product_id, name_eng) DO NOTHING;

-- ── Event types ───────────────────────────────────────────────────────────────
INSERT INTO event_types (name, name_eng) VALUES
    ('downtime_unplanned', 'Unplanned Downtime'),
    ('downtime_planned',   'Planned Downtime'),
    ('changeover',         'Changeover'),
    ('quality_hold',       'Quality Hold'),
    ('maintenance',        'Maintenance'),
    ('operator_note',      'Operator Note'),
    ('safety',             'Safety')
ON CONFLICT (name) DO NOTHING;
