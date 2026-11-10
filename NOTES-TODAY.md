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
