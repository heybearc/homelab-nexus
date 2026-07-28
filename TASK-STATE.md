# Task State - homelab-nexus

**Last updated:** 2026-07-28 (end-day)

---

## Current Task
**3-node Proxmox cluster** — IN PROGRESS (hardware + phased join; production still on prox1)

### What I'm doing right now
prox2 (`10.92.0.6`) and prox3 (`10.92.0.7`) have PVE installed. Interim TrueNAS NFS datastore `truenas-proxmox` exists. Architecture plan locked: hybrid shared NFS + local disks; need **Omada SX3016F** + **2× Intel X520-DA2** before equal 10G storage peers. Cluster join can proceed on 1G without waiting for 10G.

### Recent completions
- ✅ **prox2/prox3 Proxmox installs** — R720xd via iDRAC; IPs `.6`/`.7`; iDRAC `.16`/`.17` (2026-07-24)
- ✅ **TrueNAS interim shared datastore** — `media-pool/vms/proxmox` 4T → PVE `truenas-proxmox` @ `10.92.3.200` (2026-07-24)
- ✅ **truenas-backups fixed** — recreated on `10.92.3.200` (was inactive on `.5.200`); prune policy kept (2026-07-24)
- ✅ **Scrypted retention 14d** — Retention Period set; manual prune of older continuous footage started on CT180 (2026-07-24)
- ✅ **3-node architecture + NIC/switch buy list** — SX3016F storage fabric + X520-DA2 SFP+; LinksTek 82599ES clone OK (2026-07-24)

### Next steps
1. **Buy / receive:** Omada **SX3016F** + **2× Intel X520-DA2** (SFP+) + extra SFP+ DAC as needed
2. **Phase 1 (can start on 1G):** rename `prox` → `prox1`; upgrade prox2/prox3 to match `8.4.19`; `pvecm create` / join (no guest moves)
3. **Phase 0 (with 10G fabric):** host IPs on vlan922 (`10.92.2.5/6/7`); remount NFS to `10.92.2.200`; re-benchmark
4. **Phase 2:** wipe/reclaim prox2/prox3 ~3.1TB DATA VDs as local ZFS/LVM
5. Still pending (older): Technitium `cloudigan.com` conditional forward → `10.92.0.10`

### Paused (unchanged)
- **HHV DNS/NPM + Next.js app**
- **Cloudigan Mail Gateway** — NPM + GitHub push
- **Cloudigan Vault MSP**
- **TIP Generator Phase 1**
- **Personal Ops Center** — backlog

---

## Known Issues

- **SG3428XMP has only 4× SFP+** — all in use (TrueNAS LACP 25–26, prox1 dual 27–28); need SX3016F before dual 10G on all nodes
- **NFS ~104 MB/s today** — prox host has no IP on 10G VLAN; traffic via gateway — not OK as primary for all CTs
- **TrueNAS media-pool** — interim only; plan evacuate before disk rebuild
- **`cloudigan.com` AD DNS** — conditional forward still pending
- **Technitium auth** — `admin`/`admin`; set production passwords
- **prox `hdd-pool` DEGRADED**; prox2 RAID may still have been rebuilding post-install
- **NPM cert #30 expired** — tautulli NXDOMAIN (D-HOMELAB-007)

---

## Uncommitted work

- **Large diff:** ansible DNS/HHV/mail/monitoring — leave uncommitted until focused commits
- **Intentionally uncommitted:** `files/Logos/`, bulk `.cursor/` / `.windsurf/` noise
- **No end-day git commit** — docs/context only; cluster hardware not yet in repo as code
- Branch **ahead 1** of origin (`e5db8d6` PO counter) — push only if desired

---

## Exact Next Command

```text
# After SX3016F + X520-DA2 arrive (or skip to cluster on 1G):
# 1) Confirm cards: lspci | grep -i 82599 on prox2/prox3
# 2) Or start Phase 1 without 10G:
ssh root@10.92.0.5 'pveversion -v | head -1'
ssh root@10.92.0.6 'pveversion -v | head -1'
ssh root@10.92.0.7 'pveversion -v | head -1'
# Then rename prox→prox1 and align versions before pvecm create
```

**Tomorrow first action:** Order/confirm **SX3016F + 2× X520-DA2**, or begin **prox→prox1 rename + version align** for cluster create.

---

## Infrastructure quick reference

| Service | Primary | Notes |
|---------|---------|--------|
| prox / prox1 | `10.92.0.5` | Rename before cluster |
| prox2 | `10.92.0.6` | iDRAC `10.92.0.16` |
| prox3 | `10.92.0.7` | iDRAC `10.92.0.17` |
| TrueNAS | `10.92.0.3` / NFS `10.92.3.200` | `truenas-proxmox`, `truenas-backups` |
| Switch | SG3428XMP `10.92.0.2` | 4× SFP+ full |
| Scrypted | CT180 `10.92.3.15` | 14-day retention |
| Plan | `.cursor/plans/3-node_cluster_architecture_*.plan.md` | Hybrid NFS + local |
