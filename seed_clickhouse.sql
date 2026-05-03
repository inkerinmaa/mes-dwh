-- ClickHouse Historian — April 2026 test data
-- NOT idempotent: run once on a clean historian database.
-- To re-seed:
--   docker exec -i clickhouse-db clickhouse-client \
--     --user nik --password mysecretpassword \
--     --query "TRUNCATE TABLE historian.production_metrics; TRUNCATE TABLE historian.energy_metrics;"
-- Then re-run this script.
--
-- Apply:
--   docker exec -i clickhouse-db clickhouse-client \
--     --user nik --password mysecretpassword --multiquery \
--     < ~/projects/dwh/seed_clickhouse.sql
--
-- Rows: ~15,840 production_metrics + ~7,872 energy_metrics = ~23,712 total
-- Interval: production_metrics = 5 min, energy_metrics = 15 min
-- Lines 1 & 2 have production_metrics; all 3 lines have energy_metrics.

-- ── Production metrics ────────────────────────────────────────────────────────
-- Formula: base + amplitude*sin(n/period) + noise*(hash_noise - 1.0)
-- hash_noise = toFloat32(cityHash64(number+seed)%200)/100.0  → [0,2), centered on 1

INSERT INTO historian.production_metrics

-- ── Line 1: Wired Matts ───────────────────────────────────────────────────────

-- L1-001  SKU-B150  2026-04-01 06:00  72 h  864 rows
SELECT addMinutes(toDateTime('2026-04-01 06:00:00'),number*5) ts,toUInt8(1) line_id,'ORD-2026-L1-001' order_number,
    round(40.0+4.0*sin(number/8.)+2.0*(toFloat32(cityHash64(number+101)%200)/100.0-1.0),2) basalt_kg,
    round(4.2+0.4*sin(number/8.)+0.3*(toFloat32(cityHash64(number+102)%200)/100.0-1.0),3) binder_kg,
    round(35.0+3.0*sin(number/8.)+1.5*(toFloat32(cityHash64(number+103)%200)/100.0-1.0),2) wool_kg,
    round(5.0+0.5*sin(number/8.)+0.3*(toFloat32(cityHash64(number+104)%200)/100.0-1.0),2) waste_kg,
    round(3.5+0.3*sin(number/12.),2) speed_mpm,
    round(clamp(87.0+5.0*sin(number/15.)+2.0*(toFloat32(cityHash64(number+105)%200)/100.0-1.0),70.,100.),1) efficiency
FROM numbers(864)
UNION ALL
-- L1-002  SKU-B300  2026-04-04 08:00  72 h  864 rows
SELECT addMinutes(toDateTime('2026-04-04 08:00:00'),number*5) ts,toUInt8(1),'ORD-2026-L1-002',
    round(50.0+5.0*sin(number/8.)+2.5*(toFloat32(cityHash64(number+201)%200)/100.0-1.0),2),
    round(5.2+0.5*sin(number/8.)+0.3*(toFloat32(cityHash64(number+202)%200)/100.0-1.0),3),
    round(43.0+4.0*sin(number/8.)+2.0*(toFloat32(cityHash64(number+203)%200)/100.0-1.0),2),
    round(7.0+0.7*sin(number/8.)+0.4*(toFloat32(cityHash64(number+204)%200)/100.0-1.0),2),
    round(2.5+0.2*sin(number/12.),2),
    round(clamp(85.0+5.0*sin(number/15.)+2.0*(toFloat32(cityHash64(number+205)%200)/100.0-1.0),70.,100.),1)
FROM numbers(864)
UNION ALL
-- L1-003  SKU-B150  2026-04-07 10:00  72 h  864 rows
SELECT addMinutes(toDateTime('2026-04-07 10:00:00'),number*5) ts,toUInt8(1),'ORD-2026-L1-003',
    round(40.0+4.0*sin(number/8.)+2.0*(toFloat32(cityHash64(number+111)%200)/100.0-1.0),2),
    round(4.2+0.4*sin(number/8.)+0.3*(toFloat32(cityHash64(number+112)%200)/100.0-1.0),3),
    round(35.0+3.0*sin(number/8.)+1.5*(toFloat32(cityHash64(number+113)%200)/100.0-1.0),2),
    round(5.0+0.5*sin(number/8.)+0.3*(toFloat32(cityHash64(number+114)%200)/100.0-1.0),2),
    round(3.5+0.3*sin(number/12.),2),
    round(clamp(87.0+5.0*sin(number/15.)+2.0*(toFloat32(cityHash64(number+115)%200)/100.0-1.0),70.,100.),1)
FROM numbers(864)
UNION ALL
-- L1-004  SKU-B300  2026-04-10 12:00  72 h  864 rows
SELECT addMinutes(toDateTime('2026-04-10 12:00:00'),number*5) ts,toUInt8(1),'ORD-2026-L1-004',
    round(50.0+5.0*sin(number/8.)+2.5*(toFloat32(cityHash64(number+211)%200)/100.0-1.0),2),
    round(5.2+0.5*sin(number/8.)+0.3*(toFloat32(cityHash64(number+212)%200)/100.0-1.0),3),
    round(43.0+4.0*sin(number/8.)+2.0*(toFloat32(cityHash64(number+213)%200)/100.0-1.0),2),
    round(7.0+0.7*sin(number/8.)+0.4*(toFloat32(cityHash64(number+214)%200)/100.0-1.0),2),
    round(2.5+0.2*sin(number/12.),2),
    round(clamp(85.0+5.0*sin(number/15.)+2.0*(toFloat32(cityHash64(number+215)%200)/100.0-1.0),70.,100.),1)
FROM numbers(864)
UNION ALL
-- L1-005  SKU-B150  2026-04-13 14:00  72 h  864 rows
SELECT addMinutes(toDateTime('2026-04-13 14:00:00'),number*5) ts,toUInt8(1),'ORD-2026-L1-005',
    round(40.0+4.0*sin(number/8.)+2.0*(toFloat32(cityHash64(number+121)%200)/100.0-1.0),2),
    round(4.2+0.4*sin(number/8.)+0.3*(toFloat32(cityHash64(number+122)%200)/100.0-1.0),3),
    round(35.0+3.0*sin(number/8.)+1.5*(toFloat32(cityHash64(number+123)%200)/100.0-1.0),2),
    round(5.0+0.5*sin(number/8.)+0.3*(toFloat32(cityHash64(number+124)%200)/100.0-1.0),2),
    round(3.5+0.3*sin(number/12.),2),
    round(clamp(87.0+5.0*sin(number/15.)+2.0*(toFloat32(cityHash64(number+125)%200)/100.0-1.0),70.,100.),1)
FROM numbers(864)
UNION ALL
-- L1-006  SKU-B300  2026-04-16 16:00  72 h  864 rows
SELECT addMinutes(toDateTime('2026-04-16 16:00:00'),number*5) ts,toUInt8(1),'ORD-2026-L1-006',
    round(50.0+5.0*sin(number/8.)+2.5*(toFloat32(cityHash64(number+221)%200)/100.0-1.0),2),
    round(5.2+0.5*sin(number/8.)+0.3*(toFloat32(cityHash64(number+222)%200)/100.0-1.0),3),
    round(43.0+4.0*sin(number/8.)+2.0*(toFloat32(cityHash64(number+223)%200)/100.0-1.0),2),
    round(7.0+0.7*sin(number/8.)+0.4*(toFloat32(cityHash64(number+224)%200)/100.0-1.0),2),
    round(2.5+0.2*sin(number/12.),2),
    round(clamp(85.0+5.0*sin(number/15.)+2.0*(toFloat32(cityHash64(number+225)%200)/100.0-1.0),70.,100.),1)
FROM numbers(864)
UNION ALL
-- L1-007  SKU-B150  2026-04-19 18:00  72 h  864 rows
SELECT addMinutes(toDateTime('2026-04-19 18:00:00'),number*5) ts,toUInt8(1),'ORD-2026-L1-007',
    round(40.0+4.0*sin(number/8.)+2.0*(toFloat32(cityHash64(number+131)%200)/100.0-1.0),2),
    round(4.2+0.4*sin(number/8.)+0.3*(toFloat32(cityHash64(number+132)%200)/100.0-1.0),3),
    round(35.0+3.0*sin(number/8.)+1.5*(toFloat32(cityHash64(number+133)%200)/100.0-1.0),2),
    round(5.0+0.5*sin(number/8.)+0.3*(toFloat32(cityHash64(number+134)%200)/100.0-1.0),2),
    round(3.5+0.3*sin(number/12.),2),
    round(clamp(87.0+5.0*sin(number/15.)+2.0*(toFloat32(cityHash64(number+135)%200)/100.0-1.0),70.,100.),1)
FROM numbers(864)
UNION ALL
-- L1-008  SKU-B300  2026-04-22 20:00  72 h  864 rows
SELECT addMinutes(toDateTime('2026-04-22 20:00:00'),number*5) ts,toUInt8(1),'ORD-2026-L1-008',
    round(50.0+5.0*sin(number/8.)+2.5*(toFloat32(cityHash64(number+231)%200)/100.0-1.0),2),
    round(5.2+0.5*sin(number/8.)+0.3*(toFloat32(cityHash64(number+232)%200)/100.0-1.0),3),
    round(43.0+4.0*sin(number/8.)+2.0*(toFloat32(cityHash64(number+233)%200)/100.0-1.0),2),
    round(7.0+0.7*sin(number/8.)+0.4*(toFloat32(cityHash64(number+234)%200)/100.0-1.0),2),
    round(2.5+0.2*sin(number/12.),2),
    round(clamp(85.0+5.0*sin(number/15.)+2.0*(toFloat32(cityHash64(number+235)%200)/100.0-1.0),70.,100.),1)
FROM numbers(864)
UNION ALL
-- L1-009  SKU-B150  2026-04-25 22:00  72 h  864 rows
SELECT addMinutes(toDateTime('2026-04-25 22:00:00'),number*5) ts,toUInt8(1),'ORD-2026-L1-009',
    round(40.0+4.0*sin(number/8.)+2.0*(toFloat32(cityHash64(number+141)%200)/100.0-1.0),2),
    round(4.2+0.4*sin(number/8.)+0.3*(toFloat32(cityHash64(number+142)%200)/100.0-1.0),3),
    round(35.0+3.0*sin(number/8.)+1.5*(toFloat32(cityHash64(number+143)%200)/100.0-1.0),2),
    round(5.0+0.5*sin(number/8.)+0.3*(toFloat32(cityHash64(number+144)%200)/100.0-1.0),2),
    round(3.5+0.3*sin(number/12.),2),
    round(clamp(87.0+5.0*sin(number/15.)+2.0*(toFloat32(cityHash64(number+145)%200)/100.0-1.0),70.,100.),1)
FROM numbers(864)

-- ── Line 2: Slabs ─────────────────────────────────────────────────────────────

UNION ALL
-- L2-001  SKU-A100  2026-04-01 06:00  84 h  1008 rows
SELECT addMinutes(toDateTime('2026-04-01 06:00:00'),number*5) ts,toUInt8(2),'ORD-2026-L2-001',
    round(79.0+8.0*sin(number/8.)+4.0*(toFloat32(cityHash64(number+301)%200)/100.0-1.0),2),
    round(10.0+1.0*sin(number/8.)+0.5*(toFloat32(cityHash64(number+302)%200)/100.0-1.0),3),
    round(67.0+6.0*sin(number/8.)+3.0*(toFloat32(cityHash64(number+303)%200)/100.0-1.0),2),
    round(12.0+1.2*sin(number/8.)+0.6*(toFloat32(cityHash64(number+304)%200)/100.0-1.0),2),
    round(6.0+0.5*sin(number/12.),2),
    round(clamp(88.0+5.0*sin(number/15.)+2.0*(toFloat32(cityHash64(number+305)%200)/100.0-1.0),70.,100.),1)
FROM numbers(1008)
UNION ALL
-- L2-002  SKU-A200  2026-04-04 20:00  84 h  1008 rows
SELECT addMinutes(toDateTime('2026-04-04 20:00:00'),number*5) ts,toUInt8(2),'ORD-2026-L2-002',
    round(68.0+7.0*sin(number/8.)+3.5*(toFloat32(cityHash64(number+401)%200)/100.0-1.0),2),
    round(8.5+0.9*sin(number/8.)+0.4*(toFloat32(cityHash64(number+402)%200)/100.0-1.0),3),
    round(58.0+5.0*sin(number/8.)+2.5*(toFloat32(cityHash64(number+403)%200)/100.0-1.0),2),
    round(10.0+1.0*sin(number/8.)+0.5*(toFloat32(cityHash64(number+404)%200)/100.0-1.0),2),
    round(8.0+0.7*sin(number/12.),2),
    round(clamp(90.0+4.0*sin(number/15.)+2.0*(toFloat32(cityHash64(number+405)%200)/100.0-1.0),70.,100.),1)
FROM numbers(1008)
UNION ALL
-- L2-003  SKU-A100  2026-04-08 10:00  84 h  1008 rows
SELECT addMinutes(toDateTime('2026-04-08 10:00:00'),number*5) ts,toUInt8(2),'ORD-2026-L2-003',
    round(79.0+8.0*sin(number/8.)+4.0*(toFloat32(cityHash64(number+311)%200)/100.0-1.0),2),
    round(10.0+1.0*sin(number/8.)+0.5*(toFloat32(cityHash64(number+312)%200)/100.0-1.0),3),
    round(67.0+6.0*sin(number/8.)+3.0*(toFloat32(cityHash64(number+313)%200)/100.0-1.0),2),
    round(12.0+1.2*sin(number/8.)+0.6*(toFloat32(cityHash64(number+314)%200)/100.0-1.0),2),
    round(6.0+0.5*sin(number/12.),2),
    round(clamp(88.0+5.0*sin(number/15.)+2.0*(toFloat32(cityHash64(number+315)%200)/100.0-1.0),70.,100.),1)
FROM numbers(1008)
UNION ALL
-- L2-004  SKU-A200  2026-04-12 00:00  84 h  1008 rows
SELECT addMinutes(toDateTime('2026-04-12 00:00:00'),number*5) ts,toUInt8(2),'ORD-2026-L2-004',
    round(68.0+7.0*sin(number/8.)+3.5*(toFloat32(cityHash64(number+411)%200)/100.0-1.0),2),
    round(8.5+0.9*sin(number/8.)+0.4*(toFloat32(cityHash64(number+412)%200)/100.0-1.0),3),
    round(58.0+5.0*sin(number/8.)+2.5*(toFloat32(cityHash64(number+413)%200)/100.0-1.0),2),
    round(10.0+1.0*sin(number/8.)+0.5*(toFloat32(cityHash64(number+414)%200)/100.0-1.0),2),
    round(8.0+0.7*sin(number/12.),2),
    round(clamp(90.0+4.0*sin(number/15.)+2.0*(toFloat32(cityHash64(number+415)%200)/100.0-1.0),70.,100.),1)
FROM numbers(1008)
UNION ALL
-- L2-005  SKU-A100  2026-04-15 14:00  84 h  1008 rows
SELECT addMinutes(toDateTime('2026-04-15 14:00:00'),number*5) ts,toUInt8(2),'ORD-2026-L2-005',
    round(79.0+8.0*sin(number/8.)+4.0*(toFloat32(cityHash64(number+321)%200)/100.0-1.0),2),
    round(10.0+1.0*sin(number/8.)+0.5*(toFloat32(cityHash64(number+322)%200)/100.0-1.0),3),
    round(67.0+6.0*sin(number/8.)+3.0*(toFloat32(cityHash64(number+323)%200)/100.0-1.0),2),
    round(12.0+1.2*sin(number/8.)+0.6*(toFloat32(cityHash64(number+324)%200)/100.0-1.0),2),
    round(6.0+0.5*sin(number/12.),2),
    round(clamp(88.0+5.0*sin(number/15.)+2.0*(toFloat32(cityHash64(number+325)%200)/100.0-1.0),70.,100.),1)
FROM numbers(1008)
UNION ALL
-- L2-006  SKU-A200  2026-04-19 04:00  84 h  1008 rows
SELECT addMinutes(toDateTime('2026-04-19 04:00:00'),number*5) ts,toUInt8(2),'ORD-2026-L2-006',
    round(68.0+7.0*sin(number/8.)+3.5*(toFloat32(cityHash64(number+421)%200)/100.0-1.0),2),
    round(8.5+0.9*sin(number/8.)+0.4*(toFloat32(cityHash64(number+422)%200)/100.0-1.0),3),
    round(58.0+5.0*sin(number/8.)+2.5*(toFloat32(cityHash64(number+423)%200)/100.0-1.0),2),
    round(10.0+1.0*sin(number/8.)+0.5*(toFloat32(cityHash64(number+424)%200)/100.0-1.0),2),
    round(8.0+0.7*sin(number/12.),2),
    round(clamp(90.0+4.0*sin(number/15.)+2.0*(toFloat32(cityHash64(number+425)%200)/100.0-1.0),70.,100.),1)
FROM numbers(1008)
UNION ALL
-- L2-007  SKU-A100  2026-04-22 18:00  84 h  1008 rows
SELECT addMinutes(toDateTime('2026-04-22 18:00:00'),number*5) ts,toUInt8(2),'ORD-2026-L2-007',
    round(79.0+8.0*sin(number/8.)+4.0*(toFloat32(cityHash64(number+331)%200)/100.0-1.0),2),
    round(10.0+1.0*sin(number/8.)+0.5*(toFloat32(cityHash64(number+332)%200)/100.0-1.0),3),
    round(67.0+6.0*sin(number/8.)+3.0*(toFloat32(cityHash64(number+333)%200)/100.0-1.0),2),
    round(12.0+1.2*sin(number/8.)+0.6*(toFloat32(cityHash64(number+334)%200)/100.0-1.0),2),
    round(6.0+0.5*sin(number/12.),2),
    round(clamp(88.0+5.0*sin(number/15.)+2.0*(toFloat32(cityHash64(number+335)%200)/100.0-1.0),70.,100.),1)
FROM numbers(1008)
UNION ALL
-- L2-008  SKU-A200  2026-04-26 08:00  84 h  1008 rows
SELECT addMinutes(toDateTime('2026-04-26 08:00:00'),number*5) ts,toUInt8(2),'ORD-2026-L2-008',
    round(68.0+7.0*sin(number/8.)+3.5*(toFloat32(cityHash64(number+431)%200)/100.0-1.0),2),
    round(8.5+0.9*sin(number/8.)+0.4*(toFloat32(cityHash64(number+432)%200)/100.0-1.0),3),
    round(58.0+5.0*sin(number/8.)+2.5*(toFloat32(cityHash64(number+433)%200)/100.0-1.0),2),
    round(10.0+1.0*sin(number/8.)+0.5*(toFloat32(cityHash64(number+434)%200)/100.0-1.0),2),
    round(8.0+0.7*sin(number/12.),2),
    round(clamp(90.0+4.0*sin(number/15.)+2.0*(toFloat32(cityHash64(number+435)%200)/100.0-1.0),70.,100.),1)
FROM numbers(1008);

-- ── Energy metrics ────────────────────────────────────────────────────────────

INSERT INTO historian.energy_metrics

-- ── Line 1: Wired Matts ───────────────────────────────────────────────────────

-- L1-001  SKU-B150  2026-04-01 06:00  288 rows (15-min)
SELECT addMinutes(toDateTime('2026-04-01 06:00:00'),number*15) ts,toUInt8(1) line_id,'ORD-2026-L1-001' order_number,
    round(10.5+1.5*sin(number/6.)+0.5*(toFloat32(cityHash64(number+501)%200)/100.0-1.0),2) gas_m3,
    round(38.0+5.0*sin(number/6.)+2.0*(toFloat32(cityHash64(number+502)%200)/100.0-1.0),1) elec_kwh,
    round(0.45+0.05*sin(number/6.)+0.02*(toFloat32(cityHash64(number+503)%200)/100.0-1.0),3) water_m3
FROM numbers(288)
UNION ALL
-- L1-002  SKU-B300  2026-04-04 08:00  288 rows
SELECT addMinutes(toDateTime('2026-04-04 08:00:00'),number*15) ts,toUInt8(1),'ORD-2026-L1-002',
    round(13.0+2.0*sin(number/6.)+0.7*(toFloat32(cityHash64(number+511)%200)/100.0-1.0),2),
    round(45.0+6.0*sin(number/6.)+2.5*(toFloat32(cityHash64(number+512)%200)/100.0-1.0),1),
    round(0.55+0.06*sin(number/6.)+0.03*(toFloat32(cityHash64(number+513)%200)/100.0-1.0),3)
FROM numbers(288)
UNION ALL
-- L1-003  SKU-B150  2026-04-07 10:00  288 rows
SELECT addMinutes(toDateTime('2026-04-07 10:00:00'),number*15) ts,toUInt8(1),'ORD-2026-L1-003',
    round(10.5+1.5*sin(number/6.)+0.5*(toFloat32(cityHash64(number+521)%200)/100.0-1.0),2),
    round(38.0+5.0*sin(number/6.)+2.0*(toFloat32(cityHash64(number+522)%200)/100.0-1.0),1),
    round(0.45+0.05*sin(number/6.)+0.02*(toFloat32(cityHash64(number+523)%200)/100.0-1.0),3)
FROM numbers(288)
UNION ALL
-- L1-004  SKU-B300  2026-04-10 12:00  288 rows
SELECT addMinutes(toDateTime('2026-04-10 12:00:00'),number*15) ts,toUInt8(1),'ORD-2026-L1-004',
    round(13.0+2.0*sin(number/6.)+0.7*(toFloat32(cityHash64(number+531)%200)/100.0-1.0),2),
    round(45.0+6.0*sin(number/6.)+2.5*(toFloat32(cityHash64(number+532)%200)/100.0-1.0),1),
    round(0.55+0.06*sin(number/6.)+0.03*(toFloat32(cityHash64(number+533)%200)/100.0-1.0),3)
FROM numbers(288)
UNION ALL
-- L1-005  SKU-B150  2026-04-13 14:00  288 rows
SELECT addMinutes(toDateTime('2026-04-13 14:00:00'),number*15) ts,toUInt8(1),'ORD-2026-L1-005',
    round(10.5+1.5*sin(number/6.)+0.5*(toFloat32(cityHash64(number+541)%200)/100.0-1.0),2),
    round(38.0+5.0*sin(number/6.)+2.0*(toFloat32(cityHash64(number+542)%200)/100.0-1.0),1),
    round(0.45+0.05*sin(number/6.)+0.02*(toFloat32(cityHash64(number+543)%200)/100.0-1.0),3)
FROM numbers(288)
UNION ALL
-- L1-006  SKU-B300  2026-04-16 16:00  288 rows
SELECT addMinutes(toDateTime('2026-04-16 16:00:00'),number*15) ts,toUInt8(1),'ORD-2026-L1-006',
    round(13.0+2.0*sin(number/6.)+0.7*(toFloat32(cityHash64(number+551)%200)/100.0-1.0),2),
    round(45.0+6.0*sin(number/6.)+2.5*(toFloat32(cityHash64(number+552)%200)/100.0-1.0),1),
    round(0.55+0.06*sin(number/6.)+0.03*(toFloat32(cityHash64(number+553)%200)/100.0-1.0),3)
FROM numbers(288)
UNION ALL
-- L1-007  SKU-B150  2026-04-19 18:00  288 rows
SELECT addMinutes(toDateTime('2026-04-19 18:00:00'),number*15) ts,toUInt8(1),'ORD-2026-L1-007',
    round(10.5+1.5*sin(number/6.)+0.5*(toFloat32(cityHash64(number+561)%200)/100.0-1.0),2),
    round(38.0+5.0*sin(number/6.)+2.0*(toFloat32(cityHash64(number+562)%200)/100.0-1.0),1),
    round(0.45+0.05*sin(number/6.)+0.02*(toFloat32(cityHash64(number+563)%200)/100.0-1.0),3)
FROM numbers(288)
UNION ALL
-- L1-008  SKU-B300  2026-04-22 20:00  288 rows
SELECT addMinutes(toDateTime('2026-04-22 20:00:00'),number*15) ts,toUInt8(1),'ORD-2026-L1-008',
    round(13.0+2.0*sin(number/6.)+0.7*(toFloat32(cityHash64(number+571)%200)/100.0-1.0),2),
    round(45.0+6.0*sin(number/6.)+2.5*(toFloat32(cityHash64(number+572)%200)/100.0-1.0),1),
    round(0.55+0.06*sin(number/6.)+0.03*(toFloat32(cityHash64(number+573)%200)/100.0-1.0),3)
FROM numbers(288)
UNION ALL
-- L1-009  SKU-B150  2026-04-25 22:00  288 rows
SELECT addMinutes(toDateTime('2026-04-25 22:00:00'),number*15) ts,toUInt8(1),'ORD-2026-L1-009',
    round(10.5+1.5*sin(number/6.)+0.5*(toFloat32(cityHash64(number+581)%200)/100.0-1.0),2),
    round(38.0+5.0*sin(number/6.)+2.0*(toFloat32(cityHash64(number+582)%200)/100.0-1.0),1),
    round(0.45+0.05*sin(number/6.)+0.02*(toFloat32(cityHash64(number+583)%200)/100.0-1.0),3)
FROM numbers(288)

-- ── Line 2: Slabs ─────────────────────────────────────────────────────────────

UNION ALL
-- L2-001  SKU-A100  2026-04-01 06:00  336 rows
SELECT addMinutes(toDateTime('2026-04-01 06:00:00'),number*15) ts,toUInt8(2),'ORD-2026-L2-001',
    round(16.5+2.5*sin(number/6.)+1.0*(toFloat32(cityHash64(number+601)%200)/100.0-1.0),2),
    round(55.0+7.0*sin(number/6.)+3.0*(toFloat32(cityHash64(number+602)%200)/100.0-1.0),1),
    round(0.70+0.08*sin(number/6.)+0.04*(toFloat32(cityHash64(number+603)%200)/100.0-1.0),3)
FROM numbers(336)
UNION ALL
-- L2-002  SKU-A200  2026-04-04 20:00  336 rows
SELECT addMinutes(toDateTime('2026-04-04 20:00:00'),number*15) ts,toUInt8(2),'ORD-2026-L2-002',
    round(14.0+2.0*sin(number/6.)+0.8*(toFloat32(cityHash64(number+611)%200)/100.0-1.0),2),
    round(48.0+6.0*sin(number/6.)+2.5*(toFloat32(cityHash64(number+612)%200)/100.0-1.0),1),
    round(0.60+0.07*sin(number/6.)+0.03*(toFloat32(cityHash64(number+613)%200)/100.0-1.0),3)
FROM numbers(336)
UNION ALL
-- L2-003  SKU-A100  2026-04-08 10:00  336 rows
SELECT addMinutes(toDateTime('2026-04-08 10:00:00'),number*15) ts,toUInt8(2),'ORD-2026-L2-003',
    round(16.5+2.5*sin(number/6.)+1.0*(toFloat32(cityHash64(number+621)%200)/100.0-1.0),2),
    round(55.0+7.0*sin(number/6.)+3.0*(toFloat32(cityHash64(number+622)%200)/100.0-1.0),1),
    round(0.70+0.08*sin(number/6.)+0.04*(toFloat32(cityHash64(number+623)%200)/100.0-1.0),3)
FROM numbers(336)
UNION ALL
-- L2-004  SKU-A200  2026-04-12 00:00  336 rows
SELECT addMinutes(toDateTime('2026-04-12 00:00:00'),number*15) ts,toUInt8(2),'ORD-2026-L2-004',
    round(14.0+2.0*sin(number/6.)+0.8*(toFloat32(cityHash64(number+631)%200)/100.0-1.0),2),
    round(48.0+6.0*sin(number/6.)+2.5*(toFloat32(cityHash64(number+632)%200)/100.0-1.0),1),
    round(0.60+0.07*sin(number/6.)+0.03*(toFloat32(cityHash64(number+633)%200)/100.0-1.0),3)
FROM numbers(336)
UNION ALL
-- L2-005  SKU-A100  2026-04-15 14:00  336 rows
SELECT addMinutes(toDateTime('2026-04-15 14:00:00'),number*15) ts,toUInt8(2),'ORD-2026-L2-005',
    round(16.5+2.5*sin(number/6.)+1.0*(toFloat32(cityHash64(number+641)%200)/100.0-1.0),2),
    round(55.0+7.0*sin(number/6.)+3.0*(toFloat32(cityHash64(number+642)%200)/100.0-1.0),1),
    round(0.70+0.08*sin(number/6.)+0.04*(toFloat32(cityHash64(number+643)%200)/100.0-1.0),3)
FROM numbers(336)
UNION ALL
-- L2-006  SKU-A200  2026-04-19 04:00  336 rows
SELECT addMinutes(toDateTime('2026-04-19 04:00:00'),number*15) ts,toUInt8(2),'ORD-2026-L2-006',
    round(14.0+2.0*sin(number/6.)+0.8*(toFloat32(cityHash64(number+651)%200)/100.0-1.0),2),
    round(48.0+6.0*sin(number/6.)+2.5*(toFloat32(cityHash64(number+652)%200)/100.0-1.0),1),
    round(0.60+0.07*sin(number/6.)+0.03*(toFloat32(cityHash64(number+653)%200)/100.0-1.0),3)
FROM numbers(336)
UNION ALL
-- L2-007  SKU-A100  2026-04-22 18:00  336 rows
SELECT addMinutes(toDateTime('2026-04-22 18:00:00'),number*15) ts,toUInt8(2),'ORD-2026-L2-007',
    round(16.5+2.5*sin(number/6.)+1.0*(toFloat32(cityHash64(number+661)%200)/100.0-1.0),2),
    round(55.0+7.0*sin(number/6.)+3.0*(toFloat32(cityHash64(number+662)%200)/100.0-1.0),1),
    round(0.70+0.08*sin(number/6.)+0.04*(toFloat32(cityHash64(number+663)%200)/100.0-1.0),3)
FROM numbers(336)
UNION ALL
-- L2-008  SKU-A200  2026-04-26 08:00  336 rows
SELECT addMinutes(toDateTime('2026-04-26 08:00:00'),number*15) ts,toUInt8(2),'ORD-2026-L2-008',
    round(14.0+2.0*sin(number/6.)+0.8*(toFloat32(cityHash64(number+671)%200)/100.0-1.0),2),
    round(48.0+6.0*sin(number/6.)+2.5*(toFloat32(cityHash64(number+672)%200)/100.0-1.0),1),
    round(0.60+0.07*sin(number/6.)+0.03*(toFloat32(cityHash64(number+673)%200)/100.0-1.0),3)
FROM numbers(336)

-- ── Line 3: Packaging ─────────────────────────────────────────────────────────

UNION ALL
-- L3-001  2026-04-01 06:00  288 rows
SELECT addMinutes(toDateTime('2026-04-01 06:00:00'),number*15) ts,toUInt8(3),'ORD-2026-L3-001',
    round(2.5+0.3*sin(number/6.)+0.1*(toFloat32(cityHash64(number+701)%200)/100.0-1.0),2),
    round(22.0+3.0*sin(number/6.)+1.0*(toFloat32(cityHash64(number+702)%200)/100.0-1.0),1),
    round(0.12+0.015*sin(number/6.)+0.01*(toFloat32(cityHash64(number+703)%200)/100.0-1.0),3)
FROM numbers(288)
UNION ALL
-- L3-002  2026-04-04 08:00  288 rows
SELECT addMinutes(toDateTime('2026-04-04 08:00:00'),number*15) ts,toUInt8(3),'ORD-2026-L3-002',
    round(2.5+0.3*sin(number/6.)+0.1*(toFloat32(cityHash64(number+711)%200)/100.0-1.0),2),
    round(22.0+3.0*sin(number/6.)+1.0*(toFloat32(cityHash64(number+712)%200)/100.0-1.0),1),
    round(0.12+0.015*sin(number/6.)+0.01*(toFloat32(cityHash64(number+713)%200)/100.0-1.0),3)
FROM numbers(288)
UNION ALL
-- L3-003  2026-04-07 10:00  288 rows
SELECT addMinutes(toDateTime('2026-04-07 10:00:00'),number*15) ts,toUInt8(3),'ORD-2026-L3-003',
    round(2.5+0.3*sin(number/6.)+0.1*(toFloat32(cityHash64(number+721)%200)/100.0-1.0),2),
    round(22.0+3.0*sin(number/6.)+1.0*(toFloat32(cityHash64(number+722)%200)/100.0-1.0),1),
    round(0.12+0.015*sin(number/6.)+0.01*(toFloat32(cityHash64(number+723)%200)/100.0-1.0),3)
FROM numbers(288)
UNION ALL
-- L3-004  2026-04-10 12:00  288 rows
SELECT addMinutes(toDateTime('2026-04-10 12:00:00'),number*15) ts,toUInt8(3),'ORD-2026-L3-004',
    round(2.5+0.3*sin(number/6.)+0.1*(toFloat32(cityHash64(number+731)%200)/100.0-1.0),2),
    round(22.0+3.0*sin(number/6.)+1.0*(toFloat32(cityHash64(number+732)%200)/100.0-1.0),1),
    round(0.12+0.015*sin(number/6.)+0.01*(toFloat32(cityHash64(number+733)%200)/100.0-1.0),3)
FROM numbers(288)
UNION ALL
-- L3-005  2026-04-13 14:00  288 rows
SELECT addMinutes(toDateTime('2026-04-13 14:00:00'),number*15) ts,toUInt8(3),'ORD-2026-L3-005',
    round(2.5+0.3*sin(number/6.)+0.1*(toFloat32(cityHash64(number+741)%200)/100.0-1.0),2),
    round(22.0+3.0*sin(number/6.)+1.0*(toFloat32(cityHash64(number+742)%200)/100.0-1.0),1),
    round(0.12+0.015*sin(number/6.)+0.01*(toFloat32(cityHash64(number+743)%200)/100.0-1.0),3)
FROM numbers(288)
UNION ALL
-- L3-006  2026-04-16 16:00  288 rows
SELECT addMinutes(toDateTime('2026-04-16 16:00:00'),number*15) ts,toUInt8(3),'ORD-2026-L3-006',
    round(2.5+0.3*sin(number/6.)+0.1*(toFloat32(cityHash64(number+751)%200)/100.0-1.0),2),
    round(22.0+3.0*sin(number/6.)+1.0*(toFloat32(cityHash64(number+752)%200)/100.0-1.0),1),
    round(0.12+0.015*sin(number/6.)+0.01*(toFloat32(cityHash64(number+753)%200)/100.0-1.0),3)
FROM numbers(288)
UNION ALL
-- L3-007  2026-04-19 18:00  288 rows
SELECT addMinutes(toDateTime('2026-04-19 18:00:00'),number*15) ts,toUInt8(3),'ORD-2026-L3-007',
    round(2.5+0.3*sin(number/6.)+0.1*(toFloat32(cityHash64(number+761)%200)/100.0-1.0),2),
    round(22.0+3.0*sin(number/6.)+1.0*(toFloat32(cityHash64(number+762)%200)/100.0-1.0),1),
    round(0.12+0.015*sin(number/6.)+0.01*(toFloat32(cityHash64(number+763)%200)/100.0-1.0),3)
FROM numbers(288)
UNION ALL
-- L3-008  2026-04-22 20:00  288 rows
SELECT addMinutes(toDateTime('2026-04-22 20:00:00'),number*15) ts,toUInt8(3),'ORD-2026-L3-008',
    round(2.5+0.3*sin(number/6.)+0.1*(toFloat32(cityHash64(number+771)%200)/100.0-1.0),2),
    round(22.0+3.0*sin(number/6.)+1.0*(toFloat32(cityHash64(number+772)%200)/100.0-1.0),1),
    round(0.12+0.015*sin(number/6.)+0.01*(toFloat32(cityHash64(number+773)%200)/100.0-1.0),3)
FROM numbers(288)
UNION ALL
-- L3-009  2026-04-25 22:00  288 rows
SELECT addMinutes(toDateTime('2026-04-25 22:00:00'),number*15) ts,toUInt8(3),'ORD-2026-L3-009',
    round(2.5+0.3*sin(number/6.)+0.1*(toFloat32(cityHash64(number+781)%200)/100.0-1.0),2),
    round(22.0+3.0*sin(number/6.)+1.0*(toFloat32(cityHash64(number+782)%200)/100.0-1.0),1),
    round(0.12+0.015*sin(number/6.)+0.01*(toFloat32(cityHash64(number+783)%200)/100.0-1.0),3)
FROM numbers(288);

-- ── Waste metrics ─────────────────────────────────────────────────────────────
-- 5-minute intervals per order, Lines 1 & 2 only (same schedule as production_metrics)
-- Categories: trimming (saw edges), startup (line startup losses), rejected (quality failures)
-- waste_pct = total / (total + wool_base) * 100
-- To re-seed: TRUNCATE TABLE historian.waste_metrics; then re-run this section.

INSERT INTO historian.waste_metrics

-- ── Line 1: Wired Matts ───────────────────────────────────────────────────────

-- L1-001  SKU-B150  2026-04-01 06:00  72 h  864 rows
SELECT addMinutes(toDateTime('2026-04-01 06:00:00'),number*5) ts,toUInt8(1) line_id,'ORD-2026-L1-001' order_number,
    round(clamp(3.2+0.5*sin(number/8.)+0.4*(toFloat32(cityHash64(number+5001)%200)/100.0-1.0),1.2,5.5),1) trimming_kg,
    round(clamp(0.8+0.12*sin(number/8.)+0.1*(toFloat32(cityHash64(number+5002)%200)/100.0-1.0),0.3,1.5),1) startup_kg,
    round(clamp(1.0+0.18*sin(number/8.)+0.14*(toFloat32(cityHash64(number+5003)%200)/100.0-1.0),0.3,1.9),1) rejected_kg,
    round(clamp(5.0+0.8*sin(number/8.)+0.6*(toFloat32(cityHash64(number+5001)%200)/100.0-1.0),2.0,8.5),1) total_kg,
    round(clamp(12.5+2.0*sin(number/8.)+1.5*(toFloat32(cityHash64(number+5050)%200)/100.0-1.0),7.0,18.0),1) waste_pct
FROM numbers(864)
UNION ALL
-- L1-002  SKU-B300  2026-04-04 08:00  72 h  864 rows
SELECT addMinutes(toDateTime('2026-04-04 08:00:00'),number*5) ts,toUInt8(1) line_id,'ORD-2026-L1-002' order_number,
    round(clamp(4.5+0.7*sin(number/8.)+0.5*(toFloat32(cityHash64(number+5101)%200)/100.0-1.0),2.0,7.5),1) trimming_kg,
    round(clamp(1.0+0.15*sin(number/8.)+0.12*(toFloat32(cityHash64(number+5102)%200)/100.0-1.0),0.4,1.8),1) startup_kg,
    round(clamp(1.5+0.25*sin(number/8.)+0.2*(toFloat32(cityHash64(number+5103)%200)/100.0-1.0),0.5,2.5),1) rejected_kg,
    round(clamp(7.0+1.0*sin(number/8.)+0.8*(toFloat32(cityHash64(number+5101)%200)/100.0-1.0),3.0,11.0),1) total_kg,
    round(clamp(14.0+2.2*sin(number/8.)+1.8*(toFloat32(cityHash64(number+5150)%200)/100.0-1.0),8.0,20.0),1) waste_pct
FROM numbers(864)
UNION ALL
-- L1-003  SKU-B150  2026-04-07 10:00  72 h  864 rows
SELECT addMinutes(toDateTime('2026-04-07 10:00:00'),number*5) ts,toUInt8(1) line_id,'ORD-2026-L1-003' order_number,
    round(clamp(3.2+0.5*sin(number/8.)+0.4*(toFloat32(cityHash64(number+5201)%200)/100.0-1.0),1.2,5.5),1) trimming_kg,
    round(clamp(0.8+0.12*sin(number/8.)+0.1*(toFloat32(cityHash64(number+5202)%200)/100.0-1.0),0.3,1.5),1) startup_kg,
    round(clamp(1.0+0.18*sin(number/8.)+0.14*(toFloat32(cityHash64(number+5203)%200)/100.0-1.0),0.3,1.9),1) rejected_kg,
    round(clamp(5.0+0.8*sin(number/8.)+0.6*(toFloat32(cityHash64(number+5201)%200)/100.0-1.0),2.0,8.5),1) total_kg,
    round(clamp(12.5+2.0*sin(number/8.)+1.5*(toFloat32(cityHash64(number+5250)%200)/100.0-1.0),7.0,18.0),1) waste_pct
FROM numbers(864)
UNION ALL
-- L1-004  SKU-B300  2026-04-10 12:00  72 h  864 rows
SELECT addMinutes(toDateTime('2026-04-10 12:00:00'),number*5) ts,toUInt8(1) line_id,'ORD-2026-L1-004' order_number,
    round(clamp(4.5+0.7*sin(number/8.)+0.5*(toFloat32(cityHash64(number+5301)%200)/100.0-1.0),2.0,7.5),1) trimming_kg,
    round(clamp(1.0+0.15*sin(number/8.)+0.12*(toFloat32(cityHash64(number+5302)%200)/100.0-1.0),0.4,1.8),1) startup_kg,
    round(clamp(1.5+0.25*sin(number/8.)+0.2*(toFloat32(cityHash64(number+5303)%200)/100.0-1.0),0.5,2.5),1) rejected_kg,
    round(clamp(7.0+1.0*sin(number/8.)+0.8*(toFloat32(cityHash64(number+5301)%200)/100.0-1.0),3.0,11.0),1) total_kg,
    round(clamp(14.0+2.2*sin(number/8.)+1.8*(toFloat32(cityHash64(number+5350)%200)/100.0-1.0),8.0,20.0),1) waste_pct
FROM numbers(864)
UNION ALL
-- L1-005  SKU-B150  2026-04-13 14:00  72 h  864 rows
SELECT addMinutes(toDateTime('2026-04-13 14:00:00'),number*5) ts,toUInt8(1) line_id,'ORD-2026-L1-005' order_number,
    round(clamp(3.2+0.5*sin(number/8.)+0.4*(toFloat32(cityHash64(number+5401)%200)/100.0-1.0),1.2,5.5),1) trimming_kg,
    round(clamp(0.8+0.12*sin(number/8.)+0.1*(toFloat32(cityHash64(number+5402)%200)/100.0-1.0),0.3,1.5),1) startup_kg,
    round(clamp(1.0+0.18*sin(number/8.)+0.14*(toFloat32(cityHash64(number+5403)%200)/100.0-1.0),0.3,1.9),1) rejected_kg,
    round(clamp(5.0+0.8*sin(number/8.)+0.6*(toFloat32(cityHash64(number+5401)%200)/100.0-1.0),2.0,8.5),1) total_kg,
    round(clamp(12.5+2.0*sin(number/8.)+1.5*(toFloat32(cityHash64(number+5450)%200)/100.0-1.0),7.0,18.0),1) waste_pct
FROM numbers(864)
UNION ALL
-- L1-006  SKU-B300  2026-04-16 16:00  72 h  864 rows
SELECT addMinutes(toDateTime('2026-04-16 16:00:00'),number*5) ts,toUInt8(1) line_id,'ORD-2026-L1-006' order_number,
    round(clamp(4.5+0.7*sin(number/8.)+0.5*(toFloat32(cityHash64(number+5501)%200)/100.0-1.0),2.0,7.5),1) trimming_kg,
    round(clamp(1.0+0.15*sin(number/8.)+0.12*(toFloat32(cityHash64(number+5502)%200)/100.0-1.0),0.4,1.8),1) startup_kg,
    round(clamp(1.5+0.25*sin(number/8.)+0.2*(toFloat32(cityHash64(number+5503)%200)/100.0-1.0),0.5,2.5),1) rejected_kg,
    round(clamp(7.0+1.0*sin(number/8.)+0.8*(toFloat32(cityHash64(number+5501)%200)/100.0-1.0),3.0,11.0),1) total_kg,
    round(clamp(14.0+2.2*sin(number/8.)+1.8*(toFloat32(cityHash64(number+5550)%200)/100.0-1.0),8.0,20.0),1) waste_pct
FROM numbers(864)
UNION ALL
-- L1-007  SKU-B150  2026-04-19 18:00  72 h  864 rows
SELECT addMinutes(toDateTime('2026-04-19 18:00:00'),number*5) ts,toUInt8(1) line_id,'ORD-2026-L1-007' order_number,
    round(clamp(3.2+0.5*sin(number/8.)+0.4*(toFloat32(cityHash64(number+5601)%200)/100.0-1.0),1.2,5.5),1) trimming_kg,
    round(clamp(0.8+0.12*sin(number/8.)+0.1*(toFloat32(cityHash64(number+5602)%200)/100.0-1.0),0.3,1.5),1) startup_kg,
    round(clamp(1.0+0.18*sin(number/8.)+0.14*(toFloat32(cityHash64(number+5603)%200)/100.0-1.0),0.3,1.9),1) rejected_kg,
    round(clamp(5.0+0.8*sin(number/8.)+0.6*(toFloat32(cityHash64(number+5601)%200)/100.0-1.0),2.0,8.5),1) total_kg,
    round(clamp(12.5+2.0*sin(number/8.)+1.5*(toFloat32(cityHash64(number+5650)%200)/100.0-1.0),7.0,18.0),1) waste_pct
FROM numbers(864)
UNION ALL
-- L1-008  SKU-B300  2026-04-22 20:00  72 h  864 rows
SELECT addMinutes(toDateTime('2026-04-22 20:00:00'),number*5) ts,toUInt8(1) line_id,'ORD-2026-L1-008' order_number,
    round(clamp(4.5+0.7*sin(number/8.)+0.5*(toFloat32(cityHash64(number+5701)%200)/100.0-1.0),2.0,7.5),1) trimming_kg,
    round(clamp(1.0+0.15*sin(number/8.)+0.12*(toFloat32(cityHash64(number+5702)%200)/100.0-1.0),0.4,1.8),1) startup_kg,
    round(clamp(1.5+0.25*sin(number/8.)+0.2*(toFloat32(cityHash64(number+5703)%200)/100.0-1.0),0.5,2.5),1) rejected_kg,
    round(clamp(7.0+1.0*sin(number/8.)+0.8*(toFloat32(cityHash64(number+5701)%200)/100.0-1.0),3.0,11.0),1) total_kg,
    round(clamp(14.0+2.2*sin(number/8.)+1.8*(toFloat32(cityHash64(number+5750)%200)/100.0-1.0),8.0,20.0),1) waste_pct
FROM numbers(864)
UNION ALL
-- L1-009  SKU-B150  2026-04-25 22:00  72 h  864 rows
SELECT addMinutes(toDateTime('2026-04-25 22:00:00'),number*5) ts,toUInt8(1) line_id,'ORD-2026-L1-009' order_number,
    round(clamp(3.2+0.5*sin(number/8.)+0.4*(toFloat32(cityHash64(number+5801)%200)/100.0-1.0),1.2,5.5),1) trimming_kg,
    round(clamp(0.8+0.12*sin(number/8.)+0.1*(toFloat32(cityHash64(number+5802)%200)/100.0-1.0),0.3,1.5),1) startup_kg,
    round(clamp(1.0+0.18*sin(number/8.)+0.14*(toFloat32(cityHash64(number+5803)%200)/100.0-1.0),0.3,1.9),1) rejected_kg,
    round(clamp(5.0+0.8*sin(number/8.)+0.6*(toFloat32(cityHash64(number+5801)%200)/100.0-1.0),2.0,8.5),1) total_kg,
    round(clamp(12.5+2.0*sin(number/8.)+1.5*(toFloat32(cityHash64(number+5850)%200)/100.0-1.0),7.0,18.0),1) waste_pct
FROM numbers(864)

-- ── Line 2: Slabs ─────────────────────────────────────────────────────────────

UNION ALL
-- L2-001  SKU-A100  2026-04-01 06:00  84 h  1008 rows
SELECT addMinutes(toDateTime('2026-04-01 06:00:00'),number*5) ts,toUInt8(2) line_id,'ORD-2026-L2-001' order_number,
    round(clamp(8.0+1.2*sin(number/8.)+0.9*(toFloat32(cityHash64(number+6001)%200)/100.0-1.0),3.5,13.0),1) trimming_kg,
    round(clamp(2.0+0.3*sin(number/8.)+0.25*(toFloat32(cityHash64(number+6002)%200)/100.0-1.0),0.8,3.5),1) startup_kg,
    round(clamp(2.0+0.35*sin(number/8.)+0.28*(toFloat32(cityHash64(number+6003)%200)/100.0-1.0),0.7,3.5),1) rejected_kg,
    round(clamp(12.0+1.8*sin(number/8.)+1.4*(toFloat32(cityHash64(number+6001)%200)/100.0-1.0),5.0,19.0),1) total_kg,
    round(clamp(15.2+2.5*sin(number/8.)+2.0*(toFloat32(cityHash64(number+6050)%200)/100.0-1.0),9.0,22.0),1) waste_pct
FROM numbers(1008)
UNION ALL
-- L2-002  SKU-A200  2026-04-04 20:00  84 h  1008 rows
SELECT addMinutes(toDateTime('2026-04-04 20:00:00'),number*5) ts,toUInt8(2) line_id,'ORD-2026-L2-002' order_number,
    round(clamp(6.5+1.0*sin(number/8.)+0.8*(toFloat32(cityHash64(number+6101)%200)/100.0-1.0),3.0,11.0),1) trimming_kg,
    round(clamp(1.5+0.25*sin(number/8.)+0.2*(toFloat32(cityHash64(number+6102)%200)/100.0-1.0),0.6,2.8),1) startup_kg,
    round(clamp(2.0+0.3*sin(number/8.)+0.25*(toFloat32(cityHash64(number+6103)%200)/100.0-1.0),0.7,3.5),1) rejected_kg,
    round(clamp(10.0+1.5*sin(number/8.)+1.2*(toFloat32(cityHash64(number+6101)%200)/100.0-1.0),4.5,16.0),1) total_kg,
    round(clamp(14.7+2.3*sin(number/8.)+1.8*(toFloat32(cityHash64(number+6150)%200)/100.0-1.0),8.0,21.0),1) waste_pct
FROM numbers(1008)
UNION ALL
-- L2-003  SKU-A100  2026-04-08 10:00  84 h  1008 rows
SELECT addMinutes(toDateTime('2026-04-08 10:00:00'),number*5) ts,toUInt8(2) line_id,'ORD-2026-L2-003' order_number,
    round(clamp(8.0+1.2*sin(number/8.)+0.9*(toFloat32(cityHash64(number+6201)%200)/100.0-1.0),3.5,13.0),1) trimming_kg,
    round(clamp(2.0+0.3*sin(number/8.)+0.25*(toFloat32(cityHash64(number+6202)%200)/100.0-1.0),0.8,3.5),1) startup_kg,
    round(clamp(2.0+0.35*sin(number/8.)+0.28*(toFloat32(cityHash64(number+6203)%200)/100.0-1.0),0.7,3.5),1) rejected_kg,
    round(clamp(12.0+1.8*sin(number/8.)+1.4*(toFloat32(cityHash64(number+6201)%200)/100.0-1.0),5.0,19.0),1) total_kg,
    round(clamp(15.2+2.5*sin(number/8.)+2.0*(toFloat32(cityHash64(number+6250)%200)/100.0-1.0),9.0,22.0),1) waste_pct
FROM numbers(1008)
UNION ALL
-- L2-004  SKU-A200  2026-04-12 00:00  84 h  1008 rows
SELECT addMinutes(toDateTime('2026-04-12 00:00:00'),number*5) ts,toUInt8(2) line_id,'ORD-2026-L2-004' order_number,
    round(clamp(6.5+1.0*sin(number/8.)+0.8*(toFloat32(cityHash64(number+6301)%200)/100.0-1.0),3.0,11.0),1) trimming_kg,
    round(clamp(1.5+0.25*sin(number/8.)+0.2*(toFloat32(cityHash64(number+6302)%200)/100.0-1.0),0.6,2.8),1) startup_kg,
    round(clamp(2.0+0.3*sin(number/8.)+0.25*(toFloat32(cityHash64(number+6303)%200)/100.0-1.0),0.7,3.5),1) rejected_kg,
    round(clamp(10.0+1.5*sin(number/8.)+1.2*(toFloat32(cityHash64(number+6301)%200)/100.0-1.0),4.5,16.0),1) total_kg,
    round(clamp(14.7+2.3*sin(number/8.)+1.8*(toFloat32(cityHash64(number+6350)%200)/100.0-1.0),8.0,21.0),1) waste_pct
FROM numbers(1008)
UNION ALL
-- L2-005  SKU-A100  2026-04-15 14:00  84 h  1008 rows
SELECT addMinutes(toDateTime('2026-04-15 14:00:00'),number*5) ts,toUInt8(2) line_id,'ORD-2026-L2-005' order_number,
    round(clamp(8.0+1.2*sin(number/8.)+0.9*(toFloat32(cityHash64(number+6401)%200)/100.0-1.0),3.5,13.0),1) trimming_kg,
    round(clamp(2.0+0.3*sin(number/8.)+0.25*(toFloat32(cityHash64(number+6402)%200)/100.0-1.0),0.8,3.5),1) startup_kg,
    round(clamp(2.0+0.35*sin(number/8.)+0.28*(toFloat32(cityHash64(number+6403)%200)/100.0-1.0),0.7,3.5),1) rejected_kg,
    round(clamp(12.0+1.8*sin(number/8.)+1.4*(toFloat32(cityHash64(number+6401)%200)/100.0-1.0),5.0,19.0),1) total_kg,
    round(clamp(15.2+2.5*sin(number/8.)+2.0*(toFloat32(cityHash64(number+6450)%200)/100.0-1.0),9.0,22.0),1) waste_pct
FROM numbers(1008)
UNION ALL
-- L2-006  SKU-A200  2026-04-19 04:00  84 h  1008 rows
SELECT addMinutes(toDateTime('2026-04-19 04:00:00'),number*5) ts,toUInt8(2) line_id,'ORD-2026-L2-006' order_number,
    round(clamp(6.5+1.0*sin(number/8.)+0.8*(toFloat32(cityHash64(number+6501)%200)/100.0-1.0),3.0,11.0),1) trimming_kg,
    round(clamp(1.5+0.25*sin(number/8.)+0.2*(toFloat32(cityHash64(number+6502)%200)/100.0-1.0),0.6,2.8),1) startup_kg,
    round(clamp(2.0+0.3*sin(number/8.)+0.25*(toFloat32(cityHash64(number+6503)%200)/100.0-1.0),0.7,3.5),1) rejected_kg,
    round(clamp(10.0+1.5*sin(number/8.)+1.2*(toFloat32(cityHash64(number+6501)%200)/100.0-1.0),4.5,16.0),1) total_kg,
    round(clamp(14.7+2.3*sin(number/8.)+1.8*(toFloat32(cityHash64(number+6550)%200)/100.0-1.0),8.0,21.0),1) waste_pct
FROM numbers(1008)
UNION ALL
-- L2-007  SKU-A100  2026-04-22 18:00  84 h  1008 rows
SELECT addMinutes(toDateTime('2026-04-22 18:00:00'),number*5) ts,toUInt8(2) line_id,'ORD-2026-L2-007' order_number,
    round(clamp(8.0+1.2*sin(number/8.)+0.9*(toFloat32(cityHash64(number+6601)%200)/100.0-1.0),3.5,13.0),1) trimming_kg,
    round(clamp(2.0+0.3*sin(number/8.)+0.25*(toFloat32(cityHash64(number+6602)%200)/100.0-1.0),0.8,3.5),1) startup_kg,
    round(clamp(2.0+0.35*sin(number/8.)+0.28*(toFloat32(cityHash64(number+6603)%200)/100.0-1.0),0.7,3.5),1) rejected_kg,
    round(clamp(12.0+1.8*sin(number/8.)+1.4*(toFloat32(cityHash64(number+6601)%200)/100.0-1.0),5.0,19.0),1) total_kg,
    round(clamp(15.2+2.5*sin(number/8.)+2.0*(toFloat32(cityHash64(number+6650)%200)/100.0-1.0),9.0,22.0),1) waste_pct
FROM numbers(1008)
UNION ALL
-- L2-008  SKU-A200  2026-04-26 08:00  84 h  1008 rows
SELECT addMinutes(toDateTime('2026-04-26 08:00:00'),number*5) ts,toUInt8(2) line_id,'ORD-2026-L2-008' order_number,
    round(clamp(6.5+1.0*sin(number/8.)+0.8*(toFloat32(cityHash64(number+6701)%200)/100.0-1.0),3.0,11.0),1) trimming_kg,
    round(clamp(1.5+0.25*sin(number/8.)+0.2*(toFloat32(cityHash64(number+6702)%200)/100.0-1.0),0.6,2.8),1) startup_kg,
    round(clamp(2.0+0.3*sin(number/8.)+0.25*(toFloat32(cityHash64(number+6703)%200)/100.0-1.0),0.7,3.5),1) rejected_kg,
    round(clamp(10.0+1.5*sin(number/8.)+1.2*(toFloat32(cityHash64(number+6701)%200)/100.0-1.0),4.5,16.0),1) total_kg,
    round(clamp(14.7+2.3*sin(number/8.)+1.8*(toFloat32(cityHash64(number+6750)%200)/100.0-1.0),8.0,21.0),1) waste_pct
FROM numbers(1008);

-- ── Process snapshots ─────────────────────────────────────────────────────────
-- 1-minute resolution, 24 h window (2026-05-02 07:00 → 2026-05-03 07:00)
-- Units: Lines 1-2 → curing / acon / binder; Lines 3-6 → main / package
-- Params: cure_temp(°C), cure_pressure(bar), belt_speed(m/min)
--         acon_temp(°C), acon_airflow(m³/h), acon_humidity(%)
--         binder_flow(kg/h), binder_conc(%), binder_pressure(bar)
--         line_speed(m/min), line_output(kg/h)
--         pack_speed(ppm), film_tension(N)

INSERT INTO historian.process_snapshots

-- ── Line 1: Curing ────────────────────────────────────────────────────────────
SELECT addMinutes(toDateTime('2026-05-02 07:00:00'),number) ts, toUInt8(1) line_id, 'curing' unit, 'cure_temp' param,
    round(195.0+10.0*sin(number/120.)+2.0*(toFloat32(cityHash64(number+10001)%200)/100.0-1.0),1) value
FROM numbers(1440)
UNION ALL
SELECT addMinutes(toDateTime('2026-05-02 07:00:00'),number),toUInt8(1),'curing','cure_pressure',
    round(3.5+0.5*sin(number/90.)+0.05*(toFloat32(cityHash64(number+10002)%200)/100.0-1.0),2)
FROM numbers(1440)
UNION ALL
SELECT addMinutes(toDateTime('2026-05-02 07:00:00'),number),toUInt8(1),'curing','belt_speed',
    round(3.8+0.3*sin(number/60.)+0.05*(toFloat32(cityHash64(number+10003)%200)/100.0-1.0),2)
FROM numbers(1440)
UNION ALL
-- ── Line 1: ACON ──────────────────────────────────────────────────────────────
SELECT addMinutes(toDateTime('2026-05-02 07:00:00'),number),toUInt8(1),'acon','acon_temp',
    round(178.0+8.0*sin(number/120.)+1.5*(toFloat32(cityHash64(number+10011)%200)/100.0-1.0),1)
FROM numbers(1440)
UNION ALL
SELECT addMinutes(toDateTime('2026-05-02 07:00:00'),number),toUInt8(1),'acon','acon_airflow',
    round(9800.0+800.0*sin(number/90.)+100.0*(toFloat32(cityHash64(number+10012)%200)/100.0-1.0),0)
FROM numbers(1440)
UNION ALL
SELECT addMinutes(toDateTime('2026-05-02 07:00:00'),number),toUInt8(1),'acon','acon_humidity',
    round(24.0+5.0*sin(number/60.)+0.5*(toFloat32(cityHash64(number+10013)%200)/100.0-1.0),1)
FROM numbers(1440)
UNION ALL
-- ── Line 1: Binder ────────────────────────────────────────────────────────────
SELECT addMinutes(toDateTime('2026-05-02 07:00:00'),number),toUInt8(1),'binder','binder_flow',
    round(58.0+8.0*sin(number/120.)+1.0*(toFloat32(cityHash64(number+10021)%200)/100.0-1.0),1)
FROM numbers(1440)
UNION ALL
SELECT addMinutes(toDateTime('2026-05-02 07:00:00'),number),toUInt8(1),'binder','binder_conc',
    round(8.5+1.5*sin(number/90.)+0.2*(toFloat32(cityHash64(number+10022)%200)/100.0-1.0),2)
FROM numbers(1440)
UNION ALL
SELECT addMinutes(toDateTime('2026-05-02 07:00:00'),number),toUInt8(1),'binder','binder_pressure',
    round(1.2+0.15*sin(number/60.)+0.02*(toFloat32(cityHash64(number+10023)%200)/100.0-1.0),2)
FROM numbers(1440)
UNION ALL
-- ── Line 2: Curing ────────────────────────────────────────────────────────────
SELECT addMinutes(toDateTime('2026-05-02 07:00:00'),number),toUInt8(2),'curing','cure_temp',
    round(198.0+8.0*sin(number/120.)+1.5*(toFloat32(cityHash64(number+20001)%200)/100.0-1.0),1)
FROM numbers(1440)
UNION ALL
SELECT addMinutes(toDateTime('2026-05-02 07:00:00'),number),toUInt8(2),'curing','cure_pressure',
    round(3.8+0.4*sin(number/90.)+0.04*(toFloat32(cityHash64(number+20002)%200)/100.0-1.0),2)
FROM numbers(1440)
UNION ALL
SELECT addMinutes(toDateTime('2026-05-02 07:00:00'),number),toUInt8(2),'curing','belt_speed',
    round(3.5+0.25*sin(number/60.)+0.04*(toFloat32(cityHash64(number+20003)%200)/100.0-1.0),2)
FROM numbers(1440)
UNION ALL
-- ── Line 2: ACON ──────────────────────────────────────────────────────────────
SELECT addMinutes(toDateTime('2026-05-02 07:00:00'),number),toUInt8(2),'acon','acon_temp',
    round(182.0+7.0*sin(number/120.)+1.2*(toFloat32(cityHash64(number+20011)%200)/100.0-1.0),1)
FROM numbers(1440)
UNION ALL
SELECT addMinutes(toDateTime('2026-05-02 07:00:00'),number),toUInt8(2),'acon','acon_airflow',
    round(10200.0+600.0*sin(number/90.)+80.0*(toFloat32(cityHash64(number+20012)%200)/100.0-1.0),0)
FROM numbers(1440)
UNION ALL
SELECT addMinutes(toDateTime('2026-05-02 07:00:00'),number),toUInt8(2),'acon','acon_humidity',
    round(27.0+4.0*sin(number/60.)+0.4*(toFloat32(cityHash64(number+20013)%200)/100.0-1.0),1)
FROM numbers(1440)
UNION ALL
-- ── Line 2: Binder ────────────────────────────────────────────────────────────
SELECT addMinutes(toDateTime('2026-05-02 07:00:00'),number),toUInt8(2),'binder','binder_flow',
    round(65.0+7.0*sin(number/120.)+0.9*(toFloat32(cityHash64(number+20021)%200)/100.0-1.0),1)
FROM numbers(1440)
UNION ALL
SELECT addMinutes(toDateTime('2026-05-02 07:00:00'),number),toUInt8(2),'binder','binder_conc',
    round(9.5+1.2*sin(number/90.)+0.15*(toFloat32(cityHash64(number+20022)%200)/100.0-1.0),2)
FROM numbers(1440)
UNION ALL
SELECT addMinutes(toDateTime('2026-05-02 07:00:00'),number),toUInt8(2),'binder','binder_pressure',
    round(1.3+0.12*sin(number/60.)+0.015*(toFloat32(cityHash64(number+20023)%200)/100.0-1.0),2)
FROM numbers(1440)
UNION ALL
-- ── Line 3 (Briquette): Main ──────────────────────────────────────────────────
SELECT addMinutes(toDateTime('2026-05-02 07:00:00'),number),toUInt8(3),'main','line_speed',
    round(3.2+0.3*sin(number/90.)+0.04*(toFloat32(cityHash64(number+30001)%200)/100.0-1.0),2)
FROM numbers(1440)
UNION ALL
SELECT addMinutes(toDateTime('2026-05-02 07:00:00'),number),toUInt8(3),'main','line_output',
    round(280.0+35.0*sin(number/120.)+5.0*(toFloat32(cityHash64(number+30002)%200)/100.0-1.0),0)
FROM numbers(1440)
UNION ALL
-- ── Line 3: Package ───────────────────────────────────────────────────────────
SELECT addMinutes(toDateTime('2026-05-02 07:00:00'),number),toUInt8(3),'package','pack_speed',
    round(11.0+1.5*sin(number/60.)+0.2*(toFloat32(cityHash64(number+30011)%200)/100.0-1.0),1)
FROM numbers(1440)
UNION ALL
SELECT addMinutes(toDateTime('2026-05-02 07:00:00'),number),toUInt8(3),'package','film_tension',
    round(33.0+4.0*sin(number/90.)+0.5*(toFloat32(cityHash64(number+30012)%200)/100.0-1.0),1)
FROM numbers(1440)
UNION ALL
-- ── Line 4 (Wired Matts): Main ────────────────────────────────────────────────
SELECT addMinutes(toDateTime('2026-05-02 07:00:00'),number),toUInt8(4),'main','line_speed',
    round(4.0+0.4*sin(number/90.)+0.05*(toFloat32(cityHash64(number+40001)%200)/100.0-1.0),2)
FROM numbers(1440)
UNION ALL
SELECT addMinutes(toDateTime('2026-05-02 07:00:00'),number),toUInt8(4),'main','line_output',
    round(320.0+40.0*sin(number/120.)+6.0*(toFloat32(cityHash64(number+40002)%200)/100.0-1.0),0)
FROM numbers(1440)
UNION ALL
-- ── Line 4: Package ───────────────────────────────────────────────────────────
SELECT addMinutes(toDateTime('2026-05-02 07:00:00'),number),toUInt8(4),'package','pack_speed',
    round(13.0+2.0*sin(number/60.)+0.25*(toFloat32(cityHash64(number+40011)%200)/100.0-1.0),1)
FROM numbers(1440)
UNION ALL
SELECT addMinutes(toDateTime('2026-05-02 07:00:00'),number),toUInt8(4),'package','film_tension',
    round(36.0+5.0*sin(number/90.)+0.6*(toFloat32(cityHash64(number+40012)%200)/100.0-1.0),1)
FROM numbers(1440)
UNION ALL
-- ── Line 5 (Rockfon): Main ────────────────────────────────────────────────────
SELECT addMinutes(toDateTime('2026-05-02 07:00:00'),number),toUInt8(5),'main','line_speed',
    round(3.5+0.35*sin(number/90.)+0.04*(toFloat32(cityHash64(number+50001)%200)/100.0-1.0),2)
FROM numbers(1440)
UNION ALL
SELECT addMinutes(toDateTime('2026-05-02 07:00:00'),number),toUInt8(5),'main','line_output',
    round(300.0+38.0*sin(number/120.)+5.5*(toFloat32(cityHash64(number+50002)%200)/100.0-1.0),0)
FROM numbers(1440)
UNION ALL
-- ── Line 5: Package ───────────────────────────────────────────────────────────
SELECT addMinutes(toDateTime('2026-05-02 07:00:00'),number),toUInt8(5),'package','pack_speed',
    round(12.0+1.8*sin(number/60.)+0.22*(toFloat32(cityHash64(number+50011)%200)/100.0-1.0),1)
FROM numbers(1440)
UNION ALL
SELECT addMinutes(toDateTime('2026-05-02 07:00:00'),number),toUInt8(5),'package','film_tension',
    round(35.0+4.5*sin(number/90.)+0.55*(toFloat32(cityHash64(number+50012)%200)/100.0-1.0),1)
FROM numbers(1440)
UNION ALL
-- ── Line 6 (Grodan): Main ─────────────────────────────────────────────────────
SELECT addMinutes(toDateTime('2026-05-02 07:00:00'),number),toUInt8(6),'main','line_speed',
    round(3.8+0.3*sin(number/90.)+0.04*(toFloat32(cityHash64(number+60001)%200)/100.0-1.0),2)
FROM numbers(1440)
UNION ALL
SELECT addMinutes(toDateTime('2026-05-02 07:00:00'),number),toUInt8(6),'main','line_output',
    round(310.0+35.0*sin(number/120.)+5.0*(toFloat32(cityHash64(number+60002)%200)/100.0-1.0),0)
FROM numbers(1440)
UNION ALL
-- ── Line 6: Package ───────────────────────────────────────────────────────────
SELECT addMinutes(toDateTime('2026-05-02 07:00:00'),number),toUInt8(6),'package','pack_speed',
    round(11.5+1.5*sin(number/60.)+0.2*(toFloat32(cityHash64(number+60011)%200)/100.0-1.0),1)
FROM numbers(1440)
UNION ALL
SELECT addMinutes(toDateTime('2026-05-02 07:00:00'),number),toUInt8(6),'package','film_tension',
    round(34.0+4.0*sin(number/90.)+0.5*(toFloat32(cityHash64(number+60012)%200)/100.0-1.0),1)
FROM numbers(1440);
