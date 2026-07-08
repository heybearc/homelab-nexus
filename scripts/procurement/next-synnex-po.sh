#!/bin/bash
# Allocate the next TD Synnex purchase order number (atomic via Redis INCR).
#
# Format default: Cloud-PO-0020 (prefix + zero-padded sequence)
#
# Usage:
#   next-synnex-po.sh              # allocate and print next PO
#   next-synnex-po.sh --peek       # preview next PO without consuming
#   next-synnex-po.sh --set 19     # seed counter (last issued number)
#   next-synnex-po.sh --current    # show counter value only
#
# Environment:
#   REDIS_HOST          default 10.92.3.93
#   REDIS_PORT          default 6379
#   REDIS_PASSWORD      optional if REDIS_SSH_HOST is reachable (Bitwarden: redis-shared-homelab)
#   REDIS_SSH_HOST      default redis-shared — used when local redis-cli is missing
#   SYNNEX_PO_REDIS_KEY default synnex:po:counter
#   SYNNEX_PO_PREFIX    default Cloud-PO-
#   SYNNEX_PO_PAD       default 4

set -euo pipefail

REDIS_HOST="${REDIS_HOST:-10.92.3.93}"
REDIS_PORT="${REDIS_PORT:-6379}"
REDIS_PASSWORD="${REDIS_PASSWORD:-}"
REDIS_SSH_HOST="${REDIS_SSH_HOST:-redis-shared}"
REDIS_KEY="${SYNNEX_PO_REDIS_KEY:-synnex:po:counter}"
PO_PREFIX="${SYNNEX_PO_PREFIX:-Cloud-PO-}"
PO_PAD="${SYNNEX_PO_PAD:-4}"

MODE="allocate"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --peek) MODE="peek"; shift ;;
    --current) MODE="current"; shift ;;
    --set)
      MODE="set"
      SET_VALUE="${2:?--set requires a number (last issued PO sequence)}"
      shift 2
      ;;
    -h|--help)
      sed -n '2,18p' "$0"
      exit 0
      ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

if [[ -z "$REDIS_PASSWORD" ]] && command -v ssh >/dev/null 2>&1; then
  REDIS_PASSWORD="$(
    ssh -o BatchMode=yes -o ConnectTimeout=5 "$REDIS_SSH_HOST" \
      'grep -E "^requirepass" /etc/redis/redis.conf | awk "{print \$2}"' 2>/dev/null || true
  )"
fi

if [[ -z "$REDIS_PASSWORD" ]]; then
  echo "ERROR: REDIS_PASSWORD not set and could not read from ${REDIS_SSH_HOST}" >&2
  exit 1
fi

redis_cli() {
  if command -v redis-cli >/dev/null 2>&1; then
    redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" -a "$REDIS_PASSWORD" --no-auth-warning "$@"
  elif command -v ssh >/dev/null 2>&1; then
    ssh -o BatchMode=yes "$REDIS_SSH_HOST" \
      redis-cli -a "$REDIS_PASSWORD" --no-auth-warning "$@"
  else
    echo "ERROR: need redis-cli or ssh to ${REDIS_SSH_HOST}" >&2
    exit 1
  fi
}

format_po() {
  local num="$1"
  printf '%s%0*d\n' "$PO_PREFIX" "$PO_PAD" "$num"
}

case "$MODE" in
  set)
    redis_cli SET "$REDIS_KEY" "$SET_VALUE" >/dev/null
    echo "Seeded ${REDIS_KEY}=${SET_VALUE} (next allocation: $(format_po $((SET_VALUE + 1))))"
    ;;
  current)
    value="$(redis_cli GET "$REDIS_KEY")"
    if [[ -z "$value" || "$value" == "(nil)" ]]; then
      echo "Counter not initialized. Run: $0 --set 19"
      exit 1
    fi
    echo "$value"
    ;;
  peek)
    value="$(redis_cli GET "$REDIS_KEY")"
    if [[ -z "$value" || "$value" == "(nil)" ]]; then
      echo "ERROR: Counter not initialized. Run: $0 --set 19" >&2
      exit 1
    fi
    format_po $((value + 1))
    ;;
  allocate)
    if ! redis_cli EXISTS "$REDIS_KEY" | grep -q '^1$'; then
      echo "ERROR: Counter not initialized. Run: $0 --set 19" >&2
      exit 1
    fi
    next="$(redis_cli INCR "$REDIS_KEY")"
    format_po "$next"
    ;;
esac
