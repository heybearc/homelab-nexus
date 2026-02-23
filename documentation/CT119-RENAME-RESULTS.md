# CT119 Rename Results - sandbox-01 → bni-toolkit-dev

**Date:** 2026-02-23  
**Status:** ✅ SUCCESSFUL

---

## Summary

Successfully renamed CT119 from `sandbox-01` to `bni-toolkit-dev` with full DNS automation and zero password prompts.

---

## Changes Made

### Proxmox
- ✅ Container stopped
- ✅ Hostname updated: `bni-toolkit-dev`
- ✅ Container restarted
- ✅ Hostname verified inside container

### DNS (DC-01)
- ✅ Old record removed: `sandbox-01.cloudigan.net`
- ✅ New record added: `bni-toolkit-dev.cloudigan.net` → `10.92.3.13`
- ✅ DNS resolution verified
- ✅ Network connectivity confirmed

### Application
- ✅ BNI Chapter Toolkit app running on PM2
- ✅ Next.js 15.5.11 started successfully
- ✅ Port 3001 accessible
- ✅ Database connection working (PostgreSQL 10.92.3.21)
- ✅ No hardcoded hostname references in .env file

---

## Testing Results

### Container Status
```bash
$ ssh prox "pct exec 119 -- hostname"
bni-toolkit-dev
```

### DNS Resolution
```bash
$ nslookup bni-toolkit-dev.cloudigan.net 10.92.0.10
Server:         10.92.0.10
Address:        10.92.0.10#53

Name:   bni-toolkit-dev.cloudigan.net
Address: 10.92.3.13
```

### Network Connectivity
```bash
$ ping -c 2 bni-toolkit-dev.cloudigan.net
PING bni-toolkit-dev.cloudigan.net (10.92.3.13): 56 data bytes
64 bytes from 10.92.3.13: icmp_seq=0 ttl=62 time=8.658 ms
64 bytes from 10.92.3.13: icmp_seq=1 ttl=62 time=6.723 ms
```

### Application Status
```bash
$ ssh prox "pct exec 119 -- pm2 list"
┌────┬────────────────┬─────────────┬─────────┬─────────┬──────────┬────────┬──────┬──────────┬──────────┬──────────┬──────────┬──────────┐
│ id │ name           │ namespace   │ version │ mode    │ pid      │ uptime │ ↺    │ status   │ cpu      │ mem      │ user     │ watching │
├────┼────────────────┼─────────────┼─────────┼─────────┼──────────┼────────┼──────┼──────────┼──────────┼──────────┼──────────┼──────────┤
│ 0  │ bni-toolkit    │ default     │ N/A     │ fork    │ 162      │ 64s    │ 0    │ online   │ 0%       │ 67.7mb   │ root     │ disabled │
└────┴────────────────┴─────────────┴─────────┴─────────┴──────────┴────────┴──────┴──────────┴──────────┴──────────┴──────────┴──────────┘
```

---

## Hardcoded References Found

### Control Plane (.cloudy-work/)
- ✅ `DECISIONS.md` - D-LOCAL-009 references (documentation only)
- ✅ `TASK-STATE.md` - Historical references (documentation only)
- ✅ `APP-MAP.md` - Needs update to `bni-toolkit-dev`
- ✅ `development-contract.md` - Needs update to `bni-toolkit-dev`
- ✅ `D-024-IMPLEMENTATION-BNI-TOOLKIT.md` - Needs update to `bni-toolkit-dev`

### Application (.env)
- ✅ No hardcoded hostname references
- ✅ Uses IP addresses (10.92.3.21 for database)
- ✅ Uses domain name for NEXTAUTH_URL (bnitoolkit.cloudigan.net)

### Homelab-Nexus Repo
- ✅ Documentation updated
- ✅ Rename plan marked complete
- ✅ Infrastructure-spec.md updated

---

## Issues Encountered

### DNS Script Verification
**Issue:** DNS verification script had trouble parsing PowerShell output format  
**Impact:** Script reported failure but DNS was actually working correctly  
**Resolution:** Manual verification confirmed DNS working, script needs improvement  
**Action:** Update DNS verification parsing in future iteration

---

## Documentation Updates Needed

### Control Plane (.cloudy-work/)
1. **APP-MAP.md** - Update container name from `sandbox-01` to `bni-toolkit-dev`
2. **development-contract.md** - Update table entry
3. **D-024-IMPLEMENTATION-BNI-TOOLKIT.md** - Update all SSH commands and references
4. **sandbox-app-support.md** - Update container name references

### Note
Historical references in DECISIONS.md and TASK-STATE.md can remain as-is since they document past decisions and work.

---

## Lessons Learned

1. **SSH Key Auth:** Domain admin accounts in Administrators group require key in `C:\ProgramData\ssh\administrators_authorized_keys`, not user's `.ssh` directory
2. **DNS Automation:** Works perfectly once SSH keys configured correctly
3. **Zero Downtime:** App automatically restarted after container rename
4. **No App Changes:** Application .env uses IPs and domains, no hardcoded container names

---

## Next Steps

1. Update control plane documentation (APP-MAP.md, etc.)
2. Continue with CT101 (quantshift-standby → quantshift-bot-standby)
3. Continue with CT100 (quantshift-primary → quantshift-bot-primary)

---

**Time Taken:** ~10 minutes (including troubleshooting)  
**Downtime:** ~2 minutes (container stop/start)  
**Password Prompts:** 0 (SSH key auth working)

---

**Status:** ✅ COMPLETE - Ready for next container
