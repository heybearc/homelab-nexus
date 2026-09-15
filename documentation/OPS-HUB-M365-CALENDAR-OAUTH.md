# Ops Hub — Microsoft Calendar OAuth (delegated)

Use a **separate** Entra app from the cloudigan-api mail daemon. That app uses **application** permissions (`Mail.Send`); calendar sync needs **delegated** `Calendars.Read` with user sign-in.

## 1. Register app (Cloudigan tenant)

1. [Azure Portal](https://portal.azure.com) → **Entra ID** → **App registrations** → **New registration**
2. **Name:** `Ops Hub Calendar`
3. **Supported account types:** **Accounts in any organizational directory** (multitenant)
4. **Redirect URI:** Web → `https://ops.cloudigan.net/api/auth/microsoft/callback`
5. Register

Copy **Application (client) ID** and **Directory (tenant) ID**.

## 2. Client secret

**Certificates & secrets** → **New client secret** → copy value immediately.

## 3. API permissions (delegated)

**API permissions** → **Add permission** → **Microsoft Graph** → **Delegated permissions**:

| Permission | Purpose |
|------------|---------|
| `Calendars.ReadWrite` | Read + create/edit calendar events (capture) |
| `User.Read` | Identify signed-in account |
| `offline_access` | Refresh token (added automatically with openid) |
| `openid`, `profile` | Sign-in |

**Grant admin consent** for Cloudigan (green check for your org).

Other tenants (Thrive, Bethel, JW Pub) require **user consent** on first sign-in — works only if that org allows it.

## 4. Homelab `.env`

```bash
M365_CLIENT_ID=<ops-hub-calendar-app-client-id>
M365_TENANT_ID=<cloudigan-tenant-id>
M365_CLIENT_SECRET=<secret>
M365_CALENDAR_REDIRECT_URI=https://ops.cloudigan.net/api/auth/microsoft/callback
OPS_SYNC_DATA=/opt/ops-sync/data
```

Redeploy: `./scripts/ops/bootstrap-ops-stack.sh`

## 5. Connect accounts

1. Open https://ops.cloudigan.net
2. **Microsoft calendars** → **Connect Thrive work** (or Cloudigan / Bethel / JW Pub)
3. Sign in with that org’s account (e.g. `callen@thrivenextgen.com`)
4. Accept consent if prompted

Tokens are stored in `ops-sync/data/microsoft-accounts.json` (not in git).

## Troubleshooting

| Error | Fix |
|-------|-----|
| `AADSTS65001` / admin consent required | Thrive IT must allow user consent or grant admin consent for the app |
| `AADSTS700016` app not found in tenant | Normal for multitenant — user must complete consent flow |
| `invalid_client` | Wrong secret or client ID in `.env` |
| `redirect_uri mismatch` | Redirect URI in Entra must match `M365_CALENDAR_REDIRECT_URI` exactly |
| Connected but no events | Check ops-sync logs: `pm2 logs ops-sync` |

## Thrive locked-down tenants

If Thrive blocks third-party apps entirely, OAuth will fail at consent. Fallback: Mac calendar bridge (not yet implemented) or subscribe Ops Hub ICS into Thrive Outlook (work calendar stays native in Outlook only).
