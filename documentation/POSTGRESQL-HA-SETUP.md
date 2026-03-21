# PostgreSQL High Availability Setup

**Last Updated:** 2026-03-21  
**Status:** ✅ OPERATIONAL  
**Failover Type:** Automatic (Prometheus-based)  
**Failover Time:** ~30 seconds

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│ CT150 (Monitoring Stack)                                        │
│                                                                  │
│  Prometheus → Alert Rules → Alertmanager → Webhook (port 9098) │
│       ↓                                          ↓               │
│  postgres_exporter (CT131 + CT151)    Semaphore API Call       │
└─────────────────────────────────────────────────────────────────┘
                                                    ↓
                        Ansible Playbook (postgresql-failover.yml)
                                                    ↓
                        Promote CT151 to Primary
```

## Components

### 1. PostgreSQL Nodes

**Primary (CT131):**
- IP: 10.92.3.21
- Port: 5432
- Databases: theoshift_scheduler, semaphore, ldc_tools, quantshift, bni_toolkit
- postgres_exporter: Port 9187

**Standby (CT151):**
- IP: 10.92.3.31
- Port: 5432
- Streaming replication from CT131
- postgres_exporter: Port 9187

### 2. Monitoring (CT150)

**Prometheus:**
- Scrapes postgres_exporter on both nodes every 15 seconds
- Alert rules: `/etc/prometheus/rules/postgresql-ha.yml`
- Monitors `pg_up` metric for database availability

**Alertmanager:**
- Routes PostgreSQL alerts to webhook receiver
- Configuration: `/etc/alertmanager/alertmanager.yml`

**Webhook Receiver:**
- Service: `postgresql-failover-webhook.service`
- Port: 9098
- Script: `/usr/local/bin/postgresql-failover-webhook.py`
- Triggers Semaphore template via API

### 3. Failover Automation

**Semaphore Templates:**
- **PostgreSQL Failover** - Promotes CT151 to primary
- **PostgreSQL Rejoin Old Primary** - Rejoins CT131 as standby

**Playbooks:**
- `playbooks/postgresql-failover.yml`
- `playbooks/postgresql-rejoin-old-primary.yml`

---

## How Automatic Failover Works

1. **Detection (30 seconds):**
   - Prometheus detects `pg_up{container="ct131"} == 0`
   - Alert fires after 30 seconds of downtime

2. **Alerting:**
   - Alertmanager receives alert
   - Routes to `postgresql-failover` receiver
   - Sends webhook to CT150:9098

3. **Execution:**
   - Webhook receiver authenticates to Semaphore
   - Triggers "PostgreSQL Failover" template
   - Ansible playbook runs on Semaphore

4. **Promotion:**
   - Verifies primary is truly down (prevents split-brain)
   - Promotes CT151 to primary via `pg_ctl promote`
   - Verifies promotion successful
   - Sends Teams notification (if configured)

5. **Total Downtime:** ~30 seconds

---

## Alert Rules

**PostgreSQLPrimaryDown** (Critical):
- Triggers when: `pg_up{container="ct131"} == 0` for 30 seconds
- Action: Automatic failover to CT151
- Label: `action: failover`

**PostgreSQLStandbyPromoted** (Warning):
- Triggers when: CT151 exits recovery mode
- Indicates: Successful failover completion

**PostgreSQLReplicationLag** (Warning):
- Triggers when: Replication lag > 60 seconds
- Action: Alert only (no automatic action)

**PostgreSQLClusterDown** (Critical):
- Triggers when: Both nodes unreachable
- Action: Alert only (manual intervention required)

---

## Manual Operations

### Check Cluster Status

```bash
# Check which node is primary
ssh prox "pct exec 131 -- sudo -u postgres psql -c 'SELECT pg_is_in_recovery();'"
ssh prox "pct exec 151 -- sudo -u postgres psql -c 'SELECT pg_is_in_recovery();'"

# Check replication status on primary
ssh prox "pct exec 131 -- sudo -u postgres psql -c 'SELECT * FROM pg_stat_replication;'"

# Check postgres_exporter metrics
curl http://10.92.3.21:9187/metrics | grep pg_up
curl http://10.92.3.31:9187/metrics | grep pg_up
```

### Manual Failover

If you need to manually failover (e.g., for maintenance):

1. **Run failover playbook in Semaphore:**
   - Navigate to: https://ansible.cloudigan.net
   - Select "PostgreSQL Failover" template
   - Click "Run"

2. **Or run locally:**
   ```bash
   cd /Users/cory/Projects/ansible-playbooks
   ansible-playbook playbooks/postgresql-failover.yml
   ```

### Rejoin Old Primary After Failover

After CT131 comes back online, rejoin it as a standby:

1. **Run rejoin playbook in Semaphore:**
   - Select "PostgreSQL Rejoin Old Primary" template
   - Click "Run"

2. **Or run locally:**
   ```bash
   cd /Users/cory/Projects/ansible-playbooks
   ansible-playbook playbooks/postgresql-rejoin-old-primary.yml
   ```

---

## Monitoring & Logs

### Prometheus Alerts
- URL: http://grafana.cloudigan.net (or http://10.92.3.2:9090)
- Navigate to: Alerts → postgresql_ha

### Failover Logs
```bash
# View webhook receiver logs
ssh prox "pct exec 150 -- tail -f /var/log/postgresql-failover.log"

# View webhook service status
ssh prox "pct exec 150 -- systemctl status postgresql-failover-webhook"

# View Semaphore task history
# https://ansible.cloudigan.net/project/1/history
```

### Alertmanager
- URL: http://10.92.3.2:9093
- View active alerts and routing

---

## Configuration Files

### Prometheus Alert Rules
**Location:** CT150:/etc/prometheus/rules/postgresql-ha.yml

### Alertmanager Configuration
**Location:** CT150:/etc/alertmanager/alertmanager.yml

### Webhook Receiver
**Location:** CT150:/usr/local/bin/postgresql-failover-webhook.py  
**Service:** CT150:/etc/systemd/system/postgresql-failover-webhook.service

### Prometheus Scrape Config
**Location:** CT150:/etc/prometheus/prometheus.yml
- Job: `postgres_exporter` (CT131)
- Job: `postgres_exporter_replica` (CT151)

---

## Safety Features

1. **Split-Brain Prevention:**
   - Failover playbook verifies primary is truly unreachable
   - Aborts if primary still responds on port 5432

2. **Standby Verification:**
   - Confirms CT151 is reachable before promotion
   - Aborts if standby is down

3. **Promotion Verification:**
   - Checks `pg_is_in_recovery()` after promotion
   - Only reports success if standby exits recovery mode

4. **Alert Grouping:**
   - Alertmanager groups repeated alerts
   - Prevents multiple simultaneous failover attempts

---

## Troubleshooting

### Failover Not Triggering

1. Check Prometheus is scraping both nodes:
   ```bash
   curl http://10.92.3.2:9090/api/v1/targets | grep postgres_exporter
   ```

2. Check alert is firing:
   ```bash
   curl http://10.92.3.2:9090/api/v1/alerts | grep PostgreSQLPrimaryDown
   ```

3. Check webhook receiver is running:
   ```bash
   ssh prox "pct exec 150 -- systemctl status postgresql-failover-webhook"
   ```

4. Check webhook logs:
   ```bash
   ssh prox "pct exec 150 -- tail -50 /var/log/postgresql-failover.log"
   ```

### Failover Failed

1. Check Semaphore task output:
   - Navigate to https://ansible.cloudigan.net/project/1/history
   - View failed task details

2. Common issues:
   - Primary still reachable (split-brain prevention)
   - Standby not reachable
   - SSH connectivity issues
   - PostgreSQL promotion command failed

### Replication Broken

1. Check replication status:
   ```bash
   ssh prox "pct exec 131 -- sudo -u postgres psql -c 'SELECT * FROM pg_stat_replication;'"
   ```

2. If no replication slots, rejoin standby:
   ```bash
   ansible-playbook playbooks/postgresql-rejoin-old-primary.yml
   ```

---

## Future Enhancements

- [ ] Add Grafana dashboard for PostgreSQL HA metrics
- [ ] Implement automatic rejoin of old primary
- [ ] Add health check endpoint for application connection strings
- [ ] Consider HAProxy for database connection pooling
- [ ] Add automated testing of failover scenarios
- [ ] Implement backup verification before failover

---

## Related Documentation

- `IMPLEMENTATION-PLAN.md` - Overall infrastructure plan
- `SEMAPHORE-SETUP-INPUTS.md` - Semaphore configuration
- Ansible playbooks: `ansible-playbooks/playbooks/postgresql-*.yml`
