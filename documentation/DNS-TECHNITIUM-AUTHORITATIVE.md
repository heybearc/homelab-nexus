# DNS architecture — AdGuard filters clients, Technitium holds zones

**Updated:** 2026-10-04  
**Decision:** D-HOMELAB-018 (zone authority remains D-HOMELAB-013)  
**Goal:** Every DHCP client is filtered by AdGuard. Technitium stays the zone authority behind AdGuard.

---

## Target architecture

```
DHCP option 6 (clients):
  #1  10.92.3.11   adguard-primary   — filter for every client
  #2  10.92.3.204  adguard-standby   — same filter, so one AdGuard can restart

AdGuard upstream:
  10.92.3.10 / 10.92.3.203  Technitium (authoritative + recursive)
  Clients do not query Technitium directly.

Technitium:
  Primary zones: cloudigan.net + product zones (theoshift.com, …)
  Conditional forwarders: cloudigan.com + _msdcs.cloudigan.com → 10.92.0.10 (dc-01 AD)
  Public recursion: forwarders 1.1.1.1, 9.9.9.9

dc-01:
  Remains AD + cloudigan.com until Entra migration
  Lab zone writes: STOP — use Technitium API only
```

### Why this fixes “AdGuard restart killed internet”

| Before | After |
|--------|--------|
| DHCP → one AdGuard | DHCP → both AdGuard servers |
| That AdGuard down ⇒ no DNS | One AdGuard down ⇒ the other still filters |
| Dual SoT (DC + Tech drift) | Technitium SoT for `cloudigan.net`, behind AdGuard |

---

## Operator step (required): Omada DHCP cutover

In **Omada** → LAN DHCP (or the pool that serves Wi‑Fi / `10.92.0.0/23`):

| Field | Value |
|-------|--------|
| Primary DNS | `10.92.3.11` (AdGuard) |
| Secondary DNS | `10.92.3.204` (AdGuard standby) |
| Domain name (optional) | `cloudigan.net` (prefer over `cloudigan.com` for lab) |

AdGuard upstream on both nodes: `10.92.3.10` and `10.92.3.203`.

Then renew DHCP on clients (or wait for lease refresh).

Verify after cutover:

```bash
ipconfig getpacket en0 | grep domain_name_server   # expect 10.92.3.11, 10.92.3.204
dig +short google.com @10.92.3.11
dig +short jellyfin.cloudigan.net @10.92.3.11
dig +short dc-01.cloudigan.com @10.92.3.11
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

- [ ] **Omada DHCP** DNS = both AdGuard servers (table above). Do not point clients at Technitium.
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
