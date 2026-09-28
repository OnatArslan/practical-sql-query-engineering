#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DC=(docker compose --project-directory "$ROOT" -f "$ROOT/compose.yaml")
export LC_ALL=C
profile_check() {
    case "${1:-}" in small|full) ;; *) echo 'Usage: small|full' >&2; exit 2;; esac
}
db_check() {
    case "$1" in minicommerce|minicommerce_build_small|minicommerce_build_full|minicommerce_restore_small|minicommerce_restore_full) ;;
        *) echo "Refusing database outside this workspace: $1" >&2; exit 2;; esac
}
psql_db() {
    local database="$1"; shift
    db_check "$database"
    "${DC[@]}" exec -T postgres psql -X -v ON_ERROR_STOP=1 -U minicommerce -d "$database" "$@"
}
start_db() { "${DC[@]}" up -d --wait postgres; }
lock_dataset() {
    mkdir -p "$ROOT/.local"
    if ! mkdir "$ROOT/.local/dataset.lock" 2>/dev/null; then
        echo 'Another dataset operation is active. If it crashed, remove .local/dataset.lock after checking.' >&2
        exit 1
    fi
    trap 'rmdir "$ROOT/.local/dataset.lock"' EXIT
}
create_scratch() {
    local database="$1"
    db_check "$database"
    [[ "$database" != minicommerce ]] || return 2
    psql_db minicommerce -c "DROP DATABASE IF EXISTS $database WITH (FORCE)" \
        -c "CREATE DATABASE $database TEMPLATE template0 ENCODING 'UTF8' LC_COLLATE 'C' LC_CTYPE 'C'"
}
