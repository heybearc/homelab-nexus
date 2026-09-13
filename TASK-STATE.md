# Task State - homelab-nexus

**Last updated:** 2026-09-13 (end-day)

---

## Current Task
**3-node Proxmox cluster** — IN PROGRESS (hardware + phased join; production still on prox1)

### What I'm doing right now
Cluster plan still locked (hybrid NFS + local). This week was ops recovery: Omada CT142, Ninja/Kaseya on geo-sapnfs-p001, and SSH access on four client Linux VMs. Quote Builder infra remains handed off to the app repo.

### Recent completions
- ✅ **Omada CT142 recovered** — wedged at 2 GB; reboot + RAM to **8 GB** (D-HOMELAB-015); UI 200 at `omada.cloudigan.net` (2026-09-08)
- ✅ **geo-sapnfs-p001 Ninja/Kaseya** — killed hung Ninja PTY, restarted agent, removed Kaseya leftovers, installed `lsof` (2026-09-09)
- ✅ **Client SSH recovery** — root key on GEO-PGSQL-P001, GEO-UB-P001, AK1-UB-P002, GEO-SAP-DB-T001; SAP-DB root FS 100% → 22% (2026-09-10)
- ✅ **Scrypted Baichuan storm self-heals** — CT180 watchdog (2026-09-08)
- ✅ **Quote Builder blue-green** — CT200/201, `deploy-bluegreen-app.yml`, HAProxy, NPM, MCP handoff (2026-07-28 → 2026-08)

### Next steps
1. **Cluster Phase 1:** version-check PVE on prox/prox2/prox3; rename `prox` → `prox1`; `pvecm create` / join (1G OK)
2. **Buy / receive:** Omada **SX3016F** + **2× Intel X520-DA2**, or keep Phase 1 on 1G
3. Finish **joel-win11** VM105 OS install (VirtIO SCSI + static `10.92.4.3/24`)
4. Remaining **NO_ACCESS** VMs: ak1-ifw03-p001, GEO-ETL-D001 (no route); ak1-rtr03-p001, DGG-UB-P002, GEO-KALI-P001 (need console/owner passwords)
5. Optional: focused git commits for ansible BG template + DNS/monitoring (still uncommitted bulk)
6. Pending: Omada DHCP cutover to Technitium (D-HOMELAB-013)

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
# Cluster Phase 1 (1G OK) — version align then rename:
ssh root@10.92.0.5 'pveversion -v | head -1'
ssh root@10.92.0.6 'pveversion -v | head -1'
ssh root@10.92.0.7 'pveversion -v | head -1'
# Then rename prox→prox1 and pvecm create/join

# If Omada UI dies again:
ssh prox 'pct config 142 | grep memory; pct status 142'
# Expect memory: 8192
```

**Tomorrow first action:** Resume **3-node cluster Phase 1** (version check → prox→prox1), or confirm SX3016F/X520 order status. Quote Builder product work lives in `~/Projects/cloudigan-quote-builder`.

---

## Infrastructure quick reference

| Service | Primary | Notes |
|---------|---------|--------|
| prox / prox1 | `10.92.0.5` | Rename before cluster |
| prox2 | `10.92.0.6` | iDRAC `10.92.0.16` |
| prox3 | `10.92.0.7` | iDRAC `10.92.0.17` |
| TrueNAS | `10.92.0.3` / NFS `10.92.3.200` | `truenas-proxmox`, `truenas-backups` |
| Switch | SG3428XMP `10.92.0.2` | 4× SFP+ full |
| Omada | CT142 `10.92.0.34` | **8 GB** RAM; `omada.cloudigan.net` |
| Scrypted | CT180 `10.92.3.15` | Driveway `.184`, Garage `.189`, Front Porch `.190` |
| Quote Builder | CT200/201 `.100`/`.101` | LIVE=blue; `quotes.cloudigan.net` |
| Plan | `.cursor/plans/3-node_cluster_architecture_*.plan.md` | Hybrid NFS + local |
