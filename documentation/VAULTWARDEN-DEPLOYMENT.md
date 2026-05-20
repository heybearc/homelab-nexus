# Vaultwarden LXC Deployment (Proxmox HA pair)

**Status:** CT171/172 deployed — BLUE active, GREEN standby staged; HAProxy + NPM configured (2026-05-16)  
**Decision:** D-HOMELAB-004 (active/passive, not dual writers)  
**Date:** 2026-05-16

---

## Architecture

| Role | Host | CTID | IP (planned) | Notes |
|------|------|------|--------------|--------|
| **BLUE** | `vaultwarden-blue` | 171 | Netbox next free (e.g. `10.92.3.94`) | Proxmox LXC, `hdd-pool`, `vmbr0923` |
| **GREEN** | `vaultwarden-green` | 172 | Netbox next free (e.g. `10.92.3.95`) | Standby peer for HAProxy `backup` |
| **Homelab (separate)** | TrueNAS app | — | `10.92.5.200:8080` | Personal use only — **not** in MSP HAProxy pool |
| **Public URL** | NPM → HAProxy VIP | — | `https://vault.cloudigan.com` | Customer MSP product |

**Resources per LXC:** 2 vCPU, 2048 MB RAM, 10 GB disk  
**Database:** PostgreSQL on CT131 (`vaultwarden` / `vaultwarden` user)  
**SSH:** `homelab_root` via playbook + `ssh_config_master.conf` aliases

---

## Ansible layout

| Component | Location |
|-----------|----------|
| **Wrapper playbook** | `homelab-nexus/ansible/playbooks/deploy-vaultwarden-containers.yml` |
| **Shared deploy** | `ansible-playbooks/playbooks/deploy-proxmox-container.yml` |
| **Netbox IP script** | `homelab-nexus/scripts/provisioning/netbox-next-available-ip.sh` |
| **Full Netbox IPAM** | `ansible/playbooks/tasks/netbox-register-container.yml` |
| **Vaultwarden + Docker** | `ansible/playbooks/tasks/configure-vaultwarden-node.yml` |
| **Postgres DB** | `ansible/playbooks/tasks/create-vaultwarden-database.yml` |

---

## Prerequisites

1. Repos side by side:
   - `/Users/cory/Projects/homelab-nexus`
   - `/Users/cory/Projects/ansible-playbooks`
2. Copy and fill `homelab-nexus/.env` (minimum):

```bash
NETBOX_URL=http://10.92.3.18
NETBOX_TOKEN=...
VAULTWARDEN_DB_PASSWORD=...   # strong password; also used in DATABASE_URL
```

3. SSH: `ssh prox` and `ssh postgresql` work with `homelab_root`.

---

## Deploy

```bash
cd /Users/cory/Projects/homelab-nexus
source .env

# Optional: preview next IPs only
./scripts/provisioning/netbox-next-available-ip.sh --count 2 --start-host 94

# Full deployment
cd ansible
ansible-playbook playbooks/deploy-vaultwarden-containers.yml
```

**What the playbook does**

1. Queries Netbox for two free `10.92.3.x` addresses (starting at `.94` by default).
2. Creates CT171 + CT172 via **deploy-proxmox-container.yml** (DNS, monitoring, backups, SSH key).
3. Registers VM + eth0 + IP + primary IP in **Netbox** (complete IPAM).
4. Creates `vaultwarden` database on CT131.
5. Installs Docker + Vaultwarden (`vaultwarden/server:1.34.3`) on both LXCs.
6. **Starts Vaultwarden only on BLUE** (standby GREEN has compose staged but not running — D-HOMELAB-004).
7. Verifies SSH and `/alive` on BLUE port 8080.

**Skip database creation** (if already exists):

```bash
ansible-playbook playbooks/deploy-vaultwarden-containers.yml -e vaultwarden_skip_db=true
```

---

## Post-deploy checklist

- [x] Confirm Netbox: two VMs, IPs (green registered via `vaultwarden-finish.yml`)
- [x] `ssh_config_master.conf` entries for CT171/172
- [ ] Update `documentation/PROXMOX-INVENTORY-*.md` after deploy
- [x] HAProxy: primary TrueNAS `10.92.5.200:8080`, backup blue/green LXCs, `GET /alive`
- [x] NPM: `vault.cloudigan.com` → VIP `10.92.3.33` (proxy host ID 107)
- [ ] Public DNS A record `vault.cloudigan.com` → `174.104.207.3` (manual); re-request Let's Encrypt in NPM if cert pending
- [ ] Proxmox backup jobs (auto via shared playbook → `truenas-backups`)

---

## SSH config (add after deploy)

```sshconfig
# Vaultwarden HA LXCs (CT171/172) — update HostName if Netbox assigns different IPs
Host vaultwarden-blue vault-blue
    HostName 10.92.3.94
    User root
    IdentityFile ~/.ssh/homelab_root
    IdentitiesOnly yes

Host vaultwarden-green vault-green
    HostName 10.92.3.95
    User root
    IdentityFile ~/.ssh/homelab_root
    IdentitiesOnly yes
```

---

## Verification

```bash
curl -sS "http://$(ssh -F .cloudy-work/ssh_config_master.conf vaultwarden-blue hostname -I 2>/dev/null || echo 10.92.3.94):8080/alive"
ssh -F .cloudy-work/ssh_config_master.conf vaultwarden-blue "docker ps"
```

---

## MSP product model (not a cutover)

This stack is a **new customer-facing instance** on CT171/172. The homelab TrueNAS Vaultwarden at `10.92.5.200` stays separate (different data, different users). HAProxy sends `vault.cloudigan.com` to **BLUE** with **GREEN** as `backup` only.

**Subscription billing** lives outside Vaultwarden (e.g. Stripe + your portal). Vaultwarden does not enforce paid seats; you gate access via **invites**, **org membership**, or automation after payment webhooks.

---

## White-label checklist (server-side)

Bitwarden **mobile/desktop/browser extensions** keep Bitwarden branding; customers still install official Bitwarden clients pointed at your server URL.

| Area | Vaultwarden lever | Notes |
|------|-------------------|--------|
| **Server URL** | `DOMAIN=https://vault.cloudigan.com` | Must match what users type in the app |
| **Web vault UI** | `WEB_VAULT_FOLDER` volume mount | Custom build or themed static assets (advanced) |
| **Email** | `SMTP_*`, `SMTP_FROM`, `SMTP_FROM_NAME` | Invites, verify email, org notices — use Cloudigan domain |
| **Email templates** | `TEMPLATES_FOLDER` | HTML/text for invite, 2FA, etc. |
| **Icons** | `ICON_SERVICE`, `ICON_CACHE_TTL` | Favicon/attachment icons in vault |
| **Admin** | `ADMIN_TOKEN` | `/admin` — orgs, users, policies, disable signups |
| **Access policy** | `SIGNUPS_ALLOWED=false`, `INVITATIONS_ALLOWED=true` | Typical MSP: invite-only or org-only |
| **Orgs / teams** | Admin UI + `ORG_*` env | Sell seats per org; families plan = org type |
| **Legal / trust** | NPM TLS cert, privacy page link | Link from invite emails or custom web vault |

**Branding assets:** use `files/Logos/` (Cloudigan SVG/PNG) for web vault, email headers, and favicon packs.

**Next implementation steps:** extend `vaultwarden-docker-compose.yml.j2` with SMTP + template mounts; store secrets in `.env` (`VAULTWARDEN_SMTP_*`, `ADMIN_TOKEN`); optional Ansible task to sync branded `templates/` and `web-vault/` to `/opt/vaultwarden/`.

---

## Related

- **`documentation/CLOUDIGAN-VAULT-PRODUCT.md`** — pricing, Stripe/API plan, session resume checklist
- `TASK-STATE.md` — Vaultwarden HA plan phases 0–5 (paused)
- `DECISIONS.md` — D-HOMELAB-004
- Homelab Vaultwarden (separate): TrueNAS `10.92.5.200:8080`, NPM `vaultwarden.cloudigan.net`
