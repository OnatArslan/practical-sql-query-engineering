#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"
database="${1:-minicommerce}"
psql_db "$database" -q -f /workspace/db/scripts/fingerprint.sql
