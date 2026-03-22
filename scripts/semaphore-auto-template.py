#!/usr/bin/env python3
"""
Semaphore Template Auto-Generator

Automatically creates Semaphore task templates by scanning the playbooks directory
in the ansible-playbooks GitHub repository.

Usage:
    python3 semaphore-auto-template.py

Requirements:
    - Semaphore admin credentials
    - Project ID from Semaphore
    - Repository, Inventory, and Environment IDs
"""

import requests
import json
import yaml
import os
from typing import Dict, List, Optional

# Configuration
SEMAPHORE_URL = "https://ansible.cloudigan.net"
SEMAPHORE_API = f"{SEMAPHORE_URL}/api"

# These will be prompted or can be set as environment variables
SEMAPHORE_USER = os.getenv("SEMAPHORE_USER", "admin")
SEMAPHORE_PASSWORD = os.getenv("SEMAPHORE_PASSWORD")
PROJECT_ID = os.getenv("SEMAPHORE_PROJECT_ID")

# Playbook metadata - describes each playbook
PLAYBOOK_METADATA = {
    "fix-python-modules.yml": {
        "name": "Fix Python Modules",
        "description": "Bootstrap Python and python3-six on hosts",
        "allow_override_args": False
    },
    "system-update.yml": {
        "name": "System Update",
        "description": "Update all packages on infrastructure hosts",
        "allow_override_args": False
    },
    "health-check.yml": {
        "name": "Health Check",
        "description": "Monitor system health across all infrastructure",
        "allow_override_args": False
    },
    "nodejs-app-restart.yml": {
        "name": "Restart Node.js Apps",
        "description": "Restart PM2-managed Node.js applications",
        "allow_override_args": False
    },
    "postgresql-status.yml": {
        "name": "PostgreSQL Status",
        "description": "Check database cluster health and replication",
        "allow_override_args": False
    }
}


class SemaphoreAPI:
    """Wrapper for Semaphore API interactions"""
    
    def __init__(self, base_url: str, username: str, password: str):
        self.base_url = base_url
        self.session = requests.Session()
        self.token = None
        self.login(username, password)
    
    def login(self, username: str, password: str) -> None:
        """Authenticate with Semaphore and get session token"""
        response = self.session.post(
            f"{self.base_url}/auth/login",
            json={"auth": username, "password": password}
        )
        response.raise_for_status()
        # Token is in cookie, session handles it automatically
        print(f"✅ Logged in as {username}")
    
    def get_project_resources(self, project_id: int) -> Dict:
        """Get all resources (inventory, repos, environments) for a project"""
        resources = {}
        
        # Get inventories
        response = self.session.get(f"{self.base_url}/project/{project_id}/inventory")
        response.raise_for_status()
        resources['inventories'] = response.json()
        
        # Get repositories
        response = self.session.get(f"{self.base_url}/project/{project_id}/repositories")
        response.raise_for_status()
        resources['repositories'] = response.json()
        
        # Get environments
        response = self.session.get(f"{self.base_url}/project/{project_id}/environment")
        response.raise_for_status()
        resources['environments'] = response.json()
        
        return resources
    
    def get_templates(self, project_id: int) -> List[Dict]:
        """Get all task templates for a project"""
        response = self.session.get(f"{self.base_url}/project/{project_id}/templates")
        response.raise_for_status()
        return response.json()
    
    def create_template(self, project_id: int, template_data: Dict) -> Dict:
        """Create a new task template"""
        response = self.session.post(
            f"{self.base_url}/project/{project_id}/templates",
            json=template_data
        )
        response.raise_for_status()
        return response.json()
    
    def delete_template(self, project_id: int, template_id: int) -> None:
        """Delete a task template"""
        response = self.session.delete(
            f"{self.base_url}/project/{project_id}/templates/{template_id}"
        )
        response.raise_for_status()


def get_playbooks_from_github() -> List[str]:
    """Fetch list of playbooks from GitHub repository"""
    repo_url = "https://api.github.com/repos/heybearc/ansible-playbooks/contents/playbooks"
    response = requests.get(repo_url)
    response.raise_for_status()
    
    playbooks = []
    for item in response.json():
        if item['name'].endswith('.yml') or item['name'].endswith('.yaml'):
            playbooks.append(item['name'])
    
    return playbooks


def create_template_from_playbook(
    api: SemaphoreAPI,
    project_id: int,
    playbook_name: str,
    resources: Dict
) -> Optional[Dict]:
    """Create a Semaphore template for a given playbook"""
    
    # Get metadata for this playbook
    metadata = PLAYBOOK_METADATA.get(playbook_name)
    if not metadata:
        print(f"⚠️  No metadata for {playbook_name}, skipping")
        return None
    
    # Find the ansible-playbooks repository
    repo = next(
        (r for r in resources['repositories'] if 'ansible-playbooks' in r.get('name', '').lower()),
        None
    )
    if not repo:
        print("❌ Could not find 'Ansible Playbooks' repository")
        return None
    
    # Find Production Hosts inventory
    inventory = next(
        (i for i in resources['inventories'] if 'production' in i.get('name', '').lower()),
        None
    )
    if not inventory:
        print("❌ Could not find 'Production Hosts' inventory")
        return None
    
    # Find Production environment
    environment = next(
        (e for e in resources['environments'] if 'production' in e.get('name', '').lower()),
        None
    )
    if not environment:
        print("❌ Could not find 'Production' environment")
        return None
    
    # Build template data
    template_data = {
        "project_id": project_id,
        "name": metadata['name'],
        "description": metadata['description'],
        "playbook": f"playbooks/{playbook_name}",
        "inventory_id": inventory['id'],
        "repository_id": repo['id'],
        "environment_id": environment['id'],
        "allow_override_args_in_task": metadata.get('allow_override_args', False),
        "suppress_success_alerts": False,  # We want Teams notifications
        "type": "task"  # Can be: task, build, deploy
    }
    
    # Create the template
    try:
        result = api.create_template(project_id, template_data)
        print(f"✅ Created template: {metadata['name']}")
        return result
    except requests.exceptions.HTTPError as e:
        if e.response.status_code == 409:
            print(f"⚠️  Template '{metadata['name']}' already exists")
        else:
            print(f"❌ Failed to create template '{metadata['name']}': {e}")
        return None


def main():
    """Main execution"""
    print("🚀 Semaphore Template Auto-Generator\n")
    
    # Get credentials
    password = SEMAPHORE_PASSWORD
    if not password:
        import getpass
        password = getpass.getpass(f"Enter password for {SEMAPHORE_USER}: ")
    
    project_id = PROJECT_ID
    if not project_id:
        project_id = input("Enter Semaphore Project ID: ")
    
    try:
        project_id = int(project_id)
    except ValueError:
        print("❌ Project ID must be a number")
        return
    
    # Initialize API
    try:
        api = SemaphoreAPI(SEMAPHORE_API, SEMAPHORE_USER, password)
    except Exception as e:
        print(f"❌ Failed to connect to Semaphore: {e}")
        return
    
    # Get project resources
    print(f"\n📦 Fetching project resources...")
    try:
        resources = api.get_project_resources(project_id)
        print(f"   Found {len(resources['inventories'])} inventories")
        print(f"   Found {len(resources['repositories'])} repositories")
        print(f"   Found {len(resources['environments'])} environments")
    except Exception as e:
        print(f"❌ Failed to fetch project resources: {e}")
        return
    
    # Get existing templates
    print(f"\n📋 Checking existing templates...")
    try:
        existing_templates = api.get_templates(project_id)
        print(f"   Found {len(existing_templates)} existing templates")
    except Exception as e:
        print(f"❌ Failed to fetch templates: {e}")
        return
    
    # Get playbooks from GitHub
    print(f"\n📥 Fetching playbooks from GitHub...")
    try:
        playbooks = get_playbooks_from_github()
        print(f"   Found {len(playbooks)} playbooks")
        for pb in playbooks:
            print(f"      - {pb}")
    except Exception as e:
        print(f"❌ Failed to fetch playbooks: {e}")
        return
    
    # Create templates
    print(f"\n🔨 Creating templates...")
    created = 0
    skipped = 0
    
    for playbook in playbooks:
        result = create_template_from_playbook(api, project_id, playbook, resources)
        if result:
            created += 1
        else:
            skipped += 1
    
    # Summary
    print(f"\n✨ Summary:")
    print(f"   Created: {created} templates")
    print(f"   Skipped: {skipped} templates")
    print(f"\n🎉 Done! Visit {SEMAPHORE_URL} to see your templates")


if __name__ == "__main__":
    main()
