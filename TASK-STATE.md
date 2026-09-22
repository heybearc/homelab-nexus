# Task State - homelab-nexus

**Last updated:** 2026-09-22 (mid-day)

---

## Current Task
**10G storage fabric** — SX3016F adopted; prox2 on vlan922; TrueNAS LAG move next

### What I'm doing right now
Cluster is PVE 9.2.20, 3/3. Guests drained off prox2 onto prox1 (HA pairs still split vs prox3). X520 in prox2; SX3016F `10.92.0.4` uplink on 3428 port 25. prox2 `10.92.2.6` on `enp4s0f0.922` pings and NFS-mounts TrueNAS `10.92.2.200`. Cluster `storage.cfg` still `10.92.3.200`.

### Recent completions
- ✅ **Omada CT142 recovered** — wedged at 2 GB; reboot + RAM to **8 GB** (D-HOMELAB-015); UI 200 at `omada.cloudigan.net` (2026-09-08)
- ✅ **geo-sapnfs-p001 Ninja/Kaseya** — killed hung Ninja PTY, restarted agent, removed Kaseya leftovers, installed `lsof` (2026-09-09)
- ✅ **Client SSH recovery** — root key on GEO-PGSQL-P001, GEO-UB-P001, AK1-UB-P002, GEO-SAP-DB-T001; SAP-DB root FS 100% → 22% (2026-09-10)
- ✅ **Scrypted Baichuan storm self-heals** — CT180 watchdog (2026-09-08)
- ✅ **Quote Builder blue-green** — CT200/201, `deploy-bluegreen-app.yml`, HAProxy, NPM, MCP handoff (2026-07-28 → 2026-08)

### Next steps
1. **SX3016F LACP** for TrueNAS (spare DAC first, then move 3428 port 26). Trunk: PVID 920, tag 922–925.
2. **vlan922** on prox1 `10.92.2.5` and prox3 `10.92.2.7`, then remount NFS to `10.92.2.200`.
3. Move guests back to prox2 (pairs stay split). Do not adopt the Omada gateway.
4. Pending: Omada DHCP cutover to Technitium (D-HOMELAB-013)

### Paused (unchanged)
- **HHV DNS/NPM + Next.js app**
- **Cloudigan Mail Gateway** — NPM + GitHub push
- **Cloudigan Vault MSP**
- **TIP Generator Phase 1**
- **Personal Ops Center** — backlog
- **LDC / QuantShift / chapter-hub-dev destroy** — approved retire later only

---

## Known Issues

- **Five client VMs still no SSH** — ak1-ifw03-p001 `172.22.240.2` no route; GEO-ETL-D001 `10.60.148.101` no route; ak1-rtr03-p001 / DGG-UB-P002 / GEO-KALI-P001 vault password fail (guest ops also failed)
- **joel-win11** — VM created; OS not installed
- **Omada** — controller healthy at 8 GB; DHCP still not cut over to Technitium
- **Scrypted** — sustained Baichuan disconnect storm possible under multi-stream load; Garage `.remote` often empty; H.265 codec warnings; NFS EBUSY on prune
- **SG3428XMP has only 4× SFP+** — need SX3016F before dual 10G on all nodes
- **NFS ~104 MB/s interim** — prox host has no IP on 10G VLAN
- **TrueNAS media-pool** — interim; evacuate before disk rebuild
- **Technitium** — production passwords (not `admin`/`admin`); API token for automation
- **prox `hdd-pool` DEGRADED** (verify current status)
- **NPM cert #30 expired** — tautulli NXDOMAIN (D-HOMELAB-007)

---

## Uncommitted work

- **Large untracked/modified set:** ansible (BG template, DNS, HHV/mail), monitoring, ops-hub, docs, logos, `.cursor/` — leave until focused commits
- **Intentionally uncommitted:** `files/Logos/`, `files/isos/`, bulk IDE noise
- **This end-day:** context files only (TASK-STATE, DECISIONS, notes roll, APP-MAP/PLAN in cloudy-work)
- Branch **ahead of origin** — end-day pushes the context commit; do not force-push

---

## Exact Next Command

```text
# prox2 storage path (already up):
# 10.92.2.6 on enp4s0f0.922 → TrueNAS 10.92.2.200
```

**Tomorrow first action:** LACP TrueNAS onto SX3016F, then vlan922 IPs on prox1/prox3 and NFS remount to `10.92.2.200`.

---

## Infrastructure quick reference

| Service | Primary | Notes |
|---------|---------|--------|
| prox1 | `10.92.0.5` | Lenovo P920, no BMC; guests parked here |
| prox2 | `10.92.0.6` | iDRAC `10.92.0.16`; tag `78F8XV1`; X520; `10.92.2.6` |
| prox3 | `10.92.0.7` | iDRAC `10.92.0.17`; tag `8W72DZ1` |
| TrueNAS | `10.92.0.3` / NFS `10.92.3.200` + `10.92.2.200` | still on 3428 port 26 |
| Switch | SG3428XMP `10.92.0.2` | uplink port 25 → SX3016F |
| SX3016F | `10.92.0.4` | jumbo 9216; ports 7/8 = prox2 |
| Omada | CT142 `10.92.0.34` | **8 GB** RAM; `omada.cloudigan.net` |
| Scrypted | CT180 `10.92.3.15` | Driveway `.184`, Garage `.189`, Front Porch `.190` |
| Quote Builder | CT200/201 `.100`/`.101` | LIVE=blue; `quotes.cloudigan.net` |
| Plan | `.cursor/plans/3-node_cluster_architecture_*.plan.md` | Hybrid NFS + local |
