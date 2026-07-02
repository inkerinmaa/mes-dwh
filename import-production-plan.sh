#!/usr/bin/env bash
# Import a production-plan CSV (";"-delimited) into the orders table.
#
# Column mapping:
#   planned_order              -> orders.order_number
#   material                   -> orders.product_id  (resolved via products.number = material)
#   planned_order_start_time   -> orders.planned_start_at
#   planned_order_finish_time  -> orders.planned_complete_at
#   total_planned_order_qty    -> orders.volume
#
# All imported orders are assigned to production line $LINE (orders.production_line_id).
# When $LINE is Wired Matts (id $WIRED_MATTS_LINE_ID), cage tracking and the
# pkg UOM are enabled by default — matching the New Order form's behavior —
# with cage_size taken from the product's pcs_in_pack (falls back to 50).
#
# Rows whose `material` doesn't match any products.number are skipped (no FK match,
# so the INSERT ... SELECT produces zero rows). Rows are idempotent on
# order_number (ON CONFLICT DO NOTHING), so re-running is safe.
#
# Usage:
#   ./import-production-plan.sh <path-to-csv>
#   ./import-production-plan.sh production_plan_sample.csv
#   LINE=1 ./import-production-plan.sh production_plan_sample.csv

set -euo pipefail

CSV_FILE=${1:-}
WIRED_MATTS_LINE_ID=4
LINE=${LINE:-$WIRED_MATTS_LINE_ID}   # production_line_id

if [ -z "$CSV_FILE" ] || [ ! -f "$CSV_FILE" ]; then
  echo "Usage: $0 <path-to-csv>" >&2
  exit 1
fi

if [ "$LINE" -eq "$WIRED_MATTS_LINE_ID" ]; then
  CAGE_SQL="true"
  UOM_SQL="(SELECT id FROM uom WHERE code = 'pkg')"
  CAGE_SIZE_SQL="COALESCE(s.pcs_in_pack, 50)"
else
  CAGE_SQL="false"
  UOM_SQL="NULL"
  CAGE_SIZE_SQL="50"
fi

SQL_FILE=$(mktemp)
trap 'rm -f "$SQL_FILE"' EXIT

awk -F';' -v line="$LINE" -v cage="$CAGE_SQL" -v uom="$UOM_SQL" -v cage_size="$CAGE_SIZE_SQL" '
  NR == 1 {
    for (i = 1; i <= NF; i++) col[$i] = i
    next
  }
  {
    order_number = $(col["planned_order"])
    material     = $(col["material"])
    start_time   = $(col["planned_order_start_time"])
    finish_time  = $(col["planned_order_finish_time"])
    volume       = $(col["total_planned_order_qty"])

    if (order_number == "" || material == "" || volume == "") next

    gsub(/'"'"'/, "'"'"''"'"'", order_number)
    gsub(/'"'"'/, "'"'"''"'"'", material)
    gsub(/'"'"'/, "'"'"''"'"'", start_time)
    gsub(/'"'"'/, "'"'"''"'"'", finish_time)

    printf "INSERT INTO orders (order_number, product_id, volume, planned_start_at, planned_complete_at, production_line_id, cage, uom_id, cage_size)\n"
    printf "SELECT '"'"'%s'"'"', p.id, %s, %s, %s, %s, %s, %s, %s FROM products p WHERE p.number = '"'"'%s'"'"'\n",
      order_number, volume,
      (start_time  == "" ? "NULL" : "'"'"'" start_time  "'"'"'::timestamptz"),
      (finish_time == "" ? "NULL" : "'"'"'" finish_time "'"'"'::timestamptz"),
      line, cage, uom, cage_size,
      material
    printf "ON CONFLICT (order_number) DO NOTHING;\n"
  }
' "$CSV_FILE" > "$SQL_FILE"

ROWS=$(grep -c '^INSERT INTO orders' "$SQL_FILE" || true)
echo "Generated $ROWS insert statement(s) from $CSV_FILE"

docker exec -i postgres-db psql -U mesrwl -d mes < "$SQL_FILE"
