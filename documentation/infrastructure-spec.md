# Proxmox Infrastructure Specification

## Network Architecture

### Core Network Configuration
- **Proxmox Host**: 10.92.0.5 (credentials: root/Cl0udy!!(@)
- **Internal DNS Server**: 10.92.0.10 (CRITICAL: All containers must use this as primary DNS)
- **Network Subnet**: 10.92.3.0/24
- **Nextcloud VM**: 10.92.3.2 (VMID 109, deployed 2025-07-22)
- **Retired Infrastructure**: docker-01 (previously at 10.92.3.2) - REMOVED 2025-07-22

### DNS Configuration Standards (Updated 2025-07-20)
- **Primary DNS**: 10.92.0.10 (REQUIRED for all LXC containers)
- **Fallback DNS**: 8.8.8.8, 1.1.1.1
- **Configuration File**: `/etc/resolv.conf` in each container
- **Standard Format**:
  ```
  nameserver 10.92.0.10
  nameserver 8.8.8.8
  nameserver 1.1.1.1
  ```
- **Issue**: Many containers had incorrect DNS (10.92.0.177) causing resolution failures
- **Resolution**: All containers audited and corrected to use 10.92.0.10

### Storage Configuration
- **NFS Share**: `/mnt/pve/nfs-data` (Proxmox host)
- **Bind Mount Pattern**: `mp=/mnt/data` (in LXC containers)
- **Data Structure**: 
  - `/mnt/data/media/` (Sonarr, Radarr content)
  - `/mnt/data/usenet/` (SABnzbd downloads)
  - `/mnt/data/torrents/` (Transmission downloads)

## LXC Container Configuration

### Container Management
- **Unprivileged Containers**: Default approach for security
- **TUN Device Support**: Required for VPN functionality
  ```
  lxc.cgroup2.devices.allow: c 10:200 rwm
  lxc.mount.entry: /dev/net dev/net none bind,create=dir
  ```

### Complete Container Inventory

#### Media Management Stack
1. **Transmission LXC** (ID: 126, IP: 10.92.3.9)
   - Hostname: transmission
   - Resources: 2 cores, 2048MB RAM, 8GB storage
   - NFS Mount: /mnt/pve/nfs-data → /mnt/data
   - Status: Running with VPN routing
   - Storage: hdd-pool:subvol-126-disk-0

2. **SABnzbd LXC** (ID: 127, IP: 10.92.3.16)
   - Hostname: sabnzbd
   - Resources: 2 cores, 2048MB RAM, 5GB storage
   - NFS Mount: /mnt/pve/nfs-data → /mnt/data (VERIFIED: Added 2025-07-20)
   - Status: Running with full VPN configuration
   - Storage: hdd-pool:subvol-127-disk-0
   - **Migration Status**: COMPLETE (Docker → LXC migration successful)
   - **VPN Configuration**: PIA VPN active with SSH preservation
   - **DNS Configuration**: Fixed to use 10.92.0.10 (was causing Usenet connectivity issues)
   - **Config Migration**: Docker configs from docker-01 successfully merged
   - **Web Interface**: http://10.92.3.16:7777
   - **Download Paths**: /mnt/data/downloads/incomplete, /mnt/data/downloads/complete

3. **Readarr LXC** (ID: 120, IP: 10.92.3.4)
   - Hostname: readarr
   - Resources: 2 cores, 1024MB RAM, 4GB storage
   - NFS Mount: /mnt/pve/nfs-data → /mnt/data (VERIFIED: Added 2025-07-20)
   - Status: Running and service healthy
   - Storage: hdd-pool:subvol-120-disk-0
   - **API Status**: Healthy (authentication fixed with new API key)
   - **VPN Configuration**: PIA VPN active with DNS resolution
   - **DNS Configuration**: Fixed to use 10.92.0.10
   - **Service Issues**: 521 errors are external (upstream metadata provider outage)
   - **Root Cause**: api.bookinfo.club unavailable (not a local issue)
   - **Local Service**: Fully operational, API endpoints responding correctly
   - **Recommendation**: Monitor upstream provider status for resolution

4. **Sonarr LXC** (ID: 125, IP: 10.92.3.8)
   - Hostname: sonarr
   - Resources: 2 cores, 1024MB RAM, 4GB storage
   - NFS Mount: /mnt/pve/nfs-data → /mnt/data
   - Status: Running
   - Storage: hdd-pool:subvol-125-disk-0

5. **Radarr LXC** (ID: 124, IP: 10.92.3.7)
   - Hostname: radarr
   - Resources: 2 cores, 1024MB RAM, 4GB storage
   - NFS Mount: /mnt/pve/nfs-data → /mnt/data
   - Status: Running
   - Storage: hdd-pool:subvol-124-disk-0

6. **Bazarr LXC** (ID: 117, IP: 10.92.3.15)
   - Hostname: bazarr
   - Resources: 2 cores, 1024MB RAM, 4GB storage
   - NFS Mount: /mnt/pve/nfs-data → /mnt/data (FIXED: Added 2025-07-20)
   - Status: Running with full media storage access
   - Storage: hdd-pool:subvol-117-disk-0
   - **Issue Resolved**: Missing NFS mount prevented media library access
   - **DNS Configuration**: Verified correct (10.92.0.10)

10. **Overseerr LXC** (ID: 122, IP: 10.92.3.5)
    - Hostname: overseerr
    - Resources: 2 cores, 1024MB RAM, 4GB storage
    - NFS Mount: /mnt/pve/nfs-data → /mnt/data (VERIFIED: Added 2025-07-21)
    - Status: Running
    - Storage: hdd-pool:subvol-122-disk-0
    - **DNS Configuration**: Fixed to use 10.92.0.10 (was causing GitHub connectivity issues)
    - **Version Status**: Currently on beta branch, ready to switch to main/stable
    - **Network Connectivity**: GitHub.com resolution and HTTPS access verified

11. **Calibre-Web LXC** (ID: 129, IP: 10.92.3.19)
    - Hostname: calibre-web
    - Resources: 2 cores, 2048MB RAM, 4GB storage
    - NFS Mount: /mnt/pve/nfs-data → /mnt/data (CONFIGURED: Added 2025-07-21)
    - Status: Running and fully functional
    - Storage: hdd-pool:subvol-129-disk-0
    - **Migration Status**: COMPLETE (Docker → LXC migration successful)
    - **Docker Config Source**: /home/docker/docker/appdata/calibre-web (docker-01)
    - **Configuration**: app.db, gdrive.db, gmail.json successfully migrated
    - **Book Library**: /mnt/data/books/library (NFS mounted)
    - **Upload Directory**: /mnt/data/books/uploads
    - **Web Interface**: http://10.92.3.19:8083 (fully accessible)
    - **DNS Configuration**: Fixed to use 10.92.0.10
    - **Service Status**: Running as cps process on port 8083
    - **Existing Books Found**: Multiple ebooks detected in /mnt/data (ready for import)

7. **Prowlarr LXC** (ID: 123, IP: 10.92.3.6)
   - Hostname: prowlarr
   - Resources: 2 cores, 1024MB RAM, 4GB storage
   - Status: Running
   - Storage: hdd-pool:subvol-123-disk-0

8. **Plex Media Server LXC** (ID: 128, IP: 10.92.3.17)
   - Hostname: plex
   - Resources: 4 cores, 4096MB RAM, 10GB storage
   - NFS Mount: /mnt/pve/nfs-data → /mnt/data (VERIFIED: Added 2025-07-20)
   - Status: Running and fully functional
   - Storage: hdd-pool:subvol-128-disk-0
   - **GPU Configuration**: NVIDIA RTX 2080 SUPER (TU104) passthrough ACTIVE
     - Device passthrough: /dev/nvidia0, /dev/nvidiactl, /dev/nvidia-uvm, /dev/nvidia-uvm-tools
     - LXC GPU permissions: c 195:0, c 195:255, c 243:0, c 243:1 (rwm)
     - Hardware transcoding: Enabled for Plex
     - NVIDIA drivers: DKMS modules built and loaded successfully
   - **Migration Status**: COMPLETE (Docker → LXC migration successful)
   - **Database Migration**: 212MB Plex database successfully migrated from Docker
   - **Claim Status**: Successfully claimed and linked to Plex account
   - **Server Name**: allens_media (configured in setup wizard)
   - **DNS Configuration**: Fixed to use 10.92.0.10 (primary)
   - **Plex Installation**: Complete via official repository
   - **Web Interface**: http://10.92.3.17:32400/web (fully accessible)
   - **Config Source**: /opt/community-scripts/plex.conf (Proxmox host)
   - **Features**: nesting=1, fuse=1, USB passthrough, GPU passthrough
   - **Tags**: community-script, media, gpu-transcoding
    - **Library Status**: Ready for manual library recreation in web UI
    - **Next Steps**: Complete setup wizard and recreate libraries pointing to /mnt/data paths

15. **Nextcloud VM** (ID: 109, IP: 10.92.3.2)
    - Hostname: nextcloud
    - Resources: 4 cores, 8192MB RAM
    - Storage: 
      - scsi0: 100GB (system drive)
      - scsi1: 825MB (EFI/boot)
      - scsi2: 2TB (data drive - mounted at /mnt/data)
    - Status: Running (deployed 2025-07-22)
    - SSH: Key-based authentication configured
    - Data Mount: /mnt/data (2TB dedicated storage, separate from Synology NFS)
    - Web Interface: http://10.92.3.2 (if configured)
    - **Migration Notes**: Replaced docker-01 VM at same IP address
    - **Storage Configuration**: New data drive requires fstab configuration for permanent mounting
    - **DNS Configuration**: Should use 10.92.0.10 (primary) per infrastructure standards
    - **Deployment Date**: 2025-07-22
    - **SSH Key Location**: /root/.ssh/id_rsa (Proxmox host)

#### Infrastructure Services
9. **Netbox IPAM** (ID: 118, IP: 10.92.3.18)
   - Hostname: netbox-ipam
   - Resources: 2 cores, 2048MB RAM, 8GB storage
   - Status: Running and fully functional
   - Storage: hdd-pool:subvol-118-disk-0
   - **Static Media Issue**: RESOLVED (2025-07-21)
   - **Django Configuration**: STATIC_ROOT set to /opt/netbox/netbox/static/
   - **Static Files**: 123+ files collected (21 CSS, 30 JS, 72 fonts)
   - **Nginx Configuration**: Fixed invalid proxy_set_header directives
   - **Service Status**: Gunicorn on port 8000, Nginx on port 80
   - **Web Interface**: http://10.92.3.18/ (fully functional with static assets)
   - **DNS Configuration**: Verified correct (10.92.0.10)
   - **Proxy Configuration**: NPM forwards netbox.cloudigan.net → 10.92.3.3 → 10.92.3.18
   - Web Interface: http://10.92.3.18:8000

9. **Nginx Proxy Manager** (ID: 121, IP: 10.92.3.3)
   - Hostname: npm
   - Resources: 2 cores, 1024MB RAM, 4GB storage
   - Status: Running
   - Storage: hdd-pool:subvol-121-disk-0

10. **AdGuard Home** (ID: 113, IP: 10.92.3.11)
    - Hostname: adguard
    - Resources: 1 core, 512MB RAM, 2GB storage
    - Status: Running
    - Storage: hdd-pool:subvol-113-disk-0

11. **Jump Host** (ID: 119, IP: 10.92.0.6)
    - Hostname: jump-host
    - Resources: 1 core, 512MB RAM, 8GB storage
    - Network: vmbr920 (management network)
    - Status: Running
    - Storage: local-lvm:vm-119-disk-0

#### Monitoring and Management
12. **Homarr Dashboard** (ID: 112, IP: 10.92.3.10)
    - Hostname: homarr
    - Resources: 3 cores, 6144MB RAM, 8GB storage
    - Status: Running
    - Storage: hdd-pool:subvol-112-disk-0
    - Note: Duplicate container 111 (stopped)

13. **Tautulli** (ID: 116, IP: 10.92.3.14)
    - Hostname: tautulli
    - Resources: 2 cores, 1024MB RAM, 4GB storage
    - Status: Running
    - Storage: hdd-pool:subvol-116-disk-0

14. **Overseerr** (ID: 122, IP: 10.92.3.5)
    - Hostname: overseerr
    - Resources: 2 cores, 2048MB RAM, 8GB storage
    - NFS Mount: /mnt/pve/nfs-data → /mnt/data (FIXED: Added 2025-07-20)
    - Status: Running with full media storage access
    - Storage: hdd-pool:subvol-122-disk-0
    - **Issue Resolved**: Missing NFS mount prevented media library scanning
    - **DNS Configuration**: Fixed to use 10.92.0.10 (was 10.92.0.177, causing GitHub access failures)
    - **Branch Status**: Switching from develop (beta) to master (stable) branch
    - **Web Interface**: http://10.92.3.5:5055

#### Utility Services
15. **FlareSolverr** (ID: 115, IP: 10.92.3.13)
    - Hostname: flaresolverr
    - Resources: 2 cores, 2048MB RAM, 4GB storage
    - Status: Running
    - Storage: hdd-pool:subvol-115-disk-0

16. **Cloudflare DDNS** (ID: 114, IP: 10.92.3.12)
    - Hostname: cloudflare-ddns
    - Resources: 1 core, 512MB RAM, 3GB storage
    - Status: Running
    - Storage: hdd-pool:subvol-114-disk-0

### Virtual Machine Inventory

#### Production VMs (Running)
1. **Docker Host** (ID: 109, docker-01)
   - Resources: 16384MB RAM, 500GB storage
   - Status: Running (PID: 138203)
   - Purpose: Legacy Docker containers (SABnzbd source)
   - IP: 10.92.3.2

2. **Domain Controller** (ID: 108, dc-01)
   - Resources: 12288MB RAM
   - Status: Running (PID: 37584)
   - Purpose: Active Directory services

3. **Windows Workstations**
   - **alexa-win** (ID: 102): 24576MB RAM, 512GB storage (PID: 37802)
   - **aby-win** (ID: 104): 24576MB RAM (PID: 39393)
   - **cory-win** (ID: 107): 131072MB RAM (PID: 69122)
   - **kennedy-win** (ID: 110): 24576MB RAM (PID: 55685)
   - **win10-test** (ID: 200): 4096MB RAM, 82GB storage (PID: 958501)

4. **Infrastructure Services**
   - **cloudy-renvis01** (ID: 106): 16384MB RAM (PID: 43750)

#### Stopped VMs
- **veeam-worker** (ID: 100): 6144MB RAM, 100GB storage
- **Cloudy-Lab-Win11-01** (ID: 101): 24576MB RAM, 512GB storage
- **Cloudy-Lab-Srv-01** (ID: 103): 16384MB RAM, 250GB storage
- **Cloudy-Lab-Win11-01a** (ID: 105): 12288MB RAM, 250GB storage

### Storage Infrastructure

#### Storage Pools
1. **hdd-pool (ZFS)**
   - Type: ZFS Pool
   - Total: 16.89TB
   - Used: 5.15TB (30.51%)
   - Available: 11.74TB
   - Primary storage for LXC containers

2. **ssd2-lvm (LVM Thin)**
   - Type: LVM Thin Pool
   - Total: 1.95TB
   - Used: 220.72GB (11.30%)
   - Available: 1.73TB
   - High-performance storage

3. **local (Directory)**
   - Type: Directory storage
   - Total: 98.50GB
   - Used: 42.91GB (43.56%)
   - Available: 50.54GB
   - System and ISO storage

4. **local-lvm (LVM Thin)**
   - Type: LVM Thin Pool
   - Total: 1.79TB
   - Used: 4.30GB (0.24%)
   - Available: 1.79TB
   - VM storage pool

## Docker Infrastructure (Legacy/Migration Source)

### Docker Host (10.92.3.2)
- **SABnzbd Containers**: 
  - `sabnzbd` (port 38080)
  - `sabnzbd-2` (port 38081)
  - Both using `binhex/arch-sabnzbdvpn:latest`
- **Configuration Paths**:
  - `/home/docker/docker/appdata/sabnzbd/config`
  - `/home/docker/docker/appdata/sabnzbd-2/config`

## VPN Configuration

### Private Internet Access (PIA) Setup
- **Credentials**: p5100894/v3QzWLpFPB
- **Server**: 185.242.4.2:1198 (UDP)
- **Certificates**: 
  - `ca.rsa.2048.crt`
  - `crl.rsa.2048.pem`

### VPN Routing Strategy
```bash
# Keep local network traffic local
route 10.92.3.0 255.255.255.0 net_gateway
# Route external traffic through VPN
route 0.0.0.0 128.0.0.0 vpn_gateway
route 128.0.0.0 128.0.0.0 vpn_gateway
```

### DNS Configuration
- **Internal DNS**: 10.92.0.10 (must be preserved during VPN connection)
- **DNS Persistence**: Required to prevent OpenVPN from overwriting

## Service Dependencies

### Media Stack Integration
- **Download Clients**: SABnzbd, Transmission
- **Media Managers**: Sonarr, Radarr, Readarr
- **Remote Path Mappings**: Required between Docker and LXC environments

### Systemd Service Ordering
```
OpenVPN → Download Clients → Media Managers
```

## Security Considerations

### Firewall/Killswitch Requirements
- **SSH Access**: Must remain available from local network (10.92.3.0/24)
- **VPN Killswitch**: Prevent data leaks if VPN disconnects
- **Local Network Bypass**: Essential for management access

### Access Credentials Summary
- **Proxmox**: root/Cl0udy!!(@
- **Docker Host**: root/!Snowfa11
- **LXC Containers**: root/Cloudy_92!

## Migration Status

### Completed
- [x] SABnzbd configuration migration from Docker to LXC
- [x] NFS mount configuration in LXC containers
- [x] TUN device enablement for VPN support

### In Progress
- [ ] SABnzbd VPN setup (killswitch blocking SSH issue)
- [ ] Readarr service restoration
- [ ] Complete Docker to LXC migration

### Planned
- [ ] Transmission optimization and cleanup
- [ ] Full Docker container decommissioning
- [ ] Backup and disaster recovery procedures

## Troubleshooting Patterns

### Common Issues
1. **SSH Connectivity**: Often blocked by overly restrictive killswitch rules
2. **DNS Resolution**: OpenVPN tends to overwrite internal DNS settings
3. **Service Dependencies**: Improper startup order causes failures
4. **File Permissions**: NFS mount permission issues between containers

### Recovery Procedures
1. **SSH Recovery**: Reset iptables rules via console access
2. **DNS Recovery**: Restore `/etc/resolv.conf` from backup
3. **Service Recovery**: Systematic restart in dependency order

## Scripts and Automation

### Available Scripts (Proxmox HDD Pool)
- `install_readarr.sh`
- `repair_readarr.sh` 
- `update_readarr.sh`

### Custom Configurations
- OpenVPN configurations with custom routing
- Systemd service files with proper dependencies
- Killswitch scripts (needs SSH-safe version)

## Future Considerations

### Potential Improvements
1. **Privileged LXC**: For better network control
2. **Container Orchestration**: Systematic service management
3. **Monitoring**: Health checks and alerting
4. **Backup Strategy**: Automated configuration backups

### Scalability
- Additional VPN endpoints
- Load balancing for download clients
- Redundant storage configurations

## Validation Rules and Automated Tests

### Pre-Change Validation Rules

#### Network Connectivity Rules
1. **SSH Access Preservation**
   - Rule: SSH must remain accessible from local network (10.92.3.0/24)
   - Test: `ssh -o ConnectTimeout=5 root@<container_ip> 'echo "SSH OK"'`
   - Failure Action: Abort change, restore previous state

2. **DNS Resolution Integrity**
   - Rule: Internal DNS (10.92.0.10) must remain primary resolver
   - Test: `nslookup google.com 10.92.0.10`
   - Validation: `/etc/resolv.conf` must contain `nameserver 10.92.0.10`

3. **NFS Mount Availability**
   - Rule: `/mnt/data` must remain accessible with proper permissions
   - Test: `ls -la /mnt/data && touch /mnt/data/test_write && rm /mnt/data/test_write`
   - Failure Action: Restore mount configuration

#### Service Dependency Rules
4. **Service Startup Order**
   - Rule: VPN → Download Clients → Media Managers
   - Test: Check systemd dependencies with `systemctl list-dependencies`
   - Validation: Ensure `Before=` and `After=` directives are correct

5. **Port Accessibility**
   - Rule: Required service ports must remain accessible
   - Test: `curl -s http://localhost:7777` (SABnzbd), `curl -s http://localhost:9091` (Transmission)
   - Timeout: 10 seconds maximum

### Post-Change Validation Tests

#### Automated Test Suite
```bash
#!/bin/bash
# infrastructure-validation.sh

set -e

echo "=== Infrastructure Validation Suite ==="

# Test 1: SSH Connectivity
echo "Testing SSH connectivity..."
for ip in 10.92.3.4 10.92.3.16; do
    if ! timeout 5 ssh -o StrictHostKeyChecking=no root@$ip 'echo "SSH OK"' 2>/dev/null; then
        echo "FAIL: SSH to $ip failed"
        exit 1
    fi
done
echo "PASS: SSH connectivity"

# Test 2: DNS Resolution
echo "Testing DNS resolution..."
for ip in 10.92.3.4 10.92.3.16; do
    if ! ssh root@$ip 'nslookup google.com 10.92.0.10 >/dev/null 2>&1'; then
        echo "FAIL: DNS resolution on $ip"
        exit 1
    fi
done
echo "PASS: DNS resolution"

# Test 3: VPN Routing (if VPN active)
echo "Testing VPN routing..."
for ip in 10.92.3.4 10.92.3.16; do
    # Check if VPN is active
    if ssh root@$ip 'ip addr show tun0 >/dev/null 2>&1'; then
        # Test external IP is VPN IP (not local)
        external_ip=$(ssh root@$ip 'curl -s --max-time 10 ifconfig.me')
        if [[ $external_ip == 10.92.* ]]; then
            echo "FAIL: VPN not routing traffic on $ip (IP: $external_ip)"
            exit 1
        fi
        echo "PASS: VPN routing on $ip (External IP: $external_ip)"
    fi
done

# Test 4: Service Health
echo "Testing service health..."
services=("sabnzbd:7777" "transmission-daemon:9091")
for service_port in "${services[@]}"; do
    service=${service_port%:*}
    port=${service_port#*:}
    for ip in 10.92.3.4 10.92.3.16; do
        if ssh root@$ip "systemctl is-active $service >/dev/null 2>&1"; then
            if ! ssh root@$ip "curl -s --max-time 5 http://localhost:$port >/dev/null"; then
                echo "FAIL: $service not responding on $ip:$port"
                exit 1
            fi
        fi
    done
done
echo "PASS: Service health"

# Test 5: NFS Mount Integrity
echo "Testing NFS mounts..."
for ip in 10.92.3.4 10.92.3.16; do
    if ! ssh root@$ip 'ls /mnt/data >/dev/null 2>&1'; then
        echo "FAIL: NFS mount not accessible on $ip"
        exit 1
    fi
    if ! ssh root@$ip 'touch /mnt/data/test_write_$ip && rm /mnt/data/test_write_$ip'; then
        echo "FAIL: NFS mount not writable on $ip"
        exit 1
    fi
done
echo "PASS: NFS mount integrity"

echo "=== All tests passed ==="
```

### Change Management Rules

#### Before Any Infrastructure Change
1. **Backup Current State**
   - Export LXC configurations: `pct config <id> > /backup/lxc-<id>-$(date +%Y%m%d).conf`
   - Backup service configurations: `tar -czf /backup/services-$(date +%Y%m%d).tar.gz /etc/systemd/system/`
   - Document current routing: `ip route show > /backup/routes-$(date +%Y%m%d).txt`

2. **Run Pre-Change Validation**
   - Execute validation suite
   - Verify all services are healthy
   - Confirm SSH access from management station

3. **Prepare Rollback Plan**
   - Document exact steps to revert changes
   - Identify rollback triggers (SSH loss, service failure)
   - Set maximum change window (30 minutes)

#### During Changes
4. **Incremental Testing**
   - Test SSH after each network/firewall change
   - Verify DNS resolution after VPN modifications
   - Check service status after configuration updates

5. **Change Boundaries**
   - **Never modify**: Core network configuration without console access
   - **Always preserve**: SSH access from 10.92.3.0/24
   - **Always backup**: Service configurations before modification
   - **Always test**: Each change incrementally

#### After Changes
6. **Full Validation Suite**
   - Run complete automated test suite
   - Verify all services are functional
   - Test end-to-end workflows (download → processing)
   - Monitor for 24 hours for stability

## Critical Issues and Resolutions (Updated 2025-07-20)

### DNS Configuration Issues
**Problem**: Multiple containers had incorrect DNS configuration (10.92.0.177) causing:
- GitHub repository access failures ("Could not resolve host: github.com")
- Usenet server connectivity failures in SABnzbd
- General external service resolution issues

**Root Cause**: Proxmox automatically configured containers with non-functional DNS server

**Resolution**: Systematic audit and correction of all container DNS configurations
- **Standard Fix**: Update `/etc/resolv.conf` in each container:
  ```
  nameserver 10.92.0.10
  nameserver 8.8.8.8
  nameserver 1.1.1.1
  ```
- **Affected Containers**: SABnzbd (127), Overseerr (122), and others
- **Verification**: `nslookup github.com` and `curl -s https://github.com`

### NFS Mount Configuration Gaps
**Problem**: Critical media containers missing NFS mounts preventing media library access:
- Bazarr (117): Could not access media for subtitle management
- Overseerr (122): Could not scan existing media library

**Root Cause**: Infrastructure deployment scripts did not consistently apply NFS mounts

**Resolution**: Added missing mount points to container configurations
- **Command**: `pct set <id> --mp0 /mnt/pve/nfs-data,mp=/mnt/data`
- **Verification**: Container restart, `mountpoint /mnt/data`, `df -h /mnt/data`
- **Result**: 42TB NFS storage now accessible in all media containers

### SABnzbd Docker-to-LXC Migration
**Challenge**: Migrate SABnzbd from Docker container on docker-01 to LXC container 127

**Complications Encountered**:
1. **SSH Access Issues**: docker-01 initially unreachable (wrong IP used)
2. **VPN Killswitch Conflicts**: Existing VPN configuration blocked all traffic
3. **Package Manager Locks**: dpkg/apt locks prevented software installation
4. **DNS Resolution**: Container couldn't resolve external hostnames
5. **Config File Locations**: Docker configs in nested subdirectories
6. **Disk Space**: /tmp full on source system during extraction

**Successful Resolution Process**:
1. **Network Connectivity**: Fixed DNS to 10.92.0.10
2. **VPN Configuration**: Implemented PIA VPN with SSH preservation
3. **Config Migration**: Direct extraction from docker-01:/home/docker/docker/appdata/
4. **Intelligent Merge**: Combined Docker configs with LXC installation
5. **Path Updates**: Migrated to /mnt/data/downloads/ structure
6. **Service Verification**: Confirmed web interface and API functionality

**Final State**: SABnzbd fully operational in LXC with VPN, NFS, and migrated configurations

### Plex Media Server Docker-to-LXC Migration (2025-07-21)
**Challenge**: Migrate Plex Media Server from Docker container on docker-01 to LXC container 128

**Migration Process**:
1. **LXC Container Setup**: Created with NVIDIA GPU passthrough and NFS mount
2. **Database Migration**: Successfully copied 212MB Plex database from Docker
3. **Service Configuration**: Plex Media Server installed via official repository
4. **Claim Process**: Server successfully claimed and linked to Plex account
5. **GPU Passthrough**: NVIDIA drivers built and loaded successfully
6. **DNS Configuration**: Fixed to use 10.92.0.10 for proper resolution

**Final State**: Plex fully operational in LXC with GPU transcoding, ready for library recreation

### Readarr API and Service Resolution (2025-07-21)
**Problem**: Readarr experiencing HTTP 521 errors and API authentication failures

**Troubleshooting Process**:
1. **Service Health Check**: Confirmed Readarr service running properly
2. **API Authentication**: Fixed by generating new API key and updating config
3. **VPN Configuration**: Ensured PIA VPN active with DNS resolution
4. **External Dependencies**: Identified upstream metadata provider outage

**Root Cause**: External service (api.bookinfo.club) unavailable - not a local issue
**Resolution**: Local service fully operational, monitoring upstream provider for resolution

### Netbox Static Media Resolution (2025-07-21)
**Problem**: Netbox web interface failing to load static assets (CSS, JS, fonts)

**Root Causes Identified**:
1. **Missing Static Directory**: /opt/netbox/netbox/static/ not created
2. **Django Configuration**: STATIC_ROOT not set in Django settings
3. **Static Files Collection**: collectstatic never run
4. **Nginx Configuration**: Invalid proxy_set_header directives

**Resolution Process**:
1. **Static Directory**: Created /opt/netbox/netbox/static/ with proper permissions
2. **Django STATIC_ROOT**: Added to configuration file
3. **File Collection**: Successfully ran collectstatic (123+ files: 21 CSS, 30 JS, 72 fonts)
4. **Nginx Fix**: Corrected invalid proxy_set_header directives
5. **Service Restart**: Nginx and Gunicorn restarted successfully
6. **Verification**: Static file serving confirmed working (HTTP 200 responses)

**Final State**: Netbox fully functional with all static assets loading properly

### Calibre-Web Docker-to-LXC Migration (2025-07-21)
**Challenge**: Migrate Calibre-Web from Docker container on docker-01 to LXC container 129

**Migration Process**:
1. **Container Discovery**: Located new Calibre-Web LXC container (ID 129, IP 10.92.3.19)
2. **Docker Config Extraction**: Retrieved configuration from /home/docker/docker/appdata/calibre-web
3. **Configuration Files Migrated**:
   - app.db (main database with user settings and library metadata)
   - gdrive.db (Google Drive integration database)
   - gmail.json (email configuration)
   - client_secrets.json (OAuth credentials)
4. **NFS Mount Configuration**: Added /mnt/data mount for book library storage
5. **Book Directory Setup**: Created /mnt/data/books/library and /mnt/data/books/uploads
6. **DNS Configuration**: Fixed to use 10.92.0.10 for proper resolution
7. **Service Verification**: Confirmed Calibre-Web running on port 8083

**Key Findings**:
- **Existing Books Discovered**: Multiple ebook files found in /mnt/data (ready for import)
- **Service Method**: Calibre-Web runs as 'cps' process (not systemd service)
- **Configuration Location**: Uses /root/.calibre-web/ for config storage
- **Web Interface**: Fully accessible at http://10.92.3.19:8083

**Final State**: Calibre-Web fully operational in LXC with migrated configuration and NFS book storage

### VPN Configuration Best Practices
**Lessons from SABnzbd VPN Setup**:

**SSH Preservation Rules**:
- Always allow local network traffic (10.92.3.0/24) before VPN routing
- Test SSH connectivity after each VPN configuration change
- Implement killswitch exceptions for management traffic

**DNS Handling with VPN**:
- VPN can override DNS settings - verify resolution after VPN activation
- Use IP fallbacks for critical services when DNS fails
- Monitor for DNS leaks that could expose local network

**Service Integration**:
- VPN must start before application services
- Application should bind to VPN interface (tun0) when available
- Implement health checks for both VPN and application

### Container Branch Management (Overseerr Example)
**Issue**: Overseerr running beta/develop branch instead of stable/master

**Investigation Process**:
1. **Installation Method**: Identified Proxmox community script source
2. **Default Behavior**: Script clones without specifying branch (defaults to develop)
3. **DNS Prerequisite**: Fixed DNS before attempting git operations

**Branch Switch Process**:
```bash
cd /opt/overseerr
systemctl stop overseerr
git fetch origin
git checkout master
git pull origin master
yarn install
yarn build
systemctl start overseerr
```

**Key Requirements**:
- DNS must be functional for GitHub access
- Service must be stopped during rebuild
- Dependencies may need reinstallation
- Build process can take several minutes

### Infrastructure Audit Methodology
**Systematic Approach Developed**:

1. **DNS Verification**: Check `/etc/resolv.conf` and test resolution
2. **NFS Mount Verification**: Confirm mount points and accessibility
3. **Service Status**: Verify systemd services and web interfaces
4. **Network Connectivity**: Test internal and external access
5. **Configuration Consistency**: Compare against infrastructure spec

**Automation Scripts Created**:
- DNS audit and remediation scripts
- NFS mount verification and addition scripts
- Service migration and configuration merge scripts
- Network connectivity validation scripts

### Emergency Recovery Procedures

#### SSH Access Lost
```bash
# Via Proxmox console
iptables -F
iptables -P INPUT ACCEPT
iptables -P FORWARD ACCEPT
iptables -P OUTPUT ACCEPT
systemctl restart ssh
```

#### DNS Resolution Broken
```bash
# Restore internal DNS
cp /etc/resolv.conf.backup /etc/resolv.conf
# Or manually set
echo "nameserver 10.92.0.10" > /etc/resolv.conf
```

#### Service Dependencies Broken
```bash
# Reset service order
systemctl disable openvpn-pia.service
systemctl disable sabnzbd.service
systemctl enable openvpn-pia.service
systemctl enable sabnzbd.service
# Restart in order
systemctl start openvpn-pia.service
sleep 10
systemctl start sabnzbd.service
```

### Project Boundary Enforcement

#### Scope Limitations
1. **No changes to Proxmox host network configuration** without explicit approval
2. **No modifications to core NFS storage** without backup
3. **No firewall rules that could block SSH** from management network
4. **No DNS changes** that break internal resolution
5. **No service modifications** without dependency analysis

#### Change Approval Matrix
- **Low Risk**: Service configuration tweaks, log level changes
- **Medium Risk**: New service installation, port changes
- **High Risk**: Network configuration, VPN setup, firewall rules
- **Critical Risk**: Storage configuration, core service removal

All Medium+ risk changes require validation suite execution and rollback plan.

## GitHub Integration and Repository Management

### GitHub Connectivity
- **Authentication Method**: Personal Access Token (PAT)
- **Storage Location**: `~/.git-credentials`
- **Username**: heybearc
- **Connection Type**: HTTPS
- **Repository URL Pattern**: https://github.com/heybearc/[repo-name].git

### Repository Structure
- **Primary Infrastructure Repository**: [homelab-nexus](https://github.com/heybearc/homelab-nexus)
  - **Local Path**: `/Users/cory/Documents/cascade/CascadeProjects/2048/personal/github/infrastructure/homelab-nexus`
  - **Content**: Automation scripts, documentation, configuration templates, utility scripts

### Connectivity Verification

```bash
# Verify GitHub API connectivity using stored PAT
curl -H "Authorization: token $(cat ~/.git-credentials | grep github | cut -d: -f3 | cut -d@ -f1)" https://api.github.com/user

# List repositories
curl -H "Authorization: token $(cat ~/.git-credentials | grep github | cut -d: -f3 | cut -d@ -f1)" https://api.github.com/user/repos
```

### Repository Management Rules
1. **Always verify GitHub PAT connectivity** before repository operations
2. **Use simple commit messages** to avoid potential issues
3. **Configure local git user settings** to match GitHub username:
   ```bash
   git config --local user.name "heybearc"
   git config --local user.email "cory.allen@dewdropsai.com"
   ```
4. **Backup repository configurations** before major changes
