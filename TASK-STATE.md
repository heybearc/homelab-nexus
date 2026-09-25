# Task State - homelab-nexus

**Last updated:** 2026-09-25

---

## Current Task
**10G storage fabric** — switch path is up; cluster NFS still on `10.92.3.200`

### What I'm doing right now
TrueNAS LACP is on the SX3016F. prox3 has the reference 10G layout (`10.92.2.7` storage, guest VLANs on the second DAC). Guests are spread across all three nodes with blue/green pairs split. prox1 still has no `10.92.2.5`, and `storage.cfg` still mounts NFS at `10.92.3.200`.

### Recent completions
- ✅ **Guest balance** — running counts 18 / 17 / 19 (prox1 / prox2 / prox3). GPU, media, and Postgres primary stay on prox1. Blues and HAProxy standby stay on prox2. Greens, live HAProxy, replica, and monitoring are on prox3 (2026-09-25)
- ✅ **Intro Skipper** — Jellyfin 10.11.11 plugin `1.10.11.24` loaded on CT122. Skip button still needs the Detect and Analyze task plus the per-client Playback setting (2026-09-25)
- ✅ **SX3016F cutover** — TrueNAS LAG `truenas` (ports 3/4, native 920, tagged 922–925). prox1 10G cables moved. prox3 X520 installed and configured (2026-09-25)
- ✅ **Omada CT142 recovered** — wedged at 2 GB; reboot + RAM to **8 GB** (D-HOMELAB-015); UI 200 at `omada.cloudigan.net` (2026-09-08)
- ✅ **Scrypted Baichuan storm self-heals** — CT180 watchdog (2026-09-08)

### Next steps
1. **prox1 vlan922** — `10.92.2.5/24` on `vmbr0922` (`ens3f0.922`, MTU 9000). Ping `10.92.2.200`.
2. **Remount NFS** — point cluster `storage.cfg` from `10.92.3.200` to `10.92.2.200` and confirm all three nodes.
3. **prox2 guest VLANs** — `vmbr0923/924/925` are still on 1G `eno1`. Move them to `enp4s0f1` the way prox3 is wired (D-HOMELAB-017).
4. Pending: Omada DHCP cutover to Technitium (D-HOMELAB-013). Do not adopt the Omada gateway.
5. Optional: move Postgres primary CT131 to prox2 only in a window where a replica promote is acceptable. It stayed on prox1 on purpose.

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
- **prox1 has no storage-VLAN address** — NFS still sourced from `10.92.3.201`. prox2 is `10.92.2.6`, prox3 is `10.92.2.7`.
- **prox2 guest traffic is still on 1G** — only `vmbr0922` is on the X520.
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

- None. End-day commit includes context plus the fabric helpers (`bind-migrate-ct.sh`, drain scripts, prox2 vlan922 snapshot, Tailscale LAN-route drop-in).
- Do not force-push.

---

## Exact Next Command

```text
# prox1: address 10.92.2.5/24 on vmbr0922 (bridge-ports ens3f0.922, MTU 9000)
# ping 10.92.2.200, then change storage.cfg NFS server 10.92.3.200 → 10.92.2.200
```

**Tomorrow first action:** Give prox1 `10.92.2.5` on vlan922, then remount cluster NFS to `10.92.2.200`.

---

## Infrastructure quick reference

| Service | Primary | Notes |
|---------|---------|--------|
| prox1 | `10.92.0.5` | Lenovo P920, no BMC; GPU; no `10.92.2.5` yet |
| prox2 | `10.92.0.6` | iDRAC `10.92.0.16`; tag `78F8XV1`; X520; `10.92.2.6`; guest VLANs still 1G |
| prox3 | `10.92.0.7` | iDRAC `10.92.0.17`; tag `8W72DZ1`; X520; `10.92.2.7` + guest trunk on `enp4s0f1` |
| TrueNAS | `10.92.0.3` / NFS `10.92.3.200` + `10.92.2.200` | LAG on SX3016F ports 3–4 |
| Switch | SG3428XMP `10.92.0.2` | uplink port 25 → SX3016F |
| SX3016F | `10.92.0.4` | jumbo 9216; TrueNAS LAG; host ports unbonded (D-HOMELAB-017) |
| Omada | CT142 `10.92.0.34` | **8 GB** RAM; `omada.cloudigan.net` |
| Scrypted | CT180 `10.92.3.15` | Driveway `.184`, Garage `.189`, Front Porch `.190` |
| Quote Builder | CT200/201 `.100`/`.101` | blue on prox2, green on prox3 |
| Jellyfin | CT122 `10.92.3.20` | Intro Skipper 1.10.11.24; `jellyfin.cloudigan.net` |
| Plan | `.cursor/plans/3-node_cluster_architecture_*.plan.md` | Hybrid NFS + local |
