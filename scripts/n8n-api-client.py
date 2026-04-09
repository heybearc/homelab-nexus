#!/usr/bin/env python3
"""
n8n API Client for Homelab Automation
Provides utilities to interact with n8n workflows and automations.
"""

import os
import sys
import json
import requests
from typing import Dict, List, Optional
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

class N8nClient:
    """Client for interacting with n8n API"""
    
    def __init__(self):
        self.api_url = os.getenv('N8N_API_URL', 'https://n8n.cloudigan.net/api/v1')
        self.api_token = os.getenv('N8N_API_TOKEN')
        
        if not self.api_token:
            raise ValueError("N8N_API_TOKEN not found in environment variables")
        
        self.headers = {
            'X-N8N-API-KEY': self.api_token,
            'Content-Type': 'application/json',
            'Accept': 'application/json'
        }
    
    def _request(self, method: str, endpoint: str, data: Optional[Dict] = None) -> Dict:
        """Make API request to n8n"""
        url = f"{self.api_url}/{endpoint.lstrip('/')}"
        
        try:
            if method.upper() == 'GET':
                response = requests.get(url, headers=self.headers)
            elif method.upper() == 'POST':
                response = requests.post(url, headers=self.headers, json=data)
            elif method.upper() == 'PUT':
                response = requests.put(url, headers=self.headers, json=data)
            elif method.upper() == 'DELETE':
                response = requests.delete(url, headers=self.headers)
            else:
                raise ValueError(f"Unsupported HTTP method: {method}")
            
            response.raise_for_status()
            return response.json() if response.content else {}
        
        except requests.exceptions.RequestException as e:
            print(f"❌ API request failed: {e}")
            if hasattr(e.response, 'text'):
                print(f"Response: {e.response.text}")
            sys.exit(1)
    
    # Workflow Management
    def list_workflows(self) -> List[Dict]:
        """List all workflows"""
        return self._request('GET', 'workflows')
    
    def get_workflow(self, workflow_id: str) -> Dict:
        """Get workflow by ID"""
        return self._request('GET', f'workflows/{workflow_id}')
    
    def create_workflow(self, workflow_data: Dict) -> Dict:
        """Create a new workflow"""
        return self._request('POST', 'workflows', workflow_data)
    
    def update_workflow(self, workflow_id: str, workflow_data: Dict) -> Dict:
        """Update existing workflow"""
        return self._request('PUT', f'workflows/{workflow_id}', workflow_data)
    
    def delete_workflow(self, workflow_id: str) -> Dict:
        """Delete workflow"""
        return self._request('DELETE', f'workflows/{workflow_id}')
    
    def activate_workflow(self, workflow_id: str) -> Dict:
        """Activate a workflow"""
        return self._request('POST', f'workflows/{workflow_id}/activate')
    
    def deactivate_workflow(self, workflow_id: str) -> Dict:
        """Deactivate a workflow"""
        return self._request('POST', f'workflows/{workflow_id}/deactivate')
    
    # Execution Management
    def list_executions(self, workflow_id: Optional[str] = None) -> List[Dict]:
        """List workflow executions"""
        endpoint = 'executions'
        if workflow_id:
            endpoint += f'?workflowId={workflow_id}'
        return self._request('GET', endpoint)
    
    def get_execution(self, execution_id: str) -> Dict:
        """Get execution details"""
        return self._request('GET', f'executions/{execution_id}')
    
    def delete_execution(self, execution_id: str) -> Dict:
        """Delete execution"""
        return self._request('DELETE', f'executions/{execution_id}')
    
    # Credentials Management
    def list_credentials(self) -> List[Dict]:
        """List all credentials"""
        return self._request('GET', 'credentials')
    
    def get_credential(self, credential_id: str) -> Dict:
        """Get credential by ID"""
        return self._request('GET', f'credentials/{credential_id}')
    
    def create_credential(self, credential_data: Dict) -> Dict:
        """Create new credential"""
        return self._request('POST', 'credentials', credential_data)
    
    def update_credential(self, credential_id: str, credential_data: Dict) -> Dict:
        """Update existing credential"""
        return self._request('PUT', f'credentials/{credential_id}', credential_data)
    
    def delete_credential(self, credential_id: str) -> Dict:
        """Delete credential"""
        return self._request('DELETE', f'credentials/{credential_id}')


def main():
    """CLI interface for n8n API client"""
    if len(sys.argv) < 2:
        print("Usage: n8n-api-client.py <command> [args]")
        print("\nCommands:")
        print("  list-workflows              - List all workflows")
        print("  get-workflow <id>           - Get workflow details")
        print("  activate-workflow <id>      - Activate a workflow")
        print("  deactivate-workflow <id>    - Deactivate a workflow")
        print("  list-executions [workflow]  - List executions")
        print("  list-credentials            - List all credentials")
        print("  test-connection             - Test API connection")
        sys.exit(1)
    
    command = sys.argv[1]
    client = N8nClient()
    
    try:
        if command == 'list-workflows':
            workflows = client.list_workflows()
            print(f"✅ Found {len(workflows)} workflows:")
            for wf in workflows:
                status = "🟢 Active" if wf.get('active') else "⚪ Inactive"
                print(f"  {status} - {wf.get('name')} (ID: {wf.get('id')})")
        
        elif command == 'get-workflow':
            if len(sys.argv) < 3:
                print("❌ Error: Workflow ID required")
                sys.exit(1)
            workflow = client.get_workflow(sys.argv[2])
            print(json.dumps(workflow, indent=2))
        
        elif command == 'activate-workflow':
            if len(sys.argv) < 3:
                print("❌ Error: Workflow ID required")
                sys.exit(1)
            result = client.activate_workflow(sys.argv[2])
            print(f"✅ Workflow activated: {result}")
        
        elif command == 'deactivate-workflow':
            if len(sys.argv) < 3:
                print("❌ Error: Workflow ID required")
                sys.exit(1)
            result = client.deactivate_workflow(sys.argv[2])
            print(f"✅ Workflow deactivated: {result}")
        
        elif command == 'list-executions':
            workflow_id = sys.argv[2] if len(sys.argv) > 2 else None
            executions = client.list_executions(workflow_id)
            print(f"✅ Found {len(executions)} executions:")
            for ex in executions:
                status = ex.get('finished') and "✅" or "⏳"
                print(f"  {status} {ex.get('workflowName')} - {ex.get('startedAt')}")
        
        elif command == 'list-credentials':
            credentials = client.list_credentials()
            print(f"✅ Found {len(credentials)} credentials:")
            for cred in credentials:
                print(f"  - {cred.get('name')} ({cred.get('type')})")
        
        elif command == 'test-connection':
            workflows = client.list_workflows()
            print(f"✅ Connection successful! Found {len(workflows)} workflows.")
        
        else:
            print(f"❌ Unknown command: {command}")
            sys.exit(1)
    
    except Exception as e:
        print(f"❌ Error: {e}")
        sys.exit(1)


if __name__ == '__main__':
    main()
