#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"
[[ $# -eq 1 ]] || { echo 'Usage: restore-dataset.sh small|full' >&2; exit 2; }
profile_check "$1"
profile="$1"
dump="$ROOT/db/seed/$profile.dump"
[[ -f "$dump" && -f "$dump.sha256" ]] || { echo "Build first: db/scripts/build-datasets.sh $profile" >&2; exit 1; }
lock_dataset
(cd "$ROOT/db/seed" && shasum -a 256 -c "$profile.dump.sha256")
start_db
database="minicommerce_restore_$profile"
create_scratch "$database"
"${DC[@]}" exec -T postgres pg_restore -U minicommerce -d "$database" \
    --exit-on-error --single-transaction --no-owner --no-acl < "$dump"
psql_db "$database" -c 'ANALYZE'
"$ROOT/db/scripts/verify-dataset.sh" "$profile" "$database"
"$ROOT/db/scripts/fingerprint.sh" "$database" > "$ROOT/.local/$profile.restored.csv"
if [[ -f "$ROOT/db/seed/$profile.fingerprints.csv" ]]; then
    diff -u "$ROOT/db/seed/$profile.fingerprints.csv" "$ROOT/.local/$profile.restored.csv"
fi
# Cut over only after successful restore + assertions. This resets course mutations
# and disconnects existing clients of the dedicated minicommerce database.
"${DC[@]}" exec -T postgres psql -X -v ON_ERROR_STOP=1 -U minicommerce -d postgres \
    -c 'DROP DATABASE minicommerce WITH (FORCE)' \
    -c "ALTER DATABASE $database RENAME TO minicommerce"
"$ROOT/db/scripts/verify-dataset.sh" "$profile"
echo "RESTORED: minicommerce ($profile)"
