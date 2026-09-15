# DNS architecture — Technitium authoritative (AdGuard optional filter)

**Updated:** 2026-08-20  
**Decision:** D-HOMELAB-013  
**Goal:** Clients resolve via **Technitium** so an AdGuard restart cannot take out internet/DNS.

---

## Target architecture

```
DHCP option 6 (clients):
  #1  10.92.3.10   technitium-primary   (CT145) — authoritative + recursive
  #2  10.92.3.203  technitium-standby   (TrueNAS) — AXFR secondary + same forwarders

Technitium:
  Primary zones: cloudigan.net + product zones (theoshift.com, …)
  Conditional forwarders: cloudigan.com + _msdcs.cloudigan.com → 10.92.0.10 (dc-01 AD)
  Public recursion: forwarders 1.1.1.1, 9.9.9.9

AdGuard (10.92.3.11 / 10.92.3.204):
  OPTIONAL filter only — not in DHCP critical path
  Upstream must be Technitium (10.92.3.10, 10.92.3.203) if used
  Devices that want blocking: set DNS manually to AdGuard

dc-01:
  Remains AD + cloudigan.com until Entra migration
  Lab zone writes: STOP — use Technitium API only
```

### Why this fixes “AdGuard restart killed internet”

| Before | After |
|--------|--------|
| DHCP → AdGuard only | DHCP → Technitium primary + standby |
| AdGuard down ⇒ no DNS | AdGuard down ⇒ clients unaffected |
| Dual SoT (DC + Tech drift) | Technitium SoT for `cloudigan.net` |

---

## Operator step (required): Omada DHCP cutover

In **Omada** → LAN DHCP (or the pool that serves Wi‑Fi / `10.92.0.0/23`):

| Field | New value |
|-------|-----------|
| Primary DNS | `10.92.3.10` |
| Secondary DNS | `10.92.3.203` |
| Domain name (optional) | `cloudigan.net` (prefer over `cloudigan.com` for lab) |

Then renew DHCP on clients (or wait for lease refresh).

**Rollback:** Primary `10.92.3.11`, Secondary `10.92.3.204` (old AdGuard pair).

Verify after cutover:

```bash
ipconfig getpacket en0 | grep domain_name_server   # expect 10.92.3.10, 10.92.3.203
dig +short google.com @10.92.3.10
dig +short jellyfin.cloudigan.net @10.92.3.10
dig +short dc-01.cloudigan.com @10.92.3.10
dig +short SRV _ldap._tcp.cloudigan.com @10.92.3.10
```

---

## Done in control plane (2026-08-20)

- [x] Synced missing `cloudigan.net` A records from dc-01 → Technitium (`quotes`, quote-builder hosts, …)
- [x] Technitium conditional forwarders: `cloudigan.com`, `_msdcs.cloudigan.com` → `10.92.0.10`
- [x] Same forwarders on Technitium standby
- [x] Public forwarders on Technitium: `1.1.1.1`, `9.9.9.9`
- [x] `scripts/provisioning/dns-add-record.sh` → Technitium API
- [x] `scripts/dns/sync-dc-a-records-to-technitium.sh` for re-sync
- [x] Jellyfin LXC nameservers → Technitium

### Still manual / follow-up

- [ ] **Omada DHCP** cutover (table above)
- [ ] AdGuard **standby** upstream verify (API password unknown) — set upstream to `10.92.3.10` + `10.92.3.203` in UI
- [ ] Optional: migrate reverse zones from dc-01 → Technitium
- [ ] Entra-join Windows → later remove dc-01 (separate project)

---

## Automation

```bash
set -a && source .env && set +a
# Add lab A record
./scripts/provisioning/dns-add-record.sh jellyfin 10.92.3.20

# Re-sync any A records still only on dc-01
./scripts/dns/sync-dc-a-records-to-technitium.sh
```

Requires `TECHNITIUM_API_TOKEN` (+ optional `TECHNITIUM_STANDBY_API_TOKEN`).
