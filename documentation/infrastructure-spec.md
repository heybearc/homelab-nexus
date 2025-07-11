# Proxmox Infrastructure Specification

## Table of Contents
1. [Executive Summary](#executive-summary)
2. [Network Architecture](#network-architecture)
3. [Infrastructure Inventory](#infrastructure-inventory)
4. [Automation Framework](#automation-framework)
5. [Service Configuration](#service-configuration)
6. [Security & Access Control](#security--access-control)
7. [Monitoring & Management](#monitoring--management)
8. [Change Management](#change-management)
9. [Task Management](#task-management)
10. [Human TODOs](#human-todos)

---

## Executive Summary

### Infrastructure Overview
- **Proxmox Host**: 10.92.0.5 (Debian GNU/Linux)
- **Total Containers**: 16 LXC containers
- **Total VMs**: 12 virtual machines
- **Storage Capacity**: 20.62TB total across 4 storage pools
- **Network Segments**: Management (10.92.0.0/23) and Services (10.92.3.0/24)

### Key Services
- **Media Management**: Complete *arr stack with download clients
- **Infrastructure**: DNS, proxy management, monitoring
- **IPAM**: Netbox for IP address and asset management
- **Automation**: Community scripts integration for rapid deployment

---

## Network Architecture

### Network Topology
```
Internet
    ↓
Gateway (10.92.0.1/10.92.3.1)
    ↓
┌─────────────────────────────────────────────────────────────┐
│ Management Network (10.92.0.0/23)                          │
│ ├── Proxmox Host: 10.92.0.5                               │
│ ├── DNS Server: 10.92.0.10                               │
│ └── Jump Host: 10.92.0.6 (Container 119)                 │
└─────────────────────────────────────────────────────────────┘
    ↓
┌─────────────────────────────────────────────────────────────┐
│ Services Network (10.92.3.0/24)                            │
│ ├── Docker Host: 10.92.3.2 (Legacy)                       │
│ ├── LXC Containers: 10.92.3.3 - 10.92.3.18               │
│ └── Windows VMs: Various IPs                               │
└─────────────────────────────────────────────────────────────┘
```

### Virtual Bridges
- **vmbr920**: Management network bridge
- **vmbr923**: Services network bridge  
- **vmbr924**: Additional network bridge

### DNS Configuration
- **Primary DNS**: 10.92.0.10 (AdGuard Home)
- **Internal Resolution**: All services use internal DNS
- **External DNS**: Cloudflare DDNS for external access

---

## Infrastructure Inventory

### LXC Container Inventory

#### Media Management Stack
| Service | ID | IP | Resources | Storage | Status |
|---------|----|----|-----------|---------|--------|
| Transmission | 126 | 10.92.3.9 | 2C/2GB/8GB | hdd-pool | ✅ Running + VPN |
| SABnzbd | 127 | 10.92.3.16 | 2C/2GB/5GB | hdd-pool | ✅ Running, VPN pending |
| Sonarr | 125 | 10.92.3.8 | 2C/2GB/8GB | hdd-pool | ✅ Running |
| Radarr | 124 | 10.92.3.7 | 2C/2GB/8GB | hdd-pool | ✅ Running |
| Readarr | 120 | 10.92.3.4 | 2C/1GB/4GB | hdd-pool | ⚠️ Service issues |
| Bazarr | 117 | 10.92.3.15 | 2C/2GB/8GB | hdd-pool | ✅ Running |
| Prowlarr | 123 | 10.92.3.6 | 2C/2GB/8GB | hdd-pool | ✅ Running |

#### Infrastructure Services
| Service | ID | IP | Resources | Storage | Status |
|---------|----|----|-----------|---------|--------|
| Netbox IPAM | 118 | 10.92.3.18 | 2C/2GB/8GB | hdd-pool | ✅ Running |
| Nginx Proxy Manager | 121 | 10.92.3.3 | 2C/2GB/8GB | hdd-pool | ✅ Running |
| AdGuard Home | 113 | 10.92.3.11 | 2C/2GB/8GB | hdd-pool | ✅ Running |
| Jump Host | 119 | 10.92.0.6 | 1C/512MB/2GB | hdd-pool | ✅ Running |

#### Monitoring & Management
| Service | ID | IP | Resources | Storage | Status |
|---------|----|----|-----------|---------|--------|
| Homarr Dashboard | 112 | 10.92.3.10 | 2C/2GB/8GB | hdd-pool | ✅ Running |
| Tautulli | 116 | 10.92.3.14 | 2C/2GB/8GB | hdd-pool | ✅ Running |
| Overseerr | 122 | 10.92.3.5 | 2C/2GB/8GB | hdd-pool | ✅ Running |

#### Utility Services
| Service | ID | IP | Resources | Storage | Status |
|---------|----|----|-----------|---------|--------|
| FlareSolverr | 115 | 10.92.3.13 | 2C/1GB/8GB | hdd-pool | ✅ Running |
| Cloudflare DDNS | 114 | 10.92.3.12 | 1C/512MB/2GB | hdd-pool | ✅ Running |

### Virtual Machine Inventory

#### Production VMs (Running)
| VM Name | ID | Resources | Purpose | Status |
|---------|----|-----------|---------|---------| 
| docker-01 | 109 | 16GB/500GB | Legacy Docker host | ✅ Running |
| dc-01 | 108 | 12GB RAM | Domain Controller | ✅ Running |
| alexa-win | 102 | 24GB/512GB | Windows workstation | ✅ Running |
| aby-win | 104 | 24GB RAM | Windows workstation | ✅ Running |
| cory-win | 107 | 131GB RAM | Windows workstation | ✅ Running |
| kennedy-win | 110 | 24GB RAM | Windows workstation | ✅ Running |
| win10-test | 200 | 4GB/82GB | Test environment | ✅ Running |
| cloudy-renvis01 | 106 | 16GB RAM | Infrastructure service | ✅ Running |

#### Stopped VMs
| VM Name | ID | Resources | Purpose | Status |
|---------|----|-----------|---------|---------| 
| veeam-worker | 100 | 6GB/100GB | Backup worker | ⏹️ Stopped |
| Cloudy-Lab-Win11-01 | 101 | 24GB/512GB | Lab environment | ⏹️ Stopped |
| Cloudy-Lab-Srv-01 | 103 | 16GB/250GB | Lab server | ⏹️ Stopped |
| Cloudy-Lab-Win11-01a | 105 | 12GB/250GB | Lab environment | ⏹️ Stopped |

### Storage Infrastructure

| Pool Name | Type | Total | Used | Available | Usage | Purpose |
|-----------|------|-------|------|-----------|-------|---------|
| hdd-pool | ZFS | 16.89TB | 5.15TB | 11.74TB | 30.51% | Primary LXC storage |
| ssd2-lvm | LVM Thin | 1.95TB | 220.72GB | 1.73TB | 11.30% | High-performance storage |
| local | Directory | 98.50GB | 42.91GB | 50.54GB | 43.56% | System/ISO storage |
| local-lvm | LVM Thin | 1.79TB | 4.30GB | 1.79TB | 0.24% | VM storage pool |

---

## Automation Framework

### Proxmox Community Scripts Integration

#### Overview
Automated deployment and management system using tteck/Proxmox community scripts repository with 200+ available services.

#### Implementation
- **Script Location**: `/Users/cory/Documents/cascade/CascadeProjects/2048/proxmox-automation-scripts.py`
- **Repository**: https://github.com/tteck/Proxmox
- **Available Services**: 200+ container and install scripts
- **Integration Method**: Direct API calls to GitHub + SSH execution on Proxmox host

#### Key Features
1. **Automated Deployment**
   ```bash
   python3 proxmox-automation-scripts.py --deploy sabnzbd
   ```

2. **Configuration Management**
   ```bash
   python3 proxmox-automation-scripts.py --container-id 127 --add-nfs
   python3 proxmox-automation-scripts.py --container-id 127 --enable-tun
   ```

3. **Service Discovery**
   ```bash
   python3 proxmox-automation-scripts.py --list
   ```

#### Supported Services (Media Stack)
- ✅ **sabnzbd.sh**: SABnzbd download client
- ✅ **transmission.sh**: Transmission BitTorrent client  
- ✅ **sonarr.sh**: TV series management
- ✅ **radarr.sh**: Movie management
- ✅ **readarr.sh**: Book management
- ✅ **bazarr.sh**: Subtitle management
- ✅ **prowlarr.sh**: Indexer management
- ✅ **overseerr.sh**: Request management
- ✅ **tautulli.sh**: Plex monitoring
- ✅ **homarr.sh**: Dashboard
- ✅ **nginxproxymanager.sh**: Reverse proxy
- ✅ **adguard.sh**: DNS filtering

#### Automation Capabilities
1. **Container Lifecycle**
   - Automated deployment from community scripts
   - Resource allocation and configuration
   - Network and storage setup

2. **Post-Deployment Configuration**
   - NFS mount addition (`/mnt/pve/nfs-data → /mnt/data`)
   - TUN device enablement for VPN support
   - Container resource updates

3. **Integration Points**
   - Proxmox API integration
   - GitHub repository synchronization
   - SSH-based remote execution

---

## Service Configuration

### Container Configuration Standards

#### Base Configuration
```bash
# Standard LXC container settings
cores: 2
memory: 2048MB
storage: 8GB (hdd-pool)
network: vmbr923
unprivileged: true
```

#### NFS Mount Configuration
```bash
# Standard NFS mount for media services
mp0: /mnt/pve/nfs-data,mp=/mnt/data
```

#### VPN Support Configuration
```bash
# TUN device support for VPN
lxc.cgroup2.devices.allow: c 10:200 rwm
lxc.mount.entry: /dev/net dev/net none bind,create=dir
```

### Service-Specific Configurations

#### Download Clients (VPN-Enabled)
- **Transmission**: OpenVPN + killswitch active
- **SABnzbd**: OpenVPN configuration pending

#### Media Management
- **Sonarr/Radarr/Readarr**: Connected to download clients
- **Bazarr**: Subtitle management for all media
- **Prowlarr**: Centralized indexer management

#### Infrastructure Services
- **Nginx Proxy Manager**: Reverse proxy for all services
- **AdGuard Home**: DNS filtering and internal resolution
- **Netbox**: IPAM and infrastructure documentation

---

## Security & Access Control

### Access Credentials
- **Proxmox Host**: root / Cl0udy!!(@
- **SSH Access**: All containers accessible via SSH
- **VPN Credentials**: Service-specific (PIA for download clients)

### Network Security
- **Internal DNS**: 10.92.0.10 (AdGuard Home)
- **VPN Routing**: Download clients route through VPN
- **Firewall**: Container-level iptables rules
- **Access Control**: SSH key-based authentication recommended

### VPN Configuration
- **Provider**: Private Internet Access (PIA)
- **Protocol**: OpenVPN
- **Killswitch**: Implemented for download clients
- **DNS Leak Protection**: Internal DNS preservation

---

## Monitoring & Management

### Monitoring Stack
- **Homarr**: Central dashboard (10.92.3.10)
- **Tautulli**: Plex monitoring (10.92.3.14)
- **Netbox**: Infrastructure tracking (10.92.3.18)

### Management Interfaces
- **Proxmox**: https://10.92.0.5:8006
- **Nginx Proxy Manager**: http://10.92.3.3:81
- **AdGuard Home**: http://10.92.3.11:3000

### Backup Strategy
- **Container Backups**: Proxmox built-in backup system
- **Configuration Backups**: Service-specific config exports
- **Data Protection**: NFS-based shared storage

---

## Change Management

### Validation Rules
1. **Pre-Change Validation**
   - Verify SSH connectivity to target container
   - Check service dependencies
   - Validate network routing
   - Confirm DNS resolution

2. **Post-Change Validation**
   - SSH access verification
   - Service functionality check
   - Network connectivity test
   - DNS resolution validation

### Emergency Recovery Procedures
1. **SSH Access Lost**
   - Use Proxmox console access
   - Check firewall rules (iptables)
   - Verify network configuration
   - Restore from backup if necessary

2. **Service Failure**
   - Check service logs
   - Verify configuration files
   - Restart container if needed
   - Restore from known good state

### Change Documentation
- All changes documented in this specification
- Netbox updated with infrastructure changes
- Version control for configuration files

---

## Task Management

### Completed Tasks ✅
- [x] Complete infrastructure audit and documentation
- [x] SABnzbd Docker to LXC migration
- [x] Netbox IPAM setup and configuration
- [x] Proxmox community scripts automation framework
- [x] Infrastructure specification reorganization

### In Progress Tasks 🔄
- [ ] SABnzbd VPN configuration (OpenVPN + killswitch)
- [ ] Readarr service troubleshooting
- [ ] Infrastructure monitoring enhancement

### Pending Tasks 📋
- [ ] Complete Docker to LXC migration for remaining services
- [ ] Implement automated backup procedures
- [ ] Enhanced security hardening
- [ ] Performance optimization
- [ ] Disaster recovery testing

### Technical Debt 🔧
- [ ] Legacy Docker containers cleanup
- [ ] Standardize container resource allocation
- [ ] Implement centralized logging
- [ ] Network segmentation improvements
- [ ] SSL certificate management

---

## Human TODOs

### Immediate Actions Required 🚨
1. **Review and approve** the reorganized infrastructure specification
2. **Test the automation framework** by deploying a test service
3. **Validate VPN configuration** for SABnzbd container
4. **Update Netbox** with any missing infrastructure details

### Weekly Maintenance Tasks 📅
1. **Monitor storage utilization** across all pools
2. **Review container resource usage** and optimize as needed
3. **Check backup status** for all critical services
4. **Update community scripts** to latest versions
5. **Validate network connectivity** and DNS resolution

### Monthly Review Tasks 📊
1. **Infrastructure capacity planning** review
2. **Security audit** of all services and access controls
3. **Performance optimization** opportunities
4. **Disaster recovery procedure** testing
5. **Documentation updates** and accuracy verification

### Strategic Planning 🎯
1. **Migration roadmap** for remaining Docker services
2. **Scalability planning** for future service additions
3. **Security enhancement** strategy
4. **Automation expansion** opportunities
5. **Monitoring and alerting** improvements

### Decision Points 🤔
1. **Privileged vs Unprivileged** containers for VPN services
2. **Storage optimization** strategy (SSD vs HDD allocation)
3. **Network segmentation** enhancement approach
4. **Backup retention** policies and procedures
5. **External access** security model

---

## Quick Reference

### Essential Commands
```bash
# List all containers
pct list

# Container management
pct start <id>
pct stop <id>
pct enter <id>

# Automation framework
python3 proxmox-automation-scripts.py --list
python3 proxmox-automation-scripts.py --deploy <service>
python3 proxmox-automation-scripts.py --container-id <id> --add-nfs
```

### Key IP Addresses
- Proxmox Host: 10.92.0.5
- DNS Server: 10.92.0.10
- Netbox IPAM: 10.92.3.18
- Nginx Proxy: 10.92.3.3
- SABnzbd: 10.92.3.16
- Transmission: 10.92.3.9

### Important File Locations
- Container configs: `/etc/pve/lxc/`
- NFS mount: `/mnt/pve/nfs-data`
- Automation script: `proxmox-automation-scripts.py`
- This specification: `proxmox-infrastructure-spec.md`

---

*Last Updated: 2025-07-11*
*Version: 2.0 (Reorganized with Automation Framework)*
