#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"

usage() {
    cat <<'HELP'
Usage: seed.sh [small|full]

Rebuild and verify both datasets from schema + SQL seed sources, then restore
the selected dataset into minicommerce (default: small).
This replaces existing course data and disconnects its database clients.
For a quick reset using existing dumps, use reset-small.sh or reset-full.sh.
HELP
}

[[ $# -le 1 ]] || { usage >&2; exit 2; }
case "${1:-small}" in
    -h|--help) usage; exit 0 ;;
    small|full) profile="${1:-small}" ;;
    *) usage >&2; exit 2 ;;
esac

echo 'Building small and full datasets from the repository SQL sources...'
"$ROOT/db/scripts/build-datasets.sh"
echo "Restoring and verifying minicommerce ($profile)..."
exec "$ROOT/db/scripts/restore-dataset.sh" "$profile"
