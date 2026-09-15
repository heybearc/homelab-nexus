#!/usr/bin/env bash
# Copy M365 app credentials into homelab .env and redeploy ops-stack.
# You must still add delegated Calendars.Read + redirect URI in Entra — see documentation/OPS-HUB-M365-CALENDAR-OAUTH.md
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SSH_CONFIG="$ROOT/.cloudy-work/ssh_config_master.conf"
ENV_FILE="$ROOT/.env"
SOURCE="${M365_SOURCE_HOST:-cloudigan-api-blue}"
REMOTE_ENV="${M365_SOURCE_PATH:-/opt/cloudigan-api/.env}"

if [[ ! -f "$ENV_FILE" ]]; then
  cp "$ROOT/.env.example" "$ENV_FILE"
  echo "Created $ENV_FILE from .env.example — fill in other secrets as needed."
fi

echo "Reading M365_* from ${SOURCE}:${REMOTE_ENV}…"
REMOTE_VARS="$(ssh -F "$SSH_CONFIG" "$SOURCE" "grep '^M365_' '$REMOTE_ENV' | grep -v SMTP")"

touch "$ENV_FILE"
for key in M365_CLIENT_ID M365_TENANT_ID M365_CLIENT_SECRET M365_FROM_EMAIL; do
  val="$(echo "$REMOTE_VARS" | grep "^${key}=" | head -1 | cut -d= -f2- || true)"
  if [[ -z "$val" ]]; then
    echo "⚠ Missing $key on $SOURCE"
    continue
  fi
  if grep -q "^${key}=" "$ENV_FILE"; then
    sed -i.bak "s|^${key}=.*|${key}=${val}|" "$ENV_FILE"
  else
    echo "${key}=${val}" >> "$ENV_FILE"
  fi
done
rm -f "$ENV_FILE.bak"

if ! grep -q '^M365_CALENDAR_REDIRECT_URI=' "$ENV_FILE"; then
  echo "M365_CALENDAR_REDIRECT_URI=https://ops.cloudigan.net/api/auth/microsoft/callback" >> "$ENV_FILE"
fi
if ! grep -q '^OPS_SYNC_DATA=' "$ENV_FILE"; then
  echo "OPS_SYNC_DATA=/opt/ops-sync/data" >> "$ENV_FILE"
fi

echo ""
echo "✓ Updated $ENV_FILE with M365 credentials"
echo ""
echo "IMPORTANT — Entra portal (required before Connect works):"
echo "  1. App registration used by cloudigan-api is SINGLE-TENANT (Cloudigan only)."
echo "     For Thrive/Bethel/JW Pub, create a NEW multitenant app: Ops Hub Calendar"
echo "  2. Add redirect URI: https://ops.cloudigan.net/api/auth/microsoft/callback"
echo "  3. Add delegated permissions: Calendars.Read, User.Read"
echo "  4. Grant admin consent (Cloudigan)"
echo ""
read -r -p "Redeploy ops-stack now? [y/N] " ans
if [[ "${ans,,}" == "y" || "${ans,,}" == "yes" ]]; then
  "$ROOT/scripts/ops/bootstrap-ops-stack.sh"
fi
