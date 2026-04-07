# Omada Controller Deployment Guide

**Date:** March 29, 2026  
**Status:** Ready for Deployment  
**Container:** CT161 (omada-controller)

---

## Overview

This guide covers the deployment of TP-Link Omada SDN Controller for centralized management of network infrastructure.

**Purpose:** Centralized management and monitoring of TP-Link Omada network devices

---

## Infrastructure Details

### Container Specification
- **CTID:** 161 (network function range: 160-169)
- **Hostname:** omada-controller
- **IP Address:** 10.92.3.16/24
- **Gateway:** 10.92.3.1
- **DNS:** 10.92.0.10 (AdGuard)
- **VLAN:** 923 (Production Containers)

### Resources
- **CPU:** 2 cores
- **Memory:** 2GB RAM
- **Disk:** 32GB
- **OS:** Ubuntu 22.04 LTS

### Network Access
- **Domain:** omada.cloudigan.net
- **HTTPS Port:** 8043
- **HTTP Port:** 8088
- **Device Adoption Ports:** 29810-29814 (UDP/TCP)

---

## Managed Devices

### Current Hardware
1. **TP-Link ER7206 Omada Gigabit VPN Router**
   - Management IP: 10.92.0.1 (to be confirmed)
   - Role: Primary gateway and router
   - Features: Multi-WAN, VPN, VLAN support

2. **TP-Link 24-Port Gigabit PoE+ Managed Switch**
   - Management IP: TBD (needs assignment)
   - Role: Core L2 switch
   - Features: PoE+, VLAN 802.1Q, LACP

---

## Deployment Methods

### Method 1: Automated Deployment via Ansible (Recommended)

**Prerequisites:**
1. Container CT161 created and accessible
2. Ansible inventory updated with omada-controller host
3. SSH access configured

**Steps:**

1. **Create the container using Proxmox MCP:**
   ```
   Function: network
   Name: omada-controller
   IP: 10.92.3.16
   Cores: 2
   Memory: 2048
   Disk: 32
   ```

2. **Update Ansible inventory:**
   Add to `/etc/ansible/inventory`:
   ```ini
   [omada_controller]
   omada-controller ansible_host=10.92.3.16 ansible_user=root
   ```

3. **Run the Ansible playbook:**
   ```bash
   # Via Semaphore UI
   - Navigate to Task Templates
   - Select "Deploy Omada Controller"
   - Click Run

   # Or via command line
   ssh ansible-control
   export PATH=/usr/local/bin:$PATH
   ansible-playbook /etc/ansible/playbooks/omada-controller-deploy.yml
   ```

4. **Configure NPM reverse proxy:**
   - Host: omada.cloudigan.net
   - Forward to: 10.92.3.16:8043
   - SSL: Enabled (Let's Encrypt)
   - WebSocket Support: Enabled

5. **Add DNS record in AdGuard:**
   - omada.cloudigan.net → 10.92.3.3 (NPM)

---

### Method 2: Manual Installation

**If you prefer manual installation:**

1. **SSH to container:**
   ```bash
   ssh root@10.92.3.16
   ```

2. **Install dependencies:**
   ```bash
   apt update
   apt install -y openjdk-17-jre-headless jsvc curl wget mongodb
   ```

3. **Download Omada Controller:**
   ```bash
   cd /tmp
   wget https://static.tp-link.com/upload/software/2024/202401/20240104/Omada_SDN_Controller_v5.13.30.8_linux_x64.deb
   ```

4. **Install package:**
   ```bash
   dpkg -i Omada_SDN_Controller_v5.13.30.8_linux_x64.deb
   apt-get install -f  # Fix any dependency issues
   ```

5. **Enable and start services:**
   ```bash
   systemctl enable mongodb
   systemctl start mongodb
   systemctl enable tpeap
   systemctl start tpeap
   ```

6. **Verify installation:**
   ```bash
   systemctl status tpeap
   netstat -tlnp | grep 8043
   ```

---

## Post-Installation Configuration

### Initial Setup Wizard

1. **Access web interface:**
   - URL: https://omada.cloudigan.net
   - Or direct: https://10.92.3.16:8043

2. **Complete setup wizard:**
   - Create admin account
   - Set controller name: "Cloudigan Lab"
   - Configure time zone and location
   - Set up email notifications (optional)

3. **Adopt devices:**
   - Navigate to Devices → Pending
   - Adopt ER7206 router (10.92.0.1)
   - Adopt 24-port switch (assign management IP first)

### Network Configuration

**VLAN Setup:**
- VLAN 1: Management (10.92.0.0/24)
- VLAN 10: Cluster (10.92.1.0/24)
- VLAN 20: Storage (10.92.2.0/24)
- VLAN 923: Containers (10.92.3.0/24)

**Firewall Rules:**
- Configure inter-VLAN routing policies
- Set up WAN access rules
- Enable IDS/IPS if available

**QoS Policies:**
- Priority 1: Cluster traffic (VLAN 10)
- Priority 2: Storage traffic (VLAN 20)
- Priority 3: Management (VLAN 1)
- Priority 4: Container traffic (VLAN 923)

---

## Integration Points

### Monitoring
- **Prometheus:** Add SNMP exporter for network metrics
- **Grafana:** Create Omada dashboard
- **Alerts:** Configure Teams notifications for network events

### Backup
- **Schedule:** Weekly (Saturdays 2:00 AM)
- **Storage:** truenas-backups
- **What to backup:**
  - Omada configuration
  - Device settings
  - Network maps

### DNS
- **Internal:** omada.cloudigan.net → 10.92.3.3 (via AdGuard)
- **External:** Not required (internal only)

### Netbox
- Register container in IPAM
- Document network devices
- Track port assignments

---

## Maintenance

### Service Management
```bash
# Check status
systemctl status tpeap

# Restart controller
systemctl restart tpeap

# View logs
journalctl -u tpeap -f

# Check MongoDB
systemctl status mongodb
```

### Updates
```bash
# Download new version
wget [new_omada_controller_url]

# Stop service
systemctl stop tpeap

# Install update
dpkg -i Omada_SDN_Controller_vX.X.X_linux_x64.deb

# Start service
systemctl start tpeap
```

### Backup Configuration
```bash
# Backup is automatic via Omada UI
# Settings → Maintenance → Backup
# Or use Proxmox container backup
```

---

## Troubleshooting

### Controller Won't Start
**Check:**
1. MongoDB service running: `systemctl status mongodb`
2. Port 8043 not in use: `netstat -tlnp | grep 8043`
3. Java installed: `java -version`
4. Logs: `journalctl -u tpeap -n 100`

### Devices Won't Adopt
**Check:**
1. Network connectivity from controller to device
2. Firewall allows ports 29810-29814
3. Device firmware compatible with controller version
4. Device not already adopted by another controller

### Web UI Not Accessible
**Check:**
1. NPM proxy configuration
2. SSL certificate valid
3. DNS resolution: `dig omada.cloudigan.net`
4. Direct access works: `https://10.92.3.16:8043`

---

## Security Considerations

### Access Control
- Strong admin password
- Enable 2FA if available
- Limit access to management network
- Regular password rotation

### Network Segmentation
- Keep controller on management-accessible VLAN
- Restrict device adoption to known MAC addresses
- Enable rogue AP detection

### Updates
- Monitor TP-Link security advisories
- Apply firmware updates promptly
- Test updates in maintenance window

---

## Ansible Playbook Details

### Playbook Location
- **Repository:** https://github.com/heybearc/ansible-playbooks
- **Path:** `playbooks/omada-controller-deploy.yml`

### What the Playbook Does
1. Updates system packages
2. Installs Java 17 and dependencies
3. Installs MongoDB
4. Downloads Omada Controller package
5. Installs Omada Controller
6. Configures and starts services
7. Verifies installation
8. Displays access information

### Variables
```yaml
omada_version: "5.13"
omada_download_url: "https://static.tp-link.com/..."
omada_user: "omada"
omada_group: "omada"
```

### Inventory Group
```ini
[omada_controller]
omada-controller ansible_host=10.92.3.16 ansible_user=root
```

---

## Next Steps

1. **Create container CT161** using Proxmox MCP
2. **Update Ansible inventory** with omada-controller host
3. **Run Ansible playbook** via Semaphore or CLI
4. **Configure NPM reverse proxy** for omada.cloudigan.net
5. **Complete initial setup wizard** in web UI
6. **Adopt network devices** (ER7206, switch)
7. **Configure VLANs and policies**
8. **Set up monitoring** in Prometheus/Grafana
9. **Document device configurations** in Netbox

---

## Resources

**TP-Link Documentation:**
- Omada Controller Guide: https://www.tp-link.com/us/support/download/omada-software-controller/
- ER7206 Manual: https://www.tp-link.com/us/support/download/er7206/

**Semaphore:**
- URL: https://ansible.cloudigan.net
- Template: "Deploy Omada Controller"

**Related Documentation:**
- `NETWORK-INFRASTRUCTURE.md` - Network topology and VLAN design
- `ANSIBLE-SEMAPHORE-PLAYBOOKS.md` - Ansible playbook guide

---

**Last Updated:** March 29, 2026  
**Maintained By:** Cory Allen  
**Status:** Ready for Deployment
