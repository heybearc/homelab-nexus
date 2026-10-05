# homelab-nexus Plan

**Last updated:** 2026-10-05
**Current phase:** Omada adoption
**Status:** SX3016F is managed by CT142. Access points are still on the other controller. SG3428XMP has never appeared for adoption.

---

## Current Phase

### Active Work
- [ ] Move access points with Site Migration onto CT142. Do not use Controller Migration.
- [ ] Get the SG3428XMP to show Pending. Capture its standalone config before any Adopt click.
- [ ] Capture the ER7206 and adopt it last, after the controller site matches.
- [ ] Close the security, efficiency, and functionality gaps listed below.
- [ ] Run the staged update train (stable versions, one target at a time, snapshot first). Inventory is done (2026-10-04): 48 of 50 running containers have pending packages. Do not install without a window.
- [ ] Optional: move Postgres primary CT131 to prox2 only when a replica promote is acceptable.

### Completed This Phase
- ✅ Cluster NFS on vlan 922, server `10.92.2.200` (2026-09-30)
- ✅ prox2 guest VLANs `vmbr0923/924/925` on `enp4s0f1` (2026-09-30)
- ✅ SX3016F cutover and guest balance (2026-09-25)
- ✅ SX3016F adopted and managed from the Omada controller (2026-10-04)
- ✅ DHCP clients already use AdGuard (D-HOMELAB-018) (2026-10-04)

---

## Prioritized Backlog

### High Priority
- [ ] **AP site migration** — export the AP site, import it on CT142 as its own site, migrate only the access points, forget them on the old controller after they show Connected.
- [ ] **SG3428XMP discovery** — inform URL must be CT142 `10.92.0.34`, not the old `10.92.3.34`. Adopt only after port and VLAN profiles exist on the controller.
- [ ] **ER7206 capture and adopt** — last. Pre-build WAN, VLAN, DHCP, and firewall on the controller first.
- [ ] **Rotate the ER7206 password** stored in `documentation/SWITCH-SSH-KEY-SETUP.md` and remove it from git.

### Medium Priority
- [ ] **Postgres primary placement** — D-HOMELAB-016 wants CT131 on prox2. It stays on prox1 until a promote window.
- [ ] **prox1 guest VLAN layout** — storage `10.92.2.5` is up, but guest VLAN 923 still shares `ens3f0` with storage.

### Low Priority
- [ ] **HHV DNS/NPM + Next.js app**
- [ ] **Cloudigan Mail Gateway** — NPM + GitHub push
- [ ] **Cloudigan Vault MSP**
- [ ] **TIP Generator Phase 1**
- [ ] **Personal Ops Center**
- [ ] **LDC / QuantShift / chapter-hub-dev destroy** — approved retire later only

---

## Gaps to close

Security: gateway password in git; expired NPM cert #30; five client VMs with no working SSH. SG3428XMP and ER7206 are still outside the controller.

Efficiency: prox1 guest VLAN 923 still shares `ens3f0` with storage; Postgres primary still on prox1; `hdd-pool` degraded; TrueNAS media-pool is interim.

Functionality: access points still live on the other controller; SG3428XMP never appears for adoption; Intro Skipper analysis not confirmed; joel-win11 has no OS; Scrypted disconnects under load. Keep empty `vmbr0925`. SX3016F stays on the controller.

## Update train

Inventory versions first. Target current stable releases (30+ days old, no pre-release). Snapshot or STANDBY deploy before each change. Order: blue-green apps on STANDBY, then one LXC at a time, then one Proxmox node at a time, then TrueNAS, then the Omada controller. Skip a casual restart of CT131.

---

## Known Issues

- **Postgres primary is on prox1** — stopping CT131 can promote the replica.
- **Five client VMs still have no SSH**
- **joel-win11** — OS not installed
- **Scrypted** — Baichuan disconnects under multi-stream load
- **TrueNAS media-pool** — interim; evacuate before disk rebuild
- **NPM cert #30 expired** — tautulli NXDOMAIN
- **Intro Skipper** — plugin loaded; analysis completion not confirmed
