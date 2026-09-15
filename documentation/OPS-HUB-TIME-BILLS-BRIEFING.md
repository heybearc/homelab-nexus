# Ops Hub — Time Gaps, Bill Reminders, Briefing

Phase 2–4 of the Ops Hub plan. All logic lives in **ops-sync** in https://github.com/heybearc/ops-hub (`/opt/ops-sync` on CT 10.92.3.83); n8n workflows are thin schedulers that call ops-sync and push to ntfy.

| Feature | ops-sync endpoint | n8n workflow | Schedule (ET) |
|---|---|---|---|
| Morning briefing | `GET /briefing/text` | Ops Hub · Morning Briefing | 07:00 daily |
| Unlogged client time → Vikunja tasks | `POST /timelog/tasks` | Ops Hub · Time Gaps | 17:30 Mon–Fri (today) · 07:05 daily (yesterday) |
| Bill reminders → Vikunja tasks | `POST /bills/generate` | Ops Hub · Bill Reminders | 06:00 daily (idempotent) |
| Timer from timeline | `GET /timelog`, `/timelog/active` | Ops Hub · Kimai Timer (webhook) | on click |

Redeploy after edits:

```bash
cd homelab-nexus && set -a && source .env && set +a
bash scripts/ops/bootstrap-ops-stack.sh          # ops-sync + ops-hub
python3 scripts/ops/deploy-ops-workflows.py      # n8n
```

## 1. Kimai gap detection

`ops-sync/kimai.js` compares **calendar work blocks** against **Kimai timesheets** for a day.

- A *work block* is a timed event whose `lifeArea` is in `kimai-map.json → lifeAreas` (default `["cloudigan"]`), not matching `ignoreTitles` (lunch, focus, hold, OOO…), shorter than 12 h.
- Coverage = union of Kimai entries overlapping the block. `gap = scheduled − covered`.
- A block becomes a **gap** when `gap ≥ gapThresholdMinutes` (30) **and the block has ended**.
- `POST /timelog/tasks {date}` creates one Vikunja task per gap (label `timelog`, due next day 17:00), tracked in `data/timelog-tasks.json` so it never duplicates. Task body has a **prefilled Kimai link** (`/en/timesheet/create?begin=…&end=…&project=…`) and the calendar event link.
- n8n nudges ntfy **only when new tasks were created**.

### Mapping events → Kimai projects (`ops-sync/kimai-map.json`)

```json
"customers": { "Renvis": ["renvis"], "Highpoint Electric": ["highpoint", "high point"] }
```

- Aliases match event titles case-insensitively as whole words.
- Project prefixes are derived automatically: `HPE - General Work` → `HPE` matches case-sensitively (so "be careful" ≠ BudgetEase).
- Project chosen per customer: `projectOverrides[customer]` → first project containing `preferProjectContaining` ("General Work") → first project.
- Customer with **no Kimai project** (Renvis, Summit, LeadIQ…) → logged to `defaultProject` (`Cloudy - General Work`), customer name kept; the UI shows it as matched. Create the project in Kimai and it's picked up within 10 min (catalog cache).
- Unmatched Cloudigan events → `defaultProject`, shown with `?` in the UI.

Check a day by hand:

```bash
curl -s "http://10.92.3.83:3002/timelog?date=yesterday" | jq '.totals, .gaps[].title'
curl -s -X POST http://10.92.3.83:3002/timelog/tasks -d '{"date":"yesterday","createTasks":false}'   # dry run
```

## 2. Timer from the timeline

Events with a Kimai suggestion show **⏱ Start** in the Today card. It calls the existing n8n Kimai Timer webhook with `project`, `activity`, `description = event title`, so the entry lands on the right project. The header shows the running timer (customer — description · since · elapsed) with **Stop**; the event row gets a `tracking` badge.

The **Time today** card shows logged / scheduled / unlogged, gaps with **Log in Kimai** (prefilled), and today's entries.

Fixed in passing: the n8n Kimai node stamped times using the container's UTC clock as Eastern (entries were +4 h). It now formats in `America/New_York`.

## 3. Bill reminders (`ops-sync/bills.json`)

```json
{ "name": "Electric", "day": 15, "enabled": true, "autopay": false, "amount": "$140", "url": "https://…", "notes": "" }
```

- `day` clamps to month length; `months: [1,7]` for semi-annual, `[3]` yearly.
- `autopay: true` → task titled *Confirm autopay: …*, priority low.
- Tasks are created for **this month + next**, never for past due dates, deduped in `data/bills-created.json` (key `YYYY-MM|name`). Safe to run daily.
- Task project: `bills.json → projectId`, else `VIKUNJA_PROJECT_ID`, else 1 (Inbox). Label `bills`.
- Briefing includes **💳 Bills this week** (next 7 days).

All sample bills ship `enabled: false` — edit, set `enabled: true`, redeploy ops-sync (rsync copies the file).

## 4. Briefing composition (`ops-sync/briefing.js`)

`GET /briefing/text` returns `{ title, topic, priority, click, message, llm, structured }`. Sections: tasks (open / due today / overdue), bills this week, all-day, timed events (⚠ = in a conflict), cross-calendar conflicts (same-calendar overlaps counted only), Kimai yesterday (logged / scheduled / unlogged by customer) and week-to-date.

Priority 5 when there is a cross-calendar conflict, ≥ 1 h unlogged yesterday, or overdue tasks; else 4.

Query params: `?conflicts=all` (include same-calendar overlaps), `?llm=0` (skip LLM), `?test=1` (label as test).

### Optional LLM headline

Set one of these on the host `.env` and redeploy ops-sync; the briefing gets a 2–4 sentence prioritized summary above the lists. Unset = template only. Failures/timeouts fall back silently (`structured.llmError`).

| Provider | Env | Default model |
|---|---|---|
| Anthropic | `ANTHROPIC_API_KEY` | `claude-3-5-haiku-latest` |
| OpenAI | `OPENAI_API_KEY` (+ `OPENAI_BASE_URL` for compatible APIs) | `gpt-4o-mini` |
| Ollama (homelab) | `OLLAMA_URL=http://host:11434` | `llama3.1` |

`OPS_LLM_PROVIDER` forces one; `OPS_LLM_MODEL` overrides the model; `OPS_LLM_TIMEOUT_MS` (25000).

Test: `curl -s "http://10.92.3.83:3002/briefing/text?test=1" | jq -r .message`

## Vikunja note

Vikunja **v2.2** returns `400 Invalid model provided` for `GET /tasks/all`. Both ops-sync and ops-hub now walk `/projects` → `/projects/{id}/tasks?filter=done = false`. (Ops Hub's task list was empty before this.)

## 5. New Kimai project + onboarding tasks

From Ops Hub Quick capture → **New Kimai project**:

1. New or existing customer
2. Optional prefix + project name (default `PREFIX - General Work`)
3. Hours purchased → Kimai customer `timeBudget`
4. Optional second project `PREFIX - M365 Management`
5. ops-sync creates the Kimai records, a Vikunja project under **Cloudigan Clients** (id 3), and the seed tasks in `ops-sync/client-template.json`

n8n workflow **Ops Hub · New Client** (`POST https://flows.cloudigan.net/webhook/ops-new-client`) does the same for automations. Edit the template and redeploy ops-sync to change the default task list.

Calendar matching aliases are written to `/opt/ops-sync/data/kimai-map-extra.json` so the next deploy does not wipe them.

## 6. Hours remaining + quota alerts

Kimai customer **time budget** is the purchased pool (already set on BudgetEase, Cleveland Wrap, Fastener, etc.). ops-sync sums billable timesheets against it.

| Level | Default |
|---|---|
| warn | ≥ 80% used |
| critical | ≥ 95% used or ≤ 1h left |
| over | used ≥ purchased |

- **Hours remaining** card on Ops Hub
- Morning briefing lists clients that are warn/critical/over
- n8n **Ops Hub · Hours Quota** weekdays 08:00 → ntfy, snoozed 3 days per customer+level (`OPS_QUOTA_SNOOZE_DAYS`)

`GET /quotas` · `POST /quotas/alerts` (set `force: true` to ignore snooze).

## Files

| Path | Purpose |
|---|---|
| `ops-sync/kimai.js` | Kimai client, matcher, `analyzeDay` |
| `ops-sync/kimai-map.json` | Customer aliases, ignore list, defaults |
| `ops-sync/timelog.js` | Gap → Vikunja task, nudge text |
| `ops-sync/bills.js`, `bills.json` | Bill schedule → tasks |
| `ops-sync/briefing.js` | Briefing composer |
| `ops-sync/llm.js` | Anthropic / OpenAI / Ollama |
| `ops-sync/vikunja.js` | Vikunja client (create, list, labels) |
| `ops-sync/tz.js` | Timezone helpers |
| `ops-sync/onboard.js`, `client-template.json` | New Kimai project + Vikunja seed tasks |
| `ops-sync/quotas.js` | Hours-quota alerts / snooze |
| `ops-hub/app/api/timelog/route.ts` | Proxy for the Time card |
| `ops-hub/components/TodayTimeline.tsx` | Timeline with ⏱ Start/Stop |
| `scripts/ops/deploy-ops-workflows.py` | n8n: briefing, time gaps, bills, Kimai timer |

State on host (excluded from rsync): `/opt/ops-sync/data/{timelog-tasks,bills-created}.json`.
