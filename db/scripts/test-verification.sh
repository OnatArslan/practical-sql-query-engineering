#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"
lock_dataset
start_db
database=minicommerce_restore_small
create_scratch "$database"
"${DC[@]}" exec -T postgres pg_restore -U minicommerce -d "$database" \
    --exit-on-error --single-transaction --no-owner --no-acl < "$ROOT/db/seed/small.dump"
psql_db "$database" -f /workspace/db/scripts/test-constraints.sql
"$ROOT/db/scripts/verify-dataset.sh" small "$database" > "$ROOT/.local/test-pristine.log" 2>&1
expect_failure() {
    local label="$1" message="$2"
    if "$ROOT/db/scripts/verify-dataset.sh" small "$database" > "$ROOT/.local/test-$label.log" 2>&1; then
        echo "FAIL: verification accepted $label" >&2; exit 1
    fi
    if ! rg_check "$message" "$ROOT/.local/test-$label.log"; then
        cat "$ROOT/.local/test-$label.log" >&2; exit 1
    fi
    echo "PASS: rejected $label"
}
# Use POSIX grep here: no host ripgrep installation is required by the workspace.
rg_check() { grep -F -- "$1" "$2" > /dev/null; }
psql_db "$database" -c 'UPDATE categories SET parent_id=33 WHERE id=1'
expect_failure category-cycle 'acyclic four-level hierarchy'
psql_db "$database" -c 'UPDATE categories SET parent_id=NULL WHERE id=1'
psql_db "$database" -c 'UPDATE inventory_movements SET quantity_delta=-9 WHERE id=2'
expect_failure missing-edge-case 'zero inventory net'
psql_db "$database" -c 'UPDATE inventory_movements SET quantity_delta=-10 WHERE id=2'
psql_db "$database" -c "UPDATE customers SET name='Changed value' WHERE id=1"
expect_failure changed-content 'customers,'
psql_db "$database" -c 'ALTER TABLE products DROP CONSTRAINT products_category_fk'
expect_failure missing-foreign-key 'validated constraints'
psql_db minicommerce -c "DROP DATABASE $database WITH (FORCE)"
echo 'PASS: constraint rejection and verification failure paths; course DB unchanged'
