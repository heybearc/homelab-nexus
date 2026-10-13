# Patch rings

**Updated:** 2026-10-06 (HAProxy failover tested; Saturday window for environment outages)  
**Executor:** `scripts/ops/patch-cadence.sh` on prox1 (`/usr/local/sbin/patch-cadence.sh`)  
**Scheduler:** n8n on CT188, thin workflow only. n8n does not run apt itself.

Blue-green app containers were patched on both sides on 2026-10-05 and traffic is on the updated node. This plan covers the rest of the environment. Rings run in order. A later ring does not start because an earlier one succeeded.

## Rules

1. One ring per maintenance window. TrueNAS and Postgres never share a Saturday. A TrueNAS reboot is the disk under Postgres.
2. Environment-wide outages run Saturday 02:00 only: Postgres primary, TrueNAS, prox1, and an approved major app upgrade. Each gets its own Saturday. The job starts only after that week's approval. If the precheck fails, it aborts and posts to `homelab-patches`. It does not continue unattended.
3. `ansible/playbooks/system-update.yml` (`hosts: all`) is not an approved job. It upgrades every container with no standby order.
4. Apply mode refuses to run when `/etc/patch-cadence/HOLD` exists on prox1.
5. n8n may start a ring only after an approval step. Inventory (ring 0) and standby patch (ring 1 apply, no traffic switch) are the only unattended jobs.
6. Package updates use `apt-get upgrade` with existing conffiles kept. Not `dist-upgrade`, and not `@latest`.
7. Major app upgrades (Jellyfin 10.11.11 → 12.1 and anything that changes the app's major version) wait for an approval. When approved, they use a Saturday 02:00 window. They are not part of the OS cron.

## Ring 0 — Inventory

**Window:** Monday 07:10, already cronned. No changes.  
**Action:** `patch-cadence.sh check`. Summary to ntfy topic `homelab-patches`.  
Host pending counts and TrueNAS `update.check_available` are part of this report.

## Ring 1 — Blue-green apps

**Downtime:** none, when the standby health check passes before the switch.  
**Status:** current backlog done 2026-10-05. Both nodes patched. Live is the updated side.

This sequence is possible. `switch_traffic` moves the HAProxy backend, and it was used for these apps on 2026-10-05. The approved run is:

1. Patch and reboot the standby container.
2. Check its direct health URL. If it fails, stop and leave traffic alone.
3. Switch traffic. Standby becomes prod. Prod becomes standby.
4. Patch and reboot the new standby. Check its health URL. Do not switch back.

Sunday 02:10 still only does step 1. The switch is not in that cron until the health gate is in the script. A failed standby must not become production while nobody is watching.

Do not redeploy app git history for control-plane submodule commits. Cloudigan API listens on port 3000. The MCP source has that port. The running MCP process has to be reloaded before its health check will allow the next API switch.

## Ring 2 — Short failover

Schedule these. Do not cron them.

### HAProxy

Fixed 2026-10-06. CT136 is primary (priority 100). CT139 is backup (priority 90). The track script now uses `weight -20`, so a dead HAProxy process on the primary drops it below the backup and the VIP moves. Before this, a dead process stayed at priority 100 and the VIP never moved. CT139 now has the same `haproxy.cfg` as CT136.

Failover test: stopped keepalived on CT136, VIP was on CT139 within 1 second, `http://10.92.3.33/health` for `api.cloudigan.net` returned the green API, then CT136 took the VIP back within 2 seconds.

Later package updates of HAProxy use the same blue-green order: patch CT139, config test, move the VIP, patch CT136, move the VIP back to CT136 only after CT136 is healthy.

### Postgres

CT131 is the primary on prox1. CT151 is the replica. Stopping CT131 can promote the replica.

Saturday 02:00, and not on a TrueNAS Saturday:

1. One Saturday: patch and reboot CT151 only. Confirm replication catches up. Primary stays up. This does not take the environment down.
2. A later Saturday 02:00, only with that week's approval: patch CT131, or promote CT151 and patch the old primary after it is the replica. Abort if the replica is behind.

### Vaultwarden

CT171 is the HAProxy primary. CT172 is the backup server, with its own data directory. Patch CT172 only. Do not stop CT171 to “switch.”

## Ring 3 — Single containers

Each group is one evening. Reboot that container after apt. Confirm the service answers before the next group. Counts are the 2026-10-05 `apt-get -s upgrade` inventory.

| Group | Containers | Why this group |
|---|---|---|
| Media tools | Readarr 120, Radarr 124, Sonarr 125, SABnzbd 127, Calibre-Web 129, BookStack 130 | Reboot is local. No DNS or GPU. |
| Business apps | Kimai 111, NetBox 141, Uptime Kuma 153, LibreNMS 152, Vikunja 189, Plane 184, Zammad 186, Ops Hub 202 | User-facing, but not the edge. |
| Identity | Authentik 170 alone | Login path. |
| Automation | n8n 188 alone, run from prox1, not from the n8n workflow | The scheduler cannot patch itself. |
| Edge | AdGuard 140, then Technitium 145, then NPM 121 alone | DNS and HTTPS. One at a time. |
| Data and lab | Redis 192, qa-01 115, Ansible 183, chapter-hub-dev 119 | Redis is shared. Do it on its own night if other apps are busy. |
| Cameras | Scrypted 180 alone | Reboot drops camera streams. |
| GPU guests | Jellyfin 122 OS packages only. Plex 128 was already current. | Stop transcodes first. Do not install Jellyfin 12.1 here. |
| Skip | Omada 142 has mongosh 2.12.0 → 2.13.0 only. The controller image stays `mbentley/omada-controller:6.3.0.45`. | Docker image updates are a separate change. |

## Ring 4 — Proxmox hosts

Checked 2026-10-06. All three nodes are `pve-manager/9.2.20`, kernel `7.0.14-17-pve`.

| Node | Pending `upgrade` | Reboot order |
|---|---|---|
| prox2 | 38 | First. No GPU. Move live guests (Mail blue CT196, Chapter Hub blue CT193, AdGuard, Authentik, Vaultwarden blue, Omada) or accept their restart. |
| prox3 | 38 | Second. Live HAProxy CT136 is here. Finish the HAProxy window first so CT139 can hold the VIP. |
| prox1 | 53, including `pve-manager`. NVIDIA and a new kernel were not in this `upgrade` set. | Last. Postgres primary and the RTX 2080 SUPER are here. |

One node per window. Drain guests that can move, update, reboot, confirm `vmbr0923` and the 10G link, then move the guests back.

prox2 and prox3 can use a scheduled evening when migration is clean. prox1 is Saturday 02:00. Jellyfin and Plex pin the GPU and cannot move. The Postgres primary is also there. Do not drain prox1 on a TrueNAS Saturday.

NIC drivers (Intel 82599 `ixgbe` on all three nodes, I219/I210 on prox1, Broadcom BCM5720 on prox2/prox3) ship with the Proxmox kernel. They update when the kernel updates, which is a host reboot, not a container apt run. `apt-get upgrade` on 2026-10-06 did not show a new kernel. A later `dist-upgrade` might. Treat a new `pve-kernel` as this ring, not as ring 3.

## Ring 5 — TrueNAS

`truenas` `10.92.0.3` is version **25.04.2.6**. `midclt call update.check_available` returned `UNAVAILABLE` on 2026-10-06, so there is no confirmed update to install.

Container disks are raw files on `truenas-proxmox`, NFS `10.92.2.200`. A TrueNAS reboot pauses guests. When an update exists, it runs Saturday 02:00 after that week's approval, with no vzdump and no migration in progress. Apply from TrueNAS, not apt. If the precheck fails, abort and post to `homelab-patches`. Do not combine it with a Postgres promote or a prox1 reboot.

## Ring 6 — Firmware, quarterly

Not part of the weekly job.

| Hardware | Policy |
|---|---|
| NVIDIA RTX 2080 SUPER on prox1 | Debian DKMS `nvidia-driver` **550.163.01-2**, passed into Jellyfin CT122 and Plex CT128 (also stopped CT100/CT101). Hold `nvidia-*` so a host apt run cannot bump it. A driver update is its own window: stop Jellyfin and Plex, install the pinned 550 update if one exists, reboot prox1, confirm `/dev/nvidia0` inside CT122. Do not jump to a new major branch for its own sake. |
| Dell iDRAC prox2 `10.92.0.16`, prox3 `10.92.0.17` | BIOS, iDRAC, and NIC firmware from Dell while the node is empty. |
| prox1 | No BMC. Lenovo BIOS only when a specific fix is required. |
| SX3016F, SG3428XMP, ER7206 | Omada or vendor firmware. The ER7206 is still standalone. Not this apt plan. |

## n8n workflow

`Homelab patch ring` on CT188 SSHes to prox1 and runs the same commands as cron. A lock in the script makes the second caller log `already running` and exit. The script posts the log tail to `https://push.cloudigan.net/homelab-patches`.

| When | Command | Acts only when |
|---|---|---|
| Monday 07:10 | `check` | Always. Inventory only. |
| Tuesday 21:00 | `ring3` | That group's containers have packages. Empty group logs `no patches available` and the rotation still advances. |
| Wednesday 21:00 | `host prox2` | prox2 has packages. Otherwise no drain and no reboot. |
| Thursday 21:00 | `host prox3` | prox3 has packages. VIP moves to CT139 first and comes back to CT136 after the node returns. |
| Friday 21:00 | `ring2` | HAProxy, Postgres replica CT151, or Vaultwarden backup CT172 has packages. |
| Saturday 02:00 | `saturday` | If the current primary has packages, promote the replica so VIP `10.92.3.23` moves, then rebuild the old primary as the replica and patch that container. If the replica is not streaming, rebuild it from the primary and do not promote in that same broken state. If Postgres needs nothing, prox1 is next. If prox1 is clean, TrueNAS is checked and not rebooted. |
| Sunday 02:10 | `patch-standby` | The HAProxy standby for an app has packages. Traffic is not switched. |

`promote <app>`, `vaultwarden-primary`, and `truenas-apply` are on the script and on the n8n SSH allow-list. They are not on the cron. `truenas-apply` does not reboot TrueNAS.

Hold: `touch /etc/patch-cadence/HOLD` on prox1. Apply modes log `HELD` and exit 0. `check` and `plan` still run. The boot helper that returns evacuated guests ignores the hold.

## What is already installed

- prox1 cron: `/etc/cron.d/patch-cadence` (source `scripts/ops/patch-cadence.cron`).
- Script: `scripts/ops/patch-cadence.sh` installed at `/usr/local/sbin/patch-cadence.sh`.
- DNS standby helper: `scripts/ops/dns-standby-update.py`.
- n8n workflow deploy: `scripts/ops/deploy-patch-workflow.py`.
