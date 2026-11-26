# Task State - homelab-nexus

**Last updated:** 2026-11-26

---

## Current Task
**Fleet OS upgrade** — launched 2026-11-21. Stable targets only: Debian 13, Ubuntu 26.04, Node 26.13.1. Postgres is last. NVIDIA 550.163.01-2 stays. Bind-mount guests use a TrueNAS zvol snapshot (`pre-os-20261121`), not `pct snapshot`.

### What I'm doing right now
SG3428XMP still does not announce to Omada. Hardware is 3.20 on firmware 3.20.28, which is the latest for that hardware. `controller discover` succeeds and sends no UDP. The inform URL is CT142. Ports 29810–29817 are closed on the switch. No device key in software; serial is `2247460000486`. Quote Builder stays parked.

### Recent completions
- ✅ **TheoShift OS cutover** — 2026-11-21. LIVE green CT132, STANDBY blue CT134. Record is the `theoshift` handoff. Node 18 and the pre-upgrade snapshots are gone.
- ✅ **Documenso** — 2026-11-18. CT205 on `truenas-zvol`, database `documenso` on VIP `10.92.3.23`, NPM `sign.cloudigan.net`. Outbound mail is a local SMTP relay into Cloudigan Mail as `sales@cloudigan.com` (2026-11-25). Signup limited to cloudigan.com and cloudigan.net.
- ✅ **zvol leftovers** — 2026-11-18. Stopped the stuck vzdump jobs, then moved Authentik CT170, LibreNMS CT152, and QuantShift bot primary CT100 onto `truenas-zvol`. Failover monitor on CT101 was stopped for the bot copy and is active again. CT151 remains the Postgres primary on NFS.
- ✅ **zvol waves 4–5** — 2026-11-18. Technitium CT145 and the single containers, including NPM CT121, are on `truenas-zvol`.
- ✅ **zvol wave** — 2026-11-17. Blue-green both colors, HAProxy CT136/CT139, AdGuard CT140, and replica CT131 are on `truenas-zvol`. PBS snapshot of CT191 succeeded. VIP `10.92.3.33` is back on CT136.
- ✅ **Host drain uses restart migration** — 2026-11-15. `pct migrate --online` still unimplemented through pve-container 6.1.18. `patch-cadence.sh` on prox1 uses `--restart` for containers and `qm migrate --online` for VMs. CT137 and VM106 started with `onboot=1`. CT190 `onboot=0`. VM107 `onboot=1`.
- ✅ **Postgres role switch repair** — 2026-10-17 02:00 promoted CT151 (`10.92.3.31`); VIP `10.92.3.23` stayed there. Quote-stripping bug aborted the CT131 rebuild. Replica restored the same morning (streaming, lag 0, slot `replica_131`). `replicator` password rotated. `max_wal_senders=10` on both. Script on prox1 and `origin/main` (`91b1596`)
- ✅ **Patch cadence** — cron on prox1 and n8n workflow Homelab patch ring. Empty targets log and skip. HOLD file pauses apply mode (2026-10-12)
- ✅ **Postgres role switch** — D-067 / D-HOMELAB-019. VIP `10.92.3.23` follows a promote. The old primary is rebuilt as the replica (2026-10-12)
- ✅ **Edge patch** — DNS standbys, Technitium CT145, AdGuard CT140, NPM CT121. OpenResty held for the SHA-1 repo key (2026-10-06)
- ✅ **Single containers and blue-green** — media, business, identity, automation, lab, cameras, monitoring, Vaultwarden, Jellyfin 12.2. HAProxy failover tested (2026-10-06)
- ✅ **adguard-2** — TrueNAS Docker `adguard-standby` renamed to `adguard-2` at `10.92.3.204` without a restart (2026-10-04)

### Next steps
1. Leave Quote Builder CT200/CT201 alone.
2. Vaultwarden is done. Both nodes are Ubuntu 26.04. Docker lost its NAT rules across the OS hop; `systemctl restart docker` puts them back. `/alive` returns 200 on CT171 and CT172.
3. QuantShift bot CT100 is still Ubuntu 24.04 and is trading. CT101 is already Ubuntu 26.04, stopped, `onboot=0`. Trading units on CT101 are disabled. Do not upgrade CT100 while it is the running copy.
4. Critical serial window, one at a time: Technitium CT145 is still Ubuntu 22.04. AdGuard CT140 is still Debian 12. NPM CT121 is already Trixie. HAProxy CT139 and CT136 are done.
5. Plex CT128 is still Ubuntu 24.04 and serving. The release upgrader stops on unmet NVIDIA 550 dependencies. Leave the driver. Snapshot `media-pool/proxmox/vm-128-disk-0@pre-os-20261121` is the rollback.
6. Postgres last. CT151 is the primary on NFS. Do not promote it back onto CT131/prox1. RLH CT203/CT204 need a file backup before any OS hop.
7. Leave CT100 and CT101 on `truenas-zvol`. Pre-build ER7206 WAN, LAN, DHCP, and leave ACLs at defaults. SG3428XMP inform URL is `10.92.0.34?dPort=29810&mPort=29814&omadacId=a23a83fab1d245662222e987420d81e7`. Do not adopt until it actually sends discovery.

### Queued
- None. RLH University is in `.cloudy-work/_cloudy-ops/handoffs/rlh-university.md`.

### Paused (unchanged)
- **HHV DNS/NPM + Next.js app**
- **Cloudigan Mail Gateway** — NPM + GitHub push
- **Cloudigan Vault MSP**
- **TIP Generator** — removed from the patch rotation. CT190 and CT191 are stopped, `onboot=0`, root disks on `truenas-zvol`.
- **LDC / QuantShift / chapter-hub-dev destroy** — approved retire later only

---

## Known Issues

- **vzdump can freeze a live LXC** — 2026-10-30 job `c9d7131d` suspended CT132 (theoshift-green) after a day-long rsync. Live was switched to blue CT134. The final rsync was still stuck when checked. Confirm the cgroup is thawed before treating green as standby.
- **Postgres primary is CT151** — checked 2026-11-18. CT131 on prox1 is the streaming replica (`pg_is_in_recovery=t`, no VIP). VIP `10.92.3.23` is on CT151. Saturday's promote would reverse that. CT151 root disk is still NFS.
- **No LXC live migration** — `pct migrate --online` still dies on pve-container 6.1.14 and 6.1.18 ("lxc live migration is currently not implemented"). Host patching uses `--restart` for containers and `qm migrate --online` for VMs. Guests without `onboot=1` stay stopped after the host `startall`.
- **prox1 storage VLAN is up** — `10.92.2.5` on `vmbr0922`. `ens3f0` still carries guest VLAN 923 as well as storage VLAN 922.
- **prox2 guest trunk is on `enp4s0f1`** — `vmbr0923/924/925` left 1G `eno1`. `vmbr0925` has no guests; its bridge MTU is pinned to 1500.
- **Five client VMs still no SSH** — ak1-ifw03-p001 `172.22.240.2` no route; GEO-ETL-D001 `10.60.148.101` no route; ak1-rtr03-p001 / DGG-UB-P002 / GEO-KALI-P001 vault password fail (guest ops also failed)
- **joel-win11** — VM created; OS not installed
- **Omada** — SG3428XMP `10.92.0.2` hardware 3.20, firmware 3.20.28 Build 20260509, MAC `B0-19-21-40-9C-65`, serial `2247460000486`. Inform URL is CT142. `controller discover` and re-saving the URL send no UDP (checked 2026-11-26, including a MAC capture). A syslog test to `10.92.0.34:514` did leave the switch; that host was removed. UDP 29810 to the switch gets no reply. No device key in software. SSH port 22 wedges; toggling it from the web API brings it back. Do not adopt. Do not cron discover. ER7206 is still standalone and SNMPv3 is authNoPriv/MD5 only.
- **Scrypted** — sustained Baichuan disconnect storm possible under multi-stream load; Garage `.remote` often empty; H.265 codec warnings; NFS EBUSY on prune
- **TrueNAS media-pool** — interim; evacuate before disk rebuild
- **Technitium** — production passwords (not `admin`/`admin`); API token for automation
- **prox `hdd-pool` DEGRADED** (verify current status)
- **NPM cert #30** — not attached to a live host. `adguard-2.cloudigan.net` cert is valid through 2027-01-02 (D-HOMELAB-007)
- **Host packages** — prox1 about 125 pending on 2026-11-18, including `pve-manager` 9.2.20 → 9.2.28. Simulated dist-upgrade showed no new `pve-kernel`. Running kernel `7.0.14-17-pve`. Enterprise repo 401. NVIDIA on prox1 is held. Pins in `scripts/ops/patch-cadence.sh`: `100 101 122 128 131`. TrueNAS 25.04.2.6 has no update. NPM OpenResty is held
- **AP controller** — `10.92.0.10` UI ports were closed on 2026-10-04. Access points are still on that controller
- **Intro Skipper** — installed; analysis completion not confirmed

---

## Uncommitted work

- None after this end-day commit.
- Do not force-push.

---

## Exact Next Command

```text
python3 -c 'import socket; s=socket.create_connection(("10.92.0.2",22),4); print("open")'
```

**Next action:** Leave the SG3428XMP unadopted. `controller discover` does not transmit on 3.20.28. Do not unrack it for a device key and do not cron discover. Leave Quote Builder, the live QuantShift bot, Plex's NVIDIA driver, and Postgres.

---

## Infrastructure quick reference

| Service | Primary | Notes |
|---------|---------|--------|
| prox1 | `10.92.0.5` | Lenovo P920, no BMC; GPU; storage `10.92.2.5` |
| prox2 | `10.92.0.6` | iDRAC `10.92.0.16`; tag `78F8XV1`; X520; `10.92.2.6`; guest trunk on `enp4s0f1` |
| prox3 | `10.92.0.7` | iDRAC `10.92.0.17`; tag `8W72DZ1`; X520; `10.92.2.7` + guest trunk on `enp4s0f1` |
| TrueNAS | `10.92.0.3` / NFS `10.92.2.200` | LAG on SX3016F ports 3–4 |
| Switch | SG3428XMP `10.92.0.2` | uplink port 25 → SX3016F |
| SX3016F | `10.92.0.4` | jumbo 9216; TrueNAS LAG; host ports unbonded (D-HOMELAB-017) |
| Omada | CT142 `10.92.0.34` | **8 GB** RAM; `omada.cloudigan.net` |
| Scrypted | CT180 `10.92.3.15` | Driveway `.184`, Garage `.189`, Front Porch `.190` |
| Quote Builder | CT200/201 `.100`/`.101` | blue on prox2, green on prox3 |
| Jellyfin | CT122 `10.92.3.20` | Intro Skipper 1.10.11.24; `jellyfin.cloudigan.net` |
| Plan | `.cursor/plans/3-node_cluster_architecture_*.plan.md` | Hybrid NFS + local |
