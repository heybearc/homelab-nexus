#!/usr/bin/env bash
# Technitium DNS Server API helper
# Auth: TECHNITIUM_API_TOKEN (preferred), cached session token, or interactive password prompt.
# Password is NOT read from .env — set it in the Technitium UI.
#
# Usage:
#   ./technitium-api.sh login
#   ./technitium-api.sh add <hostname> <ip>
#   ./technitium-api.sh remove <hostname>
#   ./technitium-api.sh list
set -euo pipefail

TECHNITIUM_URL="${TECHNITIUM_URL:-http://10.92.3.10:5380}"
TECHNITIUM_USER="${TECHNITIUM_USER:-admin}"
TOKEN_FILE="${TOKEN_FILE:-${HOME}/.cache/technitium-token}"

login() {
  mkdir -p "$(dirname "$TOKEN_FILE")"
  local pass="${1:-}"
  if [[ -z "$pass" ]]; then
    read -r -s -p "Technitium password for ${TECHNITIUM_USER}@${TECHNITIUM_URL}: " pass
    echo >&2
  fi
  local resp token
  resp=$(curl -sS "${TECHNITIUM_URL}/api/user/login" \
    -d "user=${TECHNITIUM_USER}&pass=${pass}")
  token=$(echo "$resp" | python3 -c "import sys,json; print(json.load(sys.stdin).get('token',''))" 2>/dev/null || true)
  [[ -n "$token" ]] || { echo "Login failed: $resp" >&2; exit 1; }
  echo "$token" > "$TOKEN_FILE"
  chmod 600 "$TOKEN_FILE"
  echo "Logged in; token saved to $TOKEN_FILE"
}

token() {
  if [[ -n "${TECHNITIUM_API_TOKEN:-}" ]]; then
    echo "$TECHNITIUM_API_TOKEN"
    return 0
  fi
  if [[ -f "$TOKEN_FILE" ]]; then
    cat "$TOKEN_FILE"
    return 0
  fi
  login >/dev/null
  cat "$TOKEN_FILE"
}

add_record() {
  local hostname="$1" ip="$2"
  local fqdn="${hostname}.${DNS_ZONE}"
  local t; t=$(token)
  curl -sS "${TECHNITIUM_URL}/api/zones/records/add?token=${t}" \
    -d "domain=${fqdn}&type=A&value=${ip}" | python3 -m json.tool
}

remove_record() {
  local hostname="$1"
  local fqdn="${hostname}.${DNS_ZONE}"
  local t; t=$(token)
  curl -sS "${TECHNITIUM_URL}/api/zones/records/delete?token=${t}" \
    -d "domain=${fqdn}&type=A" | python3 -m json.tool
}

list_zone() {
  local t; t=$(token)
  curl -sS "${TECHNITIUM_URL}/api/zones/records/get?token=${t}&domain=${DNS_ZONE}&listZone=true" \
    | python3 -c "import sys,json; d=json.load(sys.stdin); print(json.dumps(d, indent=2)[:4000])" 2>/dev/null || true
}

DNS_ZONE="${DNS_ZONE:-cloudigan.net}"

cmd="${1:-}"
shift || true
case "$cmd" in
  login) login "${1:-}" ;;
  add) add_record "$1" "$2" ;;
  remove) remove_record "$1" ;;
  list) list_zone ;;
  token) token ;;
  *)
    echo "Usage: $0 login|token|add|remove|list"
    exit 1
    ;;
esac
