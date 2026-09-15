# DNS redundancy migration (Technitium + dual AdGuard)

**Goal:** Replace dc-01 as internal DNS authority with **Technitium** (Proxmox primary, TrueNAS secondary) and **dual AdGuard** (Proxmox primary, TrueNAS secondary), with **zero-downtime cutover** and **rollback** at every phase.

**Do not decommission dc-01 until phase 7 is stable for 2+ weeks.**

---

## Architecture (updated 2026-08-20 — D-HOMELAB-013)

**Current target:** see **`documentation/DNS-TECHNITIUM-AUTHORITATIVE.md`**.

```
DHCP (gateway)  DNS option 6:
  #1  10.92.3.10   technitium-primary     (CT145 — authoritative + recursive)
  #2  10.92.3.203  technitium-standby     (TrueNAS — AXFR secondary)

AdGuard 10.92.3.11 / 10.92.3.204:
  OPTIONAL filter only (not in DHCP). Upstream → Technitium if used.

Technitium PRIMARY  10.92.3.10
        │ AXFR/NOTIFY
        ▼
Technitium SECONDARY 10.92.3.203
  + Forwarder zones: cloudigan.com, _msdcs.cloudigan.com → dc-01 (10.92.0.10)

Automation writes records → Technitium PRIMARY API only.
dc-01 remains for AD until Entra migration; lab zones are Technitium SoT.
```

---

## IP and hostname plan

| Service | IP | Hostname | Host |
|---------|-----|----------|------|
| AdGuard primary | `10.92.3.11` | `adguard.cloudigan.net` | CT140 (exists) |
| Technitium primary | `10.92.3.10` | `technitium.cloudigan.net` | CT145 (new) |
| Technitium secondary | `10.92.3.203` | `technitium-standby.cloudigan.net` | TrueNAS Docker |
| AdGuard secondary | `10.92.3.204` | `adguard-standby.cloudigan.net` | TrueNAS Docker |

**Netbox note:** `10.92.3.201` is `proxmox-data.cloudigan.net` (10G bond label) — do not use. `.203`/`.204` are free.

**dc-01 UI hostnames** (same pattern as `adguard.cloudigan.net` → NPM):

| Hostname | dc-01 A record | Purpose |
|----------|----------------|---------|
| `technitium.cloudigan.net` | `10.92.3.3` | HTTPS UI via NPM → `10.92.3.10:5380` |
| `technitium-standby.cloudigan.net` | `10.92.3.3` | HTTPS UI via NPM → `10.92.3.203:5380` |
| `adguard-standby.cloudigan.net` | `10.92.3.3` | HTTPS UI via NPM → `10.92.3.204:3000` |

**DHCP / DNS port 53** uses real service IPs (`10.92.3.11`, `10.92.3.204`) — not NPM.

**Bootstrap (before new stack is live):** Add the three *new* hostnames as A records on **dc-01** so you can reach admin UIs during migration. Your existing `adguard.cloudigan.net` already covers primary AdGuard.

---

## What you need to provide

| # | Item | Why |
|---|------|-----|
| 1 | **Confirm IPs/hostnames** above (or preferred alternates) | Netbox + DHCP + zone records |
| 2 | **Free CTID** — proposed **CT145** for Technitium primary | Proxmox deploy |
| 3 | **AdGuard admin password** → `ADGUARD_PASSWORD` in `.env` | API + Ansible |
| 4 | **Technitium admin password** → set in UI (`auth.config`); optional `TECHNITIUM_API_TOKEN` for scripts | API + zone import |
| 5 | **dc-01 SSH** — `cory@cloudigan.com` password or working key | Zone export during migration |
| 6 | **Gateway (Omada) access** — DHCP DNS option 6 change | Client cutover + rollback |
| 7 | **TrueNAS** — OK to run **Docker** (not ix-apps) for secondary DNS | Survives Proxmox outage |
| 8 | **TrueNAS vlan923 alias** — OK to add `.201` / `.202` on `vlan923` | Reachable secondary IPs |

Optional: `TECHNITIUM_API_TOKEN` after first login (playbook can create via login API).

---

## Zero-downtime phases

Each phase writes state to **`/opt/dns-migration/state.json`** on ansible-control (CT183) for rollback.

| Phase | Action | Client impact | Rollback |
|-------|--------|---------------|----------|
| **0** | dc-01: add A records for new hostnames | None | Delete those A records |
| **1** | Deploy CT145 Technitium primary + TrueNAS Docker secondaries | None | Stop/remove containers |
| **2** | Import `cloudigan.net` zone from dc-01 → Technitium primary; configure AXFR → secondary | None | Delete zone on Technitium |
| **3** | Configure AdGuard **primary** upstream: Technitium for `cloudigan.net` (dc-01 still in DHCP) | None | Revert AdGuard upstream in UI/API |
| **4** | Deploy AdGuard secondary on TrueNAS; sync blocklists from primary | None | Stop TrueNAS AdGuard container |
| **5** | DHCP: add **10.92.3.202** as DNS **#2** (keep current #1) | None — failover only | Remove DNS #2 |
| **6** | DHCP: set DNS **#1** = `10.92.3.11`, **#2** = `10.92.3.202`; remove dc-01 from DNS | Brief retry window on some clients | `./scripts/dns/rollback-dns-cutover.sh` |
| **7** | Point automation (`dns-add-record.sh`) at Technitium API; stop dc-01 writes | None | Re-enable dc-01 script path |
| **8** | (Later) Decommission dc-01 / Entra-join Windows | — | Restore dc-01 VM |

**Run phases:**

```bash
cd /Users/cory/Projects/homelab-nexus
source .env
./scripts/dns/migrate-dns-phase.sh 0   # bootstrap dc-01 records
cd ansible && ansible-playbook playbooks/deploy-dns-stack.yml
./scripts/dns/migrate-dns-phase.sh 2   # zone import + AXFR verify
./scripts/dns/migrate-dns-phase.sh 3   # adguard upstream
# ... manual Omada DHCP for phase 5-6, or provide API creds later
./scripts/dns/migrate-dns-phase.sh 6 --apply
```

**Emergency rollback (restore dc-01 as client DNS):**

```bash
./scripts/dns/rollback-dns-cutover.sh
```

---

## Failover recap

1. **Clients** — two AdGuard IPs in DHCP; OS tries #2 when #1 is down.
2. **AdGuard → Technitium** — each AdGuard prefers **local** Technitium, other as fallback upstream.
3. **Technitium** — secondary holds last AXFR copy when primary is down (read-only).

---

## Ansible

```bash
cd /Users/cory/Projects/homelab-nexus
source .env
cd ansible
ansible-playbook playbooks/deploy-dns-stack.yml
```

Deploys:
- Technitium primary LXC (CT145) via shared `deploy-proxmox-container.yml`
- Technitium + AdGuard Docker on TrueNAS
- TSIG + secondary zone on TrueNAS Technitium
- Netbox registration

Does **not** change DHCP or dc-01 — run migration phases separately.

---

## After cutover

- Update `scripts/provisioning/dns-add-record.sh` → Technitium API (done in repo)
- Remove dc-01 step from rename playbook when confident
- Register Technitium + standby AdGuard in `monitoring/apps-registry.yaml`
- Document Omada DHCP DNS settings in Netbox

---

## Related files

- `ansible/group_vars/dns_deploy.yml` — IPs, CTID, hostnames
- `ansible/playbooks/deploy-dns-stack.yml` — main deploy
- `scripts/dns/migrate-dns-phase.sh` — phased cutover
- `scripts/dns/rollback-dns-cutover.sh` — emergency rollback
- `scripts/dns/export-dc01-zone.sh` — zone export for import
- `scripts/dns/technitium-api.sh` — API helper / add-record
