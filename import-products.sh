#!/usr/bin/env bash
# Import products from a ';'-delimited CSV into the products table.
#
# Column header names are matched case-insensitively.
# Empty fields become NULL. Decimal commas (3,5) are converted to dots (3.5).
# Rows without a materialnumber are skipped.
# Uses ON CONFLICT (number) DO UPDATE SET — safe to re-run.
#
# CSV column → products column mapping:
#   id                  → id
#   materialnumber      → number  (conflict key)
#   articlegroup        → group_id
#   covercode           → cover_code
#   packingcode         → package_code
#   sequencenumber      → sequence
#   productioninstruction → production_instruction
#   description         → name_eng
#   length              → length
#   width               → width
#   thickness           → thickness
#   density             → density
#   pcspercolli         → pcs_in_pack
#   collisperunit       → packs_in_package
#   lengthdirection     → cut_direction
#   layers              → layers
#   normwaste           → norm_waste
#   grindingwasteow     → grinding_waste_ow
#   packaging           → uom_id  (resolved via SELECT id FROM uom WHERE code = packaging)
#   storelocation       → category
#   directrclmode       → direct_recycle_mode
#   remark              → comment
#   info1 … info6       → info_1 … info_6
#   productionlinewidth → product_line_width
#   edgetrimwidth       → edge_trim_width
#   wetedgetrimwidth    → wet_edge_trim_width
#   wetedgetrimmode     → wet_edge_trim_mode
#   mark                → mark
#   state               → state
#   (others / grindingwasteosw → skipped)
#
# Usage:
#   ./import-products.sh products.csv
#   DELIM=, ./import-products.sh products.csv

set -euo pipefail

CSV_FILE=${1:-}
DELIM=${DELIM:-;}

if [ -z "$CSV_FILE" ] || [ ! -f "$CSV_FILE" ]; then
  echo "Usage: $0 <path-to-csv>" >&2
  echo "       DELIM=, $0 products.csv   # use comma delimiter" >&2
  exit 1
fi

SQL_FILE=$(mktemp)
AWK_FILE=$(mktemp)
trap 'rm -f "$SQL_FILE" "$AWK_FILE"' EXIT

# Write awk program to a temp file so single quotes need no shell escaping
cat > "$AWK_FILE" << 'AWKEOF'
NR == 1 {
    for (i = 1; i <= NF; i++) {
        h = $i
        gsub(/[\r\n \t"]/, "", h)
        col[tolower(h)] = i
    }
    next
}

# Return SQL string literal for a text column, or NULL
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

# Return SQL numeric literal (handles European decimal comma), or NULL
function num(name,    v, idx) {
    if (!(name in col)) return "NULL"
    idx = col[name]
    v = $idx
    gsub(/\r/, "", v)
    gsub(/^[ \t]+|[ \t]+$/, "", v)
    gsub(/,/, ".", v)
    if (v == "" || v !~ /^[+-]?[0-9]*\.?[0-9]+$/) return "NULL"
    return v
}

# Return SQL integer literal, or NULL
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
    number = ("materialnumber" in col) ? $(col["materialnumber"]) : ""
    gsub(/\r/, "", number)
    gsub(/^[ \t]+|[ \t]+$/, "", number)
    if (number == "") next

    id_val  = iget("id")
    gsub(/'/, "''", number)

    base_cols = "number, group_id, cover_code, package_code, sequence, production_instruction," \
                " name_eng, length, width, thickness, density, pcs_in_pack, packs_in_package," \
                " cut_direction, layers, norm_waste, grinding_waste_ow, uom_id, category," \
                " direct_recycle_mode, comment," \
                " info_1, info_2, info_3, info_4, info_5, info_6," \
                " product_line_width, edge_trim_width, wet_edge_trim_width, wet_edge_trim_mode," \
                " mark, state"

    base_vals = "'" number "'," \
                iget("articlegroup") "," str("covercode") "," str("packingcode") "," \
                iget("sequencenumber") "," str("productioninstruction") "," \
                str("description") "," \
                num("length") "," num("width") "," num("thickness") "," num("density") "," \
                iget("pcspercolli") "," iget("collisperunit") "," \
                str("lengthdirection") "," iget("layers") "," num("normwaste") "," num("grindingwasteow") "," \
                "(SELECT id FROM uom WHERE code = " str("packaging") ")," str("storelocation") "," \
                iget("directrclmode") "," str("remark") "," \
                str("info1") "," str("info2") "," str("info3") "," str("info4") "," str("info5") "," str("info6") "," \
                num("productionlinewidth") "," num("edgetrimwidth") "," num("wetedgetrimwidth") "," num("wetedgetrimmode") "," \
                iget("mark") "," iget("state")

    if (id_val != "NULL") {
        ins_cols = "id, " base_cols
        ins_vals = id_val ", " base_vals
    } else {
        ins_cols = base_cols
        ins_vals = base_vals
    }

    conflict = (id_val != "NULL") ? "(id) DO UPDATE SET\n    number = EXCLUDED.number," : "(number) DO UPDATE SET"
    print "INSERT INTO products (" ins_cols ") VALUES (" ins_vals ")"
    print "ON CONFLICT " conflict
    print "    group_id              = EXCLUDED.group_id,"
    print "    cover_code            = EXCLUDED.cover_code,"
    print "    package_code          = EXCLUDED.package_code,"
    print "    sequence              = EXCLUDED.sequence,"
    print "    production_instruction= EXCLUDED.production_instruction,"
    print "    name_eng              = EXCLUDED.name_eng,"
    print "    length                = EXCLUDED.length,"
    print "    width                 = EXCLUDED.width,"
    print "    thickness             = EXCLUDED.thickness,"
    print "    density               = EXCLUDED.density,"
    print "    pcs_in_pack           = EXCLUDED.pcs_in_pack,"
    print "    packs_in_package      = EXCLUDED.packs_in_package,"
    print "    cut_direction         = EXCLUDED.cut_direction,"
    print "    layers                = EXCLUDED.layers,"
    print "    norm_waste            = EXCLUDED.norm_waste,"
    print "    grinding_waste_ow     = EXCLUDED.grinding_waste_ow,"
    print "    uom_id                = EXCLUDED.uom_id,"
    print "    category              = EXCLUDED.category,"
    print "    direct_recycle_mode   = EXCLUDED.direct_recycle_mode,"
    print "    comment               = EXCLUDED.comment,"
    print "    info_1                = EXCLUDED.info_1,"
    print "    info_2                = EXCLUDED.info_2,"
    print "    info_3                = EXCLUDED.info_3,"
    print "    info_4                = EXCLUDED.info_4,"
    print "    info_5                = EXCLUDED.info_5,"
    print "    info_6                = EXCLUDED.info_6,"
    print "    product_line_width    = EXCLUDED.product_line_width,"
    print "    edge_trim_width       = EXCLUDED.edge_trim_width,"
    print "    wet_edge_trim_width   = EXCLUDED.wet_edge_trim_width,"
    print "    wet_edge_trim_mode    = EXCLUDED.wet_edge_trim_mode,"
    print "    mark                  = EXCLUDED.mark,"
    print "    state                 = EXCLUDED.state;"
}
AWKEOF

awk -F"$DELIM" -f "$AWK_FILE" "$CSV_FILE" >> "$SQL_FILE"

# Reset sequence so new manual inserts don't collide with imported IDs
echo "SELECT setval('products_id_seq', COALESCE(MAX(id), 1)) FROM products;" >> "$SQL_FILE"

ROWS=$(grep -c '^INSERT INTO products' "$SQL_FILE" || true)
echo "Generated $ROWS insert statement(s) from $CSV_FILE"

docker exec -i postgres-db psql -U mesrwl -d mes < "$SQL_FILE"
