# 🏠 Homelab Nexus

> **Your Central Command Center for Proxmox Infrastructure Management**

Homelab Nexus is a comprehensive automation and management framework for Proxmox-based homelabs. It provides MCP-powered automated deployment, blue-green infrastructure management, and complete infrastructure documentation tools to streamline your homelab operations.

## 🚀 Features

- **🤖 MCP-Powered Automation** - Natural language container provisioning via Model Context Protocol
- **🔄 Blue-Green Deployments** - Zero-downtime deployments for production apps (TheoShift, LDC Tools, QuantShift, Cloudigan API)
- **📦 Automated Provisioning Pipeline** - End-to-end container deployment (CTID, Netbox, NPM, DNS, monitoring, backups)
- **📊 Infrastructure Documentation** - Comprehensive specs and asset tracking with Netbox IPAM
- **🔧 Configuration Management** - Standardized container and VM setup with governance
- **🌐 Network Management** - Full IPAM integration with Netbox, AdGuard DNS, NPM reverse proxy
- **📋 Task Management** - Control plane governance with durable context management

## 🏗️ Infrastructure Overview

### Current Setup
- **Proxmox Host**: 10.92.0.5 (pve)
- **LXC Containers**: 25+ services (Media, Infrastructure, Monitoring, Production Apps, Bots)
- **Virtual Machines**: 12 VMs (Windows workstations, Domain controller)
- **Storage**: TrueNAS (32TB media-pool) + Proxmox pools
- **Networks**: Management (10.92.0.0/23) + Services (10.92.3.0/24)
- **MCP Integration**: Proxmox MCP server + Blue-Green Deployment MCP server

### Key Services
- **Production Apps**: TheoShift, LDC Tools, QuantShift, Cloudigan API (blue-green deployment)
- **Media Management**: Complete *arr stack with VPN-enabled download clients
- **Infrastructure**: AdGuard DNS, NPM Proxy, Netbox IPAM, HAProxy (blue-green routing)
- **Monitoring**: Grafana, Prometheus, Loki, Alertmanager, Uptime Kuma
- **Bots**: QuantShift trading bots (blue-green deployment)

## 🛠️ Quick Start

### Prerequisites
```bash
# Install required dependencies
pip3 install -r requirements.txt

# Configure environment
cp .env.example .env
# Edit .env with your Proxmox, Netbox, NPM, and DNS credentials
```

### Automated Container Provisioning
```bash
# Deploy a new container with full automation
./scripts/provisioning/provision-container.sh \
  --name my-service \
  --function utility \
  --ip 10.92.3.50 \
  --domain my-service.cloudigan.net \
  --ssl

# This automatically:
# - Assigns CTID from appropriate range
# - Creates Proxmox LXC container
# - Registers in Netbox IPAM
# - Creates NPM reverse proxy with SSL
# - Adds DNS record to AdGuard
# - Installs monitoring (node_exporter, promtail)
# - Configures backup schedule
```

### MCP-Powered Deployment (via Windsurf)
```
Create a media server container with 4GB RAM and Plex at 10.92.3.60
```

### Blue-Green Deployment Management
```python
# Check deployment status
mcp0_get_deployment_status(app='theoshift')

# Deploy to STANDBY
mcp0_deploy_to_standby(app='theoshift')

# Switch traffic (with approval)
mcp0_switch_traffic(app='theoshift', requireApproval=True)
```

## 📁 Repository Structure

```
homelab-nexus/
├── 📄 README.md                          # This file
├── 📋 TASK-STATE.md                      # Current work and next steps
├── 📋 IMPLEMENTATION-PLAN.md             # Backlog and roadmap
├── 📋 DECISIONS.md                       # Architectural decisions
├── 📋 requirements.txt                   # Python dependencies
├── 🔄 .cloudy-work/                      # Control plane governance (submodule)
├── 🔄 .windsurf/                         # Workflows (/start-day, /end-day, etc.)
├── 🤖 automation/                        # Legacy automation scripts
├── 📚 documentation/                     # Infrastructure documentation
│   ├── infrastructure-spec.md            # Complete infrastructure specification
│   ├── container-naming-standard.md      # Container naming conventions
│   ├── CT180-SCRYPTED-DEPLOYMENT.md      # Deployment records
│   └── dns-management-for-renames.md     # DNS automation guides
├── ⚙️ configuration/                     # Configuration templates
├── 🔧 scripts/                          # Automation and utility scripts
│   ├── provisioning/                    # **NEW** Automated provisioning pipeline
│   │   ├── provision-container.sh       # Master orchestration script
│   │   ├── netbox-register.sh           # Netbox IPAM integration
│   │   ├── npm-create-proxy.sh          # NPM reverse proxy setup
│   │   ├── dns-add-record.sh            # AdGuard DNS registration
│   │   ├── install-monitoring.sh        # Monitoring stack setup
│   │   └── configure-backup.sh          # Backup configuration
│   ├── dns/                             # DNS automation (DC-01, AdGuard)
│   ├── cloudigan-api/                   # Cloudigan API deployment scripts
│   ├── backup/                          # Backup automation
│   ├── maintenance/                     # Maintenance procedures
│   └── troubleshooting/                 # Diagnostic scripts
└── 📦 archive/                          # Archived promotions and old docs
```

## 🎯 Current Status

### ✅ Recently Completed (Mar 2026)
- [x] **Automated Container Provisioning Pipeline** - Full end-to-end automation (Mar 14)
- [x] **Proxmox MCP Server Integration** - Natural language container deployment (Mar 16)
- [x] **Cloudigan API Production Deployment** - Stripe→Datto→Wix integration (Mar 17)
- [x] **Blue-Green MCP Server** - Automated deployment management for 4 apps (Mar 18)
- [x] **Container Naming Convention Audit** - All 8 containers renamed and standardized (Feb 23-25)
- [x] **TrueNAS Disk Replacement** - Pool healthy, resilver complete (Mar 5-9)
- [x] **Netbox IPAM Full Buildout** - 25+ VMs, IPs, physical layer, VLANs (Feb 21)
- [x] **HAProxy VRRP** - Blue-green traffic routing with VIP (Feb 21)
- [x] **Monitoring Stack** - Grafana, Prometheus, Loki, Alertmanager (Feb 21)

### � In Progress
- [ ] **Proxmox Infrastructure Manager (PIM)** - MCP server with full provisioning capabilities
  - Phase 1: Merge automation pipeline into mcp-server-proxmox (Mar 14-31)
  - Strategic goal: Validate as potential commercial product

### 📋 High Priority Backlog
- [ ] Wix thank-you page setup for Cloudigan API
- [ ] TrueNAS OS update (Fangtooth - safe to apply)
- [ ] Backup automation for all containers
- [ ] Infrastructure-as-Code templates (Terraform/Ansible)

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
