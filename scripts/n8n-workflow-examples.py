#!/usr/bin/env python3
"""
n8n Workflow Examples for Homelab Automation
Pre-built workflow templates for common homelab tasks.
"""

import json
from typing import Dict

class N8nWorkflowTemplates:
    """Collection of n8n workflow templates"""
    
    @staticmethod
    def container_health_check() -> Dict:
        """
        Workflow: Container Health Check
        Checks node_exporter metrics for all containers every hour
        """
        return {
            "name": "Container Health Check",
            "nodes": [
                {
                    "parameters": {
                        "rule": {
                            "interval": [
                                {
                                    "field": "hours",
                                    "hoursInterval": 1
                                }
                            ]
                        }
                    },
                    "name": "Schedule Trigger",
                    "type": "n8n-nodes-base.scheduleTrigger",
                    "typeVersion": 1,
                    "position": [250, 300]
                },
                {
                    "parameters": {
                        "url": "=http://10.92.3.2:9090/api/v1/query?query=up",
                        "options": {}
                    },
                    "name": "Check Prometheus",
                    "type": "n8n-nodes-base.httpRequest",
                    "typeVersion": 3,
                    "position": [450, 300]
                },
                {
                    "parameters": {
                        "conditions": {
                            "string": [
                                {
                                    "value1": "={{$json.status}}",
                                    "value2": "success"
                                }
                            ]
                        }
                    },
                    "name": "Check Status",
                    "type": "n8n-nodes-base.if",
                    "typeVersion": 1,
                    "position": [650, 300]
                }
            ],
            "connections": {
                "Schedule Trigger": {
                    "main": [
                        [
                            {
                                "node": "Check Prometheus",
                                "type": "main",
                                "index": 0
                            }
                        ]
                    ]
                },
                "Check Prometheus": {
                    "main": [
                        [
                            {
                                "node": "Check Status",
                                "type": "main",
                                "index": 0
                            }
                        ]
                    ]
                }
            },
            "active": False,
            "settings": {},
            "tags": ["homelab", "monitoring"]
        }
    
    @staticmethod
    def backup_orchestration() -> Dict:
        """
        Workflow: Backup Orchestration
        Triggers container backups daily at 2 AM
        """
        return {
            "name": "Daily Container Backup",
            "nodes": [
                {
                    "parameters": {
                        "rule": {
                            "interval": [
                                {
                                    "field": "cronExpression",
                                    "expression": "0 2 * * *"
                                }
                            ]
                        }
                    },
                    "name": "Daily at 2 AM",
                    "type": "n8n-nodes-base.scheduleTrigger",
                    "typeVersion": 1,
                    "position": [250, 300]
                },
                {
                    "parameters": {
                        "command": "vzdump --all --mode snapshot --compress zstd --storage local"
                    },
                    "name": "Run Backup",
                    "type": "n8n-nodes-base.executeCommand",
                    "typeVersion": 1,
                    "position": [450, 300]
                }
            ],
            "connections": {
                "Daily at 2 AM": {
                    "main": [
                        [
                            {
                                "node": "Run Backup",
                                "type": "main",
                                "index": 0
                            }
                        ]
                    ]
                }
            },
            "active": False,
            "settings": {},
            "tags": ["homelab", "backup"]
        }
    
    @staticmethod
    def dns_update_webhook() -> Dict:
        """
        Workflow: DNS Update via Webhook
        Receives webhook to update DNS records
        """
        return {
            "name": "DNS Update Webhook",
            "nodes": [
                {
                    "parameters": {
                        "path": "dns-update",
                        "options": {}
                    },
                    "name": "Webhook",
                    "type": "n8n-nodes-base.webhook",
                    "typeVersion": 1,
                    "position": [250, 300],
                    "webhookId": "dns-update"
                },
                {
                    "parameters": {
                        "url": "=http://10.92.3.10/control/rewrite/add",
                        "authentication": "genericCredentialType",
                        "genericAuthType": "httpBasicAuth",
                        "sendBody": True,
                        "bodyParameters": {
                            "parameters": [
                                {
                                    "name": "domain",
                                    "value": "={{$json.body.domain}}"
                                },
                                {
                                    "name": "answer",
                                    "value": "={{$json.body.ip}}"
                                }
                            ]
                        }
                    },
                    "name": "Update AdGuard DNS",
                    "type": "n8n-nodes-base.httpRequest",
                    "typeVersion": 3,
                    "position": [450, 300]
                }
            ],
            "connections": {
                "Webhook": {
                    "main": [
                        [
                            {
                                "node": "Update AdGuard DNS",
                                "type": "main",
                                "index": 0
                            }
                        ]
                    ]
                }
            },
            "active": False,
            "settings": {},
            "tags": ["homelab", "dns", "webhook"]
        }
    
    @staticmethod
    def ssl_renewal_check() -> Dict:
        """
        Workflow: SSL Certificate Renewal Check
        Checks SSL certificates weekly and alerts on expiry
        """
        return {
            "name": "SSL Certificate Check",
            "nodes": [
                {
                    "parameters": {
                        "rule": {
                            "interval": [
                                {
                                    "field": "cronExpression",
                                    "expression": "0 9 * * 1"
                                }
                            ]
                        }
                    },
                    "name": "Weekly Monday 9 AM",
                    "type": "n8n-nodes-base.scheduleTrigger",
                    "typeVersion": 1,
                    "position": [250, 300]
                },
                {
                    "parameters": {
                        "url": "http://10.92.3.3:81/api/nginx/certificates",
                        "authentication": "genericCredentialType",
                        "genericAuthType": "httpHeaderAuth",
                        "options": {}
                    },
                    "name": "Get NPM Certificates",
                    "type": "n8n-nodes-base.httpRequest",
                    "typeVersion": 3,
                    "position": [450, 300]
                },
                {
                    "parameters": {
                        "conditions": {
                            "number": [
                                {
                                    "value1": "={{$json.expires_on}}",
                                    "operation": "smaller",
                                    "value2": "={{Math.floor(Date.now()/1000) + 30*24*60*60}}"
                                }
                            ]
                        }
                    },
                    "name": "Expires in 30 days",
                    "type": "n8n-nodes-base.if",
                    "typeVersion": 1,
                    "position": [650, 300]
                }
            ],
            "connections": {
                "Weekly Monday 9 AM": {
                    "main": [
                        [
                            {
                                "node": "Get NPM Certificates",
                                "type": "main",
                                "index": 0
                            }
                        ]
                    ]
                },
                "Get NPM Certificates": {
                    "main": [
                        [
                            {
                                "node": "Expires in 30 days",
                                "type": "main",
                                "index": 0
                            }
                        ]
                    ]
                }
            },
            "active": False,
            "settings": {},
            "tags": ["homelab", "ssl", "monitoring"]
        }
    
    @staticmethod
    def netbox_sync() -> Dict:
        """
        Workflow: Netbox IPAM Sync
        Syncs container inventory to Netbox
        """
        return {
            "name": "Netbox Container Sync",
            "nodes": [
                {
                    "parameters": {
                        "rule": {
                            "interval": [
                                {
                                    "field": "hours",
                                    "hoursInterval": 6
                                }
                            ]
                        }
                    },
                    "name": "Every 6 Hours",
                    "type": "n8n-nodes-base.scheduleTrigger",
                    "typeVersion": 1,
                    "position": [250, 300]
                },
                {
                    "parameters": {
                        "url": "http://10.92.0.5:8006/api2/json/nodes/prox/lxc",
                        "authentication": "genericCredentialType",
                        "genericAuthType": "httpHeaderAuth",
                        "options": {}
                    },
                    "name": "Get Proxmox Containers",
                    "type": "n8n-nodes-base.httpRequest",
                    "typeVersion": 3,
                    "position": [450, 300]
                },
                {
                    "parameters": {
                        "url": "http://10.92.3.18/api/virtualization/virtual-machines/",
                        "authentication": "genericCredentialType",
                        "genericAuthType": "httpHeaderAuth",
                        "sendBody": True,
                        "bodyParameters": {
                            "parameters": [
                                {
                                    "name": "name",
                                    "value": "={{$json.name}}"
                                },
                                {
                                    "name": "status",
                                    "value": "={{$json.status}}"
                                }
                            ]
                        }
                    },
                    "name": "Update Netbox",
                    "type": "n8n-nodes-base.httpRequest",
                    "typeVersion": 3,
                    "position": [650, 300]
                }
            ],
            "connections": {
                "Every 6 Hours": {
                    "main": [
                        [
                            {
                                "node": "Get Proxmox Containers",
                                "type": "main",
                                "index": 0
                            }
                        ]
                    ]
                },
                "Get Proxmox Containers": {
                    "main": [
                        [
                            {
                                "node": "Update Netbox",
                                "type": "main",
                                "index": 0
                            }
                        ]
                    ]
                }
            },
            "active": False,
            "settings": {},
            "tags": ["homelab", "netbox", "sync"]
        }


def print_template(name: str, template: Dict):
    """Print workflow template as JSON"""
    print(f"\n{'='*60}")
    print(f"Workflow Template: {name}")
    print('='*60)
    print(json.dumps(template, indent=2))
    print()


def main():
    """Display all workflow templates"""
    templates = N8nWorkflowTemplates()
    
    print("n8n Workflow Templates for Homelab Automation")
    print("=" * 60)
    print("\nAvailable templates:")
    print("1. Container Health Check")
    print("2. Backup Orchestration")
    print("3. DNS Update Webhook")
    print("4. SSL Certificate Renewal Check")
    print("5. Netbox IPAM Sync")
    print("\nTo use these templates:")
    print("1. Copy the JSON output")
    print("2. Import into n8n via API or UI")
    print("3. Configure credentials and parameters")
    print("4. Activate the workflow")
    
    print_template("Container Health Check", templates.container_health_check())
    print_template("Backup Orchestration", templates.backup_orchestration())
    print_template("DNS Update Webhook", templates.dns_update_webhook())
    print_template("SSL Certificate Check", templates.ssl_renewal_check())
    print_template("Netbox Sync", templates.netbox_sync())


if __name__ == '__main__':
    main()
