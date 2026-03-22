# Ansible Semaphore Playbooks Guide

**Date:** March 21, 2026  
**Status:** ✅ Active and Ready

---

## Overview

This guide provides a complete reference for all Ansible playbooks available in Semaphore for managing the Cloudigan infrastructure.

**Repository:** https://github.com/heybearc/ansible-playbooks  
**Semaphore URL:** https://ansible.cloudigan.net

---

## Available Playbooks

### 1. Fix Python Modules (`fix-python-modules.yml`)

**Purpose:** Bootstrap Python and python3-six on hosts that don't have it installed

**Target Hosts:**
- theoshift-green
- quantshift-blue
- quantshift-green
- postgresql-primary
- postgresql-replica
- monitoring-stack

**What it does:**
- Installs python3 and python3-six using raw commands
- Verifies Python installation
- Verifies six module installation
- Displays results for each host

**When to use:**
- New container deployments
- After OS reinstalls
- When Ansible modules fail with Python errors

**Status:** ✅ Successfully executed - all 6 hosts fixed

---

### 2. System Update (`system-update.yml`)

**Purpose:** Update all packages on infrastructure hosts

**Target Hosts:** All containers (20 hosts)

**What it does:**
- Updates apt cache
- Upgrades all packages (dist-upgrade)
- Runs autoremove and autoclean
- Checks if reboot is required
- Alerts if reboot needed

**When to use:**
- Weekly maintenance windows
- Security patch deployments
- Before major changes

**Recommended schedule:** Weekly (Saturdays 2:00 AM)

---

### 3. Health Check (`health-check.yml`)

**Purpose:** Monitor system health across all infrastructure

**Target Hosts:** All containers (20 hosts)

**What it does:**
- Checks disk usage (alerts if >80%)
- Checks memory usage (alerts if >90%)
- Monitors CPU load
- Verifies PM2 status on Node.js apps
- Displays comprehensive health report

**When to use:**
- Daily health monitoring
- Before deployments
- Troubleshooting performance issues
- Capacity planning

**Recommended schedule:** Daily (6:00 AM)

---

### 4. Node.js App Restart (`nodejs-app-restart.yml`)

**Purpose:** Restart PM2-managed Node.js applications

**Target Hosts:** nodejs_apps group (6 containers)
- theoshift-green, theoshift-blue
- ldctools-green, ldctools-blue
- quantshift-green, quantshift-blue

**What it does:**
- Checks PM2 service status
- Lists current PM2 processes
- Restarts all PM2 processes
- Saves PM2 configuration
- Confirms restart success

**When to use:**
- After code deployments
- Memory leak mitigation
- Configuration changes
- Troubleshooting app issues

---

### 5. PostgreSQL Status (`postgresql-status.yml`)

**Purpose:** Check database cluster health and replication status

**Target Hosts:** postgresql group (2 containers)
- postgresql-primary (10.92.3.31)
- postgresql-replica (10.92.3.32)

**What it does:**
- Checks PostgreSQL service status
- Shows PostgreSQL version
- Identifies server role (primary/replica)
- Displays database sizes
- Shows replication status on primary
- Verifies replica connectivity

**When to use:**
- Daily database health checks
- Before database maintenance
- Troubleshooting replication issues
- Capacity planning

**Recommended schedule:** Daily (7:00 AM)

---

## Setting Up Playbooks in Semaphore

### Step 1: Verify Repository

1. Go to **Repositories** in Semaphore
2. Confirm "Ansible Playbooks" repository exists:
   - URL: `https://github.com/heybearc/ansible-playbooks.git`
   - Branch: `main`
   - Access: Public (no key needed)

### Step 2: Verify Inventory

1. Go to **Inventory**
2. Confirm "Production Hosts" exists with:
   - Type: Static
   - SSH Key: "Homelab Root SSH Key"
   - 20 hosts configured

### Step 3: Verify Environment

1. Go to **Environment**
2. Confirm "Production" environment exists
3. Can be empty or contain global variables

### Step 4: Create Task Templates

For each playbook, create a template:

**Template: Fix Python Modules**
- Name: `Fix Python Modules`
- Playbook: `playbooks/fix-python-modules.yml`
- Inventory: Production Hosts
- Repository: Ansible Playbooks
- Environment: Production

**Template: System Update**
- Name: `System Update`
- Playbook: `playbooks/system-update.yml`
- Inventory: Production Hosts
- Repository: Ansible Playbooks
- Environment: Production

**Template: Health Check**
- Name: `Health Check`
- Playbook: `playbooks/health-check.yml`
- Inventory: Production Hosts
- Repository: Ansible Playbooks
- Environment: Production

**Template: Restart Node.js Apps**
- Name: `Restart Node.js Apps`
- Playbook: `playbooks/nodejs-app-restart.yml`
- Inventory: Production Hosts
- Repository: Ansible Playbooks
- Environment: Production

**Template: PostgreSQL Status**
- Name: `PostgreSQL Status`
- Playbook: `playbooks/postgresql-status.yml`
- Inventory: Production Hosts
- Repository: Ansible Playbooks
- Environment: Production

---

## Running Playbooks

### Via Semaphore UI

1. Navigate to **Task Templates**
2. Find the playbook you want to run
3. Click the **Run** button (play icon)
4. Confirm execution
5. Watch real-time output
6. Receive Teams notification on completion

### Via Command Line

```bash
# SSH to Ansible control node
ssh ansible-control

# Set PATH for new Ansible version
export PATH=/usr/local/bin:$PATH
export LC_ALL=en_US.UTF-8

# Run a playbook
ansible-playbook /etc/ansible/playbooks/health-check.yml

# Run with verbose output
ansible-playbook /etc/ansible/playbooks/system-update.yml -vv

# Run on specific hosts
ansible-playbook /etc/ansible/playbooks/nodejs-app-restart.yml --limit theoshift-green
```

---

## Scheduling Playbooks

### Recommended Schedule

**Daily:**
- 6:00 AM - Health Check
- 7:00 AM - PostgreSQL Status

**Weekly:**
- Saturday 2:00 AM - System Update

**As Needed:**
- Fix Python Modules (one-time or after new deployments)
- Restart Node.js Apps (after deployments)

### Setting Up Schedules in Semaphore

1. Go to **Task Templates**
2. Edit the template
3. Enable **Schedule**
4. Set cron expression:
   - Daily 6 AM: `0 6 * * *`
   - Weekly Saturday 2 AM: `0 2 * * 6`
5. Save template

---

## Teams Notifications

**Configured:** ✅ Yes

**What you'll receive:**
- Task start notification
- Task completion notification
- Success/failure status
- Execution duration
- Link to view full output

**Webhook URL:** Configured in Semaphore config

---

## Host Status

### Working Hosts (13/20)

✅ **Production Apps:**
- theoshift-green, theoshift-blue
- ldctools-green, ldctools-blue
- quantshift-green, quantshift-blue

✅ **Core Infrastructure:**
- postgresql-primary, postgresql-replica
- haproxy-primary
- npm

✅ **Monitoring:**
- monitoring-stack

### Unreachable Hosts (7/20)

❌ **Not yet deployed:**
- quantshift-bot-primary, quantshift-bot-standby
- cloudigan-api-blue, cloudigan-api-green
- haproxy-standby
- qa-01, bni-toolkit-dev

❌ **SSH key issues:**
- scrypted-nvr (needs homelab_root key)
- netbox (needs homelab_root key)

---

## Troubleshooting

### Playbook Fails to Clone Repository

**Error:** "Failed to clone repository"

**Solution:**
- Verify repository URL is correct
- Ensure repository is public or SSH key is configured
- Check network connectivity from CT183

### Playbook Fails with Python Errors

**Error:** "No module named 'ansible.module_utils.six.moves'"

**Solution:**
- Run "Fix Python Modules" playbook first
- Verifies Python and python3-six are installed

### Host Unreachable

**Error:** "No route to host" or "Permission denied"

**Solution:**
- Verify container exists and is running
- Check SSH key is distributed to host
- Verify IP address in inventory is correct

### Teams Notifications Not Received

**Solution:**
- Verify webhook URL in Semaphore config
- Check "Suppress success alerts" is unchecked in template
- Test webhook manually in Teams

---

## Adding New Playbooks

### 1. Create Playbook Locally

```bash
cd /Users/cory/Projects/ansible-playbooks/playbooks
# Create your new playbook
vim my-new-playbook.yml
```

### 2. Test Locally

```bash
ssh ansible-control
export PATH=/usr/local/bin:$PATH
ansible-playbook /path/to/my-new-playbook.yml --check
```

### 3. Commit to GitHub

```bash
cd /Users/cory/Projects/ansible-playbooks
git add playbooks/my-new-playbook.yml
git commit -m "feat: Add new playbook for X"
git push
```

### 4. Create Template in Semaphore

1. Go to **Task Templates** → **New Template**
2. Fill in details
3. Set playbook path: `playbooks/my-new-playbook.yml`
4. Save and test

---

## Best Practices

### Before Running Playbooks

1. **Review the playbook** - Understand what it will do
2. **Check host status** - Ensure targets are reachable
3. **Use --check mode** - Dry run first (command line)
4. **Schedule during maintenance windows** - For disruptive changes

### After Running Playbooks

1. **Review output** - Check for errors or warnings
2. **Verify changes** - Confirm expected results
3. **Check Teams notification** - Ensure alerting works
4. **Document issues** - Note any problems for future reference

### Security

1. **Never commit secrets** - Use Semaphore's vault or environment variables
2. **Use SSH keys** - Not passwords
3. **Limit sudo access** - Only when necessary
4. **Audit playbook runs** - Review Semaphore task history

---

## Next Steps

1. **Create remaining templates** - Set up all 5 playbooks in Semaphore
2. **Schedule automated runs** - Set up daily/weekly schedules
3. **Test Teams alerts** - Run a playbook and verify notification
4. **Add custom playbooks** - Create playbooks for your specific needs
5. **Document procedures** - Update runbooks with playbook usage

---

## Support

**Semaphore Documentation:** https://docs.semaphoreui.com  
**Ansible Documentation:** https://docs.ansible.com  
**GitHub Repository:** https://github.com/heybearc/ansible-playbooks

**Ansible Control Node:** CT183 (10.92.3.90)  
**Semaphore Web UI:** https://ansible.cloudigan.net  
**Authentication:** Microsoft 365 SSO

---

**Last Updated:** March 21, 2026  
**Maintained By:** Cory Allen (cory@cloudigan.com)
