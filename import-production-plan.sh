#!/usr/bin/env bash
# Import a production-plan CSV (";"-delimited) into the orders table.
#
# Expected CSV headers (only these columns are used):
#   PlannedOrder              -> orders.order_number
#   Material                  -> orders.product_id  (resolved via products.number = Material)
#   PlannedOrderStartTime     -> orders.planned_start_at
#   PlannedOrderFinishTime    -> orders.planned_complete_at
#   TotalPlannedOrderQuantity -> orders.volume
#
# UOM is derived directly from the product's uom_id FK.
#
# All imported orders go to production line $LINE (orders.production_line_id).
# Rows whose Material doesn't match any products.number are skipped.
# Re-running is idempotent — duplicate order_number rows are ignored.
#
# Usage:
#   LINE=1 ./import-production-plan.sh <path-to-csv>
#   ./import-production-plan.sh production_plan.csv         # defaults to LINE=1

set -euo pipefail

CSV_FILE=${1:-}
LINE=${LINE:-1}

if [ -z "$CSV_FILE" ] || [ ! -f "$CSV_FILE" ]; then
  echo "Usage: LINE=<id> $0 <path-to-csv>" >&2
  exit 1
fi

SQL_FILE=$(mktemp)
trap 'rm -f "$SQL_FILE"' EXIT

awk -F';' -v line="$LINE" '
  NR == 1 {
    for (i = 1; i <= NF; i++) col[$i] = i
    next
  }
  {
    order_number = $(col["PlannedOrder"])
    material     = $(col["Material"])
    start_time   = $(col["PlannedOrderStartTime"])
    finish_time  = $(col["PlannedOrderFinishTime"])
    volume       = $(col["TotalPlannedOrderQuantity"])

    if (order_number == "" || material == "" || volume == "") next

    gsub(/'"'"'/, "'"'"''"'"'", order_number)
    gsub(/'"'"'/, "'"'"''"'"'", material)
    gsub(/'"'"'/, "'"'"''"'"'", start_time)
    gsub(/'"'"'/, "'"'"''"'"'", finish_time)

    printf "INSERT INTO orders (order_number, product_id, volume, uom_id, planned_start_at, planned_complete_at, production_line_id)\n"
    printf "SELECT '"'"'%s'"'"', p.id, %s,\n",
      order_number, volume
    printf "    p.uom_id,\n"
    printf "    %s, %s, %s\n",
      (start_time  == "" ? "NULL" : "'"'"'" start_time  "'"'"'::timestamptz"),
      (finish_time == "" ? "NULL" : "'"'"'" finish_time "'"'"'::timestamptz"),
      line
    printf "FROM products p WHERE p.number = '"'"'%s'"'"'\n", material
    printf "ON CONFLICT (order_number) DO NOTHING;\n"
  }
' "$CSV_FILE" > "$SQL_FILE"

ROWS=$(grep -c '^INSERT INTO orders' "$SQL_FILE" || true)
echo "Generated $ROWS insert statement(s) from $CSV_FILE (LINE=$LINE)"

docker exec -i postgres-db psql -U mesrwl -d mes < "$SQL_FILE"
