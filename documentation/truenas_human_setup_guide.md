# TrueNAS SCALE Human Setup Guide
## Step-by-Step Instructions for Nextcloud Migration Prerequisites

### Overview
Complete these steps in the TrueNAS web interface before running automated migration scripts.

---

## Step 1: Access TrueNAS Web Interface

1. **Open web browser**
2. **Navigate to**: `http://10.92.0.3`
3. **Login** with your TrueNAS credentials
4. **Verify** you're on the main dashboard

---

## Step 2: Enable Apps Platform

### 2.1 Navigate to Apps
1. **Click** "Apps" in the left sidebar
2. **Click** "Settings" (gear icon in top right)

### 2.2 Configure Apps Pool
1. **Pool Selection**: Choose `media-pool` from dropdown
2. **Click** "Choose" button
3. **Confirm** the selection shows `media-pool`

### 2.3 Enable Apps Platform
1. **Click** "Enable Apps" button
2. **Wait** for initialization (5-10 minutes)
3. **Watch** for status messages in the UI
4. **Verify** when complete: You should see "Apps" menu become active

### 2.4 Verification
- **Check**: Apps dashboard shows "Running" status
- **Check**: You can see "Available Applications" tab
- **If issues**: Refresh browser and wait longer

---

## Step 3: Create Required Datasets

### 3.1 Navigate to Storage
1. **Click** "Storage" in left sidebar
2. **Click** "Pools" 
3. **Click** on `media-pool` to expand

### 3.2 Create Nextcloud Dataset
1. **Click** "Add Dataset" button
2. **Name**: `nextcloud`
3. **Compression**: Select `lz4` from dropdown
4. **Click** "Save"

### 3.3 Set Nextcloud Permissions
1. **Click** on newly created `nextcloud` dataset
2. **Click** "Edit Permissions" 
3. **Owner**: 
   - User: `www-data` (or UID `33`)
   - Group: `www-data` (or GID `33`)
4. **Click** "Save"

### 3.4 Create MinIO Dataset
1. **Click** "Add Dataset" button again
2. **Name**: `minio`
3. **Compression**: Select `lz4` from dropdown
4. **Click** "Save"

### 3.5 Set MinIO Permissions
1. **Click** on newly created `minio` dataset
2. **Click** "Edit Permissions"
3. **Owner**:
   - User: `minio` (or UID `1001`)
   - Group: `minio` (or GID `1001`)
4. **Click** "Save"

---

## Step 4: Install MinIO App

### 4.1 Navigate to Available Apps
1. **Click** "Apps" in left sidebar
2. **Click** "Available Applications" tab
3. **Search**: Type "minio" in search box

### 4.2 Install MinIO
1. **Click** "Install" on MinIO app
2. **Application Name**: Leave as `minio`
3. **Version**: Use latest stable version

### 4.3 Configure MinIO Storage
**Storage Configuration**:
1. **Data Storage**:
   - **Type**: Host Path
   - **Host Path**: `/mnt/media-pool/minio`
   - **Mount Path**: `/data`

### 4.4 Configure MinIO Network
**Network Configuration**:
1. **Network Type**: Select "Host Network"
2. **Web UI Port**: `9001`
3. **API Port**: `9000`

### 4.5 Configure MinIO Security
**MinIO Configuration**:
1. **Root User**: `admin`
2. **Root Password**: Generate secure password (save this!)
   - Example: `MinIO_Secure_2024!`
3. **Console Address**: Leave default

### 4.6 Deploy MinIO
1. **Click** "Install" button
2. **Wait** for deployment (3-5 minutes)
3. **Verify**: Status shows "Running"

### 4.7 Save MinIO Credentials
**IMPORTANT**: Copy and save these credentials:
- **MinIO Web UI**: `http://10.92.0.3:9001`
- **MinIO API**: `http://10.92.0.3:9000`
- **Username**: `admin`
- **Password**: `[your_generated_password]`

---

## Step 5: Install Nextcloud App

### 5.1 Navigate to Available Apps
1. **Stay in** "Available Applications" tab
2. **Search**: Type "nextcloud" in search box

### 5.2 Install Nextcloud
1. **Click** "Install" on Nextcloud app
2. **Application Name**: Leave as `nextcloud`
3. **Version**: Use latest stable version

### 5.3 Configure Nextcloud Storage
**Storage Configuration**:
1. **Nextcloud Data**:
   - **Type**: Host Path
   - **Host Path**: `/mnt/media-pool/nextcloud`
   - **Mount Path**: `/var/www/html/data`

### 5.4 Configure Nextcloud Database
**Database Configuration**:
1. **Database Type**: Select "PostgreSQL"
2. **Database Name**: `nextcloud`
3. **Database User**: `nextcloud`
4. **Database Password**: Generate secure password (save this!)
   - Example: `NC_DB_Secure_2024!`

### 5.5 Configure Nextcloud Network
**Network Configuration**:
1. **Network Type**: Select "Bridge"
2. **Web Port**: `80` (default)
3. **HTTPS Port**: `443` (if using SSL)

### 5.6 Configure Nextcloud Admin
**Admin Account**:
1. **Admin Username**: `admin`
2. **Admin Password**: Generate secure password (save this!)
   - Example: `NC_Admin_Secure_2024!`

### 5.7 Deploy Nextcloud
1. **Click** "Install" button
2. **Wait** for deployment (5-10 minutes)
3. **Verify**: Status shows "Running"

### 5.8 Get Nextcloud Service Information
1. **Click** on deployed Nextcloud app
2. **Note** the assigned IP address
3. **Save** this IP for NPM configuration later

### 5.9 Save Nextcloud Credentials
**IMPORTANT**: Copy and save these credentials:
- **Nextcloud URL**: `http://[service_ip]`
- **Admin Username**: `admin`
- **Admin Password**: `[your_generated_password]`
- **Database Name**: `nextcloud`
- **Database User**: `nextcloud`
- **Database Password**: `[your_db_password]`

---

## Step 6: Verification Checklist

### 6.1 Apps Platform
- [ ] Apps dashboard shows "Running" status
- [ ] Can access "Available Applications"
- [ ] No error messages in Apps section

### 6.2 Datasets
- [ ] `media-pool/nextcloud` dataset exists
- [ ] `media-pool/minio` dataset exists
- [ ] Permissions set correctly on both datasets

### 6.3 MinIO
- [ ] MinIO app status shows "Running"
- [ ] Can access MinIO web UI at `http://10.92.0.3:9001`
- [ ] Can login with admin credentials
- [ ] MinIO credentials saved securely

### 6.4 Nextcloud
- [ ] Nextcloud app status shows "Running"
- [ ] Can access Nextcloud at service IP
- [ ] Setup wizard appears (don't complete yet)
- [ ] Nextcloud service IP noted for NPM config
- [ ] All credentials saved securely

---

## Step 7: Pre-Migration Test

### 7.1 Test MinIO Access
1. **Open**: `http://10.92.0.3:9001`
2. **Login**: admin / [your_password]
3. **Verify**: Dashboard loads successfully

### 7.2 Test Nextcloud Access
1. **Open**: `http://[nextcloud_service_ip]`
2. **Verify**: Nextcloud setup page appears
3. **DO NOT** complete setup wizard yet

### 7.3 Test SSH Access
```bash
# Test from your local machine
ssh truenas "k3s kubectl get pods"
ssh truenas "k3s kubectl get svc"
```

---

## Troubleshooting

### Apps Platform Won't Enable
- **Check**: Sufficient storage space in media-pool
- **Try**: Refresh browser and wait longer
- **Check**: TrueNAS system logs for errors

### App Installation Fails
- **Check**: Apps platform is fully initialized
- **Verify**: Dataset permissions are correct
- **Try**: Restart app installation

### Can't Access App Web Interfaces
- **Check**: App status is "Running"
- **Verify**: Correct IP addresses and ports
- **Check**: No firewall blocking access

### Dataset Permission Issues
- **Verify**: UID/GID numbers are correct
- **Check**: Dataset is mounted properly
- **Try**: Recreate dataset with correct permissions

---

## Ready for Automation

Once all steps are completed successfully:

1. **Verify** all credentials are saved
2. **Confirm** all services are running
3. **Execute** automated migration script:
   ```bash
   ./nextcloud_migration_scripts.sh
   ```

## Important Notes

- **Save all passwords** - you'll need them for troubleshooting
- **Don't complete Nextcloud setup wizard** - automation will handle this
- **Keep TrueNAS web UI open** - useful for monitoring during migration
- **Ensure 10Gig network** is stable before starting data migration
