# 🏠 Homelab Nexus

> **Your Central Command Center for Proxmox Infrastructure Management**

Homelab Nexus is a comprehensive automation and management framework for Proxmox-based homelabs. It provides automated deployment, configuration management, and infrastructure documentation tools to streamline your homelab operations.

## 🚀 Features

- **🤖 Automated Service Deployment** - Deploy 200+ services with community scripts
- **📊 Infrastructure Documentation** - Comprehensive specs and asset tracking
- **🔧 Configuration Management** - Standardized container and VM setup
- **🌐 Network Management** - IPAM integration with Netbox
- **🔒 VPN Integration** - Automated VPN setup for download clients
- **📋 Task Management** - Organized workflows and human TODOs

## 🏗️ Infrastructure Overview

### Current Setup
- **Proxmox Host**: 10.92.0.5
- **LXC Containers**: 16 services (Media stack, Infrastructure, Monitoring)
- **Virtual Machines**: 12 VMs (Windows workstations, Domain controller)
- **Storage**: 20.62TB across 4 storage pools
- **Networks**: Management (10.92.0.0/23) + Services (10.92.3.0/24)

### Key Services
- **Media Management**: Complete *arr stack with VPN-enabled download clients
- **Infrastructure**: DNS (AdGuard), Proxy (Nginx), IPAM (Netbox)
- **Monitoring**: Homarr dashboard, Tautulli, Overseerr

## 🛠️ Quick Start

### Prerequisites
```bash
# Install required dependencies
pip3 install -r requirements.txt

# Ensure sshpass is available (macOS)
brew install sshpass
```

### Basic Usage
```bash
# List all available services
python3 automation/proxmox-automation-scripts.py --list

# Deploy a new service
python3 automation/proxmox-automation-scripts.py --deploy jellyfin

# Add NFS mount to container
python3 automation/proxmox-automation-scripts.py --container-id 127 --add-nfs

# Enable VPN support
python3 automation/proxmox-automation-scripts.py --container-id 127 --enable-tun
```

## 📁 Repository Structure

```
homelab-nexus/
├── 📄 README.md                          # This file
├── 📋 requirements.txt                   # Python dependencies
├── 🤖 automation/                        # Automation scripts and tools
│   ├── proxmox-automation-scripts.py     # Main automation framework
│   └── deployment-templates/             # Service deployment templates
├── 📚 documentation/                     # Infrastructure documentation
│   ├── infrastructure-spec.md            # Complete infrastructure specification
│   ├── netbox-ipam-spec.md              # Netbox IPAM management guide
│   └── network-topology.md              # Network architecture details
├── ⚙️ configuration/                     # Configuration templates and examples
│   ├── container-configs/               # LXC container configurations
│   ├── vpn-configs/                     # VPN configuration templates
│   └── service-configs/                 # Service-specific configurations
├── 📊 monitoring/                        # Monitoring and alerting
│   ├── dashboards/                      # Grafana/Homarr dashboards
│   └── alerts/                          # Alert configurations
└── 🔧 scripts/                          # Utility scripts and helpers
    ├── backup-scripts/                  # Backup automation
    ├── maintenance/                     # Maintenance procedures
    └── troubleshooting/                 # Common fixes and diagnostics
```

## 🎯 Current Status

### ✅ Completed
- [x] Infrastructure audit and documentation
- [x] Proxmox community scripts automation framework
- [x] SABnzbd Docker to LXC migration
- [x] Netbox IPAM setup and integration
- [x] Comprehensive infrastructure specification

### 🔄 In Progress
- [ ] SABnzbd VPN configuration (OpenVPN + killswitch)
- [ ] Readarr service troubleshooting
- [ ] Enhanced monitoring and alerting

### 📋 Planned
- [ ] Complete Docker to LXC migration
- [ ] Automated backup procedures
- [ ] Security hardening implementation
- [ ] Performance optimization
- [ ] Disaster recovery testing

## 🏠 Services Inventory

### Media Management Stack
| Service | Container ID | IP | Status | VPN |
|---------|-------------|-----|---------|-----|
| Transmission | 126 | 10.92.3.9 | ✅ Running | ✅ Active |
| SABnzbd | 127 | 10.92.3.16 | ✅ Running | 🔄 Pending |
| Sonarr | 125 | 10.92.3.8 | ✅ Running | ❌ None |
| Radarr | 124 | 10.92.3.7 | ✅ Running | ❌ None |
| Readarr | 120 | 10.92.3.4 | ⚠️ Issues | ❌ None |
| Bazarr | 117 | 10.92.3.15 | ✅ Running | ❌ None |
| Prowlarr | 123 | 10.92.3.6 | ✅ Running | ❌ None |

### Infrastructure Services
| Service | Container ID | IP | Purpose |
|---------|-------------|-----|----------|
| Netbox IPAM | 118 | 10.92.3.18 | Infrastructure tracking |
| Nginx Proxy Manager | 121 | 10.92.3.3 | Reverse proxy |
| AdGuard Home | 113 | 10.92.3.11 | DNS filtering |
| Homarr Dashboard | 112 | 10.92.3.10 | Central dashboard |

## 🔧 Configuration Standards

### Container Defaults
- **CPU**: 2 cores
- **Memory**: 2048MB
- **Storage**: 8GB (hdd-pool)
- **Network**: vmbr923 (Services network)
- **Type**: Unprivileged LXC

### NFS Mount Standard
```bash
mp0: /mnt/pve/nfs-data,mp=/mnt/data
```

### VPN Support
```bash
lxc.cgroup2.devices.allow: c 10:200 rwm
lxc.mount.entry: /dev/net dev/net none bind,create=dir
```

## 🔐 Security

### Access Control
- **Proxmox Host**: SSH key-based authentication recommended
- **Container Access**: Individual SSH access per container
- **VPN Protection**: Download clients route through VPN
- **DNS Security**: AdGuard Home with filtering

### Credentials Management
- Proxmox host credentials stored securely
- VPN credentials service-specific
- SSH keys for automated access
- Service-specific authentication

## 📈 Monitoring

### Dashboards
- **Homarr**: Central service dashboard
- **Netbox**: Infrastructure and IP management
- **Tautulli**: Media server monitoring
- **Proxmox**: Host and container monitoring

### Key Metrics
- Container resource utilization
- Storage pool usage
- Network connectivity
- Service availability
- VPN connection status

## 🆘 Support & Troubleshooting

### Common Issues
1. **SSH Access Lost**: Use Proxmox console, check firewall rules
2. **VPN Connection Failed**: Verify TUN device, check credentials
3. **Service Won't Start**: Check logs, verify configuration
4. **Storage Full**: Monitor usage, clean up old data

### Emergency Procedures
- Container recovery from backup
- Network connectivity restoration
- Service configuration rollback
- Infrastructure state validation

## 🤝 Contributing

This is a personal homelab management system, but feel free to:
- Suggest improvements
- Report issues
- Share configuration optimizations
- Contribute automation scripts

## 📜 License

This project is for personal homelab use. Feel free to adapt for your own infrastructure needs.

---

**Homelab Nexus** - *Where Infrastructure Meets Automation* 🚀
