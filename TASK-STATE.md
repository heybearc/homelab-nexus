# Task State - homelab-nexus

**Last updated:** 2026-10-15

---

## Current Task
**Patch cadence** — first live week. Tonight Thursday 21:00 is prox3. The VIP moves to CT139 first and returns to CT136 after the node is back.

### What I'm doing right now
No repo changes since the 2026-10-13 checkpoint. Tuesday ring3 and Wednesday prox2 have passed on the calendar. prox1 was unreachable this morning (`10.92.0.5`, no route), so those logs are unread. Omada access-point migration is still the open adoption task.

### Recent completions
- ✅ **Patch cadence** — cron on prox1 and n8n workflow Homelab patch ring. Empty targets log and skip. HOLD file pauses apply mode (2026-10-12)
- ✅ **Postgres role switch** — D-067 / D-HOMELAB-019. VIP `10.92.3.23` follows a promote. The old primary is rebuilt as the replica (2026-10-12)
- ✅ **Edge patch** — DNS standbys, Technitium CT145, AdGuard CT140, NPM CT121. OpenResty held for the SHA-1 repo key (2026-10-06)
- ✅ **Single containers and blue-green** — media, business, identity, automation, lab, cameras, monitoring, Vaultwarden, Jellyfin 12.2. HAProxy failover tested (2026-10-06)
- ✅ **adguard-2** — TrueNAS Docker `adguard-standby` renamed to `adguard-2` at `10.92.3.204` without a restart (2026-10-04)

### Next steps
1. When prox1 is reachable, confirm `/etc/patch-cadence/HOLD` is absent and read `/var/log/patch-cadence/` for Tuesday `ring3` and Wednesday `host prox2` before 21:00.
2. If those logs are clean, leave Thursday 21:00 (`host prox3`) on the cron. The VIP goes to CT139 first and comes back to CT136 after the node returns. Set HOLD only if a log shows a failure.
3. Leave Friday 21:00 (`ring2`: HAProxy, Postgres replica CT151, Vaultwarden backup CT172) and Saturday 02:00 (Postgres promote when the primary has packages) on the cron unless a hold is required.
4. Site-migrate the access points onto CT142. Import creates a new site. Do not use Controller Migration.
5. Point the SG3428XMP inform URL at `10.92.0.34`. Capture the ER7206 and adopt it last.

### Paused (unchanged)
- **HHV DNS/NPM + Next.js app**
- **Cloudigan Mail Gateway** — NPM + GitHub push
- **Cloudigan Vault MSP**
- **TIP Generator Phase 1**
- **LDC / QuantShift / chapter-hub-dev destroy** — approved retire later only

---

## Known Issues

- **Postgres primary is on prox1** — VIP `10.92.3.23` is on CT131. Saturday's cron promotes the replica when the primary has packages. Do not restart that primary outside the procedure.
- **prox1 storage VLAN is up** — `10.92.2.5` on `vmbr0922`. `ens3f0` still carries guest VLAN 923 as well as storage VLAN 922.
- **prox2 guest trunk is on `enp4s0f1`** — `vmbr0923/924/925` left 1G `eno1`. `vmbr0925` has no guests; its bridge MTU is pinned to 1500.
- **Five client VMs still no SSH** — ak1-ifw03-p001 `172.22.240.2` no route; GEO-ETL-D001 `10.60.148.101` no route; ak1-rtr03-p001 / DGG-UB-P002 / GEO-KALI-P001 vault password fail (guest ops also failed)
- **joel-win11** — VM created; OS not installed
- **Omada** — CT142 manages the SX3016F. SG3428XMP never appears for adoption. Access points are on the other controller. ER7206 is not adopted.
- **Scrypted** — sustained Baichuan disconnect storm possible under multi-stream load; Garage `.remote` often empty; H.265 codec warnings; NFS EBUSY on prune
- **TrueNAS media-pool** — interim; evacuate before disk rebuild
- **Technitium** — production passwords (not `admin`/`admin`); API token for automation
- **prox `hdd-pool` DEGRADED** (verify current status)
- **NPM cert #30** — not attached to a live host. `adguard-2.cloudigan.net` cert is valid through 2027-01-02 (D-HOMELAB-007)
- **Host packages** — prox1 about 60 (enterprise repo 401), prox2 42, prox3 42. PVE 9.2.20. NVIDIA on prox1 is held. TrueNAS 25.04.2.6 has no update. NPM OpenResty is held
- **AP controller** — `10.92.0.10` UI ports were closed on 2026-10-04. Access points are still on that controller
- **Intro Skipper** — installed; analysis completion not confirmed

---

## Uncommitted work

- None after this end-day commit.
- Do not force-push.

---

## Exact Next Command

```text
ssh -F .cloudy-work/ssh_config_master.conf prox1 'test ! -f /etc/patch-cadence/HOLD && echo HOLD_ABSENT || echo HOLD_SET; ls -1t /var/log/patch-cadence | head -20'
```

**Tomorrow first action:** Read the Tuesday ring3 and Wednesday prox2 logs once prox1 answers. If they are clean and HOLD is absent, leave Thursday 21:00 prox3 armed. Omada site migration stays the next manual adoption step.

---

## Infrastructure quick reference

| Service | Primary | Notes |
|---------|---------|--------|
| prox1 | `10.92.0.5` | Lenovo P920, no BMC; GPU; storage `10.92.2.5` |
| prox2 | `10.92.0.6` | iDRAC `10.92.0.16`; tag `78F8XV1`; X520; `10.92.2.6`; guest trunk on `enp4s0f1` |
| prox3 | `10.92.0.7` | iDRAC `10.92.0.17`; tag `8W72DZ1`; X520; `10.92.2.7` + guest trunk on `enp4s0f1` |
| TrueNAS | `10.92.0.3` / NFS `10.92.2.200` | LAG on SX3016F ports 3–4 |
| Switch | SG3428XMP `10.92.0.2` | uplink port 25 → SX3016F |
| SX3016F | `10.92.0.4` | jumbo 9216; TrueNAS LAG; host ports unbonded (D-HOMELAB-017) |
| Omada | CT142 `10.92.0.34` | **8 GB** RAM; `omada.cloudigan.net` |
| Scrypted | CT180 `10.92.3.15` | Driveway `.184`, Garage `.189`, Front Porch `.190` |
| Quote Builder | CT200/201 `.100`/`.101` | blue on prox2, green on prox3 |
| Jellyfin | CT122 `10.92.3.20` | Intro Skipper 1.10.11.24; `jellyfin.cloudigan.net` |
| Plan | `.cursor/plans/3-node_cluster_architecture_*.plan.md` | Hybrid NFS + local |
