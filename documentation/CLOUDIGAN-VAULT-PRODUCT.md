# Cloudigan Vault — Product & Session Notes

**Last updated:** 2026-05-16  
**Status:** Infrastructure largely deployed; commercial launch pending (DNS, branding, Stripe/API, replication)  
**ADR:** D-HOMELAB-004 (active/passive HA, not dual writers)

---

## Product intent (confirmed 2026-05-16)

- **New MSP product** for paying customers — **not** a cutover from homelab TrueNAS Vaultwarden.
- **Brand:** Cloudigan Vault at **`https://vault.cloudigan.com`**
- **Homelab instance stays separate:** TrueNAS `10.92.5.200`, NPM `vaultwarden.cloudigan.net`
- **Positioning:** Business password manager hosted and supported by Cloudigan IT (Bitwarden-compatible clients, Cloudigan server URL).
- **Billing:** Stripe (Wix checkout) → **Cloudigan API** (`api.cloudigan.net/webhook/stripe`) — **not n8n** for subscription automation (n8n OK for secondary/internal workflows only).

---

## Infrastructure deployed

| Component | Detail |
|-----------|--------|
| **BLUE (active)** | CT171 `vaultwarden-blue` @ `10.92.3.94` — Vaultwarden running, `/alive` OK |
| **GREEN (standby)** | CT172 `vaultwarden-green` @ `10.92.3.95` — compose + image staged; **service not started** (D-HOMELAB-004) |
| **Database** | Postgres `vaultwarden` on CT131 — password in `.env` as `VAULTWARDEN_DB_PASSWORD` |
| **Netbox** | Both VMs + IPs registered |
| **SSH** | `vaultwarden-blue` / `vaultwarden-green` in `ssh_config_master.conf`; privileged LXC required for Docker |
| **HAProxy** | `vaultwarden_ha` on VIP `10.92.3.33` — primary **BLUE**, backup **GREEN**; **TrueNAS excluded** from MSP pool |
| **NPM** | Proxy host **107** — `vault.cloudigan.com` → `10.92.3.33:80` (cert ID 96; verify after public DNS) |
| **Public DNS** | Manual A record `vault.cloudigan.com` → `174.104.207.3` (Wix MCP cannot manage DNS — missing `DOMAINS.READ_DNS_ZONES`) |

**Ansible:** `ansible/playbooks/deploy-vaultwarden-containers.yml`, resume `vaultwarden-finish.yml`  
**Ops doc:** `documentation/VAULTWARDEN-DEPLOYMENT.md`

---

## White label (server-side)

- Bitwarden **apps stay Bitwarden-branded**; customers set server URL to `https://vault.cloudigan.com`.
- Cloudigan branding via: `DOMAIN`, SMTP/`TEMPLATES_FOLDER`, optional `WEB_VAULT_FOLDER`, `/admin` org policies.
- Access policy: `SIGNUPS_ALLOWED=false`, `INVITATIONS_ALLOWED=true` (invite-only MSP).
- Logos: `files/Logos/`

---

## Stripe + Cloudigan API (to build)

Extend existing webhook (**D-038** product-type routing) — same pattern as RMM vs support hours:

| `product_type` (metadata) | Webhook behavior |
|---------------------------|------------------|
| `rmm` (default / existing) | Datto site + welcome email + Wix CMS |
| `vault` | Vaultwarden org/invite — **no Datto**, no RMM email |
| support hours | Admin notify only (existing) |

**Stripe product naming:** include **`Cloudigan Vault`** in product name for keyword/metadata routing.

**Checkout:** company name + admin email; **quantity = seats** (use line_items quantity pattern from `stripe-device-quantity-extraction.md`).

**Vaultwarden does not enforce paid seats** — gate via org seat count + admin or API automation after payment.

---

## Pricing (proposed — not yet in Stripe)

**Goal:** Affordable for small businesses (5–25 users); at or under Bitwarden Teams (~$4/seat/mo annual).

| Plan | Audience | Pricing (suggested) | Notes |
|------|----------|---------------------|--------|
| **Starter** | 1–5 users | **$3/seat/mo** or **$30/seat/yr** — or flat **$12/mo** for ≤5 seats | Simple invoice for micro businesses |
| **Business** | 6–25 users | **$4/seat/mo** or **$40/seat/yr** | Default “most popular” on Wix |
| **Business Plus** | 6–50, needs hand-holding | **$6/seat/mo** or **$60/seat/yr** | + onboarding call, priority support |

**SMB-friendly rules:**

- Default **annual** checkout (show savings vs monthly).
- Consider **minimum 3 seats** on Business tiers (or Starter-only for 1–2 users).
- **Per user** only (not per device).
- Optional **14-day Stripe trial** on subscription.
- Optional later: bundle discount with existing RMM customers.

**Metadata on Stripe products:** `product_type=vault`, `plan=starter|business|business_plus`

---

## Resume checklist (when back)

1. [ ] Public DNS live → `curl -sS https://vault.cloudigan.com/alive`
2. [ ] NPM proxy 107 — re-request Let's Encrypt if needed
3. [ ] SMTP + email templates + `ADMIN_TOKEN` in compose (`.env`)
4. [ ] Create Stripe products/prices + Wix pricing page
5. [ ] Cloudigan API: vault branch in `webhook-handler.js`
6. [ ] Postgres replica CT151 + `DATA_FOLDER` sync (failover)
7. [ ] Failover runbook (phase 5)

---

## Related

- `TASK-STATE.md` — phases 0–5, paused state
- `DECISIONS.md` — D-HOMELAB-004
- `documentation/STRIPE-WEBHOOK-SETUP-GUIDE.md` — webhook endpoint
- `.cloudy-work/_cloudy-ops/context/DECISIONS.md` — D-038 product-type routing
