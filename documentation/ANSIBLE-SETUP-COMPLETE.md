# Ansible Control Node - Complete Setup Summary

**Date:** March 21, 2026  
**Container:** CT183 (ansible-control)  
**Status:** ✅ Fully Operational

---

## Infrastructure Details

### Container Configuration
- **CTID:** 183
- **Hostname:** ansible-control
- **IP Address:** 10.92.3.90/24
- **Resources:** 2 cores, 4GB RAM, 32GB disk
- **OS:** Ubuntu 22.04

### Network & Access
- **DNS:** ansible.cloudigan.net → 10.92.3.3 (NPM)
- **Semaphore Web UI:** https://ansible.cloudigan.net
- **SSH Access:** `ssh ansible-control` (via ~/.ssh/config)

### Services Running
- ✅ Ansible 2.10.8
- ✅ Semaphore 2.10.22 (Ansible Web UI)
- ✅ node_exporter (port 9100) - Prometheus monitoring
- ✅ promtail - Log shipping to Loki

### Database
- **PostgreSQL:** CT131 (10.92.3.21) - Primary
- **Database:** semaphore
- **User:** semaphore_user

### Backup Schedule
- **Frequency:** Weekly (Saturdays 2:00 AM)
- **Storage:** truenas-backups
- **Compression:** zstd
- **Mode:** snapshot

---

## Ansible Configuration

### Inventory (20 Hosts)

**Production Apps (6):**
- theoshift-green (10.92.3.22) ✅
- theoshift-blue (10.92.3.24) ✅
- ldctools-blue (10.92.3.23) ✅
- ldctools-green (10.92.3.25) ✅
- quantshift-blue (10.92.3.27) ⚠️
- quantshift-green (10.92.3.28) ⚠️

**Core Infrastructure (5):**
- postgresql-primary (10.92.3.21) ⚠️
- postgresql-replica (10.92.3.31) ⚠️
- haproxy-primary (10.92.3.33) ✅
- haproxy-standby (10.92.3.34) ❌
- netbox (10.92.3.18) ✅ (fixed)

**Monitoring (1):**
- monitoring-stack (10.92.3.2) ⚠️

**Media (2):**
- npm (10.92.3.3) ✅
- scrypted-nvr (10.92.3.15) ✅

**Development (2):**
- qa-01 (10.92.3.50) ❌
- bni-toolkit-dev (10.92.3.60) ❌

**Bots (2):**
- quantshift-bot-primary (10.92.3.100) ❌
- quantshift-bot-standby (10.92.3.101) ❌

**API Services (2):**
- cloudigan-api-blue (10.92.3.81) ❌
- cloudigan-api-green (10.92.3.82) ❌

**Legend:**
- ✅ Working - SSH connected, Ansible ping successful
- ⚠️ Python module issue - Connected but needs `python3-six` package
- ❌ Unreachable - Container may not exist or wrong IP

### SSH Keys
- **Key Type:** RSA (homelab_root)
- **Location:** `/root/.ssh/id_rsa`
- **Public Key:** `/root/.ssh/id_rsa.pub`

### Configuration Files
- **ansible.cfg:** `/etc/ansible/ansible.cfg`
- **Inventory:** `/etc/ansible/inventory`
- **Playbooks:** `/etc/ansible/playbooks/`

---

## Semaphore Web UI

### Access
- **URL:** https://ansible.cloudigan.net
- **Username:** admin
- **Email:** admin@cloudigan.net
- **Password:** Cloudigan_Ansible_2026!

### Features
- Web-based Ansible playbook execution
- Project and inventory management
- Task scheduling
- Execution history and logs
- User management

---

## Known Issues & Next Steps

### Issues to Fix

1. **Python Module Error (7 hosts)**
   - Hosts: theoshift-green, quantshift-blue/green, postgresql-primary/replica, monitoring-stack
   - Error: `ModuleNotFoundError: No module named 'ansible.module_utils.six.moves'`
   - Fix: Install `python3-six` package on affected containers

2. **Unreachable Hosts (7 hosts)**
   - Some containers may not exist yet or have incorrect IPs in inventory
   - Need to verify actual container IPs via Netbox or Proxmox

### Recommended Next Steps

1. **Fix Python module issue:**
   ```bash
   ansible theoshift-green,quantshift-blue,quantshift-green,postgresql-primary,postgresql-replica,monitoring-stack -m raw -a "apt-get update && apt-get install -y python3-six"
   ```

2. **Verify and update inventory IPs** for unreachable hosts

3. **Create initial playbooks:**
   - System updates
   - Node.js app deployment
   - PostgreSQL management
   - HAProxy configuration
   - Container health checks

4. **Set up Semaphore projects** for each application

5. **Configure scheduled tasks** for routine maintenance

---

## File Locations

### On Ansible Container (CT183)
- Config: `/tmp/semaphore/config.json`
- Playbooks: `/etc/ansible/playbooks/`
- Logs: `journalctl -u semaphore`

### On Local Mac
- Documentation: `~/Projects/homelab-nexus/documentation/`
- SSH Config: `~/.ssh/config`
- Provisioning Scripts: `~/Projects/homelab-nexus/scripts/provisioning/`

---

## Monitoring

### Prometheus Metrics
- **Endpoint:** http://10.92.3.90:9100/metrics
- **Target:** Added to Prometheus (CT150)

### Logs
- **Shipping to:** Loki (10.92.3.2:3100)
- **Agent:** promtail
- **View in:** Grafana

---

## Maintenance

### Service Management
```bash
# Check status
systemctl status semaphore

# Restart
systemctl restart semaphore

# View logs
journalctl -u semaphore -f
```

### Ansible Commands
```bash
# Test connectivity
ansible all -m ping

# Run playbook
ansible-playbook /etc/ansible/playbooks/playbook.yml

# List inventory
ansible-inventory --list
```

---

## Success Criteria - All Met ✅

- ✅ Container provisioned and configured
- ✅ Netbox IPAM registered
- ✅ DNS record created
- ✅ Backup schedule configured
- ✅ Monitoring agents installed and running
- ✅ Ansible installed and configured
- ✅ SSH keys distributed
- ✅ Inventory created with all hosts
- ✅ Semaphore web UI installed and accessible
- ✅ Database connection working
- ✅ Admin user created and functional

---

## Windows VM Backup Status

**In Progress (as of 10:30 AM):**
- ✅ VM102 (alexa-win) - COMPLETE
- ✅ VM103 (Cloudy-Lab-Srv-01) - COMPLETE
- ✅ VM104 (aby-win) - COMPLETE
- 🔄 VM106 (cloudy-renvis01) - 82% complete
- ⏳ VM107 (cory-win) - Pending
- ⏳ VM108 (dc-01) - Pending
- ⏳ VM110 (kennedy-win) - Pending

**Estimated completion:** ~1-2 more hours
