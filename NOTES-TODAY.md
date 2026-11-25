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

## 2026-11-20

### Discoveries / Notes
- Fleet OS work is one container at a time. TheoShift green is the active app. See the `theoshift` handoff.
- CT132 is Ubuntu 26.04.1. The first attempt replaced Node 18 and was rolled back. The held retry kept Node 18, then Node 26 was installed beside it.
- `pct snapshot` is unavailable on `truenas-zvol`. Snapshots go through the TrueNAS plugin. Rollback only works for the newest snapshot.
- Proxmox hosts are already 9.2.0. Pending work is a package dist-upgrade, not a major version jump. Not applied.
- Postgres CT131 and CT151 stay on Debian 12. A Debian 13 upgrade would jump the Postgres major.

### Decisions to Promote
- None.

### Blockers / Risks
- Superseded 2026-11-21. TheoShift traffic is on green. See the `theoshift` handoff.

## 2026-11-21

### Discoveries / Notes
- TheoShift cutover is done. LIVE is green CT132. STANDBY is blue CT134. Both are Ubuntu 26.04.1 and Node 26. Details are in the `theoshift` handoff.
- NodeSource Node 18 and the three pre-upgrade ZFS snapshots were removed. There is no disk rollback to the old OS.
- Green `pm2 update` stopped the live app for about two minutes. The app was restored on Node 26 before Node 18 was removed.

### Decisions to Promote
- None.

### Blockers / Risks
- Do not switch TheoShift traffic unless asked. Notify-blast work is still open in the handoff.

## 2026-11-24

### Discoveries / Notes
- Fleet OS wave from 2026-11-21 finished. Logs on prox1 under `/var/log/os-upgrade/`. Debian media CT120, CT124, CT125, CT127, CT129 are Trixie. Scrypted CT180 is 26.04.
- `pct snapshot` fails when a guest has an `mp0` bind. Rollback for those disks is the TrueNAS zvol snapshot `pre-os-20261121`.
- Plex CT128 stayed on Ubuntu 24.04. NVIDIA 550 userspace packages are not installable after third-party apt sources are set aside. The service stayed up.
- App updates after the OS hop are still open except Kimai, BookStack, Vikunja, Documenso, API blue, FactorPoint blue, and Mail green.
- Traffic already switched: API live CT181, FactorPoint live CT185, Mail live CT197.

### Decisions to Promote
- Postgres OS and major upgrade are last. NVIDIA stays at 550.163.01-2. Node target for this wave is 26.13.1.

### Blockers / Risks
- Jellyfin CT122 was stopped in HA error because `/dev/nvidia-uvm` was missing. `nvidia-modprobe -u` created the nodes, HA was cleared, and the container started. `https://jellyfin.cloudigan.net/health` returns 200. OS is Ubuntu 26.04.
- LDC green CT135 had no address: `systemd-networkd` exited 243 on `ImportCredential`. A drop-in clears that, and the service is active on `10.92.3.25`. App rebuilt from `b0adbf1`, migrations applied, PM2 restarted by hand after `pm2 jlist` came back empty. Traffic switched to green. `https://ldctools.com/api/auth/providers` returns 200.
- QuantShift blue CT137 is Ubuntu 26.04 and Node 26.13.1. Traffic switched to blue. `https://quantshift.io/api/system/server-info` returns 200. Green CT138 was upgraded later the same day.
- Chapter Hub traffic switched to green CT194. Standby blue CT193 was then upgraded to Ubuntu 26.04.1 and Node 26.13.1. The first attempt rolled back because `npm` was not on PATH after the tarball extract. The prox1 script now calls `/usr/local/bin/npm` and keeps an existing `pre-os-20261121` snapshot. `https://hub.cloudigan.net/api/auth/providers` returns 200.
- HHV traffic switched to blue CT198. Standby green CT199 is Ubuntu 26.04.1 and Node 26.13.1. `https://helpfulhirschventures.com/` returns 200.
- LDC standby blue CT133 and QuantShift standby green CT138 are Ubuntu 26.04.1 and Node 26.13.1. Both health checks return 200. Quote Builder was not touched.
- CT172 `/alive` was a Docker NAT failure. Restarting Docker restored it. CT171 was upgraded to Ubuntu 26.04.1 and its Docker daemon was restarted the same way. Both `/alive` checks and `https://vault.cloudigan.com/alive` return 200. Bot CT100 is still Ubuntu 24.04 and trading. CT101 is already 26.04 and stopped.
- HAProxy standby CT139 is Ubuntu 26.04.1. Live CT136 was upgraded 22.04 → 24.04 → 26.04.1 while keepalived was masked and the VIP stayed on CT139. The first live attempt rolled back: `curl` was missing, then the disk was 508 MB short, then DNS had no nameservers. Disk was freed, `/etc/resolv.conf` is static (`10.92.3.10`, `10.92.3.203`), and the VIP is back on CT136. Public checks return 200.

## 2026-11-25

### Discoveries / Notes
- Plane on CT184 was crash-looping. Compose had started without `plane.env`, so the API looked for `plane-db`. Postgres `10.92.3.23` was up. Stack restarted with that env file. `space` health check now uses `wget`.
- theoshift-blue CT134 had `eth0` down. `systemd-networkd` exited 243 on credentials. Drop-in restored `10.92.3.24`.
- nginx-proxy CT121 was 92% full. Yarn cache, apt cache, journals, and old logs. Now 45%, journal capped at 50M.
- ops-stack CT202 and postgres-replica CT151 had no node_exporter. Both now answer on 9100.
- n8n CT188 could not reach Postgres because Docker NAT rules were gone. Restarting Docker restored masquerade. The public webhook is no longer 503.
- Watchdog only asked prox1, then tried to start containers that were already running on prox3. It now uses the cluster resource list and starts a container only when Proxmox says it is stopped. Service runs on system Python 3.14. The 3.12 venv is dead.
- `ContainerDown` is now `HostMetricsDown` (warning). TIP monitors are paused. ntfy test to `homelab-alerts` returned 200. The CT150 email relay still has an empty journal.
- LibreNMS CT152 is up with one never-polled device (`10.92.0.1`) and no alert rules.

### Decisions to Promote
- D-HOMELAB-022. Outbound mail uses Cloudigan Mail. `noreply@` does not take replies. Documenso stays `sales@`. Ops alerts use `notifications@cloudigan.com`.

### Blockers / Risks
- Email to `cory@cloudigan.com` is not proven. ntfy is the path that worked.
- Subscribe the phone to `https://push.cloudigan.net/homelab-alerts`. The topic is still world-readable.
