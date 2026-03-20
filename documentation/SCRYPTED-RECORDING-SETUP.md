# Scrypted NVR - Recording Setup with TrueNAS Storage

**Date:** 2026-03-20  
**Container:** CT180 (scrypted) - 10.92.3.15  
**TrueNAS:** 10.92.0.3

---

## Overview

This guide sets up camera recording in Scrypted NVR using TrueNAS for storage.

**What You'll Get:**
- 24/7 or motion-based recording
- Large storage capacity from TrueNAS
- Configurable retention policies
- Playback and timeline view

---

## Step 1: Create TrueNAS NFS Share

### 1.1 Create Dataset (via TrueNAS Web UI)

1. Go to: http://10.92.0.3 (TrueNAS web interface)
2. Navigate to: **Storage** → **Pools**
3. Click on your pool (e.g., `media-pool`)
4. Click **Add Dataset**
5. Configure:
   - **Name:** `camera-recordings`
   - **Share Type:** Generic
   - **Compression:** LZ4 (recommended)
   - **Quota:** Set based on desired storage (e.g., 2TB)
6. Click **SAVE**

### 1.2 Create NFS Share

1. Navigate to: **Sharing** → **Unix Shares (NFS)**
2. Click **ADD**
3. Configure:
   - **Path:** `/mnt/media-pool/camera-recordings`
   - **Description:** Scrypted camera recordings
4. Click **SUBMIT**
5. Click **EDIT** on the new share
6. Under **Access**, add:
   - **Authorized Networks:** `10.92.3.15/32` (Scrypted container)
   - **Maproot User:** root
   - **Maproot Group:** wheel
7. Click **SAVE**
8. Enable the NFS service if not already running:
   - Go to **Services**
   - Find **NFS** and click the toggle to **ON**
   - Click the gear icon and ensure **Start Automatically** is checked

---

## Step 2: Mount NFS Share on Scrypted Container

### 2.1 SSH into Scrypted Container

```bash
ssh root@10.92.3.15
# Accept the new host key when prompted
```

### 2.2 Install NFS Client

```bash
# Update package list
apt update

# Install NFS client
apt install -y nfs-common

# Verify NFS is working
showmount -e 10.92.0.3
```

You should see the camera-recordings share listed.

### 2.3 Create Mount Point and Mount NFS Share

```bash
# Create directory for recordings
mkdir -p /mnt/recordings

# Test mount manually first
mount -t nfs 10.92.0.3:/mnt/media-pool/camera-recordings /mnt/recordings

# Verify it's mounted
df -h | grep recordings

# Test write access
touch /mnt/recordings/test.txt
ls -la /mnt/recordings/
rm /mnt/recordings/test.txt
```

### 2.4 Make Mount Permanent

```bash
# Add to fstab for automatic mounting on boot
echo "10.92.0.3:/mnt/media-pool/camera-recordings /mnt/recordings nfs defaults,_netdev 0 0" >> /etc/fstab

# Verify fstab entry
cat /etc/fstab | grep recordings

# Test fstab mount
umount /mnt/recordings
mount -a
df -h | grep recordings
```

**Note:** The `_netdev` option ensures the mount waits for network to be available.

---

## Step 3: Configure Scrypted NVR Plugin

### 3.1 Install Plugin (if not already done)

1. Go to: https://scrypted.cloudigan.net
2. Click **Plugins**
3. Search for: `nvr`
4. Install **@scrypted/nvr**

### 3.2 Configure Storage Path

1. Click **Plugins** → **Scrypted NVR**
2. Click the **Settings** gear icon
3. Find **Recording Path** setting
4. Enter: `/mnt/recordings`
5. Click **SAVE**

### 3.3 Configure Recording Settings

In the Scrypted NVR plugin settings:

**General Settings:**
- **Recording Path:** `/mnt/recordings`
- **Max Recording Size:** Leave default or set based on your needs
- **Retention Policy:** Configure how long to keep recordings

**Recommended Retention:**
- **Continuous Recording:** 7-14 days
- **Motion Recording:** 30-60 days

---

## Step 4: Enable Recording on Cameras

### 4.1 Enable NVR Extension for Each Camera

For each camera (Front Porch, Garage, Driveway, Backyard):

1. Click on the camera in the device list
2. Go to **Extensions** tab
3. Find **Scrypted NVR** and toggle it **ON**
4. Click the **Settings** gear icon for NVR extension

### 4.2 Configure Recording Mode

**For each camera, choose:**

**Option 1: Continuous Recording (24/7)**
- **Recording Mode:** Continuous
- **Pros:** Never miss anything
- **Cons:** Uses more storage
- **Storage estimate:** ~50-100GB per camera per day

**Option 2: Motion-Based Recording**
- **Recording Mode:** Motion
- **Motion Detection:** Enable
- **Pre-buffer:** 10 seconds (records before motion)
- **Post-buffer:** 30 seconds (records after motion)
- **Pros:** Saves storage
- **Cons:** Might miss some events
- **Storage estimate:** ~5-20GB per camera per day (varies by activity)

**Recommended:** Start with motion-based and switch to continuous if needed.

### 4.3 Configure Motion Detection

1. In camera settings, go to **Motion Sensor** section
2. Enable motion detection
3. Adjust sensitivity (start with default)
4. Set detection zones if needed (to ignore areas like trees, roads)

---

## Step 5: Verify Recording

### 5.1 Check Recording Status

1. Go to **Scrypted NVR** plugin
2. Click **Console** tab
3. Look for recording status messages
4. Should see: "Recording started for [camera name]"

### 5.2 Verify Files on Storage

```bash
ssh root@10.92.3.15

# Check recordings directory
ls -lh /mnt/recordings/

# You should see directories for each camera
# Example: /mnt/recordings/front-porch-camera/

# Check a camera's recordings
ls -lh /mnt/recordings/front-porch-camera/
```

### 5.3 Test Playback

1. Click on a camera
2. Look for **Timeline** or **Recordings** tab
3. You should see recorded segments
4. Click on a segment to play it back

---

## Storage Calculations

### Estimate Storage Needs

**Per Camera (1080p, H.264):**
- Continuous: 50-100 GB/day
- Motion: 5-20 GB/day (varies)

**For 4 Cameras:**
- Continuous 7 days: 1.4 - 2.8 TB
- Continuous 14 days: 2.8 - 5.6 TB
- Motion 30 days: 600 GB - 2.4 TB

**Recommendation:** Allocate 2-3 TB for camera recordings.

---

## Monitoring and Maintenance

### Check Storage Usage

```bash
ssh root@10.92.3.15

# Check NFS mount
df -h /mnt/recordings

# Check per-camera storage
du -sh /mnt/recordings/*

# Check total recordings size
du -sh /mnt/recordings
```

### Automatic Cleanup

Scrypted NVR automatically deletes old recordings based on:
- Retention policy (days)
- Storage space limits
- Per-camera settings

**No manual cleanup needed!**

### Monitor Recording Health

1. Go to **Scrypted NVR** plugin
2. Check **Console** for errors
3. Common issues:
   - Storage full
   - Network issues
   - Camera offline

---

## Troubleshooting

### NFS Mount Issues

**Mount fails:**
```bash
# Check NFS service on TrueNAS
showmount -e 10.92.0.3

# Check network connectivity
ping 10.92.0.3

# Try manual mount with verbose
mount -v -t nfs 10.92.0.3:/mnt/media-pool/camera-recordings /mnt/recordings
```

**Permission denied:**
- Check TrueNAS NFS share permissions
- Verify Maproot is set to root
- Check authorized networks includes 10.92.3.15

### Recording Not Starting

1. Check storage path is correct: `/mnt/recordings`
2. Verify NFS is mounted: `df -h | grep recordings`
3. Check write permissions: `touch /mnt/recordings/test.txt`
4. Review Scrypted NVR console for errors
5. Restart Scrypted: `systemctl restart scrypted`

### High Storage Usage

1. Check retention settings
2. Reduce recording quality if needed
3. Switch from continuous to motion-based
4. Increase storage allocation on TrueNAS

---

## Advanced Configuration

### Adjust Video Quality

In camera settings:
- **Bitrate:** Lower = less storage, lower quality
- **Resolution:** 1080p vs 720p
- **Frame Rate:** 30fps vs 15fps

**Recommendation:** Start with defaults, adjust if storage is an issue.

### Multiple Storage Locations

You can configure different cameras to use different storage:
- High-priority cameras: Local SSD (faster)
- Low-priority cameras: NFS (larger capacity)

### Backup Recordings

To backup recordings to another location:

```bash
# From Scrypted container
rsync -av /mnt/recordings/ user@backup-server:/path/to/backup/
```

Or set up a cron job for automated backups.

---

## Summary Checklist

- [ ] TrueNAS dataset created: `camera-recordings`
- [ ] NFS share created and configured
- [ ] NFS client installed on Scrypted container
- [ ] NFS share mounted at `/mnt/recordings`
- [ ] Mount added to `/etc/fstab` for persistence
- [ ] Scrypted NVR plugin installed
- [ ] Recording path set to `/mnt/recordings`
- [ ] Recording enabled on all cameras
- [ ] Recording mode configured (continuous or motion)
- [ ] Retention policy set
- [ ] Verified recordings are being created
- [ ] Tested playback

---

## Quick Reference

**TrueNAS Web UI:** http://10.92.0.3  
**Scrypted Web UI:** https://scrypted.cloudigan.net  
**Scrypted SSH:** `ssh root@10.92.3.15`  
**Recordings Path:** `/mnt/recordings`  
**NFS Share:** `10.92.0.3:/mnt/media-pool/camera-recordings`

---

## Next Steps

After recording is set up:

1. **Configure Notifications:**
   - Install Notifier plugin
   - Set up motion alerts
   - Configure email/SMS/push notifications

2. **Add to HomeKit:**
   - Install HomeKit plugin
   - Add cameras to Apple Home
   - Enable HomeKit Secure Video (optional)

3. **Set Up Remote Access:**
   - Already configured via https://scrypted.cloudigan.net
   - Access cameras from anywhere

4. **Create Automation:**
   - Motion-triggered lights
   - Doorbell notifications
   - Recording schedules
