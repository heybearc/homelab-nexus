#!/bin/bash
# keepalived: 0 only when this node is a writable Postgres primary.
set -euo pipefail
pg_isready -q || exit 1
out="$(sudo -u postgres psql -tAc "SELECT pg_is_in_recovery();" 2>/dev/null || true)"
[ "$out" = "f" ]
