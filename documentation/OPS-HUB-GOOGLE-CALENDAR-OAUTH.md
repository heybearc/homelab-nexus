# Ops Hub — Google Calendar OAuth

Connect personal Gmail calendars to Ops Hub. Read-only; all calendars visible to the signed-in Google account are synced.

## 1. Create Google Cloud OAuth client

1. Open [Google Cloud Console](https://console.cloud.google.com/)
2. Create or select a project (e.g. **Ops Hub**)
3. **APIs & Services** → **Library** → enable **Google Calendar API**
4. **APIs & Services** → **OAuth consent screen**
   - User type: **External** (personal Gmail) or **Internal** (Workspace only)
   - App name: `Ops Hub Calendar`
   - Support email: your address
   - Scopes → add: `.../auth/calendar.readonly`, `.../auth/calendar.events.owned`, `email`, `profile`, `openid`
   - Test users: add every Gmail address you will connect (required while app is in Testing)
5. **APIs & Services** → **Credentials** → **Create credentials** → **OAuth client ID**
   - Application type: **Web application**
   - Name: `Ops Hub`
   - Authorized redirect URIs:
     ```
     https://ops.cloudigan.net/api/auth/google/callback
     ```
6. Copy **Client ID** and **Client secret**

## 2. Homelab `.env`

```bash
GOOGLE_CLIENT_ID=<client-id>.apps.googleusercontent.com
GOOGLE_CLIENT_SECRET=<client-secret>
GOOGLE_CALENDAR_REDIRECT_URI=https://ops.cloudigan.net/api/auth/google/callback
```

Redeploy:

```bash
./scripts/ops/bootstrap-ops-stack.sh
```

## 3. Connect

1. Open https://ops.cloudigan.net
2. **Google calendars** → **Connect Google**
3. Sign in with the Gmail account
4. Grant calendar read access

Repeat for each personal Gmail account. Tokens live in `ops-sync/data/google-accounts.json` (not in git).

## Troubleshooting

| Error | Fix |
|-------|-----|
| `redirect_uri_mismatch` | Redirect URI in Google Cloud must match exactly |
| `access_denied` / app not verified | Add your email under **Test users** on the consent screen |
| No refresh token | Revoke Ops Hub in [Google Account → Third-party access](https://myaccount.google.com/permissions), then Connect again |
| Connected but no events | `pm2 logs ops-sync` on ops-stack; confirm Calendar API is enabled |

## Publishing (optional)

While status is **Testing**, only listed test users can connect. For unlimited personal use, submit for verification — or keep Testing and add each Gmail as a test user.
