# Chapter Hub — production blue-green

**Product:** Chapter Hub (BNI chapters)  
**URL:** https://hub.cloudigan.net  
**MCP app:** `chapter-hub`  
**Repo:** https://github.com/heybearc/chapter-hub.git → `/opt/chapter-hub`  
**Sandbox (decommissioned):** CT119 @ `10.92.3.12` — `chapter-hub-dev` (PM2 stopped; Ansible seed only)

---

## Infrastructure

| Role | Hostname | CTID | IP | PM2 (D-025) |
|------|----------|------|-----|-------------|
| BLUE | chapter-hub-blue | 193 | 10.92.3.96 | `chapter-hub-blue` |
| GREEN | chapter-hub-green | 194 | 10.92.3.97 | `chapter-hub-green` |

- **Subnet:** `10.92.3.0/24`, bridge `vmbr0923`, gateway `10.92.3.1` (D-020)
- **Postgres:** `10.92.3.21` — DB `chapter_hub`, user `chapter_hub` (credentials in Cloudy-Work `DATABASE-CREDENTIALS.md` / `chapter-hub.md`, not git)
- **HAProxy:** VIP `10.92.3.33` (CT136) — ACL `is_chapter_hub`, backends `chapter-hub-blue` / `chapter-hub-green`
- **Legacy:** `is_bnitoolkit` removed 2026-05-22

---

## Ansible deploy

```bash
cd /Users/cory/Projects/homelab-nexus
source .env   # NETBOX_TOKEN, CHAPTER_HUB_DB_PASSWORD
cd ansible
ansible-playbook playbooks/deploy-chapter-hub-containers.yml
```

Post-build on each node:

```bash
curl -sI http://127.0.0.1:3001/api/auth/providers
pm2 list   # chapter-hub-blue OR chapter-hub-green
```

---

## Release workflow (MCP)

1. `get_deployment_status(app: "chapter-hub")` — confirm LIVE/STANDBY via HAProxy
2. `deploy_to_standby(app: "chapter-hub", pullGithub: true, runMigrations: true, createBackup: true)`
3. Smoke test STANDBY: `https://blue-hub.cloudigan.net` or `https://green-hub.cloudigan.net` (after DNS/NPM)
4. `switch_traffic(app: "chapter-hub", requireApproval: false)` after operator approval
5. Confirm `https://hub.cloudigan.net/api/auth/providers` → 200 on LIVE

**Do not** auto-sync STANDBY → LIVE without explicit approval.

---

## NPM

Add or update proxy host **hub.cloudigan.net** → HAProxy VIP `10.92.3.33:80` (SSL as for other `*.cloudigan.net` apps).

---

## Rollback

1. `switch_traffic(app: "chapter-hub", emergency: true)` to previous color, or
2. `switch_traffic` to previous color, or point HAProxy `is_chapter_hub` at the known-good backend manually
3. `pm2 restart` on known-good node; restore DB from `/mnt/data/chapter-hub-backups/database/manual` if migration failed

---

## Migrations

On deploy: `npx prisma generate` then `npx prisma migrate deploy` (never `db push` in prod).

If `_prisma_migrations` has a failed/rolled-back row, resolve per chapter-hub runbook before re-running migrate.

---

## Password rotation

1. `ALTER ROLE chapter_hub PASSWORD '...'` on `postgres`
2. `/opt/chapter-hub/.env` on blue, green, sandbox
3. Cloudy-Work `DATABASE-CREDENTIALS.md` and `chapter-hub.md`

---

## Handoff checklist

- [x] MCP `server.js` → `chapter-hub` (`isSandbox: false`, IPs, PM2 names)
- [x] SSH: `chapter-hub-blue`, `chapter-hub-green` in `ssh_config_master.conf`
- [x] NPM `hub.cloudigan.net`
- [x] Public DNS → NPM
- [x] Remove `is_bnitoolkit` when sandbox decommissioned (2026-05-22)
- [x] Update chapter-hub `docs/deployment/RENAME-CHECKLIST.md` homelab-nexus section
