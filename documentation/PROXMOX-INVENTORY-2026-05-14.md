# Proxmox + TrueNAS Inventory Snapshot

**Date:** 2026-05-14  
**Source:** Live queries from `prox` and `truenas`

## Running LXC (39)

| CTID | Hostname | IP |
|------|----------|-----|
| 100 | quantshift-bot-primary | 10.92.3.27 |
| 101 | quantshift-bot-standby | 10.92.3.28 |
| 111 | kimai | 10.92.3.76 |
| 115 | qa-01 | 10.92.3.13 |
| 119 | bni-toolkit-dev | 10.92.3.12 |
| 120 | readarr | 10.92.3.4 |
| 121 | nginx-proxy | 10.92.3.3 |
| 124 | radarr | 10.92.3.7 |
| 125 | sonarr | 10.92.3.8 |
| 127 | sabnzbd | 10.92.3.16 |
| 128 | plex | 10.92.3.17 |
| 129 | calibre-web | 10.92.3.19 |
| 130 | bookstack | 10.92.3.50 |
| 131 | postgresql | 10.92.3.21 |
| 132 | theoshift-green | 10.92.3.22 |
| 133 | ldctools-blue | 10.92.3.23 |
| 134 | theoshift-blue | 10.92.3.24 |
| 135 | ldctools-green | 10.92.3.25 |
| 136 | haproxy | 10.92.3.26 |
| 137 | quantshift-blue | 10.92.3.29 |
| 138 | quantshift-green | 10.92.3.30 |
| 139 | haproxy-standby | 10.92.3.32 |
| 140 | adguard | 10.92.3.11 |
| 141 | netbox | 10.92.3.18 |
| 142 | omada-controller | 10.92.0.34 |
| 150 | monitoring-stack | 10.92.3.2 |
| 151 | postgres-replica | 10.92.3.31 |
| 152 | librenms | 10.92.3.81 |
| 153 | uptime-kuma | 10.92.3.82 |
| 170 | authentik | 10.92.3.75 |
| 180 | scrypted | 10.92.3.15 |
| 181 | cloudigan-api-blue | 10.92.3.181 |
| 182 | cloudigan-api-green | 10.92.3.182 |
| 183 | ansible-control | 10.92.3.90 |
| 184 | plane | 10.92.3.51 |
| 185 | factorpoint-blue | 10.92.3.183 |
| 186 | zammad | 10.92.3.77 |
| 187 | factorpoint-green | 10.92.3.187 |
| 188 | n8n | 10.92.3.79 |
| 189 | vikunja | 10.92.3.80 |
| 190 | tip-blue | 10.92.3.91 |
| 191 | tip-green | 10.92.3.92 |
| 192 | redis-shared | 10.92.3.93 |

## VMs (7)

| VMID | Name | Status |
|------|------|--------|
| 102 | alexa-win | running |
| 103 | Cloudy-Lab-Srv-01 | stopped |
| 104 | aby-win | running |
| 106 | cloudy-renvis01 | running |
| 107 | cory-win | running |
| 108 | dc-01 | running |
| 110 | kennedy-win | stopped |

## TrueNAS SCALE apps (apps bridge 10.92.5.200)

| App | State | Version | Portal |
|-----|-------|---------|--------|
| nextcloud | RUNNING | 2.3.23 | :9002 |
| aistor | RUNNING | 1.1.12 | :9001 |
| vaultwarden | RUNNING | 1.6.14 | :8080 |

## SSH key audit (2026-05-16)

- `homelab_root` verified on all 39 running LXCs; installed on 9 (kimai, bni-toolkit, haproxy-standby, postgres-replica, librenms, uptime-kuma, zammad, n8n, vikunja)
- `dc-01` (VM 108): fixed `administrators_authorized_keys` formatting; `homelab_root` works
- See **D-HOMELAB-005** / control plane **D-041**

## Remediation applied

- Updated `.cloudy-work/ssh_config_master.conf` and synced to `~/.ssh/config.d/homelab.conf`
- Updated `_cloudy-ops/context/APP-MAP.md` and `_cloudy-ops/ssh/homelab-hosts.txt`
