# Task State - homelab-nexus

**Last updated:** 2026-10-04

---

## Current Task
**10G fabric** — prox2 guest VLANs are on `enp4s0f1`. Next is the Omada DHCP cutover.

### What I'm doing right now
prox2 matches prox3: storage stays on `enp4s0f0` (`vmbr0922` `10.92.2.6`), and `vmbr0923`/`vmbr0924`/`vmbr0925` are on `enp4s0f1`. Management `vmbr0` stays on `eno1`.

### Recent completions
- ✅ **prox2 guest trunk** — `vmbr0923` `10.92.3.206`, `vmbr0924`, and `vmbr0925` moved from `eno1` to `enp4s0f1` on SX3016F port 7 (PVID 920). Gateway pings and CT139 `10.92.3.32` answered (2026-09-30)
- ✅ **Cluster NFS on vlan 922** — `storage.cfg` server is `10.92.2.200`. prox1 `10.92.2.5`, prox2 `10.92.2.6`, prox3 `10.92.2.7`. Guests returned to their original nodes. Postgres primary stayed primary (2026-09-30)
- ✅ **Guest balance** — running counts 18 / 17 / 19 (prox1 / prox2 / prox3). GPU, media, and Postgres primary stay on prox1. Blues and HAProxy standby stay on prox2. Greens, live HAProxy, replica, and monitoring are on prox3 (2026-09-25)
- ✅ **SX3016F cutover** — TrueNAS LAG `truenas` (ports 3/4, native 920, tagged 922–925). prox1 10G cables moved. prox3 X520 installed and configured (2026-09-25)

### Next steps
1. Pending: Omada DHCP cutover to Technitium (D-HOMELAB-013). Do not adopt the Omada gateway.
2. Optional: move Postgres primary CT131 to prox2 only in a window where a replica promote is acceptable. It stayed on prox1 on purpose.

### Paused (unchanged)
- **HHV DNS/NPM + Next.js app**
- **Cloudigan Mail Gateway** — NPM + GitHub push
- **Cloudigan Vault MSP**
- **TIP Generator Phase 1**
- **Personal Ops Center** — backlog
- **LDC / QuantShift / chapter-hub-dev destroy** — approved retire later only

---

## Known Issues

- **Postgres primary is on prox1, not prox2** — D-HOMELAB-016 still wants CT131 on prox2 with CT151 on prox3. Stopping the primary can promote the replica. Do not restart CT131 casually.
- **prox1 storage VLAN is up** — `10.92.2.5` on `vmbr0922`. `ens3f0` still carries guest VLAN 923 as well as storage VLAN 922.
- **prox2 guest trunk is on `enp4s0f1`** — `vmbr0923/924/925` left 1G `eno1`. `vmbr0925` has no guests; its bridge MTU is pinned to 1500.
- **Five client VMs still no SSH** — ak1-ifw03-p001 `172.22.240.2` no route; GEO-ETL-D001 `10.60.148.101` no route; ak1-rtr03-p001 / DGG-UB-P002 / GEO-KALI-P001 vault password fail (guest ops also failed)
- **joel-win11** — VM created; OS not installed
- **Omada** — controller healthy at 8 GB; DHCP still not cut over to Technitium
- **Scrypted** — sustained Baichuan disconnect storm possible under multi-stream load; Garage `.remote` often empty; H.265 codec warnings; NFS EBUSY on prune
- **TrueNAS media-pool** — interim; evacuate before disk rebuild
- **Technitium** — production passwords (not `admin`/`admin`); API token for automation
- **prox `hdd-pool` DEGRADED** (verify current status)
- **NPM cert #30 expired** — tautulli NXDOMAIN (D-HOMELAB-007)
- **Intro Skipper** — installed; analysis completion not confirmed

---

## Uncommitted work

- None. End-day commit covers the vlan 922 NFS cutover, the prox2 guest trunk, and the helper scripts.
- Do not force-push.

---

## Exact Next Command

```text
# Omada DHCP cutover to Technitium (D-HOMELAB-013). Do not adopt the Omada gateway.
```

**Tomorrow first action:** Omada DHCP cutover to Technitium. Do not adopt the Omada gateway.

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
