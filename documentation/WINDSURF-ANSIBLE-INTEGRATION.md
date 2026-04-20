# Windsurf → Ansible Integration

**Status:** 🚧 In Progress  
**Date:** 2026-04-20  
**Workflow ID:** 6RI9JH7gtAypClvt (needs update)

---

## 🎯 Goal

Enable execution of Ansible playbooks directly from Windsurf chat interface via n8n workflow.

---

## 🔧 Current Status

**Attempted Approach:** n8n Execute Command node  
**Issue:** Execute Command node not available in current n8n version

**Alternative Approaches:**

### **Option A: SSH Execution via n8n** (Recommended)
- Use n8n SSH node to connect to ansible-control container
- Execute playbooks remotely
- Return results

### **Option B: Local API Wrapper**
- Create simple Flask/FastAPI service on local machine
- n8n calls local API
- API executes Ansible playbooks
- Returns results

### **Option C: Direct Ansible Control Access**
- n8n runs on CT188 (10.92.3.79)
- Mount ansible-playbooks repo in n8n container
- Execute playbooks directly

---

## 📋 Available Playbooks

**Infrastructure:**
- `deploy-proxmox-container` - Deploy LXC containers
- `deploy-proxmox-vm` - Deploy VMs
- `decommission-container` - Remove containers

**System Management:**
- `system-update` - Update packages
- `health-check` - Check system health
- `fix-python-modules` - Bootstrap Python

**Database:**
- `postgresql-status` - Check DB health
- `postgresql-failover` - Failover to replica
- `postgresql-rejoin-old-primary` - Rejoin old primary

**Application:**
- `nodejs-app-restart` - Restart Node.js apps

---

## 🚀 Recommended Implementation

### **Step 1: Setup SSH Access from n8n to ansible-control**

```bash
# On n8n container (CT188)
ssh-keygen -t ed25519 -f /root/.ssh/ansible_control -N ""

# Copy public key to ansible-control (CT183)
ssh-copy-id -i /root/.ssh/ansible_control.pub root@10.92.3.77
```

### **Step 2: Create n8n Workflow with SSH Node**

**Nodes:**
1. Webhook - Receive playbook request
2. Validate - Check playbook name is whitelisted
3. SSH - Execute playbook on ansible-control
4. Parse Output - Extract results
5. Response - Return success/failure

**Webhook Payload:**
```json
{
  "playbook": "health-check",
  "variables": {
    "target_host": "all"
  },
  "requester": "cory@cloudigan.com"
}
```

**SSH Command:**
```bash
cd /root/ansible-playbooks && \
ansible-playbook playbooks/{playbook}.yml \
  -e "{variables}" \
  --one-line
```

### **Step 3: Whitelist Allowed Playbooks**

**Safe Playbooks (Read-only):**
- health-check
- postgresql-status
- system-update (with approval)

**Restricted Playbooks (Require approval):**
- deploy-proxmox-container
- deploy-proxmox-vm
- postgresql-failover
- decommission-container

---

## 🔐 Security Considerations

**Whitelist:**
- Only allow specific playbooks
- Validate playbook names against whitelist
- Reject any path traversal attempts

**Authentication:**
- Require API token in webhook
- Log all executions
- Track requester

**Approval Workflow:**
- Destructive actions require approval
- Send approval request to Teams/Slack
- Wait for confirmation before executing

**Audit Trail:**
- Log to BookStack
- Create Vikunja task for tracking
- Store execution history

---

## 📊 Usage Examples

### **Example 1: Run Health Check**

```bash
curl -X POST https://flows.cloudigan.net/webhook/ansible-execute \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -d '{
    "playbook": "health-check",
    "variables": {},
    "requester": "cory@cloudigan.com"
  }'
```

**Response:**
```json
{
  "success": true,
  "playbook": "health-check",
  "output": "All hosts healthy",
  "execution_time": "45s",
  "task_url": "https://tasks.cloudigan.net/tasks/44"
}
```

### **Example 2: Deploy Container**

```bash
curl -X POST https://flows.cloudigan.net/webhook/ansible-execute \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -d '{
    "playbook": "deploy-proxmox-container",
    "variables": {
      "container_name": "test-app",
      "container_function": "dev",
      "container_ip": "10.92.3.99",
      "container_domain": "test.cloudigan.net"
    },
    "requester": "cory@cloudigan.com"
  }'
```

**Response:**
```json
{
  "success": true,
  "playbook": "deploy-proxmox-container",
  "container_id": "199",
  "container_ip": "10.92.3.99",
  "domain": "test.cloudigan.net",
  "execution_time": "2m15s"
}
```

---

## 🔄 Integration with Windsurf

Once the workflow is complete, you can execute playbooks from Windsurf like this:

**User:** "Deploy a new container for test-app at 10.92.3.99"

**Windsurf/Cascade:**
1. Parses request
2. Calls n8n webhook with playbook parameters
3. n8n executes Ansible playbook
4. Returns results

**Response:** "Container deployed successfully at 10.92.3.99 (test.cloudigan.net)"

---

## 📝 Next Steps

**To Complete This Workflow:**

1. ✅ Setup SSH key from n8n (CT188) to ansible-control (CT183)
2. ⏳ Create n8n workflow with SSH node
3. ⏳ Test with health-check playbook
4. ⏳ Add approval workflow for destructive actions
5. ⏳ Document Windsurf integration
6. ⏳ Create helper function for Windsurf to call

---

## 🚧 Current Blocker

**Issue:** n8n Execute Command node not available  
**Solution:** Use SSH node instead to execute on ansible-control container

**Alternative:** Since Semaphore is not running, we can:
- Use direct SSH execution (recommended)
- Install and configure Semaphore
- Create local API wrapper

---

**Recommendation:** Proceed with SSH node approach - it's simpler and doesn't require additional services.

**Would you like me to:**
- A) Continue building with SSH node approach
- B) Setup and configure Semaphore first
- C) Create a local API wrapper instead

---

**Last Updated:** 2026-04-20 11:26 UTC
