# Ansible Playbooks Quick Reference

**⚠️ IMPORTANT: We have a dedicated ansible-playbooks repository!**

---

## 📍 Location

**Local:** `/Users/cory/Projects/ansible-playbooks`  
**GitHub:** https://github.com/heybearc/ansible-playbooks  
**Semaphore UI:** https://ansible.cloudigan.net

---

## 🚀 Deploy New Container (Most Common Task)

### Via Semaphore UI (Recommended)
1. Go to https://ansible.cloudigan.net
2. Click **Task Templates**
3. Find **"Deploy Proxmox Container"**
4. Click **Run**
5. Enter variables:
   - `container_name`: omada-controller
   - `container_function`: network
   - `container_ip`: 10.92.3.16
   - `container_domain`: omada.cloudigan.net
   - `container_port`: 8043

### Via Command Line
```bash
cd /Users/cory/Projects/ansible-playbooks

ansible-playbook playbooks/deploy-proxmox-container.yml \
  -e "container_name=omada-controller" \
  -e "container_function=network" \
  -e "container_ip=10.92.3.16" \
  -e "container_domain=omada.cloudigan.net" \
  -e "container_port=8043"
```

---

## 📋 Available Playbooks

### Infrastructure
- **deploy-proxmox-container.yml** - Deploy LXC with full automation
- **deploy-proxmox-vm.yml** - Deploy VM with full automation

### System Management
- **system-update.yml** - Update all packages
- **health-check.yml** - Check system health
- **fix-python-modules.yml** - Bootstrap Python

### Database
- **postgresql-status.yml** - Check DB health
- **postgresql-failover.yml** - Failover to replica

### Automation
- **sync-semaphore-templates.yml** - Sync playbooks to Semaphore UI

---

## 🔄 After Adding New Playbooks

**MUST DO:** Sync to Semaphore so they appear in the UI

```bash
# 1. Update metadata in semaphore-auto-template.py
# 2. Push to GitHub
# 3. Run sync:

cd /Users/cory/Projects/ansible-playbooks
ansible-playbook playbooks/sync-semaphore-templates.yml \
  -e "semaphore_password=YOUR_PASSWORD"
```

Or run "Sync Semaphore Templates" task in Semaphore UI.

---

## 📚 Full Documentation

- **ansible-playbooks/README.md** - Quick start guide
- **ansible-playbooks/README-DEPLOYMENT.md** - Detailed examples
- **homelab-nexus/documentation/ANSIBLE-SEMAPHORE-PLAYBOOKS.md** - Semaphore guide

---

## 💡 Remember

1. ✅ **Use Semaphore UI** - Easier, has history, Teams notifications
2. ✅ **Playbooks are in separate repo** - Not in homelab-nexus
3. ✅ **Sync after changes** - Run sync-semaphore-templates.yml
4. ✅ **Full automation** - Netbox, NPM, DNS, monitoring, backups all automatic

---

**Last Updated:** March 29, 2026
