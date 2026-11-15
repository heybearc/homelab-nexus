---
date: 2026-11-10
purpose: Scratchpad for today's discoveries (promote on /end-day)
---

## 2026-11-15

### Discoveries / Notes
- TrueNAS updated 25.04.2.6 → 25.10.8. Pool stayed online. Internet path is the ER7206, not the NAS.
- PBS is VM 110 on prox2, datastore `homelab` (4 TB sparse zvol, excluded from its own backup). UI `https://pbs.cloudigan.net` via NPM `10.92.3.3`.
- Plugin 2.1.24 on prox1/2/3. Transport is iSCSI on `10.92.2.200`, not NVMe/TCP.
- Lab servers use Technitium `.10` and `.203`. AdGuard stays on the DHCP path. `10.92.3.19` is not a resolver.
- prox1 enterprise apt source returned 401 and is disabled. prox1 still has pending package upgrades.
- Six abandoned vzdump working directories remain under the backup export.

### Decisions to Promote
- D-HOMELAB-021. Servers query Technitium. Published names point at NPM.

### Blockers / Risks
- Existing guest disks are still raw files on NFS. Snapshot backups of those LXCs can still suspend them.

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

---
date: 2026-11-15
purpose: Scratchpad for today's discoveries (promote on /end-day)
---

## Today

### Focus
- Explain stopped guests, then keep the next host reboot from leaving them down.

### Discoveries / Notes
- CT137 `quantshift-blue` and VM106 `cloudy-renvis01` were stopped by host `startall` because `onboot` was off. Both are running with `onboot=1`. CT190 `tip-blue` stays stopped with `onboot=0`. VM107 `cory-win` now has `onboot=1`.
- `pve-container` 6.1.18 still rejects LXC live migration. prox1 `/usr/local/sbin/patch-cadence.sh` now uses `pct migrate --restart` and `qm migrate --online`.
- VM106 booted with a warning: EFI 2011 certificates are expired. Enroll the 2023 keys only while the VM is shut down, and disable BitLocker protectors first.
- Stripe MCP connects with the new agent key after a full Cursor restart. Account is Cloudigan IT Solutions LLC. Expire the old restricted key.
- Proxmox MCP ticket refresh is in the local `mcp-server-proxmox` tree (not this repo). From this Mac, `10.92.0.5:8006` was unreachable (`EHOSTUNREACH`).

### Decisions to Promote
- None. Host migration behavior is in `documentation/PATCH-RINGS.md`.

### Blockers / Risks
- CT191 `tip-green` is still running. The Level B archive said both tip containers were stopped.
- Next prox2/prox3 window will restart containers while they move. Pinned guests stay.

### Links / Commands
- `scripts/ops/patch-cadence.sh`
- `documentation/PATCH-RINGS.md`
