# homelab-nexus Plan

**Last updated:** 2026-10-04
**Current phase:** 10G fabric
**Status:** Storage path and prox2 guest trunk are in place

---

## Current Phase

### Active Work
- [ ] Omada DHCP cutover to Technitium (D-HOMELAB-013). Do not adopt the Omada gateway.
- [ ] Optional: move Postgres primary CT131 to prox2 only when a replica promote is acceptable.

### Completed This Phase
- ✅ Cluster NFS on vlan 922, server `10.92.2.200` (2026-09-30)
- ✅ prox2 guest VLANs `vmbr0923/924/925` on `enp4s0f1` (2026-09-30)
- ✅ SX3016F cutover and guest balance (2026-09-25)

---

## Prioritized Backlog

### High Priority
- [ ] **Omada DHCP cutover** — Technitium becomes DHCP DNS. Do not adopt the Omada gateway.

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

## Known Issues

- **Postgres primary is on prox1** — stopping CT131 can promote the replica.
- **Five client VMs still have no SSH**
- **joel-win11** — OS not installed
- **Scrypted** — Baichuan disconnects under multi-stream load
- **TrueNAS media-pool** — interim; evacuate before disk rebuild
- **NPM cert #30 expired** — tautulli NXDOMAIN
- **Intro Skipper** — plugin loaded; analysis completion not confirmed
