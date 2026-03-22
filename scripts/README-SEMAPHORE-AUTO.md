# Semaphore Template Auto-Generator

Automatically creates Semaphore task templates from playbooks in the ansible-playbooks repository.

## Quick Start

```bash
# 1. Get your Semaphore Project ID
# Go to https://ansible.cloudigan.net
# Click on your project (Cloudigan Infrastructure)
# Look at the URL: /project/1/templates
# The number is your project ID (probably 1)

# 2. Run the script
cd /Users/cory/Projects/homelab-nexus/scripts
python3 semaphore-auto-template.py

# 3. Enter credentials when prompted
# Username: admin (or your M365 email)
# Password: Cloudigan_Ansible_2026! (or your M365 password)
# Project ID: 1 (or whatever you found in step 1)
```

## What It Does

The script will:
1. ✅ Connect to Semaphore API
2. ✅ Fetch all playbooks from GitHub
3. ✅ Get your project resources (inventory, repos, environments)
4. ✅ Create templates for each playbook
5. ✅ Skip templates that already exist
6. ✅ Show a summary of what was created

## Templates Created

- **Fix Python Modules** - Bootstrap Python on hosts
- **System Update** - Update all packages
- **Health Check** - Monitor system health
- **Restart Node.js Apps** - Restart PM2 processes
- **PostgreSQL Status** - Check database health

## Environment Variables (Optional)

Instead of entering credentials each time:

```bash
export SEMAPHORE_USER="admin"
export SEMAPHORE_PASSWORD="Cloudigan_Ansible_2026!"
export SEMAPHORE_PROJECT_ID="1"

python3 semaphore-auto-template.py
```

## Adding New Playbooks

When you add a new playbook to the ansible-playbooks repo:

1. Add metadata to `PLAYBOOK_METADATA` in the script:
```python
"my-new-playbook.yml": {
    "name": "My New Playbook",
    "description": "What this playbook does",
    "allow_override_args": False
}
```

2. Run the script again - it will create only the new template

## Troubleshooting

**Error: "Failed to connect to Semaphore"**
- Check that Semaphore is running at https://ansible.cloudigan.net
- Verify your credentials are correct

**Error: "Could not find 'Ansible Playbooks' repository"**
- Make sure you've created the repository in Semaphore
- Repository name should contain "ansible-playbooks"

**Error: "Could not find 'Production Hosts' inventory"**
- Create the inventory in Semaphore first
- Name should contain "production"

**Warning: "Template already exists"**
- This is normal - the script skips existing templates
- Delete the template in Semaphore UI if you want to recreate it

## Manual Alternative

If the script doesn't work, you can still create templates manually in the UI:

1. Go to Task Templates → New Template
2. Fill in the form for each playbook
3. Use the playbook documentation as reference

## Requirements

- Python 3.6+
- `requests` library: `pip3 install requests`
- Semaphore admin access
- Project already created in Semaphore
