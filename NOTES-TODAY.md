---
date: 2026-10-24
purpose: Scratchpad for today's discoveries (promote on /end-day)
---

## Today

### Focus
- Checkpoint the Oct 17 Postgres role switch. No new work this session.

### Discoveries / Notes
- Saturday 2026-10-17 02:00 promoted CT151 (prox3, `10.92.3.31`). VIP `10.92.3.23` stayed there. The old primary CT131 was wiped, then `pg_basebackup` failed because the replicator password kept its wrapping quotes.
- CT131 was rebuilt the same morning. It is in recovery, streaming from `10.92.3.21`, lag 0, slot `replica_131` active. `max_wal_senders` is 10 on both nodes. The `replicator` password was rotated for that rebuild.
- `91b1596` is on `origin/main` and was already installed at `/usr/local/sbin/patch-cadence.sh` on prox1.
- Patch windows after 2026-10-17, including Saturday 2026-10-24 02:00, were not read in this session.

### Decisions to Promote
- 

### Blockers / Risks
- No standby until that rebuild. The standby was restored on 2026-10-17 and has not been rechecked since.
- A later Saturday promote could move the primary again. Do not treat CT151 as permanent without reading `/var/log/patch-cadence/`.

### Links / Commands
- `git show 91b1596 -- scripts/ops/patch-cadence.sh`
