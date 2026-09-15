# Ops Hub Deployment

Self-hosted productivity stack: unified calendar view, Vikunja task pane, Kimai timer, n8n routing, ntfy push.

## Architecture

| Component | Role | URL |
|-----------|------|-----|
| **ops-hub** | Next.js UI — capture, tasks, calendar, timer | https://ops.cloudigan.net |
| **ops-sync** | Calendar worker — ICS/Google/Graph, conflict detection | internal :3002 |
| **ntfy** | Push notifications (morning briefing) | https://push.cloudigan.net |
| **n8n** | Workflow router (already deployed CT188) | https://flows.cloudigan.net |
| **Vikunja** | Task source of truth | https://tasks.cloudigan.net |
| **Kimai** | Time source of truth | https://time.cloudigan.net |

## n8n Workflows (deployed)

Deploy/update:

```bash
cd homelab-nexus
set -a && source .env && set +a
export N8N_API_URL=http://10.92.3.79:5678/api/v1
python3 scripts/ops/deploy-ops-workflows.py
```

| Workflow | ID | Webhook |
|----------|-----|---------|
| Zammad → Vikunja (updated) | `6mcHbtq1wHF8dzBe` | `zammad-ticket` |
| Vikunja → Zammad close | `BvTrGaq18B4XcgOX` | `vikunja-task-updated` |
| Zammad → Vikunja complete | `tk2rGL5ttv6To0TN` | `zammad-ticket-closed` |
| Quick capture router | `O4y0efTXpBbDOYBu` | `ops-capture` |
| Morning briefing (7am ET) | `HmflegdeD6sDRASh` | cron → `ops-sync /briefing/text` |
| Time gaps → Vikunja (17:30 / 07:05 ET) | `Aa7Oj9ujBWl7xa0b` | cron → `ops-sync /timelog/tasks` |
| Bill reminders → Vikunja (06:00 ET) | `2UYWa3ZKvVmrP71e` | cron → `ops-sync /bills/generate` |
| Kimai timer | `qdJXsB2eBjY3UYp2` | `ops-kimai-timer` |

Briefing, time-gap, and bill logic: see [OPS-HUB-TIME-BILLS-BRIEFING.md](OPS-HUB-TIME-BILLS-BRIEFING.md).

### Zammad ↔ Vikunja sync

When you **complete a Vikunja task** linked to a Zammad ticket, n8n closes the ticket automatically.

When a ticket is **closed in Zammad**, n8n marks the matching Vikunja Inbox task done.

Configure Zammad close trigger:

```bash
export ZAMMAD_API_TOKEN=your-token
./scripts/ops/setup-zammad-close-trigger.sh
```

## Branding

Uses Cloudigan brand colors (`#2d388a` → `#00aeef` gradient) and the gear + `</>` cog mark from `files/Logos/`.

| Asset | Path |
|-------|------|
| Favicon (SVG) | `ops-hub/app/icon.svg`, `ops-hub/public/icon.svg` |
| Favicon (ICO) | `ops-hub/public/favicon.ico` (from Cloudigan browser.ico) |
| Apple touch | `ops-hub/public/apple-icon.png` |
| Header mark | `ops-hub/components/BrandMark.tsx` |

## Bootstrap homelab stack

**Preferred (playbook):** Netbox + Technitium DNS + NPM per homelab standard:

```bash
cd homelab-nexus && set -a && source .env && set +a
cd ansible && ansible-playbook playbooks/deploy-ops-stack.yml
```

**Initial container** (if CT202 does not exist):

```bash
chmod +x scripts/ops/bootstrap-ops-stack.sh
./scripts/ops/bootstrap-ops-stack.sh
# then re-run ansible-playbook deploy-ops-stack.yml
```

Creates **CT202** `ops-stack` @ **10.92.3.83** with ops-hub, ops-sync, ntfy.

Post-bootstrap (manual):

1. **NPM** — `ops.cloudigan.net` → `10.92.3.83:3001`, `push.cloudigan.net` → `10.92.3.83:8080`
2. **Technitium** — A records → NPM VIP `10.92.3.3`
3. **ntfy app** (iPhone/Mac) — subscribe to topic `cory-daily-briefing` at `https://push.cloudigan.net`

## Environment variables

Copy from `.env.example`:

- `VIKUNJA_API_URL` / `VIKUNJA_API_TOKEN`
- `KIMAI_API_USER` / `KIMAI_API_TOKEN` — create at https://time.cloudigan.net → Profile → API
- `ZAMMAD_API_TOKEN` — for close trigger script
- `NTFY_TOPIC=cory-daily-briefing`

## Calendar feeds (ops-sync)

Edit `ops-sync/feeds.json` on the server (or locally before rsync):

### Thrive (secular work)

1. Log into Thrive on web
2. Settings → Calendar / Integrations → **Export calendar** or **ICS subscription URL**
3. Copy the `https://…` URL (often ends in `.ics`)
4. Set in `feeds.json`:

```json
{
  "name": "Thrive (secular work)",
  "url": "PASTE_ICS_URL_HERE",
  "lifeArea": "thrive",
  "enabled": true
}
```

### Congregation / theocratic

Sources (pick what you use):

- **JW Library** app → Settings → Calendar → subscribe link (if available)
- **Congregation** shared calendar ICS from your secretary/elder
- **Bethel** / regional theocratic events ICS if provided

```json
{
  "name": "Congregation",
  "url": "PASTE_ICS_URL_HERE",
  "lifeArea": "theocratic",
  "enabled": true
}
```

### Google (all personal calendars)

Per-account OAuth from the Ops Hub UI (**Connect Google**) — see [OPS-HUB-GOOGLE-CALENDAR-OAUTH.md](OPS-HUB-GOOGLE-CALENDAR-OAUTH.md). Tokens live in `/opt/ops-sync/data/google-accounts.json` (excluded from deploy rsync).

### Microsoft 365 / Entra calendars

Per-account OAuth from the Ops Hub UI (**Connect Cloudigan / Thrive / Bethel / JW Pub**) — see [OPS-HUB-M365-CALENDAR-OAUTH.md](OPS-HUB-M365-CALENDAR-OAUTH.md).

## Apple Calendar subscription

After ops-sync runs, subscribe on iPhone/Mac:

```
https://ops.cloudigan.net/api/calendar/ics
```

(or direct: `http://10.92.3.83:3002/merged.ics` at home)

## Quick capture from Ops Hub

Pick destinations in the UI:

- **Vikunja task** — via n8n capture router
- **Personal Google calendar** — direct Google API; pick account + calendar, duration, invitees
- **Cloudigan / Entra calendar** — direct Microsoft Graph; invitees supported
- **Kimai time block** — via n8n capture router

## Remaining setup

1. **Thrive / Bethel** — reconnect from Ops Hub once tenant admin consent is granted
2. **JW Pub** — retry connect; capture the error text if it fails again
3. **Bills** — fill `ops-sync/bills.json`, set `enabled: true`, redeploy
4. **LLM headline** (optional) — add a key per [OPS-HUB-TIME-BILLS-BRIEFING.md](OPS-HUB-TIME-BILLS-BRIEFING.md)
5. **Kimai projects** for Renvis, Summit, LeadIQ, Nil Doctor, Kelly's Angels, Stack Construction — until then their time logs to `Cloudy - General Work`
