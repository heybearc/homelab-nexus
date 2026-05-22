---
purpose: Archive of rolled daily notes
---


## 2026-05-20

_Rolled from NOTES-TODAY.md_

---
date: 2026-05-16
purpose: Scratchpad for today's discoveries (promote on /end-day)
---

## Today

### Focus (paused — other task)
- **Cloudigan Vault MSP** — infra deployed; product/pricing captured in `documentation/CLOUDIGAN-VAULT-PRODUCT.md`

### Session summary (2026-05-16, agent chat)
- Deployed CT171/172 (BLUE active `.94`, GREEN standby `.95`); Netbox; privileged LXC + SSH fixes
- HAProxy `vaultwarden_ha`: BLUE primary, GREEN backup — **not** homelab TrueNAS (separate product)
- NPM proxy **107** for `vault.cloudigan.com` → VIP `10.92.3.33`
- User clarified: **new paid MSP instance**, not TrueNAS cutover; white-label + subscriptions
- **Stripe automation:** stay on **Cloudigan API** (extend D-038 routing); n8n only for optional side workflows
- **Wix MCP:** cannot add DNS (403 `DOMAINS.READ_DNS_ZONES`) — user doing manual A → `174.104.207.3`
- **Pricing:** proposed Starter / Business / Business Plus tiers in product doc (not in Stripe yet)

### Discoveries / Notes
- Nextcloud verified OK — no lockouts; NPM forwards headers via standard include
- CT130 had 3 daily vzdump jobs; local filled root to 92% → fixed
- Ansible `wait_for` port+path bug fixed → `uri` module in `configure-vaultwarden-node.yml`

### Decisions to Promote
- ✅ **D-HOMELAB-006** — Cloudigan Vault MSP product model + Cloudigan API billing (not n8n)

### Mid-day checkpoint (2026-05-16)
- Vault MSP **paused**; resume at `documentation/CLOUDIGAN-VAULT-PRODUCT.md`
- Infra done: CT171/172, HAProxy, NPM 107; pending DNS, Stripe, API vault branch, branding
- No `PLAN.md` in homelab-nexus; no URGENT feedback items

### Blockers / Risks
- Public DNS + NPM SSL verification pending
- `VAULTWARDEN_DB_PASSWORD` must stay in `.env` (not committed)
- Vault webhook + Stripe products not created yet

### Links / Commands
- **Resume here:** `documentation/CLOUDIGAN-VAULT-PRODUCT.md`
- Infra: `documentation/VAULTWARDEN-DEPLOYMENT.md`
- State: `TASK-STATE.md` → Vaultwarden HA plan + paused section
- Verify: `curl -sS https://vault.cloudigan.com/alive` (after DNS)
- SSH: `ssh vaultwarden-blue` / `ssh vaultwarden-green`
