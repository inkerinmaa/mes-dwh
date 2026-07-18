#!/usr/bin/env bash
# Import product groups from a ';'-delimited CSV into the product_groups table.
#
# Column header names are matched case-insensitively.
# Empty fields become NULL. Rows without an articlegroup are skipped.
# Uses ON CONFLICT (id) DO UPDATE SET name_eng — safe to re-run.
# Existing Russian names (name column) are preserved on conflict.
#
# CSV column → product_groups column mapping:
#   articlegroup → id
#   name         → name_eng  (also used as name on fresh insert if no Russian name exists)
#
# Usage:
#   ./import-product-groups.sh groups.csv
#   DELIM=, ./import-product-groups.sh groups.csv

set -euo pipefail

CSV_FILE=${1:-}
DELIM=${DELIM:-;}

if [ -z "$CSV_FILE" ] || [ ! -f "$CSV_FILE" ]; then
  echo "Usage: $0 <path-to-csv>" >&2
  echo "       DELIM=, $0 groups.csv   # use comma delimiter" >&2
  exit 1
fi

SQL_FILE=$(mktemp)
AWK_FILE=$(mktemp)
trap 'rm -f "$SQL_FILE" "$AWK_FILE"' EXIT

cat > "$AWK_FILE" << 'AWKEOF'
NR == 1 {
    for (i = 1; i <= NF; i++) {
        h = $i
        gsub(/[\r\n \t"]/, "", h)
        col[tolower(h)] = i
    }
    next
}

function str(name,    v, idx) {
    if (!(name in col)) return "NULL"
    idx = col[name]
    v = $idx
    gsub(/\r/, "", v)
    gsub(/^[ \t]+|[ \t]+$/, "", v)
    if (v == "") return "NULL"
    gsub(/'/, "''", v)
    return "'" v "'"
}

function iget(name,    v, idx) {
    if (!(name in col)) return "NULL"
    idx = col[name]
    v = $idx
    gsub(/\r/, "", v)
    gsub(/^[ \t]+|[ \t]+$/, "", v)
    if (v == "" || v !~ /^[+-]?[0-9]+$/) return "NULL"
    return v + 0
}

{
    id_val   = iget("articlegroup")
    if (id_val == "NULL") next

    name_val = str("name")
    if (name_val == "NULL") next   # name NOT NULL in DB

    # On fresh insert: name = name_eng (placeholder until Russian name is set manually)
    # On conflict: only update name_eng, preserve existing Russian name
    print "INSERT INTO product_groups (id, name, name_eng) VALUES (" id_val ", " name_val ", " name_val ")"
    print "ON CONFLICT (id) DO UPDATE SET name_eng = EXCLUDED.name_eng;"
}
AWKEOF

awk -F"$DELIM" -f "$AWK_FILE" "$CSV_FILE" >> "$SQL_FILE"

echo "SELECT setval('product_groups_id_seq', COALESCE(MAX(id), 1)) FROM product_groups;" >> "$SQL_FILE"

ROWS=$(grep -c '^INSERT INTO product_groups' "$SQL_FILE" || true)
echo "Generated $ROWS insert statement(s) from $CSV_FILE"

docker exec -i postgres-db psql -U mesrwl -d mes < "$SQL_FILE"
