# Network Topology Documentation

## Overview
This document describes the complete network architecture for the Proxmox homelab infrastructure.

## Network Segments

### Management Network (10.92.0.0/23)
- **Purpose**: Infrastructure management and control
- **Gateway**: 10.92.0.1
- **DNS**: 10.92.0.10 (AdGuard Home)
- **DHCP Range**: 10.92.0.100-10.92.1.254

#### Key Hosts
| Host | IP | Purpose | Access |
|------|----|---------|---------| 
| Proxmox Host | 10.92.0.5 | Hypervisor | SSH, Web UI (8006) |
| DNS Server | 10.92.0.10 | AdGuard Home | Web UI (3000) |
| Jump Host | 10.92.0.6 | SSH Gateway | SSH only |

### Services Network (10.92.3.0/24)
- **Purpose**: Application and service hosting
- **Gateway**: 10.92.3.1
- **DNS**: 10.92.0.10 (AdGuard Home)
- **Static Range**: 10.92.3.2-10.92.3.50

#### Service Allocation
| Service Type | IP Range | Purpose |
|-------------|----------|---------|
| Legacy Docker | 10.92.3.2 | Docker host (migration source) |
| Infrastructure | 10.92.3.3-10.92.3.12 | Core services |
| Media Stack | 10.92.3.13-10.92.3.20 | Media management |
| Future Services | 10.92.3.21-10.92.3.50 | Expansion |

## Virtual Bridges

### vmbr920 (Management Bridge)
- **Network**: 10.92.0.0/23
- **Purpose**: Management traffic
- **Connected**: Proxmox host, Jump host

### vmbr923 (Services Bridge)
- **Network**: 10.92.3.0/24
- **Purpose**: Service traffic
- **Connected**: All LXC containers, Docker host

### vmbr924 (Future Bridge)
- **Network**: TBD
- **Purpose**: Future network segmentation
- **Status**: Available for expansion

## DNS Configuration

### Internal DNS (AdGuard Home - 10.92.0.10)
- **Primary Function**: DNS filtering and internal resolution
- **Upstream DNS**: Cloudflare (1.1.1.1, 1.0.0.1)
- **Filtering**: Ad blocking, malware protection
- **Custom Records**: Internal service resolution

### DNS Records
```
# Infrastructure
proxmox.local         → 10.92.0.5
dns.local            → 10.92.0.10
jump.local           → 10.92.0.6

# Services
netbox.local         → 10.92.3.18
proxy.local          → 10.92.3.3
dashboard.local      → 10.92.3.10
transmission.local   → 10.92.3.9
sabnzbd.local        → 10.92.3.16
```

## VPN Configuration

### Download Client VPN
- **Provider**: Private Internet Access (PIA)
- **Protocol**: OpenVPN
- **Affected Services**: Transmission, SABnzbd
- **Routing**: All traffic through VPN tunnel
- **Killswitch**: Blocks traffic if VPN disconnects

### VPN Network Flow
```
Download Client → VPN Tunnel → Internet
     ↓
Local Network (SSH/Management) → Direct Route
```

## Firewall Rules

### Container-Level Rules
- **SSH Access**: Allow from management network
- **Service Ports**: Allow from services network
- **VPN Traffic**: Route through tunnel interface
- **Killswitch**: Block all traffic if VPN down

### Network-Level Rules
- **Inter-VLAN**: Controlled routing between segments
- **Internet Access**: Via gateway with filtering
- **Management Access**: Restricted to admin networks

## Storage Network

### NFS Shares
- **Source**: Proxmox host `/mnt/pve/nfs-data`
- **Mount Point**: Container `/mnt/data`
- **Purpose**: Shared media storage
- **Access**: Media management containers

### Storage Flow
```
NFS Server (Proxmox) → Network Share → Container Mount
/mnt/pve/nfs-data   → NFS Protocol → /mnt/data
```

## Monitoring Points

### Network Monitoring
- **Connectivity**: Ping tests between segments
- **DNS Resolution**: Query response times
- **VPN Status**: Tunnel connectivity
- **Bandwidth**: Traffic analysis

### Key Metrics
- Network latency between segments
- DNS query success rate
- VPN connection stability
- Storage network performance

## Troubleshooting

### Common Network Issues
1. **DNS Resolution Failure**
   - Check AdGuard Home status
   - Verify upstream DNS connectivity
   - Validate container DNS configuration

2. **VPN Connection Issues**
   - Verify TUN device availability
   - Check VPN credentials
   - Validate routing table

3. **Storage Access Problems**
   - Check NFS server status
   - Verify mount points
   - Validate network connectivity

### Diagnostic Commands
```bash
# Network connectivity
ping 10.92.0.10
nslookup google.com 10.92.0.10

# VPN status
ip route show
ip addr show tun0

# Storage mounts
mount | grep nfs
df -h /mnt/data
```

## Future Expansion

### Planned Networks
- **DMZ Network**: 10.92.4.0/24 for external services
- **IoT Network**: 10.92.5.0/24 for smart home devices
- **Lab Network**: 10.92.6.0/24 for testing

### Scalability Considerations
- VLAN segmentation for security
- Additional DNS servers for redundancy
- Load balancing for high-traffic services
- Network monitoring and alerting

---

*Last Updated: 2025-07-11*
