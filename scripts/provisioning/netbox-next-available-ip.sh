#!/bin/bash
# Find next available IP(s) in a Netbox-managed prefix (default 10.92.3.0/24).
#
# Usage:
#   netbox-next-available-ip.sh [--count N] [--prefix CIDR] [--start-host N]
#
# Requires: NETBOX_TOKEN, optional NETBOX_URL (default http://10.92.3.18)
# Outputs: one IP per line (no CIDR suffix)

set -euo pipefail

COUNT=1
PREFIX="10.92.3.0/24"
START_HOST=4

while [[ $# -gt 0 ]]; do
  case "$1" in
    --count) COUNT="$2"; shift 2 ;;
    --prefix) PREFIX="$2"; shift 2 ;;
    --start-host) START_HOST="$2"; shift 2 ;;
    -h|--help)
      sed -n '2,8p' "$0"
      exit 0
      ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

NETBOX_URL="${NETBOX_URL:-http://10.92.3.18}"
NETBOX_TOKEN="${NETBOX_TOKEN:-}"

if [[ -z "$NETBOX_TOKEN" ]]; then
  echo "ERROR: NETBOX_TOKEN not set" >&2
  exit 1
fi

PREFIX_IP="${PREFIX%%/*}"
IFS='.' read -r _O1 _O2 _O3 _O4 <<< "$PREFIX_IP"
BASE="${_O1}.${_O2}.${_O3}"

RESERVED=(
  "${BASE}.0"
  "${BASE}.1"
  "${BASE}.2"
  "${BASE}.3"
  "${BASE}.10"
  "${BASE}.11"
  "${BASE}.33"
)

USED="$(
  curl -sS -H "Authorization: Token ${NETBOX_TOKEN}" \
    "${NETBOX_URL}/api/ipam/ip-addresses/?limit=500" \
  | jq -r --arg base "$BASE" '.results[].address | split("/")[0] | select(startswith($base + "."))'
)"

is_used() {
  local ip="$1"
  echo "$USED" | grep -qx "$ip" && return 0
  for r in "${RESERVED[@]}"; do
    [[ "$ip" == "$r" ]] && return 0
  done
  return 1
}

found=0
for ((host=START_HOST; host < 254 && found < COUNT; host++)); do
  ip="${BASE}.${host}"
  if ! is_used "$ip"; then
    echo "$ip"
    found=$((found + 1))
  fi
done

if [[ "$found" -lt "$COUNT" ]]; then
  echo "ERROR: only found ${found}/${COUNT} free addresses in ${PREFIX}" >&2
  exit 1
fi
