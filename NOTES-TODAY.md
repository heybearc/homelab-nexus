---
date: 2026-10-04
purpose: Scratchpad for today's discoveries (promote on /end-day)
---

## Today

### Focus
- Correct the client DNS plan so AdGuard still filters every client

### Discoveries / Notes
- Pointing Omada DHCP at Technitium skips AdGuard, so the network loses ad and DNS filtering.
- DHCP clients already use AdGuard. SX3016F is already managed by our controller.
- Access points move by Site Migration onto CT142. Controller Migration would collide with the existing site.
- SG3428XMP has never appeared. Old notes point it at `10.92.3.34`; the controller is `10.92.0.34`.
- CT142 OS packages are current. Omada runs as Docker `mbentley/omada-controller:6.3.0.45`. Data stays in `/opt/omada/data`. The host `tpeap` service is disabled.

### Decisions to Promote
- D-HOMELAB-018 recorded: DHCP DNS is AdGuard `10.92.3.11` and `10.92.3.204`. Technitium is AdGuard upstream and zone authority only.

### Blockers / Risks
- 

### Links / Commands
- 

## 2026-10-05

### Discoveries / Notes
- This Mac's Wi-Fi is healthy: 802.11ax channel 48, about −47 dBm, 0% loss, 1200 Mbps. The access-point controller at `10.92.0.10` still answers ping, but its UI ports are closed.
- NPM cert #30 is not attached to a live proxy host. The other names from that bundle already have their own certs.
- `adguard-2.cloudigan.net` is `10.92.3.204`. Renamed the TrueNAS Docker container from `adguard-standby` to `adguard-2` without a restart. Data stays in `/mnt/media-pool/vms/dns-stack/adguard-standby`.
- 48 of 50 running containers have pending packages. Nothing was installed. Jellyfin is 10.11.11 with 12.1 waiting. Postgres, live HAProxy, NPM, AdGuard, and Technitium need a maintenance window.

### Decisions to Promote
- Standby AdGuard container name is `adguard-2`. IP stays `10.92.3.204`.
