#!/bin/bash
# Setup M365 OAuth2 for Email Sending
# This script helps configure Azure AD app registration for SMTP OAuth2

echo "=== M365 OAuth2 Setup for Cloudigan API ==="
echo ""
echo "Step 1: Register Azure AD Application"
echo "--------------------------------------"
echo ""
echo "1. Go to: https://portal.azure.com"
echo "2. Navigate to: Azure Active Directory → App registrations → New registration"
echo ""
echo "Application Details:"
echo "  Name: Cloudigan API Email Service"
echo "  Supported account types: Accounts in this organizational directory only"
echo "  Redirect URI: Leave blank (not needed for daemon app)"
echo ""
echo "3. Click 'Register'"
echo ""
echo "After registration, note down:"
echo "  - Application (client) ID"
echo "  - Directory (tenant) ID"
echo ""
read -p "Press Enter when you have the Application ID and Tenant ID..."
echo ""

echo "Step 2: Create Client Secret"
echo "----------------------------"
echo ""
echo "1. In your app registration, go to: Certificates & secrets"
echo "2. Click: New client secret"
echo "3. Description: Cloudigan API SMTP OAuth"
echo "4. Expires: 24 months (or your preference)"
echo "5. Click 'Add'"
echo "6. COPY THE SECRET VALUE IMMEDIATELY (you won't see it again)"
echo ""
read -p "Press Enter when you have the client secret..."
echo ""

echo "Step 3: Configure API Permissions"
echo "---------------------------------"
echo ""
echo "1. In your app registration, go to: API permissions"
echo "2. Click: Add a permission"
echo "3. Select: Microsoft Graph"
echo "4. Select: Application permissions (not Delegated)"
echo "5. Search and add: Mail.Send"
echo "6. Click: Add permissions"
echo "7. Click: Grant admin consent for [Your Organization]"
echo "8. Confirm the consent"
echo ""
read -p "Press Enter when permissions are granted..."
echo ""

echo "Step 4: Collect Configuration Values"
echo "------------------------------------"
echo ""
read -p "Enter Application (client) ID: " CLIENT_ID
read -p "Enter Directory (tenant) ID: " TENANT_ID
read -p "Enter Client Secret: " -s CLIENT_SECRET
echo ""
echo ""
read -p "Enter sender email (e.g., noreply@cloudigan.com): " SENDER_EMAIL
echo ""

echo "Step 5: Save Configuration"
echo "-------------------------"
echo ""

CONFIG_FILE="/tmp/m365-oauth-config.env"

cat > "$CONFIG_FILE" << EOF
# M365 OAuth2 Configuration for Cloudigan API
# Generated: $(date)

# Azure AD Application
AZURE_CLIENT_ID=$CLIENT_ID
AZURE_TENANT_ID=$TENANT_ID
AZURE_CLIENT_SECRET=$CLIENT_SECRET

# Email Configuration
EMAIL_FROM=$SENDER_EMAIL
EMAIL_FROM_NAME=Cloudigan IT Solutions

# OAuth2 Endpoints (automatically derived)
AZURE_TOKEN_ENDPOINT=https://login.microsoftonline.com/$TENANT_ID/oauth2/v2.0/token
GRAPH_API_ENDPOINT=https://graph.microsoft.com/v1.0/users/$SENDER_EMAIL/sendMail
EOF

echo "✅ Configuration saved to: $CONFIG_FILE"
echo ""
echo "Next steps:"
echo "1. Copy this file to STANDBY container: scp $CONFIG_FILE root@10.92.3.182:/opt/cloudigan-api/.env.oauth"
echo "2. Update webhook code to use OAuth2 instead of SMTP"
echo "3. Test email sending"
echo ""
cat "$CONFIG_FILE"
