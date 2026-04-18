# Alert Email Example - New Format

**What you'll see in your next alert email:**

---

## Email Subject
```
🚨 LowDiskSpace - 10.92.3.2
```

---

## Email Body (HTML Formatted)

### Header (Color-coded)
- **Red background** for critical alerts
- **Orange background** for warnings
- **Green background** for resolved alerts

---

### Alert Details Box

**Alert Name:** Low disk on 10.92.3.2

**Description:** Disk usage is 82.3% on 10.92.3.2:9100

**Instance:** 10.92.3.2:9100

**Severity:** WARNING (in orange text)

**Job:** node_exporter

**Mount Point:** /

**Filesystem:** ext4

**Metrics:**
```
Alert Started: 2026-04-18 07:00:00 EDT
Status: firing
```

---

### Action Items (Orange Box)

**📋 Recommended Actions:**

- SSH to affected host: `ssh 10.92.3.2`
- Check disk usage: `df -h /`
- Find large files: `du -sh /* | sort -rh | head -10`
- Check logs: `du -sh /var/log/*`
- Clean Docker: `docker system prune -af` (if applicable)
- View Grafana: [Dashboard Link]

---

### Footer

**Monitoring System:** Prometheus + Alertmanager (CT150)  
**Grafana:** https://grafana.cloudigan.net  
**Prometheus:** http://10.92.3.2:9090

---

## What Changed

### Before (Your Screenshot)
```
Subject: LowDiskSpace - monitor
Body: (blank)
```

### After (New Format)
```
Subject: 🚨 LowDiskSpace - 10.92.3.2
Body: 
  - Full alert details
  - Severity and instance info
  - Exact disk usage percentage
  - Mount point and filesystem
  - Copy-paste SSH commands
  - Specific remediation steps
  - Links to dashboards
  - Timestamps
```

---

## Alert-Specific Examples

### Critical Disk Space
```
🚨 IMMEDIATE ACTIONS REQUIRED:

- URGENT: Disk is >90% full - service disruption imminent
- SSH immediately: ssh 10.92.3.2
- Free space NOW: docker system prune -af && apt-get clean
- Check disk: df -h && du -sh /* | sort -rh | head -10
- Review logs: journalctl --vacuum-time=7d
```

### Container Down
```
📋 Recommended Actions:

- Check container status: ssh prox "pct status 131"
- View container logs: ssh prox "pct exec 131 -- journalctl -n 50"
- Start container: ssh prox "pct start 131"
- Check Proxmox: https://10.92.0.5:8006
```

### PostgreSQL Down
```
🚨 DATABASE DOWN - IMMEDIATE ACTION:

- Check PostgreSQL: ssh prox "pct exec 131 -- systemctl status postgresql"
- View logs: ssh prox "pct exec 131 -- journalctl -u postgresql -n 100"
- Restart if needed: ssh prox "pct exec 131 -- systemctl restart postgresql"
- Check connections: ssh prox "pct exec 131 -- psql -U postgres -c 'SELECT count(*) FROM pg_stat_activity;'"
```

---

## Benefits

✅ **No more blank emails** - All alerts now have detailed information  
✅ **Actionable** - Copy-paste commands ready to use  
✅ **Context-aware** - Shows relevant info for each alert type  
✅ **Professional** - HTML styling, color-coded, easy to read  
✅ **Mobile-friendly** - Looks good on phone and desktop  
✅ **Faster response** - Don't need to log into Grafana to understand issue

---

## Next Alert

The next time you receive an alert email, it will have:
1. Detailed description of the problem
2. Exact metrics (CPU %, disk %, memory %, etc.)
3. Affected instance/container
4. Severity level
5. Specific commands to diagnose
6. Specific commands to fix
7. Links to relevant dashboards
8. Timestamps

**No more guessing what the alert is about!**
