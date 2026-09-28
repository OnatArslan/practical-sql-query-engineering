#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"
[[ $# -le 2 ]] || { echo 'Usage: verify-dataset.sh [small|full] [database]' >&2; exit 2; }
profile="${1:-small}"
database="${2:-minicommerce}"
profile_check "$profile"
# Keep the human manifest and machine row-count contract in sync.
column=3
[[ "$profile" != full ]] || column=4
diff -u \
    <(awk -F, -v p="$profile" '$1==p {print}' "$ROOT/db/seed/expected-counts.csv") \
    <(awk -F'|' -v p="$profile" -v c="$column" '
        {name=$2; count=$c; gsub(/[[:space:]]/, "", name); gsub(/[[:space:]]/, "", count)}
        name ~ /^(customers|categories|products|orders|order_items|payments|shipments|order_status_history|inventory_movements)$/ && count ~ /^[0-9]+$/ {print p "," name "," count}
    ' "$ROOT/docs/DATASET_MANIFEST.md")
psql_db "$database" -q -v profile="$profile" -f /workspace/db/scripts/verify.sql
if [[ -f "$ROOT/db/seed/$profile.fingerprints.csv" ]]; then
    actual="$(mktemp)"
    trap 'rm -f "$actual"' EXIT
    "$ROOT/db/scripts/fingerprint.sh" "$database" > "$actual"
    diff -u "$ROOT/db/seed/$profile.fingerprints.csv" "$actual"
    echo 'PASS: canonical content fingerprints (all rows, all columns)'
fi
echo "PASS: $profile dataset in $database"
