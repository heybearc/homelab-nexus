# Semaphore Microsoft 365 SSO Setup Guide

**Date:** March 21, 2026  
**Status:** ✅ Configured and Active

---

## Overview

This guide walks through configuring OpenID Connect (OIDC) authentication with Microsoft Entra ID (formerly Azure AD) for Semaphore, allowing users to log in with their Microsoft 365 accounts.

---

## Prerequisites

- ✅ Semaphore installed and running (https://ansible.cloudigan.net)
- ✅ Microsoft 365 Business Standard subscription
- ✅ Global Administrator access to Entra ID
- ✅ Teams alerts already configured

---

## Step 1: Register Application in Entra ID

### 1.1 Access Azure Portal
1. Go to https://portal.azure.com
2. Sign in with your Global Administrator account
3. Navigate to **Microsoft Entra ID** (formerly Azure Active Directory)

### 1.2 Create App Registration
1. In the left menu, click **App registrations**
2. Click **+ New registration**
3. Fill in the details:
   - **Name:** `Semaphore Ansible`
   - **Supported account types:** `Accounts in this organizational directory only (Cloudigan only - Single tenant)`
   - **Redirect URI:** 
     - Platform: `Web`
     - URI: `https://ansible.cloudigan.net/api/auth/oidc/redirect`

4. Click **Register**

### 1.3 Note the Application Details
After registration, you'll see the **Overview** page. **Copy these values:**

- **Application (client) ID:** `[COPY THIS]`
- **Directory (tenant) ID:** `[COPY THIS]`

**Example:**
```
Application (client) ID: 12345678-1234-1234-1234-123456789012
Directory (tenant) ID: 8e44be3f-91ca-4ea4-9148-56ecc910f556
```

### 1.4 Create Client Secret
1. In the left menu, click **Certificates & secrets**
2. Click **+ New client secret**
3. Fill in:
   - **Description:** `Semaphore OIDC`
   - **Expires:** `24 months` (or your preference)
4. Click **Add**
5. **IMMEDIATELY COPY THE SECRET VALUE** - you won't be able to see it again!

**Example:**
```
Client Secret Value: abc123~DEF456.GHI789-JKL012_MNO345
```

### 1.5 Configure API Permissions
1. In the left menu, click **API permissions**
2. Click **+ Add a permission**
3. Select **Microsoft Graph**
4. Select **Delegated permissions**
5. Add these permissions:
   - `openid`
   - `profile`
   - `email`
   - `User.Read`
6. Click **Add permissions**
7. Click **Grant admin consent for Cloudigan** (requires Global Admin)
8. Click **Yes** to confirm

### 1.6 Configure Token Configuration (Optional but Recommended)
1. In the left menu, click **Token configuration**
2. Click **+ Add optional claim**
3. Select **ID** token type
4. Add these claims:
   - `email`
   - `family_name`
   - `given_name`
   - `upn`
5. Click **Add**

---

## Step 2: Configure Semaphore OIDC

Once you have the values from Step 1, provide them to me and I'll configure Semaphore with:

**Required Information:**
1. **Application (client) ID:** `_________________`
2. **Directory (tenant) ID:** `_________________`
3. **Client Secret Value:** `_________________`

---

## Step 3: Configuration Details

### OIDC Endpoints
Semaphore will use these Microsoft endpoints:

- **Authorization URL:** `https://login.microsoftonline.com/{tenant-id}/oauth2/v2.0/authorize`
- **Token URL:** `https://login.microsoftonline.com/{tenant-id}/oauth2/v2.0/token`
- **User Info URL:** `https://graph.microsoft.com/oidc/userinfo`

### Semaphore Configuration
The configuration will be added to `/tmp/semaphore/config.json`:

```json
{
  "oidc_providers": {
    "microsoft": {
      "display_name": "Microsoft 365",
      "provider_url": "https://login.microsoftonline.com/{tenant-id}/v2.0",
      "client_id": "{client-id}",
      "client_secret": "{client-secret}",
      "redirect_url": "https://ansible.cloudigan.net/api/auth/oidc/redirect",
      "scopes": ["openid", "profile", "email"],
      "username_claim": "email",
      "name_claim": "name",
      "email_claim": "email"
    }
  }
}
```

---

## Step 4: User Experience After Setup

### Login Flow
1. User goes to https://ansible.cloudigan.net
2. Clicks **"Sign in with Microsoft 365"** button
3. Redirected to Microsoft login page
4. Enters M365 credentials
5. Consents to permissions (first time only)
6. Redirected back to Semaphore, logged in

### User Management
- **First login:** User account created automatically in Semaphore
- **Email mapping:** Uses M365 email as username
- **Name mapping:** Uses M365 display name
- **Admin rights:** Must be granted manually in Semaphore after first login

---

## Step 5: Testing

After configuration, test the SSO:

1. **Log out** of Semaphore (if logged in)
2. Go to https://ansible.cloudigan.net
3. Click **"Sign in with Microsoft 365"**
4. Log in with your M365 account
5. Verify you're logged into Semaphore

---

## Security Considerations

### Best Practices
- ✅ Use single tenant (organization-only) authentication
- ✅ Client secret expires in 24 months - set calendar reminder to rotate
- ✅ Grant admin consent for required permissions
- ✅ Use HTTPS only (already configured)
- ✅ Limit redirect URIs to production URL only

### User Access Control
- Users can log in with any M365 account in your tenant
- Admin privileges must be granted manually in Semaphore
- Consider creating a security group in Entra ID for Semaphore users
- Can restrict access via Conditional Access policies

---

## Troubleshooting

### Common Issues

**"Redirect URI mismatch"**
- Verify redirect URI in Entra ID exactly matches: `https://ansible.cloudigan.net/api/auth/oidc/redirect`
- Check for trailing slashes or http vs https

**"Invalid client secret"**
- Secret may have expired
- Create new secret in Entra ID
- Update Semaphore configuration

**"User not found"**
- User must log in at least once to create account
- Check username claim mapping in config

**"Insufficient permissions"**
- Verify API permissions are granted
- Ensure admin consent was provided

---

## Maintenance

### Rotating Client Secret
1. Create new secret in Entra ID
2. Update Semaphore config with new secret
3. Restart Semaphore service
4. Delete old secret after verifying new one works

### Adding New Users
- No action needed - users auto-created on first login
- Grant admin rights in Semaphore UI if needed

### Revoking Access
- Remove user from Semaphore UI, OR
- Disable user account in Entra ID, OR
- Use Conditional Access to block access

---

## Next Steps After Setup

1. **Test with multiple users** from your organization
2. **Grant admin rights** to appropriate users in Semaphore
3. **Disable local admin account** (optional, keep as backup)
4. **Configure Conditional Access** policies if needed
5. **Set up MFA** enforcement via Entra ID (if not already enabled)

---

## Files and References

### Configuration Files
- **Semaphore config:** `/tmp/semaphore/config.json` (on CT183)
- **Service file:** `/etc/systemd/system/semaphore.service` (on CT183)

### Microsoft Documentation
- [Microsoft identity platform and OpenID Connect](https://docs.microsoft.com/en-us/azure/active-directory/develop/v2-protocols-oidc)
- [Register an application with the Microsoft identity platform](https://docs.microsoft.com/en-us/azure/active-directory/develop/quickstart-register-app)

---

## Ready to Configure?

**Please provide the following from your Entra ID app registration:**

1. **Application (client) ID:** `_________________`
2. **Directory (tenant) ID:** `_________________`  
3. **Client Secret Value:** `_________________`

Once you provide these, I'll configure Semaphore and test the SSO integration!
