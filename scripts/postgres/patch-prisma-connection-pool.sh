#!/usr/bin/env bash
# Patch DATABASE_URL in a .env file with Prisma pool limits (idempotent).
# Usage: patch-prisma-connection-pool.sh /path/to/.env [connection_limit] [pool_timeout]
set -euo pipefail

ENV_FILE="${1:?env file path required}"
LIMIT="${2:-5}"
TIMEOUT="${3:-10}"

python3 - "$ENV_FILE" "$LIMIT" "$TIMEOUT" <<'PY'
import re
import sys
from pathlib import Path

path = Path(sys.argv[1])
limit = sys.argv[2]
timeout = sys.argv[3]
text = path.read_text()
lines = text.splitlines(keepends=True)
out = []
patched = False

for line in lines:
    m = re.match(r'^(\s*DATABASE_URL\s*=\s*)(["\']?)(.+?)\2\s*$', line.rstrip('\n'))
    if not m:
        out.append(line)
        continue
    prefix, quote, url = m.group(1), m.group(2) or '', m.group(3)
    if 'connection_limit=' in url:
        url = re.sub(r'connection_limit=\d+', f'connection_limit={limit}', url)
    else:
        sep = '&' if '?' in url else '?'
        url = f'{url}{sep}connection_limit={limit}'
    if 'pool_timeout=' in url:
        url = re.sub(r'pool_timeout=\d+', f'pool_timeout={timeout}', url)
    elif 'connection_limit=' in url:
        url = f'{url}&pool_timeout={timeout}'
    out.append(f'{prefix}{quote}{url}{quote}\n')
    patched = True

if not patched:
    sys.exit(2)
path.write_text(''.join(out))
print(f'patched {path}')
PY
