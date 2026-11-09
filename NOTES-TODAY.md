---
date: 2026-11-09
purpose: Scratchpad for today's discoveries (promote on /end-day)
---

## Today

### Focus
- Checkpoint the Oct 30 backup freeze and the PBS roadmap. No new cluster work this session.

### Discoveries / Notes
- 2026-10-30 job `c9d7131d` (02:00, mode snapshot) reached CT132 theoshift-green at 14:07 the day before. NFS raw root disks cannot snapshot, so vzdump logged `mode failure` and used suspend mode.
- The first rsync moved 23.53 GB in about 24 hours. The final sync then froze the container. Ping and TCP connect still worked. Userspace did not. Traffic was switched to blue (CT134, `10.92.3.24`).
- The stuck rsync was writing `/mnt/pve/truenas-backups/dump/vzdump-lxc-132-2026_10_29-14_07_06.tmp` and was in `rpc_wait_bit_killable`. This session did not stop that job or thaw the cgroup.
- A second job, `edc48ab7` (daily), also includes CT132.
- PBS is a separate backup server. A new NFS export does not make an LXC disk snapshotable. Zvols via the TrueNAS Proxmox plugin do, and that plugin needs TrueNAS 25.10. This cluster is on 25.04.2.6.

### Decisions to Promote
- D-HOMELAB-020: stop adding vzdump-to-NFS jobs. PBS datastore on its own ZFS dataset. Live blue-green color stays out of any job that can suspend.

### Blockers / Risks
- CT132 may still be frozen if that vzdump is running.
- Patch logs after 2026-10-17, including Saturday 2026-10-24 and later, are still unread.

### Links / Commands
- Roadmap: `IMPLEMENTATION-PLAN.md` Phase 3, "PBS and snapshot-capable container disks"
