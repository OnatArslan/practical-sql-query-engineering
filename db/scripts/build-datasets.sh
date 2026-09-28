#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"
[[ $# -le 1 ]] || { echo 'Usage: build-datasets.sh [small|full]' >&2; exit 2; }
profiles=(small full)
if [[ $# -eq 1 ]]; then profile_check "$1"; profiles=("$1"); fi
lock_dataset
start_db
for profile in "${profiles[@]}"; do
    database="minicommerce_build_$profile"
    create_scratch "$database"
    psql_db "$database" --single-transaction -v profile="$profile" \
        -f /workspace/db/schema/00_schema.sql \
        -f /workspace/db/schema/01_constraints.sql \
        -f /workspace/db/seed/generate.sql \
        -f /workspace/db/schema/02_indexes.sql
    psql_db "$database" -c 'ANALYZE'
    "$ROOT/db/scripts/verify-dataset.sh" "$profile" "$database"
    # Publish only a verified complete custom-format archive; leave previous dump on failure.
    dump="$ROOT/db/seed/$profile.dump"
    "${DC[@]}" exec -T postgres pg_dump -U minicommerce -d "$database" \
        --format=custom --compress=6 --no-owner --no-acl > "$dump.tmp.$$"
    "${DC[@]}" exec -T postgres pg_restore --list < "$dump.tmp.$$" > /dev/null
    mv "$dump.tmp.$$" "$dump"
    (cd "$ROOT/db/seed" && shasum -a 256 "$profile.dump" > "$profile.dump.sha256")
    "$ROOT/db/scripts/fingerprint.sh" "$database" > "$ROOT/.local/$profile.generated.csv"
    psql_db minicommerce -c "DROP DATABASE $database WITH (FORCE)"
    echo "READY: $dump"
done
