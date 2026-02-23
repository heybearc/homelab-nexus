#!/bin/bash
#
# Setup SSH Key Authentication on DC-01
# This script manually configures SSH key auth since ssh-copy-id doesn't work with PowerShell default shell
#

set -euo pipefail

DC01_HOST="10.92.0.10"
DC01_USER="Administrator"
SSH_KEY="${HOME}/.ssh/id_rsa.pub"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}Setting up SSH key authentication for DC-01...${NC}\n"

# Check if public key exists
if [[ ! -f "${SSH_KEY}" ]]; then
    echo -e "${RED}Error: SSH public key not found at ${SSH_KEY}${NC}"
    exit 1
fi

echo -e "${BLUE}Step 1: Reading public key...${NC}"
PUBLIC_KEY=$(cat "${SSH_KEY}")
echo -e "${GREEN}✓ Public key loaded${NC}\n"

echo -e "${BLUE}Step 2: Creating .ssh directory on DC-01...${NC}"
ssh "${DC01_USER}@${DC01_HOST}" "powershell.exe -Command \"New-Item -ItemType Directory -Force -Path C:\\Users\\Administrator\\.ssh | Out-Null; Write-Host 'Directory created'\""
echo -e "${GREEN}✓ .ssh directory created${NC}\n"

echo -e "${BLUE}Step 3: Adding public key to authorized_keys...${NC}"
ssh "${DC01_USER}@${DC01_HOST}" "powershell.exe -Command \"Add-Content -Path C:\\Users\\Administrator\\.ssh\\authorized_keys -Value '${PUBLIC_KEY}'; Write-Host 'Key added'\""
echo -e "${GREEN}✓ Public key added${NC}\n"

echo -e "${BLUE}Step 4: Setting correct permissions...${NC}"
ssh "${DC01_USER}@${DC01_HOST}" "powershell.exe -Command \"icacls C:\\Users\\Administrator\\.ssh\\authorized_keys /inheritance:r /grant 'Administrators:F' /grant 'SYSTEM:F' | Out-Null; Write-Host 'Permissions set'\""
echo -e "${GREEN}✓ Permissions configured${NC}\n"

echo -e "${BLUE}Step 5: Testing SSH key authentication...${NC}"
if ssh -o BatchMode=yes -o ConnectTimeout=5 "${DC01_USER}@${DC01_HOST}" "powershell.exe -Command 'Write-Host \"SSH key auth successful\"'" 2>/dev/null; then
    echo -e "${GREEN}✓ SSH key authentication working!${NC}\n"
    echo -e "${GREEN}Setup complete! You can now use SSH without password.${NC}"
else
    echo -e "${RED}✗ SSH key authentication test failed${NC}"
    echo -e "${RED}You may need to restart the sshd service on DC-01:${NC}"
    echo -e "${RED}  Restart-Service sshd${NC}"
fi
