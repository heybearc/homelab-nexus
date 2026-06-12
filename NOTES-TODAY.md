---
date: 2026-06-12
purpose: Scratchpad for today's discoveries (promote on /end-day)
---

## Today

### Focus
- Scrypted Reolink CX810 integration + NVR recording
- PM2 / decommission cleanup (ldc-tools, quantshift, factorpoint legacy)

### Discoveries / Notes
- Three Reolink CX810 on `10.92.0.184` / `.189` / `.190`; ports HTTP 80, RTSP 554, ONVIF 8000, RTMP 1935 (9000 Baichuan still open)
- `@apocaliss92/scrypted-reolink-native` works before RTSP/ONVIF enabled; add cameras with **unique `uid` = IP** when same model (otherwise one device overwrites)
- NVR mixin id **31** + object detection **35** on cams 60–62; **3/3** licenses; recordings on TrueNAS NFS `/mnt/recordings` (~227 GB after ~1 day continuous)
- Stale Nest dirs (`scrypted-27`–`30`) removed; ~27 GB freed; slow NFS delete on `.events` metadata
- Garage main recording folder tiny vs remote/adaptive — snapshots OK; verify timeline naming/aim
- ldc-tools (CT133/135) + quantshift (CT137/138) stopped; factorpoint `registry-gateway` + `OHIO_SOS_*` env removed

### Decisions to Promote
- Reolink Native plugin + uid-per-IP for multi-CX810 in Scrypted (see DECISIONS D-HOMELAB-010)

### Blockers / Risks
- `cloudigan.com` AD conditional forward on Technitium still pending (from DNS cutover)
- Reolink admin password has `@` — may break RTSP; alphanumeric recommended
- Continuous NVR ~85 GB/camera/day at 2K — set explicit retention days on 21 TB pool when ready

### Links / Commands
- Scrypted: https://scrypted.cloudigan.net
- Verify recordings: `ssh scrypted 'df -h /mnt/recordings; du -sh /mnt/recordings/scrypted-6*'`
