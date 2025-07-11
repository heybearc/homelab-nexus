# Proxmox Infrastructure Specification

## Network Architecture

### Core Network Configuration
- **Proxmox Host**: 10.92.0.5 (credentials: root/Cl0udy!!(@)
- **Internal DNS Server**: 10.92.0.10
- **Network Subnet**: 10.92.3.0/24
- **Docker Host**: 10.92.3.2 (docker-01, credentials: root/!Snowfa11)

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
   - Status: Running, VPN setup in progress
   - Storage: hdd-pool:subvol-127-disk-0
   - Note: Missing NFS mount configuration

3. **Readarr LXC** (ID: 120, IP: 10.92.3.4)
   - Hostname: readarr
   - Resources: 2 cores, 1024MB RAM, 4GB storage
   - Status: Running but service issues
   - Storage: hdd-pool:subvol-120-disk-0

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
   - Status: Running
   - Storage: hdd-pool:subvol-117-disk-0

7. **Prowlarr LXC** (ID: 123, IP: 10.92.3.6)
   - Hostname: prowlarr
   - Resources: 2 cores, 1024MB RAM, 4GB storage
   - Status: Running
   - Storage: hdd-pool:subvol-123-disk-0

#### Infrastructure Services
8. **Netbox IPAM** (ID: 118, IP: 10.92.3.18)
   - Hostname: netbox-ipam
   - Resources: 2 cores, 2048MB RAM, 8GB storage
   - Status: Running (HTTP/1.1 accessible)
   - Storage: hdd-pool:subvol-118-disk-0
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
    - Status: Running
    - Storage: hdd-pool:subvol-122-disk-0

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
