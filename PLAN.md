# homelab-nexus Plan

**Last updated:** 2026-10-24
**Current phase:** Patch cadence after the first role switch. Omada adoption is still open.
**Status:** Cron and n8n run the rings. Saturday 2026-10-17 promoted CT151 and the CT131 rebuild was repaired the same morning (`91b1596`). Logs after that, including Saturday 2026-10-24, are unread. Access points are still on the other controller. SG3428XMP has never appeared for adoption.

---

## Current Phase

### Active Work
- [ ] Move access points with Site Migration onto CT142. Do not use Controller Migration.
- [ ] Get the SG3428XMP to show Pending. Capture its standalone config before any Adopt click.
- [ ] Capture the ER7206 and adopt it last, after the controller site matches.
- [ ] Close the security, efficiency, and functionality gaps listed below.
- [x] Patch cadence installed (2026-10-12). Cron on prox1 and n8n. Saturday promotes Postgres. See D-HOMELAB-019.
- [x] First Saturday promote ran 2026-10-17. Rebuild failed on quoted replicator password, then CT131 was restored streaming. Script fix is `91b1596`.
- [ ] Read patch logs after 2026-10-17, including Saturday 2026-10-24, and confirm CT151 primary / CT131 streaming.

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
- [ ] **AP site migration** — export the AP site, import it on CT142 as its own site, migrate only the access points, forget them on the old controller after they show Connected.
- [ ] **SG3428XMP discovery** — inform URL must be CT142 `10.92.0.34`, not the old `10.92.3.34`. Adopt only after port and VLAN profiles exist on the controller.
- [ ] **ER7206 capture and adopt** — last. Pre-build WAN, VLAN, DHCP, and firewall on the controller first.
- [ ] **Rotate the ER7206 password** stored in `documentation/SWITCH-SSH-KEY-SETUP.md` and remove it from git.

### Medium Priority
- [ ] **Postgres primary placement** — as of 2026-10-17 the primary is CT151 on prox3 and CT131 is the replica. Saturday's procedure can promote again. Do not restart the current primary outside that window. Confirm roles before acting.
- [ ] **prox1 guest VLAN layout** — storage `10.92.2.5` is up, but guest VLAN 923 still shares `ens3f0` with storage.

### Low Priority
- [ ] **HHV DNS/NPM + Next.js app**
- [ ] **Cloudigan Mail Gateway** — NPM + GitHub push
- [ ] **Cloudigan Vault MSP**
- [ ] **TIP Generator Phase 1**
- [x] **Personal Ops Center** — live as Ops Hub, CT202, https://ops.cloudigan.net (D-065, 2026-10-06). Planner follow-up stays in the ops-hub repo.
- [ ] **LDC / QuantShift / chapter-hub-dev destroy** — approved retire later only

---

## Gaps to close

Security: gateway password in git; expired NPM cert #30; five client VMs with no working SSH. SG3428XMP and ER7206 are still outside the controller.

Efficiency: prox1 guest VLAN 923 still shares `ens3f0` with storage; Postgres primary is CT151 on prox3 as of 2026-10-17; `hdd-pool` degraded; TrueNAS media-pool is interim.

Functionality: access points still live on the other controller; SG3428XMP never appears for adoption; Intro Skipper analysis not confirmed; joel-win11 has no OS; Scrypted disconnects under load. Keep empty `vmbr0925`. SX3016F stays on the controller.

## Update train

The cadence in `documentation/PATCH-RINGS.md` is the update train. Sunday patches blue-green standbys only. Saturday promotes Postgres when the primary has packages. TrueNAS is not applied by the cron. Skip a casual restart of the current primary.

---

## Known Issues

- **Postgres primary was CT151 on prox3** as of 2026-10-17, with CT131 streaming. A later Saturday promote may have moved it. Do not restart the current primary outside that procedure.
- **Five client VMs still have no SSH**
- **joel-win11** — OS not installed
- **Scrypted** — Baichuan disconnects under multi-stream load
- **TrueNAS media-pool** — interim; evacuate before disk rebuild
- **NPM cert #30 expired** — tautulli NXDOMAIN
- **Intro Skipper** — plugin loaded; analysis completion not confirmed
