---
date: 2026-09-22
purpose: Scratchpad for today's discoveries (promote on /end-day)
---

## Today

### Focus
- 

### Discoveries / Notes
- prox1 was up; Tailscale accept-routes blackholed LAN. Nodes advertise 10.92.0.0/16 but `--accept-routes=false` plus ip rule pref 5190.
- prox2 (R720xd `78F8XV1`) drained to prox1, X520 installed, cluster 3/3. Guests still on prox1.
- SX3016F adopted `10.92.0.4`, jumbo 9216. Uplink 3428:25. prox2 ports 7/8 trunked. Do not adopt Omada gateway.
- prox2 `10.92.2.6/24` on `enp4s0f0.922` pings and NFS-mounts TrueNAS `10.92.2.200`. storage.cfg still `.3.200`.
- Next: LACP TrueNAS onto SX3016F (spare DAC first, then move 3428 port 26). Then `.2.5`/`.2.7` and remount.

### Decisions to Promote
- 

### Blockers / Risks
- 

### Links / Commands
- 
