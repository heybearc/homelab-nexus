# Semaphore Setup Inputs - CT183

## Setup Choice: 3 (PostgreSQL)

### Database Configuration

**DB Hostname:** `10.92.3.31`  
**DB User:** `semaphore_user`  
**DB Password:** `semaphore_password_2026`  
**DB Name:** `semaphore`  
**DB Port:** `5432` (default)

### Semaphore Configuration

**Playbook path:** `/etc/ansible/playbooks`  
**Web root URL:** `http://ansible.cloudigan.net`  
**Enable email alerts:** `no`  
**Enable telegram alerts:** `no`  
**Enable LDAP:** `no`

### Admin User

**Admin name:** `admin`  
**Admin email:** `admin@cloudigan.net`  
**Admin username:** `admin`  
**Admin password:** `Cloudigan_Ansible_2026!`

---

## Complete Setup Sequence

When you run `semaphore setup`, choose these options:

1. **Database type:** `3` (PostgreSQL)
2. **DB Hostname:** `10.92.3.31`
3. **DB User:** `semaphore_user`
4. **DB Password:** `semaphore_password_2026`
5. **DB Name:** `semaphore`
6. **DB Port:** `5432`
7. **Playbook path:** `/etc/ansible/playbooks`
8. **Web root URL:** `http://ansible.cloudigan.net`
9. **Enable email alerts:** `n`
10. **Enable telegram alerts:** `n`
11. **Enable LDAP:** `n`
12. **Admin name:** `admin`
13. **Admin email:** `admin@cloudigan.net`
14. **Admin username:** `admin`
15. **Admin password:** `Cloudigan_Ansible_2026!`

---

## After Setup

### Start Semaphore Service
```bash
systemctl enable semaphore
systemctl start semaphore
systemctl status semaphore
```

### Access Web UI
- **URL:** http://ansible.cloudigan.net:3000
- **Username:** admin
- **Password:** Cloudigan_Ansible_2026!

### Create NPM Proxy Entry
Go to NPM web UI (http://10.92.3.3:81) and create:
- **Domain:** ansible.cloudigan.net
- **Forward to:** 10.92.3.90:3000
- **SSL:** No (for now)

---

## Database Details

**PostgreSQL Server:** CT131 (10.92.3.31)  
**Database:** semaphore  
**User:** semaphore_user  
**Password:** semaphore_password_2026  
**Permissions:** GRANT ALL ON DATABASE semaphore TO semaphore_user

---

## Verification

```bash
# Test database connection from CT183
psql -h 10.92.3.31 -U semaphore_user -d semaphore -c "SELECT version();"

# Check Semaphore service
systemctl status semaphore

# Check web UI is responding
curl -I http://localhost:3000
```
