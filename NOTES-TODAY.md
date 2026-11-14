---
date: 2026-11-10
purpose: Scratchpad for today's discoveries (promote on /end-day)
---

## Today

### Focus
- Close patch-cadence gaps. Remove TIP Generator from the rotation.

### Discoveries / Notes
- Saturday 2026-11-07 promoted CT131. CT151 is the replica. prox1 was not rebooted.
- prox2 and prox3 host jobs aborted because `pct migrate --online` is unimplemented. One failed migrate used to cancel the node.
- Sunday patched standbys only. Six apps were promoted 2026-11-09. FactorPoint green and TheoShift blue were patched in place today.
- Missed rings ran today: edge, data, cameras, gpu, and a new retired group (LDC, QuantShift, bots 100/101). Omada CT142 got OS packages. Controller image unchanged.
- Monday `check` stopped early because SSH ate the container list. `run_node` now uses `ssh -n`.

### Decisions to Promote
- None. Host behavior is recorded in `documentation/PATCH-RINGS.md`.

### Blockers / Risks
- Wednesday prox2 and Thursday prox3 will reboot every guest on that node. Live FactorPoint is on prox2.
- TrueNAS is still 25.04.2.6 with no update. PBS still needs 25.10 for zvols.

### Links / Commands
- `scripts/ops/patch-cadence.sh`
- `documentation/PATCH-RINGS.md`

---
date: 2026-11-14
purpose: Scratchpad for today's discoveries (promote on /end-day)
---

## Today

### Focus
- Finish the access-point move onto Cloudigan Lab, then prepare the ER7206 adopt.

### Discoveries / Notes
- Site Migration (Global View → Settings → Migration) put every AP on CT142. The site is Home Network. Controller Migration was not used.
- Garage AP was powered off during the first wave, then brought over. All APs are on that site.
- Alma on Home Network and Alma on Cloudigan Lab match on the visible fields. The key is hidden. VLAN is Default on both.
- This Mac reached the internet after the AP move.
- Adopting the ER7206 overwrites the live router with the Cloudigan Lab Internet and LAN. Copy the standalone LAN list first. DHCP DNS stays AdGuard `10.92.3.11` and `10.92.3.204`. Do not retag the SX3016F.

### Decisions to Promote
- None. Gateway stays unadopted until the controller LAN list matches the router.

### Blockers / Risks
- Move to Site replaces AP config with the destination site. A mismatched Alma key drops clients.
- March `NETWORK-INFRASTRUCTURE.md` is older than the VLAN split. Do not type those VLAN IDs onto the controller without checking the router.

### Links / Commands
- CT142 `https://omada.cloudigan.net` (`10.92.0.34`)
