# TP-Link SG3428XMP Switch - SSH Key Setup & Omada Adoption

**Date:** April 2, 2026  
**Status:** Configuration Complete - Pending Key Upload & Reboot  
**Switch:** SG3428XMP at 10.92.0.2

---

## Summary

The TP-Link SG3428XMP core switch has been configured for Omada Controller adoption but requires:
1. SSH public key upload via web UI (for key-based authentication)
2. Reboot during maintenance window (to trigger Omada discovery)

---

## Completed Configuration

### ✅ Network Configuration
- **Default Gateway:** 10.92.0.1 (configured via CLI)
- **Static Route:** `ip route 0.0.0.0 0.0.0.0 10.92.0.1`
- **Connectivity:** Switch can now ping Omada Controller at 10.92.3.34

### ✅ Omada Controller Settings
- **Inform URL:** `http://10.92.3.34:8088` (configured)
- **Controller Management:** Disabled (will activate after reboot)
- **Discovery Command:** Sent via CLI (`controller discover`)

### ✅ SSH Configuration
- **SSH Config Updated:** `~/.ssh/config` entry created with proper cipher/kex algorithms
- **Aliases:** `switch`, `sg3428xmp`, `core-switch`
- **Current Auth:** Password-based (admin / xmk@xyf7qyq9hac7MGU)

---

## Pending Actions

### 1. Upload SSH Public Key (Manual - Web UI Required)

**Access:** `https://10.92.0.2:8443`  
**Login:** admin / xmk@xyf7qyq9hac7MGU

**Steps:**
1. Navigate to **Security → Access Security → SSH Config**
2. Scroll to **Import Key File** section
3. Select **Key Type:** SSH-2 RSA/DSA
4. Click **Browse** and upload: `~/.ssh/id_rsa.pub`
5. Click **Import**
6. Wait for import to complete (may take several minutes)

**Your RSA Public Key:**
```
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCzTcxhxNV5yY0YhOe3TxKVk8ZFHpz2hZQSelv5jsCY0Q5F8n4uGAdmBLqjF5vfKB8uY4sBp3xKz9B59l/bdyS9wFjCh22M5M/tmkccecYfHctE7G8k9bqXpzIYlpTzckIPa0RbFs5Q1hjmSSplmFODZbQJaDMaRyP/grKa1dRtjt4LgB4JVGgiZujBJeRCOwA0AG6xEbGF5PzLunoXn10aXMtNa8gl10P0mGZd2xKgiQD0PR4pNRW/s3yrvTW3QhHeTMqE5Zs+WOc0ebHZQVNAu2nkDs5EbM4DOqY5d8qycMKyALJu9QaeAaLNzU1P7mLhssJpLALII24VAuS8w0srHSQtf92pWE1XtZaFxJFMXt9merEFLKC5UP/JfltcIToEZG0mgne98PQNNvKylG9VpnX8JiRJ9gdAujSclZ8GhiHoQxjduwSdpUXP6Oo0lkuv3MgW+Ez6teMhSL30t7sRCDM+isyzm5q+Fpzsa4NE5GhiQ+0YdjYwWIf7S9ZU5CrCp3HIExRcfb5p5/VV1R4IZGjOVnblHuGGAra8gsagdVO0SRmlZZFuT37DBmkcYiTH6fuyHJqopkQSGD4l0KH9KGZbjCZcUe+WnJqFoLmFMc1yLZe+FBFRGSC+3eHXoSfWIyATayb/ITqvrmE8ca7sIaNMZCXUQB0CgalP2MPRiQ== cory@Corys-MacBook-Pro.local
```

**After Import:**
- Test SSH key authentication: `ssh switch hostname`
- If successful, update SSH config to use key auth (see below)

### 2. Update SSH Config After Key Upload

Edit `~/.ssh/config` (or `.cloudy-work/ssh_config_master.conf`):

**Remove these lines:**
```
PreferredAuthentications password
PubkeyAuthentication no
```

**Uncomment these lines:**
```
IdentityFile ~/.ssh/id_rsa
IdentitiesOnly yes
AddKeysToAgent yes
```

**Keep these lines** (required for TP-Link compatibility):
```
Ciphers aes256-ctr,aes192-ctr,aes128-ctr
KexAlgorithms diffie-hellman-group14-sha256,diffie-hellman-group16-sha512
HostKeyAlgorithms ssh-rsa,rsa-sha2-256,rsa-sha2-512
```

### 3. Reboot Switch (Maintenance Window Required)

**Why:** The switch needs to reboot to trigger Omada Controller discovery with the new inform URL.

**Via CLI:**
```bash
ssh switch
enable
reload
# Confirm when prompted
```

**Via Web UI:**
- Navigate to **Maintenance → Reboot**
- Click **Reboot**

**Expected Result:**
- Switch will reboot (~2-3 minutes)
- On startup, it will contact Omada Controller at 10.92.3.34:8088
- Switch should appear in Omada Controller UI as pending adoption

### 4. Adopt Switch in Omada Controller

**Access:** `https://10.92.3.34:8043`

**Steps:**
1. Log into Omada Controller
2. Navigate to **Devices** section
3. Look for SG3428XMP (10.92.0.2) in pending devices
4. Click **Adopt**
5. Set device name and location
6. Complete adoption process

---

## Gateway (ER7206) - Still Pending

The ER7206 gateway at 10.92.0.1 also needs Omada adoption:

**Access:** `https://10.92.0.1:8443`  
**Login:** cloudy_admin / dxn.ruf5MTB8mbk8npc

**Steps:**
1. Navigate to **Controller Settings**
2. Set **Inform URL:** `http://10.92.3.34:8088`
3. Enable controller management (NOT cloud-based management)
4. Gateway should appear in Omada Controller for adoption

---

## Technical Details

### Switch Specifications
- **Model:** TP-Link SG3428XMP
- **IP Address:** 10.92.0.2/23 (VLAN920)
- **Gateway:** 10.92.0.1
- **Management VLAN:** 920
- **Serial Number:** 2247460000486
- **Firmware:** 3.20.10 Build 20250307 Rel.72795

### SSH Connection Requirements
- **Ciphers:** AES-CTR modes only (AES128-CTR, AES192-CTR, AES256-CTR)
- **Key Exchange:** diffie-hellman-group14-sha256, diffie-hellman-group16-sha512
- **Host Key:** SSH-RSA
- **Public Key Type:** SSH-2 RSA/DSA (ED25519 NOT supported)

### Current SSH Access
```bash
# Password-based (current):
ssh switch

# After key upload:
ssh switch  # Will use key authentication
```

---

## Troubleshooting

### SSH Connection Issues
If SSH fails after key upload:
```bash
# Test with verbose output:
ssh -v switch

# Verify key is loaded:
ssh-add -l | grep id_rsa

# Manual connection with all options:
ssh -o Ciphers=aes256-ctr -o KexAlgorithms=diffie-hellman-group14-sha256 -o HostKeyAlgorithms=ssh-rsa admin@10.92.0.2
```

### Omada Adoption Issues
If switch doesn't appear in controller after reboot:
```bash
# Check switch can reach controller:
ssh switch
enable
ping 10.92.3.34

# Verify inform URL:
show controller

# Manually trigger discovery:
configure
controller discover
exit
```

### Check Omada Controller Logs
```bash
ssh root@10.92.3.34
tail -f /opt/omada/logs/server.log | grep -i "10.92.0.2\|sg3428"
```

---

## Files Modified

- `~/.ssh/config` - SSH configuration with switch entry
- `.cloudy-work/ssh_config_master.conf` - Master SSH config updated

---

## Next Steps Summary

1. **Now:** Upload SSH public key via web UI at https://10.92.0.2:8443
2. **After key upload:** Test SSH key auth and update SSH config
3. **Maintenance window:** Reboot switch to trigger Omada discovery
4. **After reboot:** Adopt switch in Omada Controller UI
5. **Optional:** Configure gateway (ER7206) for Omada adoption

---

## References

- Omada Controller: https://10.92.3.34:8043
- Switch Web UI: https://10.92.0.2:8443
- Gateway Web UI: https://10.92.0.1:8443
- SSH Master Config: `.cloudy-work/ssh_config_master.conf`
