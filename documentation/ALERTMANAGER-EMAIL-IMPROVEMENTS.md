# Alertmanager Email Improvements

**Date:** 2026-04-18  
**Issue:** Email alerts contained no useful information (blank body)  
**Status:** ✅ RESOLVED

---

## Problem

Email alerts from Alertmanager were showing only the subject line with no body content, making it impossible to diagnose issues without logging into Grafana/Prometheus.

**Example of old alert:**
- Subject: "🚨 LowDiskSpace - monitor"
- Body: (blank)

---

## Root Cause

The original email template used `.CommonAnnotations` which is only populated when multiple alerts are grouped together. For single alerts, this field was empty, resulting in blank email bodies.

**Original template:**
```html
<p><strong>Summary:</strong> {{ .CommonAnnotations.summary }}</p>
<p><strong>Description:</strong> {{ .CommonAnnotations.description }}</p>
```

---

## Solution

Completely redesigned the email template to:

1. **Loop through individual alerts** using `{{ range .Alerts }}`
2. **Extract annotations from each alert** using `.Annotations.summary` and `.Annotations.description`
3. **Add contextual information** (instance, severity, labels, timestamps)
4. **Include actionable remediation steps** based on alert type
5. **Style with HTML/CSS** for better readability

---

## New Email Template Features

### Visual Design
- ✅ Color-coded headers (red=critical, orange=warning, green=resolved)
- ✅ Styled alert boxes with left border indicators
- ✅ Monospace metric displays
- ✅ Highlighted action items in orange boxes
- ✅ Professional HTML layout with responsive design

### Information Displayed

**For Every Alert:**
- Alert name and status (firing/resolved)
- Summary and description from alert rules
- Instance/hostname
- Severity level (color-coded)
- Job name (if applicable)
- Container ID (if applicable)
- Mount point and filesystem type (for disk alerts)
- Alert start time (and end time if resolved)

**Context-Specific Labels:**
- Automatically shows relevant labels based on alert type
- Filters out noise, shows only useful information

### Actionable Remediation Steps

The template now includes **alert-specific action items** for common scenarios:

#### LowDiskSpace
```
📋 Recommended Actions:
- SSH to affected host: ssh [hostname]
- Check disk usage: df -h [mountpoint]
- Find large files: du -sh /* | sort -rh | head -10
- Check logs: du -sh /var/log/*
- Clean Docker: docker system prune -af
- View Grafana: [link]
```

#### CriticalDiskSpace
```
🚨 IMMEDIATE ACTIONS REQUIRED:
- URGENT: Disk is >90% full - service disruption imminent
- SSH immediately: ssh [hostname]
- Free space NOW: docker system prune -af && apt-get clean
- Check disk: df -h && du -sh /* | sort -rh | head -10
- Review logs: journalctl --vacuum-time=7d
```

#### HighCPU
```
📋 Recommended Actions:
- SSH to host: ssh [hostname]
- Check processes: top or htop
- View CPU details: mpstat -P ALL 1
- Check systemd services: systemctl --failed
- View Grafana: [link]
```

#### HighMemory
```
📋 Recommended Actions:
- SSH to host: ssh [hostname]
- Check memory: free -h
- Top processes: ps aux --sort=-%mem | head -20
- Check for memory leaks: systemctl status
- View Grafana: [link]
```

#### ContainerDown
```
📋 Recommended Actions:
- Check container status: ssh prox "pct status [CTID]"
- View container logs: ssh prox "pct exec [CTID] -- journalctl -n 50"
- Start container: ssh prox "pct start [CTID]"
- Check Proxmox: [link]
```

#### PostgresDown
```
🚨 DATABASE DOWN - IMMEDIATE ACTION:
- Check PostgreSQL: ssh prox "pct exec 131 -- systemctl status postgresql"
- View logs: ssh prox "pct exec 131 -- journalctl -u postgresql -n 100"
- Restart if needed: ssh prox "pct exec 131 -- systemctl restart postgresql"
- Check connections: ssh prox "pct exec 131 -- psql -U postgres -c 'SELECT count(*) FROM pg_stat_activity;'"
```

#### HAProxyBackendDown
```
🚨 BACKEND DOWN - SERVICE IMPACT:
- Check HAProxy stats: [link to stats page]
- View HAProxy logs: ssh prox "pct exec 136 -- journalctl -u haproxy -n 50"
- Check backend health: curl -I http://[backend-ip]:[port]/health
- Restart backend if needed
```

---

## Email Footer

Every email includes:
- Monitoring system info (Prometheus + Alertmanager on CT150)
- Links to Grafana dashboard
- Links to Prometheus UI
- Timestamp information

---

## Implementation

**File:** `/etc/alertmanager/alertmanager.yml` (CT150)

**Backup created:** `/etc/alertmanager/alertmanager.yml.backup-[timestamp]`

**Service restarted:** April 18, 2026 at 11:14 UTC

**Verification:**
```bash
# Check Alertmanager status
ssh prox "pct exec 150 -- systemctl status alertmanager"

# View current config
ssh prox "pct exec 150 -- cat /etc/alertmanager/alertmanager.yml"

# Test email template (trigger a test alert)
ssh prox "pct exec 150 -- amtool alert add test_alert alertname=TestAlert instance=test severity=warning"
```

---

## Testing

To test the new email format:

1. **Trigger a test alert** (optional - wait for real alert)
2. **Check email** for improved formatting
3. **Verify action items** are relevant to alert type
4. **Confirm links work** (Grafana, Prometheus, HAProxy stats)

---

## Benefits

✅ **Actionable information** - No need to log into Grafana to understand the issue  
✅ **Copy-paste commands** - SSH commands ready to use  
✅ **Visual clarity** - Color-coded severity and styled layout  
✅ **Context-aware** - Shows only relevant labels and metrics  
✅ **Faster response** - Remediation steps included in alert  
✅ **Professional appearance** - HTML styling improves readability  
✅ **Mobile-friendly** - Responsive design works on phones

---

## Alert Types Covered

The template includes specific action items for:
- ✅ LowDiskSpace
- ✅ CriticalDiskSpace
- ✅ HighCPU
- ✅ HighMemory
- ✅ ContainerDown
- ✅ PostgresDown
- ✅ HAProxyBackendDown

**Generic template** used for all other alert types (still shows all relevant info)

---

## Future Enhancements

Potential improvements:
- [ ] Add more alert-specific action items (bot health, TrueNAS, etc.)
- [ ] Include graphs/charts in emails (Grafana image renderer)
- [ ] Add runbook links for complex scenarios
- [ ] Integrate with ticketing system (create ticket from alert)
- [ ] Add "acknowledge" button in email
- [ ] Include recent metric trends in email body

---

## Related Files

- **Config:** `/etc/alertmanager/alertmanager.yml` (CT150)
- **Alert Rules:** `/etc/prometheus/rules/*.yml` (CT150)
- **Local Copy:** `/tmp/alertmanager-improved.yml`

---

## Rollback Procedure

If needed, restore previous config:

```bash
# Find latest backup
ssh prox "pct exec 150 -- ls -lt /etc/alertmanager/alertmanager.yml.backup-*"

# Restore backup
ssh prox "pct exec 150 -- cp /etc/alertmanager/alertmanager.yml.backup-[timestamp] /etc/alertmanager/alertmanager.yml"

# Restart Alertmanager
ssh prox "pct exec 150 -- systemctl restart alertmanager"
```

---

**Implemented:** April 18, 2026  
**Status:** Active and monitoring  
**Next Review:** Monitor email alerts over next week for any issues
