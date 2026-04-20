# Automation Audit & n8n Workflow Opportunities

**Date:** 2026-04-20  
**Purpose:** Identify existing automation and opportunities for n8n workflow integration

---

## 📊 Current Automation Inventory

### **1. Cron Jobs (Proxmox Host)**

**Location:** Proxmox host (prox)

```bash
# Backup automations
0 2 * * * /usr/local/bin/backup-npm-db.sh          # Daily NPM DB backup
0 3 * * * /root/backup-scrypted-db.sh              # Daily Scrypted DB backup
0 * * * * /usr/local/bin/backup-metrics.sh         # Hourly metrics backup
```

**Location:** CT150 (monitoring-stack)

```bash
# Sync automation
*/15 * * * * /opt/sync/run-sync.sh                 # Proxmox-Netbox sync every 15 min
```

---

### **2. Ansible Playbooks**

**Location:** `/Users/cory/Projects/ansible-playbooks`  
**Semaphore UI:** https://ansible.cloudigan.net

**Infrastructure Management:**
- `deploy-proxmox-container.yml` - Deploy LXC with full automation
- `deploy-proxmox-vm.yml` - Deploy VM with full automation
- `decommission-container.yml` - Remove containers cleanly

**System Management:**
- `system-update.yml` - Update all packages
- `health-check.yml` - Check system health
- `fix-python-modules.yml` - Bootstrap Python
- `distribute-ssh-key.yml` - Deploy SSH keys

**Database Management:**
- `postgresql-status.yml` - Check DB health
- `postgresql-failover.yml` - Failover to replica
- `postgresql-rejoin-old-primary.yml` - Rejoin old primary

**Application Management:**
- `nodejs-app-restart.yml` - Restart Node.js apps
- `install-coreutils-calibre.yml` - Install specific packages

**Automation Management:**
- `sync-semaphore-templates.yml` - Sync playbooks to Semaphore
- `sync-inventory.yml` - Sync inventory

---

### **3. Existing n8n Workflows**

**Deployed:**
1. **Uptime Kuma → Zammad** (ID: hpcPBbttShe5Uc7j)
   - Auto-create tickets on service down
   - 28 monitors configured

2. **Zammad → Vikunja** (ID: 6mcHbtq1wHF8dzBe)
   - Auto-create tasks from tickets
   - Active on all new tickets

---

## 🎯 n8n Workflow Opportunities

### **Priority 1: High-Value Automations**

#### **1. Windsurf → Ansible Playbook Execution** ⭐⭐⭐
**Use Case:** Run Ansible playbooks directly from Windsurf/chat interface

**Flow:**
```
Windsurf/API Request → n8n → Semaphore API → Ansible Playbook → Response
```

**Benefits:**
- Deploy containers from chat
- Run health checks on demand
- Execute failovers without SSH
- Full audit trail in Semaphore

**Implementation:**
- n8n webhook receives playbook name + variables
- Calls Semaphore API to trigger task
- Polls for completion
- Returns results

---

#### **2. Scheduled Health Checks** ⭐⭐⭐
**Use Case:** Automated daily/weekly infrastructure health checks

**Flow:**
```
n8n Schedule → Ansible health-check.yml → Parse Results → Alert if Issues
```

**Benefits:**
- Proactive issue detection
- Automated reporting
- Integration with Zammad for issues

**Implementation:**
- Daily schedule trigger
- Run health-check playbook
- Parse output for failures
- Create Zammad ticket if issues found
- Send summary to Teams/Slack

---

#### **3. Backup Monitoring & Alerting** ⭐⭐
**Use Case:** Monitor backup jobs and alert on failures

**Flow:**
```
Backup Script → n8n Webhook → Check Success → Alert if Failed
```

**Benefits:**
- Immediate failure notification
- Backup verification
- Historical tracking

**Implementation:**
- Modify backup scripts to POST to n8n webhook
- n8n checks exit code and output
- Create Zammad ticket on failure
- Log to BookStack

---

#### **4. PostgreSQL Failover Automation** ⭐⭐⭐
**Use Case:** Automated database failover with approval workflow

**Flow:**
```
Alert → n8n → Check DB Status → Request Approval → Execute Failover → Notify
```

**Benefits:**
- Faster failover response
- Approval workflow for safety
- Automated post-failover checks

**Implementation:**
- Triggered by Uptime Kuma alert
- Runs postgresql-status.yml
- Sends approval request (Teams/Slack)
- Executes postgresql-failover.yml
- Verifies new primary
- Updates documentation

---

#### **5. Container Provisioning Workflow** ⭐⭐
**Use Case:** Full container lifecycle from request to deployment

**Flow:**
```
Request → Approval → Deploy Container → Configure → Test → Document
```

**Benefits:**
- Standardized deployment process
- Approval workflow
- Automatic documentation

**Implementation:**
- Webhook or form submission
- Manager approval step
- Run deploy-proxmox-container.yml
- Wait for service to be healthy
- Create BookStack documentation page
- Send completion notification

---

### **Priority 2: Efficiency Improvements**

#### **6. Automated System Updates** ⭐
**Use Case:** Scheduled updates with maintenance windows

**Flow:**
```
Schedule → Check Maintenance Window → Run Updates → Verify → Report
```

**Implementation:**
- Weekly schedule (Sunday 2 AM)
- Run system-update.yml on all hosts
- Verify services after update
- Create summary report

---

#### **7. Backup Consolidation Workflow** ⭐
**Use Case:** Centralized backup orchestration

**Flow:**
```
Schedule → Run All Backups → Verify → Sync to TrueNAS → Report
```

**Implementation:**
- Replace individual cron jobs
- Centralized in n8n
- Better error handling
- Unified reporting

---

#### **8. SSH Key Distribution** ⭐
**Use Case:** Automated SSH key deployment to new containers

**Flow:**
```
New Container Created → Wait for SSH → Deploy Keys → Verify
```

**Implementation:**
- Triggered by container creation
- Run distribute-ssh-key.yml
- Verify SSH access
- Update documentation

---

### **Priority 3: Advanced Integrations**

#### **9. Client Onboarding Automation** ⭐⭐⭐
**Use Case:** Full client setup from Stripe payment

**Flow:**
```
Stripe Payment → Create CRM Record → Deploy Resources → Setup Access → Notify
```

**Implementation:**
- Stripe webhook trigger
- Create Twenty CRM record
- Deploy client containers (if needed)
- Create BookStack workspace
- Create Plane project
- Setup Zammad category
- Send welcome email

---

#### **10. Incident Response Workflow** ⭐⭐
**Use Case:** Automated incident handling

**Flow:**
```
Alert → Create Incident → Run Diagnostics → Attempt Remediation → Escalate
```

**Implementation:**
- Triggered by critical alerts
- Create Zammad incident ticket
- Run health-check.yml
- Attempt auto-remediation
- Create Vikunja task
- Notify on-call team

---

## 🔧 Implementation Plan

### **Phase 1: Core Infrastructure (Week 1)**

**1. Windsurf → Ansible Integration** (Priority 1)
- Create n8n workflow for Semaphore API
- Add webhook endpoint for playbook execution
- Document usage in Windsurf
- Test with deploy-proxmox-container.yml

**2. Scheduled Health Checks** (Priority 1)
- Create daily health check workflow
- Parse and alert on failures
- Integration with Zammad

**3. Backup Monitoring** (Priority 1)
- Update backup scripts to use webhooks
- Create monitoring workflow
- Alert on failures

---

### **Phase 2: Database & High Availability (Week 2)**

**4. PostgreSQL Failover Automation**
- Create approval workflow
- Integrate with Uptime Kuma alerts
- Automated failover execution

**5. Container Provisioning Workflow**
- Full lifecycle automation
- Approval steps
- Documentation generation

---

### **Phase 3: Client & Operations (Week 3)**

**6. Client Onboarding Automation**
- Stripe integration
- Multi-system setup
- Welcome email workflow

**7. Incident Response Workflow**
- Auto-remediation attempts
- Escalation paths
- Documentation

---

## 📋 Recommended Workflow: Windsurf → Ansible

### **Workflow Design**

**Name:** Execute Ansible Playbook from Windsurf

**Trigger:** Webhook POST to `/webhook/ansible-execute`

**Input:**
```json
{
  "playbook": "deploy-proxmox-container",
  "variables": {
    "container_name": "test-app",
    "container_function": "dev",
    "container_ip": "10.92.3.99",
    "container_domain": "test.cloudigan.net"
  },
  "requester": "cory@cloudigan.com"
}
```

**Steps:**
1. Validate playbook name (whitelist)
2. Call Semaphore API to create task
3. Poll for task completion (max 10 min)
4. Return results with task ID and logs
5. Log execution to BookStack

**Response:**
```json
{
  "success": true,
  "task_id": 123,
  "status": "success",
  "output": "Container deployed successfully",
  "semaphore_url": "https://ansible.cloudigan.net/project/1/history/123"
}
```

---

## 🔐 Security Considerations

**Ansible Playbook Execution:**
- Whitelist allowed playbooks
- Require authentication token
- Log all executions
- Approval workflow for destructive actions

**API Access:**
- Semaphore API token stored in n8n credentials
- Rate limiting on webhooks
- IP whitelist for sensitive workflows

**Audit Trail:**
- All executions logged to BookStack
- Zammad tickets for major changes
- Vikunja tasks for tracking

---

## 📊 Expected Benefits

**Time Savings:**
- Container deployment: 15 min → 2 min (87% faster)
- Health checks: Manual → Automated (100% time saved)
- Backup monitoring: Reactive → Proactive
- Incident response: 30 min → 5 min (83% faster)

**Reliability:**
- Consistent execution
- No missed backups
- Faster failover
- Better documentation

**Visibility:**
- Centralized workflow management
- Execution history
- Performance metrics
- Audit trail

---

## 🚀 Next Steps

**Immediate (Today):**
1. ✅ Create Windsurf → Ansible workflow
2. ✅ Test with deploy-proxmox-container
3. ✅ Document usage

**This Week:**
1. Implement health check automation
2. Add backup monitoring
3. Create PostgreSQL failover workflow

**Next Week:**
1. Container provisioning workflow
2. Client onboarding automation
3. Incident response workflow

---

## 📚 Related Documentation

- [Ansible Playbooks Reference](../ANSIBLE-PLAYBOOKS-REFERENCE.md)
- [Semaphore Setup](./ANSIBLE-SEMAPHORE-PLAYBOOKS.md)
- [n8n API Integration](./N8N-API-INTEGRATION.md)
- [Existing n8n Workflows](./N8N-UPTIME-KUMA-ZAMMAD-COMPLETE.md)

---

**Status:** Analysis Complete - Ready for Implementation  
**Priority:** High - Windsurf → Ansible integration recommended first  
**Last Updated:** 2026-04-20
