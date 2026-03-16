# CT180 Scrypted NVR Deployment

**Date:** 2026-03-16  
**Status:** Deployed - Pending Automation Backfill

---

## Container Details

- **CTID:** 180 (Utility range: 180-189)
- **Hostname:** scrypted
- **IP Address:** 10.92.3.15/24
- **Gateway:** 10.92.3.1
- **Network:** vmbr0923 (VLAN 923)
- **Resources:** 16GB RAM, 8GB swap, 48GB root + 48GB data volume
- **Type:** Unprivileged LXC
- **OS:** Ubuntu (via Scrypted official image)

## Deployment Method

**Used:** Scrypted official Proxmox installation script  
**Command:** `VMID=180 bash install-scrypted-proxmox.sh`

**Why not MCP provisioning pipeline:**
- Scrypted requires specific pre-configured container image
- Hardware passthrough for GPU/Coral devices
- Pre-installed software and optimized configuration
- Official script handles all Scrypted-specific requirements

## Current Status

### ✅ Completed
- Container created with CTID 180
- Network configured on correct VLAN (vmbr0923)
- Static IP assigned: 10.92.3.15/24
- Scrypted web interface accessible: https://10.92.3.15:10443/
- Hardware passthrough configured (GPU, Coral, USB)
- Container set to start on boot

### ❌ Pending Automation Backfill

The following infrastructure automation components need to be added manually:

1. **Netbox IPAM Registration**
   - Register VM in Netbox
   - Create network interface
   - Assign IP 10.92.3.15
   - **Blocker:** Need Netbox API token

2. **NPM Reverse Proxy**
   - Create proxy host: scrypted.cloudigan.net → 10.92.3.15:10443
   - Enable SSL certificate
   - **Blocker:** Need NPM credentials

3. **DNS A Record**
   - Add to DC01 (Windows AD DNS): scrypted.cloudigan.net → 10.92.3.15
   - **Note:** NOT AdGuard - use AD DNS
   - **Blocker:** Need DC01 access/credentials

4. **Monitoring Agents**
   - Install node_exporter (Prometheus metrics)
   - Install promtail (Loki log shipping)
   - Configure to ship to monitoring-stack (CT150)

5. **Proxmox Backup Schedule**
   - Configure backup job for CT180
   - Schedule: Daily at 02:00
   - Retention: keep-last=7,keep-weekly=4,keep-monthly=3
   - Storage: local

## Access Information

- **Web Interface:** https://10.92.3.15:10443/ or https://scrypted.cloudigan.net:10443/ (after DNS)
- **SSH:** `ssh root@10.92.3.15`
- **Default Password:** `scrypted` (should be changed on first login)

## Next Steps

### Immediate (Manual Configuration)
1. Access Scrypted web interface
2. Change default root password
3. Configure Google Nest camera integration
4. Add TrueNAS NFS mount for recordings storage

### Infrastructure Automation (Requires Credentials)
1. Get Netbox API token from http://10.92.3.11
2. Get NPM credentials for http://10.92.3.33:81
3. Get DC01 credentials for DNS management
4. Run automation scripts:
   ```bash
   cd /Users/cory/Projects/homelab-nexus
   
   # Netbox registration
   ./scripts/provisioning/netbox-register.sh --name scrypted --ctid 180 --ip 10.92.3.15 --function utility
   
   # NPM proxy (if domain needed)
   ./scripts/provisioning/npm-create-proxy.sh --domain scrypted.cloudigan.net --ip 10.92.3.15 --port 10443 --ssl
   
   # DNS (manual via DC01 or script if available)
   # Add A record: scrypted.cloudigan.net → 10.92.3.15
   
   # Monitoring
   ./scripts/provisioning/install-monitoring.sh --ctid 180 --ip 10.92.3.15
   
   # Backup
   ./scripts/provisioning/configure-backup.sh --ctid 180
   ```

## Storage Configuration

The container has two volumes:
- **Root:** 48GB (`local-lvm:vm-180-disk-0`)
- **Data:** 48GB (`local-lvm:vm-180-disk-1`) mounted at `/root/.scrypted/volume`

### Adding TrueNAS NFS for Recordings

To add TrueNAS storage for camera recordings:

```bash
# On Proxmox host
pct set 180 -mp1 /mnt/truenas/media-pool/recordings,mp=/mnt/recordings

# Or manually in container
ssh root@10.92.3.15
mkdir -p /mnt/recordings
echo "10.92.0.3:/mnt/media-pool/recordings /mnt/recordings nfs defaults 0 0" >> /etc/fstab
mount -a
```

## Lessons Learned

1. **Specialized containers benefit from official installers** - Scrypted's pre-configured image saved significant setup time
2. **Network configuration critical** - Must use correct bridge (vmbr0923) for VLAN 923
3. **Automation can be backfilled** - Core deployment first, infrastructure integration second
4. **Document exceptions** - Not all containers fit the standard provisioning pipeline

## Related Documentation

- Container Naming Standard: `/documentation/container-naming-standard.md`
- Provisioning Pipeline: `/scripts/provisioning/README.md`
- MCP Server: `/Users/cory/Projects/mcp-server-proxmox/README.md`
