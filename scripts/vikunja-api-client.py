#!/usr/bin/env python3
"""
Vikunja API Client for Task Management
Provides utilities to interact with Vikunja tasks, projects, and labels.
"""

import os
import sys
import json
import requests
from typing import Dict, List, Optional
from datetime import datetime
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

class VikunjaClient:
    """Client for interacting with Vikunja API"""
    
    def __init__(self):
        self.api_url = os.getenv('VIKUNJA_API_URL', 'https://vikunja.cloudigan.net/api/v1')
        self.api_token = os.getenv('VIKUNJA_API_TOKEN')
        
        if not self.api_token:
            raise ValueError("VIKUNJA_API_TOKEN not found in environment variables")
        
        self.headers = {
            'Authorization': f'Bearer {self.api_token}',
            'Content-Type': 'application/json',
            'Accept': 'application/json'
        }
    
    def _request(self, method: str, endpoint: str, data: Optional[Dict] = None, params: Optional[Dict] = None) -> Dict:
        """Make API request to Vikunja"""
        url = f"{self.api_url}/{endpoint.lstrip('/')}"
        
        try:
            if method.upper() == 'GET':
                response = requests.get(url, headers=self.headers, params=params)
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
            if hasattr(e, 'response') and e.response is not None:
                print(f"Response: {e.response.text}")
            sys.exit(1)
    
    # Project Management
    def list_projects(self) -> List[Dict]:
        """List all projects"""
        return self._request('GET', 'projects')
    
    def get_project(self, project_id: int) -> Dict:
        """Get project by ID"""
        return self._request('GET', f'projects/{project_id}')
    
    def create_project(self, title: str, description: str = "", **kwargs) -> Dict:
        """Create a new project"""
        data = {
            'title': title,
            'description': description,
            **kwargs
        }
        return self._request('POST', 'projects', data)
    
    def update_project(self, project_id: int, **kwargs) -> Dict:
        """Update existing project"""
        return self._request('PUT', f'projects/{project_id}', kwargs)
    
    def delete_project(self, project_id: int) -> Dict:
        """Delete project"""
        return self._request('DELETE', f'projects/{project_id}')
    
    # Task Management
    def list_tasks(self, project_id: Optional[int] = None, **params) -> List[Dict]:
        """List tasks, optionally filtered by project"""
        if project_id:
            return self._request('GET', f'projects/{project_id}/tasks', params=params)
        return self._request('GET', 'tasks/all', params=params)
    
    def get_task(self, task_id: int) -> Dict:
        """Get task by ID"""
        return self._request('GET', f'tasks/{task_id}')
    
    def create_task(self, project_id: int, title: str, **kwargs) -> Dict:
        """Create a new task"""
        data = {
            'title': title,
            **kwargs
        }
        return self._request('PUT', f'projects/{project_id}/tasks', data)
    
    def update_task(self, task_id: int, **kwargs) -> Dict:
        """Update existing task"""
        return self._request('POST', f'tasks/{task_id}', kwargs)
    
    def delete_task(self, task_id: int) -> Dict:
        """Delete task"""
        return self._request('DELETE', f'tasks/{task_id}')
    
    def complete_task(self, task_id: int) -> Dict:
        """Mark task as complete"""
        return self.update_task(task_id, done=True)
    
    # Label Management
    def list_labels(self) -> List[Dict]:
        """List all labels"""
        return self._request('GET', 'labels')
    
    def create_label(self, title: str, hex_color: str = "#1973ff", **kwargs) -> Dict:
        """Create a new label"""
        data = {
            'title': title,
            'hex_color': hex_color,
            **kwargs
        }
        return self._request('PUT', 'labels', data)
    
    def update_label(self, label_id: int, **kwargs) -> Dict:
        """Update existing label"""
        return self._request('POST', f'labels/{label_id}', kwargs)
    
    def delete_label(self, label_id: int) -> Dict:
        """Delete label"""
        return self._request('DELETE', f'labels/{label_id}')
    
    # User Management
    def get_user_info(self) -> Dict:
        """Get current user information"""
        return self._request('GET', 'user')
    
    # Search
    def search(self, query: str) -> Dict:
        """Search across tasks and projects"""
        return self._request('GET', 'search', params={'s': query})


def format_task(task: Dict) -> str:
    """Format task for display"""
    status = "✅" if task.get('done') else "⬜"
    title = task.get('title', 'Untitled')
    task_id = task.get('id', 'N/A')
    
    # Format due date if exists
    due_date = ""
    if task.get('due_date'):
        try:
            dt = datetime.fromisoformat(task['due_date'].replace('Z', '+00:00'))
            due_date = f" 📅 {dt.strftime('%Y-%m-%d')}"
        except:
            pass
    
    # Format priority
    priority = ""
    priority_val = task.get('priority', 0)
    if priority_val > 0:
        priority_icons = {1: "🔵", 2: "🟢", 3: "🟡", 4: "🟠", 5: "🔴"}
        priority = f" {priority_icons.get(priority_val, '⚪')}"
    
    return f"{status} {title} (ID: {task_id}){due_date}{priority}"


def main():
    """CLI interface for Vikunja API client"""
    if len(sys.argv) < 2:
        print("Usage: vikunja-api-client.py <command> [args]")
        print("\nCommands:")
        print("  list-projects               - List all projects")
        print("  get-project <id>            - Get project details")
        print("  create-project <title>      - Create a new project")
        print("  list-tasks [project_id]     - List tasks (all or by project)")
        print("  get-task <id>               - Get task details")
        print("  create-task <project> <title> - Create a new task")
        print("  complete-task <id>          - Mark task as complete")
        print("  list-labels                 - List all labels")
        print("  search <query>              - Search tasks and projects")
        print("  user-info                   - Get current user info")
        print("  test-connection             - Test API connection")
        sys.exit(1)
    
    command = sys.argv[1]
    client = VikunjaClient()
    
    try:
        if command == 'list-projects':
            projects = client.list_projects()
            print(f"✅ Found {len(projects)} projects:")
            for proj in projects:
                task_count = proj.get('count', {}).get('tasks', 0)
                print(f"  📁 {proj.get('title')} (ID: {proj.get('id')}) - {task_count} tasks")
        
        elif command == 'get-project':
            if len(sys.argv) < 3:
                print("❌ Error: Project ID required")
                sys.exit(1)
            project = client.get_project(int(sys.argv[2]))
            print(json.dumps(project, indent=2))
        
        elif command == 'create-project':
            if len(sys.argv) < 3:
                print("❌ Error: Project title required")
                sys.exit(1)
            title = ' '.join(sys.argv[2:])
            project = client.create_project(title)
            print(f"✅ Created project: {project.get('title')} (ID: {project.get('id')})")
        
        elif command == 'list-tasks':
            project_id = int(sys.argv[2]) if len(sys.argv) > 2 else None
            tasks = client.list_tasks(project_id)
            
            if project_id:
                print(f"✅ Found {len(tasks)} tasks in project {project_id}:")
            else:
                print(f"✅ Found {len(tasks)} total tasks:")
            
            for task in tasks:
                print(f"  {format_task(task)}")
        
        elif command == 'get-task':
            if len(sys.argv) < 3:
                print("❌ Error: Task ID required")
                sys.exit(1)
            task = client.get_task(int(sys.argv[2]))
            print(json.dumps(task, indent=2))
        
        elif command == 'create-task':
            if len(sys.argv) < 4:
                print("❌ Error: Project ID and task title required")
                sys.exit(1)
            project_id = int(sys.argv[2])
            title = ' '.join(sys.argv[3:])
            task = client.create_task(project_id, title)
            print(f"✅ Created task: {task.get('title')} (ID: {task.get('id')})")
        
        elif command == 'complete-task':
            if len(sys.argv) < 3:
                print("❌ Error: Task ID required")
                sys.exit(1)
            task = client.complete_task(int(sys.argv[2]))
            print(f"✅ Task completed: {task.get('title')}")
        
        elif command == 'list-labels':
            labels = client.list_labels()
            print(f"✅ Found {len(labels)} labels:")
            for label in labels:
                color = label.get('hex_color', '#000000')
                print(f"  🏷️  {label.get('title')} ({color})")
        
        elif command == 'search':
            if len(sys.argv) < 3:
                print("❌ Error: Search query required")
                sys.exit(1)
            query = ' '.join(sys.argv[2:])
            results = client.search(query)
            
            tasks = results.get('tasks', [])
            projects = results.get('projects', [])
            
            print(f"✅ Search results for '{query}':")
            if projects:
                print(f"\n📁 Projects ({len(projects)}):")
                for proj in projects:
                    print(f"  - {proj.get('title')} (ID: {proj.get('id')})")
            
            if tasks:
                print(f"\n📝 Tasks ({len(tasks)}):")
                for task in tasks:
                    print(f"  {format_task(task)}")
        
        elif command == 'user-info':
            user = client.get_user_info()
            print(f"✅ User: {user.get('username')} ({user.get('name', 'N/A')})")
            print(f"   Email: {user.get('email', 'N/A')}")
            print(f"   ID: {user.get('id')}")
        
        elif command == 'test-connection':
            user = client.get_user_info()
            projects = client.list_projects()
            print(f"✅ Connection successful!")
            print(f"   User: {user.get('username')}")
            print(f"   Projects: {len(projects)}")
        
        else:
            print(f"❌ Unknown command: {command}")
            sys.exit(1)
    
    except Exception as e:
        print(f"❌ Error: {e}")
        sys.exit(1)


if __name__ == '__main__':
    main()
