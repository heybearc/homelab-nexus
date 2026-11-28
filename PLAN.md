# homelab-nexus Plan

**Last updated:** 2026-11-27
**Current phase:** Omada gateway. Access points are in Cloudigan Lab on CT142. Gateway adopt is still open.
**Status:** Access points moved into Cloudigan Lab. SG3428XMP has never appeared. ER7206 is still standalone. Zvol cutover is in progress.

---

## Current Phase

### Active Work
- [x] Move access points with Site Migration onto CT142 (2026-11-14). Site name is Home Network. Do not use Controller Migration.
- [x] Move those access points from Home Network into Cloudigan Lab (2026-11-17).
- [ ] Get the SG3428XMP to show Pending. Capture its standalone config before any Adopt click.
- [ ] Capture the ER7206 and adopt it last, after the controller site matches.
- [ ] Close the security, efficiency, and functionality gaps listed below.
- [x] Patch cadence installed (2026-10-12). Cron on prox1 and n8n. Saturday promotes Postgres. See D-HOMELAB-019.
- [x] First Saturday promote ran 2026-10-17. Rebuild failed on quoted replicator password, then CT131 was restored streaming. Script fix is `91b1596`.
- [x] Read patch logs through 2026-11-09. Saturday 2026-11-07 promoted CT131. CT151 was rebuilt as the replica.
- [x] CT151 datadir was empty on 2026-11-26. Rebuilt again from CT131. Streaming. Stay on PostgreSQL 17.12 (D-HOMELAB-024).

### Completed This Phase
- ✅ Cluster NFS on vlan 922, server `10.92.2.200` (2026-09-30)
- ✅ prox2 guest VLANs `vmbr0923/924/925` on `enp4s0f1` (2026-09-30)
- ✅ SX3016F cutover and guest balance (2026-09-25)
- ✅ SX3016F adopted and managed from the Omada controller (2026-10-04)
- ✅ DHCP clients already use AdGuard (D-HOMELAB-018) (2026-10-04)
- ✅ Patch cadence and Postgres role switch (D-HOMELAB-019, D-067) (2026-10-12)

---

## Prioritized Backlog

### High Priority
- [x] **AP site migration** — access points are in Cloudigan Lab on CT142 (2026-11-17).
- [ ] **SG3428XMP discovery** — hardware 3.20, firmware 3.20.28 Build 20260509 (2026-11-26). `V3.36` `3.30.7` does not apply. Inform URL is CT142. `controller discover` sends no UDP. Serial `2247460000486` is in software; the device key is only on the sticker and does not make it announce. Adopt only after it transmits and port/VLAN profiles exist.
- [ ] **ER7206 capture and adopt** — last. Pre-build WAN, VLAN, DHCP, and firewall on the controller first.
- [ ] **Rotate the ER7206 password** stored in `documentation/SWITCH-SSH-KEY-SETUP.md` and remove it from git.
- [ ] **PBS and snapshot-capable container disks** — 85 disks are on iSCSI `truenas-zvol`. Still on NFS `truenas-proxmox`: VM105–108, CT151, CT203, CT204, and the PBS cloud-init image. Backup jobs target PBS. NFS `truenas-backups` still holds the old archives. Do not remove either export yet. D-HOMELAB-027.
- [x] **Documenso** — CT205 https://sign.cloudigan.net (2026-11-18). Confirmation mail is accepted by Graph and not yet seen in the mailbox.

### Medium Priority
- [ ] **Postgres primary placement** — as of 2026-11-18 CT151 is the primary on prox3 and CT131 is the streaming replica on prox1. Do not let Saturday promote CT131. Do not reboot the primary outside Saturday's procedure.
- [ ] **prox1 guest VLAN layout** — storage `10.92.2.5` is up, but guest VLAN 923 still shares `ens3f0` with storage.

### Low Priority
- [ ] **HHV DNS/NPM + Next.js app**
- [ ] **Cloudigan Mail Gateway** — NPM + GitHub push
- [ ] **Cloudigan Vault MSP**
- [x] **TIP Generator** — archived. CT190 and CT191 are stopped and removed from the patch rotation (2026-11-10).
- [x] **Personal Ops Center** — live as Ops Hub, CT202, https://ops.cloudigan.net (D-065, 2026-10-06). Planner follow-up stays in the ops-hub repo.
- [ ] **LDC / QuantShift / chapter-hub-dev destroy** — approved retire later only

---

## Gaps to close

Security: gateway password in git; expired NPM cert #30; five client VMs with no working SSH. SG3428XMP and ER7206 are still outside the controller.

Efficiency: prox1 guest VLAN 923 still shares `ens3f0` with storage; Postgres primary is CT151 on prox3 as of 2026-10-17; `hdd-pool` degraded; TrueNAS media-pool is interim.

Functionality: access points are on CT142 site Home Network, not yet in Cloudigan Lab; SG3428XMP never appears for adoption; Intro Skipper analysis not confirmed; joel-win11 has no OS; Scrypted disconnects under load. Keep empty `vmbr0925`. SX3016F stays on the controller.

## Update train

The cadence in `documentation/PATCH-RINGS.md` is the update train. Sunday patches blue-green standbys only, not TIP Generator. Saturday promotes Postgres when the primary has packages, and prox1's host packages wait for a Saturday when Postgres needs nothing. TrueNAS is not applied by the cron. Do not reboot prox1 while CT131 is the primary outside that procedure. Guest migrate failure does not cancel a prox2 or prox3 host update.

---

## Known Issues

- **Postgres primary is CT151 on prox3** as of 2026-11-18, with CT131 streaming on prox1. Saturday's package promote would put the VIP back on CT131. Do not restart the current primary outside Saturday's procedure.
- **Five client VMs still have no SSH**
- **joel-win11** — OS not installed
- **Scrypted** — Baichuan disconnects under multi-stream load
- **TrueNAS media-pool** — interim; evacuate before disk rebuild
- **NPM cert #30 expired** — tautulli NXDOMAIN
- **Intro Skipper** — plugin loaded; analysis completion not confirmed
