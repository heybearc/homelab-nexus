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

## 2026-11-18

### Discoveries / Notes
- Access points are in Cloudigan Lab. User confirmed the site move is done.
- Blue-green both colors, HAProxy CT136/CT139, AdGuard CT140, replica CT131, and bot standby CT101 are on `truenas-zvol`.
- CT151 is the Postgres primary. CT131 is in recovery and streaming from `10.92.3.21`.
- HAProxy VIP `10.92.3.33` returned to CT136 after the disk move. Standby config was copied from CT136 before the move.
- CT191 PBS snapshot used snapshot mode. The first clone delete hit EBUSY; a retry removed it.
- Bot failover is `quantshift-failover-monitor` on CT101. It does not stop CT100. HAProxy trader backends are unused.

### Decisions to Promote
- None.

### Blockers / Risks
- Forcing a bot failover while CT100 is trading leaves both sides running.
- Technitium CT145 and wave 5 single containers, including NPM CT121, moved to `truenas-zvol` on 2026-11-18. `https://omada.cloudigan.net` returned HTTP/2 200 after NPM started.
- Still on NFS after the afternoon moves: Postgres primary CT151 and the VMs. Authentik CT170, LibreNMS CT152, and QuantShift bot CT100 are on `truenas-zvol`. Bot equity and crypto services are active on CT100. The CT101 failover monitor is active. Standby bot services are inactive.
- prox3 iSCSI portal login is now automatic. prox1 is still manual.
- prox1 simulated dist-upgrade: ~125 packages, `pve-manager` 9.2.20 → 9.2.28, no new kernel. Saturday promote of CT131 would put Postgres back on prox1.
- RLH University containers, DNS, NPM, and a blue/green switch are done. Details are in the `rlh-university` handoff. Ansible playbooks for that standup are still uncommitted in this repo. The DB password file is gitignored.
- Incomplete vzdump working dirs remain for CT170 and CT152. Monitoring sync to CT150 failed (`scp: Connection closed`).

## 2026-11-19

### Discoveries / Notes
- Documenso is CT205 at 10.92.3.5 on `truenas-zvol`. https://sign.cloudigan.net returns the sign-in redirect.
- Database `documenso` is on the Postgres VIP 10.92.3.23 (primary CT151). Signup is limited to cloudigan.com and cloudigan.net.
- Outbound mail is a container SMTP relay that posts to Cloudigan Mail as noreply@cloudigan.com. A `documenso` API key is on mail blue and green.
- Graph accepted "Please confirm your email" at 2026-11-19 12:32Z and a plain "Your Documenso confirmation link" at 12:37Z, both to cory@cloudigan.com.
- Mail.Read is denied on the Graph app, so inbox, junk, and sent items could not be read.

### Decisions to Promote
- None.

### Blockers / Risks
- Confirmation messages are accepted by Graph and still not seen in the mailbox. Check Junk and Quarantine.
- Relay source sits in `ansible/playbooks/files/`, which `.gitignore` ignores, so a fresh clone does not contain it. The running copy is on CT205.
- Saturday must not promote CT131. CT151 stays the primary until it is the replica, then its disk can move off NFS.
