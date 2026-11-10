# Task State - homelab-nexus

**Last updated:** 2026-11-10

---

## Current Task
**Patch cadence** — container rings caught up. prox2 and prox3 host packages wait for their night windows because LXC live migration is not implemented.

### What I'm doing right now
Script on prox1 matches `scripts/ops/patch-cadence.sh`. Wednesday 21:00 reboots prox2 in place. Thursday 21:00 reboots prox3. Do not reboot prox1 while CT131 is the Postgres primary.

### Recent completions
- ✅ **Postgres role switch repair** — 2026-10-17 02:00 promoted CT151 (`10.92.3.31`); VIP `10.92.3.23` stayed there. Quote-stripping bug aborted the CT131 rebuild. Replica restored the same morning (streaming, lag 0, slot `replica_131`). `replicator` password rotated. `max_wal_senders=10` on both. Script on prox1 and `origin/main` (`91b1596`)
- ✅ **Patch cadence** — cron on prox1 and n8n workflow Homelab patch ring. Empty targets log and skip. HOLD file pauses apply mode (2026-10-12)
- ✅ **Postgres role switch** — D-067 / D-HOMELAB-019. VIP `10.92.3.23` follows a promote. The old primary is rebuilt as the replica (2026-10-12)
- ✅ **Edge patch** — DNS standbys, Technitium CT145, AdGuard CT140, NPM CT121. OpenResty held for the SHA-1 repo key (2026-10-06)
- ✅ **Single containers and blue-green** — media, business, identity, automation, lab, cameras, monitoring, Vaultwarden, Jellyfin 12.2. HAProxy failover tested (2026-10-06)
- ✅ **adguard-2** — TrueNAS Docker `adguard-standby` renamed to `adguard-2` at `10.92.3.204` without a restart (2026-10-04)

### Next steps
1. Let Wednesday 21:00 reboot prox2 and Thursday 21:00 reboot prox3. Guests stay on the node.
2. Saturday 02:00 may patch prox1 only when Postgres needs nothing. CT131 is the primary.
3. Site-migrate the access points onto CT142. Import creates a new site. Do not use Controller Migration.
4. Point the SG3428XMP inform URL at `10.92.0.34`. Capture the ER7206 and adopt it last.

### Paused (unchanged)
- **HHV DNS/NPM + Next.js app**
- **Cloudigan Mail Gateway** — NPM + GitHub push
- **Cloudigan Vault MSP**
- **TIP Generator** — removed from the patch rotation. CT190 and CT191 are stopped.
- **LDC / QuantShift / chapter-hub-dev destroy** — approved retire later only

---

## Known Issues

- **vzdump can freeze a live LXC** — 2026-10-30 job `c9d7131d` suspended CT132 (theoshift-green) after a day-long rsync. Live was switched to blue CT134. The final rsync was still stuck when checked. Confirm the cgroup is thawed before treating green as standby.
- **Postgres primary is CT131 on prox1** — promoted 2026-11-07. CT151 is the replica. Do not reboot prox1 outside Saturday's procedure.
- **No LXC live migration** — `pct migrate --online` dies with "lxc live migration is currently not implemented". `--restart` shuts the container down and starts it on the other node.
- **prox1 storage VLAN is up** — `10.92.2.5` on `vmbr0922`. `ens3f0` still carries guest VLAN 923 as well as storage VLAN 922.
- **prox2 guest trunk is on `enp4s0f1`** — `vmbr0923/924/925` left 1G `eno1`. `vmbr0925` has no guests; its bridge MTU is pinned to 1500.
- **Five client VMs still no SSH** — ak1-ifw03-p001 `172.22.240.2` no route; GEO-ETL-D001 `10.60.148.101` no route; ak1-rtr03-p001 / DGG-UB-P002 / GEO-KALI-P001 vault password fail (guest ops also failed)
- **joel-win11** — VM created; OS not installed
- **Omada** — CT142 manages the SX3016F. SG3428XMP never appears for adoption. Access points are on the other controller. ER7206 is not adopted.
- **Scrypted** — sustained Baichuan disconnect storm possible under multi-stream load; Garage `.remote` often empty; H.265 codec warnings; NFS EBUSY on prune
- **TrueNAS media-pool** — interim; evacuate before disk rebuild
- **Technitium** — production passwords (not `admin`/`admin`); API token for automation
- **prox `hdd-pool` DEGRADED** (verify current status)
- **NPM cert #30** — not attached to a live host. `adguard-2.cloudigan.net` cert is valid through 2027-01-02 (D-HOMELAB-007)
- **Host packages** — prox1 about 60 (enterprise repo 401), prox2 42, prox3 42. PVE 9.2.20. NVIDIA on prox1 is held. TrueNAS 25.04.2.6 has no update. NPM OpenResty is held
- **AP controller** — `10.92.0.10` UI ports were closed on 2026-10-04. Access points are still on that controller
- **Intro Skipper** — installed; analysis completion not confirmed

---

## Uncommitted work

- None after this end-day commit.
- Do not force-push.

---

## Exact Next Command

```text
ssh -F .cloudy-work/ssh_config_master.conf prox1 'test ! -f /etc/patch-cadence/HOLD && echo HOLD_ABSENT || echo HOLD_SET; ls -1t /var/log/patch-cadence | head -20'
```

**Next action:** Confirm CT132 is thawed and blue is still live. Then read patch logs since 2026-10-17 and confirm the Postgres roles. Omada site migration stays the next manual adoption step.

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
