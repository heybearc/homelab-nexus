# n8n Workflow Automation Summary

**Date:** 2026-04-20  
**Status:** 2 Workflows Deployed, Multiple Opportunities Identified

---

## ✅ Deployed Workflows

### **1. Uptime Kuma → Zammad Ticket Creation**

**ID:** `hpcPBbttShe5Uc7j`  
**Status:** ✅ Active  
**Webhook:** `https://flows.cloudigan.net/webhook/uptime-kuma-alert`

**What it does:**
- Monitors 28 services via Uptime Kuma
- Automatically creates high-priority Zammad tickets when services go down
- Includes service name, URL, timestamp, error message

**Test Results:**
- ✅ Test ticket #10 created successfully
- ✅ All 28 monitors configured

**Documentation:** [N8N-UPTIME-KUMA-ZAMMAD-COMPLETE.md](./N8N-UPTIME-KUMA-ZAMMAD-COMPLETE.md)

---

### **2. Zammad → Vikunja Task Creation**

**ID:** `6mcHbtq1wHF8dzBe`  
**Status:** ✅ Active  
**Webhook:** `https://flows.cloudigan.net/webhook/zammad-ticket`

**What it does:**
- Automatically creates Vikunja tasks when new Zammad tickets are created
- Includes ticket link, customer info, priority, full description
- Tasks created in Inbox project

**Test Results:**
- ✅ Test task #43 created from ticket #29011
- ✅ Zammad webhook and trigger configured

**Documentation:** [N8N-ZAMMAD-VIKUNJA-COMPLETE.md](./N8N-ZAMMAD-VIKUNJA-COMPLETE.md)

---

## 🎯 Recommended Next Workflows

### **Priority 1: Windsurf → Ansible Playbook Execution** ⭐⭐⭐

**Why this is important:**
- Execute infrastructure automation from chat/Windsurf
- Deploy containers without SSH
- Run health checks on demand
- Full audit trail in Semaphore

**What it would enable:**
```
You: "Deploy a new container for test-app"
Windsurf: [Calls n8n workflow]
n8n: [Triggers Ansible playbook via Semaphore]
Response: "Container deployed at 10.92.3.99"
```

**Available Playbooks:**
- `deploy-proxmox-container.yml` - Deploy LXC containers
- `deploy-proxmox-vm.yml` - Deploy VMs
- `health-check.yml` - Check system health
- `system-update.yml` - Update packages
- `postgresql-failover.yml` - Database failover
- `decommission-container.yml` - Remove containers

**Requirements:**
- Semaphore API token (need to generate)
- Whitelist of allowed playbooks
- Authentication for security

---

### **Priority 2: Scheduled Health Checks** ⭐⭐⭐

**What it would do:**
- Run daily infrastructure health checks
- Parse results for issues
- Create Zammad tickets for problems
- Send summary reports

**Benefits:**
- Proactive issue detection
- Automated reporting
- Integration with existing ticketing

---

### **Priority 3: Backup Monitoring** ⭐⭐

**Current State:**
```bash
# Proxmox host cron jobs
0 2 * * * /usr/local/bin/backup-npm-db.sh
0 3 * * * /root/backup-scrypted-db.sh
0 * * * * /usr/local/bin/backup-metrics.sh
```

**What it would do:**
- Monitor all backup jobs
- Alert immediately on failures
- Track backup history
- Verify backup integrity

**Benefits:**
- No more silent backup failures
- Centralized monitoring
- Better visibility

---

### **Priority 4: PostgreSQL Failover Automation** ⭐⭐⭐

**What it would do:**
- Detect database failures via Uptime Kuma
- Check database status automatically
- Request approval for failover
- Execute failover playbook
- Verify new primary
- Update documentation

**Benefits:**
- Faster failover (30 min → 5 min)
- Approval workflow for safety
- Automated verification

---

### **Priority 5: Client Onboarding** ⭐⭐⭐

**What it would do:**
- Trigger on Stripe payment
- Create Twenty CRM record
- Create BookStack workspace
- Create Plane project
- Setup Zammad category
- Create Kimai client
- Send welcome email

**Benefits:**
- Consistent onboarding
- No manual steps
- Better client experience

---

## 📊 Current Automation Inventory

### **Cron Jobs**

**Proxmox Host:**
- NPM database backup (daily 2 AM)
- Scrypted database backup (daily 3 AM)
- Metrics backup (hourly)

**CT150 (monitoring-stack):**
- Proxmox-Netbox sync (every 15 min)

### **Ansible Playbooks**

**Location:** `/Users/cory/Projects/ansible-playbooks`  
**Count:** 17 playbooks  
**UI:** https://ansible.cloudigan.net

**Categories:**
- Infrastructure (deploy, decommission)
- System management (updates, health checks)
- Database (status, failover, rejoin)
- Application (restart, install)
- Automation (sync templates, inventory)

---

## 🔧 Implementation Recommendations

### **Week 1: Core Infrastructure**
1. ✅ Build Windsurf → Ansible workflow
2. ✅ Test with container deployment
3. ✅ Document usage

### **Week 2: Monitoring & Reliability**
1. Scheduled health checks
2. Backup monitoring
3. PostgreSQL failover automation

### **Week 3: Client Operations**
1. Client onboarding workflow
2. Incident response workflow
3. Container provisioning lifecycle

---

## 🎯 Next Steps

**Option A: Build Windsurf → Ansible Workflow**
- Most requested feature
- Enables infrastructure automation from chat
- Requires Semaphore API token

**Option B: Implement Health Check Automation**
- Proactive monitoring
- Uses existing playbooks
- Quick win

**Option C: Setup Backup Monitoring**
- Critical for reliability
- Prevents silent failures
- Relatively simple

**Option D: Continue with Client Onboarding (Option C from earlier)**
- Stripe → Full client setup
- Multi-system integration
- High business value

---

## 📈 Expected Impact

**Time Savings:**
- Container deployment: 15 min → 2 min (87% faster)
- Health checks: Manual → Automated (100% saved)
- Incident response: 30 min → 5 min (83% faster)

**Reliability:**
- Proactive issue detection
- Faster failover
- No missed backups
- Consistent execution

**Visibility:**
- Centralized workflow management
- Execution history
- Audit trail
- Performance metrics

---

## 📚 Documentation

**Completed:**
- [Automation Audit & Opportunities](./AUTOMATION-AUDIT-N8N-OPPORTUNITIES.md)
- [Uptime Kuma → Zammad Workflow](./N8N-UPTIME-KUMA-ZAMMAD-COMPLETE.md)
- [Zammad → Vikunja Workflow](./N8N-ZAMMAD-VIKUNJA-COMPLETE.md)
- [n8n API Integration](./N8N-API-INTEGRATION.md)

**References:**
- [Ansible Playbooks Reference](../ANSIBLE-PLAYBOOKS-REFERENCE.md)
- [Semaphore Setup](./ANSIBLE-SEMAPHORE-PLAYBOOKS.md)

---

## 🔐 Security Considerations

**For Ansible Integration:**
- Whitelist allowed playbooks
- Require authentication token
- Log all executions
- Approval workflow for destructive actions
- Rate limiting

**API Access:**
- Tokens stored encrypted in n8n
- IP whitelisting where possible
- Audit trail for all executions

---

**Status:** 2 workflows operational, ready for next phase  
**Recommendation:** Build Windsurf → Ansible integration next  
**Last Updated:** 2026-04-20 11:20 UTC
