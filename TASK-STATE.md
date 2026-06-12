# Task State - homelab-nexus

**Last updated:** 2026-06-12 (end-day)

---

## Current Task
**DNS post-cutover** — AD conditional forward still blocking clean domain logons; Scrypted Reolink NVR **done**

### What I'm doing right now
Reolink CX810 ×3 recording to TrueNAS via Scrypted NVR (3/3 licenses). **Tomorrow:** Technitium conditional forward `cloudigan.com` → `10.92.0.10` (dc-01) so AD SRV records resolve through new DNS stack.

### Recent completions
- ✅ **Reolink CX810 → Scrypted + NVR** — Native plugin, cams 60–62, ~227 GB recording on NFS (2026-06-12)
- ✅ **Stale Nest recordings cleared** — `scrypted-27`–`30` removed from TrueNAS
- ✅ **PM2 audit + decommission** — ldc-tools/quantshift stopped; factorpoint legacy env cleaned
- ✅ **DNS redundancy + DHCP phase 6** — Technitium + dual AdGuard cutover (2026-06-08)
- ✅ **Mid-day context** — D-HOMELAB-010, TASK-STATE/NOTES/DECISIONS pushed (`4746d81`)

### Next steps
1. **Technitium conditional forward:** `cloudigan.com` → `10.92.0.10` — verify `dig @10.92.3.11 _ldap._tcp.cloudigan.com SRV +short`
2. **Scrypted (optional):** Reolink motion zones; NVR retention days (~30–60); verify Garage camera aim/timeline
3. **Set Technitium production passwords** on dns + dns-2
4. **Client server identity** — AD users → local or Entra
5. **Git** — commit DNS ansible/docs chunk (large diff still uncommitted)
6. **Backlog:** Linux dev VM spec — Cursor Remote SSH from Mac, RDP from iPad, single repo on VM (discussed, not built)

### Paused (unchanged)
- **HHV DNS/NPM + Next.js app**
- **Cloudigan Mail Gateway** — NPM + GitHub push
- **Cloudigan Vault MSP**
- **TIP Generator Phase 1**

---

## Known Issues

- **`cloudigan.com` AD DNS not on new stack** — `_ldap._tcp.cloudigan.com` SRV empty via AdGuard until conditional forward added
- **Technitium auth** — `admin`/`admin` after permission fix; set production passwords
- **Scrypted NVR growth** — continuous 2K ~85 GB/camera/day; set explicit retention when ready
- **Reolink admin password** — `@` may break RTSP; alphanumeric recommended
- **Garage timeline** — main recording folder small vs remote; snapshots OK — verify placement
- **NPM cert #30 expired** — tautulli NXDOMAIN (D-HOMELAB-007)
- **cloudigan-mail GitHub** — not pushed
- **dc-01** — keep up 2+ weeks during identity migration

---

## Uncommitted work

- **Large diff:** ansible DNS stack, HHV/mail/monitoring scripts — commit DNS slice after forwarder verify
- **Intentionally uncommitted:** `files/Logos/`, `.cursor/`, `.windsurf/`
- **`.cloudy-work/PLAN.md`** — backlog updated locally (submodule); pointer may need separate commit

---

## Exact Next Command

```bash
dig @10.92.3.11 _ldap._tcp.cloudigan.com SRV +short
# empty → add Technitium forward cloudigan.com → 10.92.0.10, re-test
```

**Tomorrow first action:** Technitium UI → conditional forward `cloudigan.com` → `10.92.0.10`.

---

## Infrastructure quick reference

| Service | Primary | Standby |
|---------|---------|---------|
| AdGuard (DHCP DNS) | `10.92.3.11` | `10.92.3.204` |
| Technitium | `10.92.3.10` | `10.92.3.203` |
| Scrypted NVR | CT180 `10.92.3.15` | recordings → TrueNAS NFS |
| Reolink CX810 | `.184` Driveway, `.189` Garage, `.190` Front Porch | Scrypted ids 60–62 |
| AD DNS (legacy) | dc-01 `10.92.0.10` | `cloudigan.com` zone |

**DHCP DNS:** `#1 10.92.3.11`, `#2 10.92.3.204`
