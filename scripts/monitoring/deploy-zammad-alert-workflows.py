#!/usr/bin/env python3
"""Deploy enhanced Prometheus + Uptime Kuma → Zammad workflows (open on alert, close on resolve)."""
from __future__ import annotations

import json
import os
import sys
import urllib.request

API = os.environ.get("N8N_API_URL", "http://10.92.3.79:5678/api/v1").replace("https://n8n.cloudigan.net/api/v1", "http://10.92.3.79:5678/api/v1").rstrip("/")
TOKEN = os.environ.get("N8N_API_TOKEN", "")
ZAMMAD_CRED = "g9DGyY5zBJy8ruQn"
VIKUNJA_CRED = "BRJWKbv7F1KUu5y3"

PROM_WORKFLOW_ID = "7BSAqpNF5VCevaZ2"
KUMA_WORKFLOW_ID = "hpcPBbttShe5Uc7j"


def api(method: str, path: str, data: dict | None = None) -> dict:
    url = f"{API}/{path.lstrip('/')}"
    body = json.dumps(data).encode() if data is not None else None
    req = urllib.request.Request(
        url,
        data=body,
        method=method,
        headers={"X-N8N-API-KEY": TOKEN, "Content-Type": "application/json", "Accept": "application/json"},
    )
    with urllib.request.urlopen(req, timeout=60) as resp:
        return json.loads(resp.read())


def zammad_cred_node(name: str, node_id: str, x: int, y: int) -> dict:
    return {
        "parameters": {
            "method": "GET",
            "url": "=https://support.cloudigan.net/api/v1/tickets/search",
            "authentication": "genericCredentialType",
            "genericAuthType": "httpHeaderAuth",
            "sendQuery": True,
            "queryParameters": {
                "parameters": [{"name": "query", "value": f"={{{{ $json.{name} }}}}"}]
            },
            "options": {},
        },
        "id": node_id,
        "name": node_id,
        "type": "n8n-nodes-base.httpRequest",
        "typeVersion": 4.2,
        "position": [x, y],
        "credentials": {"httpHeaderAuth": {"id": ZAMMAD_CRED, "name": "Zammad API Token"}},
    }


def build_prometheus_workflow() -> dict:
    parse_code = r"""
const body = $input.first().json.body || {};
const alert = (body.alerts && body.alerts[0]) || {};
const labels = alert.labels || {};
const ann = alert.annotations || {};
const fp = `${labels.alertname || 'unknown'}-${labels.instance || 'unknown'}`.replace(/[^a-zA-Z0-9._-]+/g, '-');
const tag = `alert-fp-${fp}`;
const searchQuery = `tag:${tag} AND state.name:open`;
const title = `[${(labels.severity || 'alert').toUpperCase()}] ${labels.alertname}: ${labels.instance}`;
return [{
  json: {
    status: body.status || 'firing',
    fp,
    tag,
    searchQuery,
    title,
    labels,
    ann,
    startsAt: alert.startsAt,
    endsAt: alert.endsAt,
    body
  }
}];
"""

    close_article_body = r"""=Alert resolved automatically.

Alert: {{ $json.labels.alertname }}
Instance: {{ $json.labels.instance }}
Severity: {{ $json.labels.severity }}
Resolved at: {{ $json.endsAt }}

Summary: {{ $json.ann.summary }}

The condition cleared in Prometheus (auto-heal, watchdog restart, or manual fix). No further action required unless the alert reopens.

— Homelab monitoring (Alertmanager → n8n)"""

    nodes = [
        {
            "parameters": {"httpMethod": "POST", "path": "prometheus-alert", "responseMode": "responseNode", "options": {}},
            "id": "webhook-prom",
            "name": "Webhook - Prometheus Alert",
            "type": "n8n-nodes-base.webhook",
            "typeVersion": 2,
            "position": [240, 400],
            "webhookId": "prometheus-alert",
        },
        {
            "parameters": {"jsCode": parse_code},
            "id": "parse-prom",
            "name": "Parse Alert",
            "type": "n8n-nodes-base.code",
            "typeVersion": 2,
            "position": [480, 400],
        },
        {
            "parameters": {
                "conditions": {
                    "options": {"caseSensitive": True, "typeValidation": "strict"},
                    "conditions": [
                        {
                            "id": "firing",
                            "leftValue": "={{ $json.status }}",
                            "rightValue": "firing",
                            "operator": {"type": "string", "operation": "equals"},
                        }
                    ],
                    "combinator": "and",
                },
                "options": {},
            },
            "id": "if-firing",
            "name": "Is Firing?",
            "type": "n8n-nodes-base.if",
            "typeVersion": 2,
            "position": [720, 400],
        },
        {
            "parameters": {
                "method": "GET",
                "url": "https://support.cloudigan.net/api/v1/tickets/search",
                "authentication": "genericCredentialType",
                "genericAuthType": "httpHeaderAuth",
                "sendQuery": True,
                "queryParameters": {
                    "parameters": [{"name": "query", "value": "={{ $json.searchQuery }}"}, {"name": "limit", "value": "1"}]
                },
                "options": {},
            },
            "id": "search-open-firing",
            "name": "Search Open Ticket",
            "type": "n8n-nodes-base.httpRequest",
            "typeVersion": 4.2,
            "position": [960, 280],
            "credentials": {"httpHeaderAuth": {"id": ZAMMAD_CRED, "name": "Zammad API Token"}},
        },
        {
            "parameters": {
                "conditions": {
                    "options": {"caseSensitive": True, "typeValidation": "loose"},
                    "conditions": [
                        {
                            "id": "no-ticket",
                            "leftValue": "={{ Array.isArray($json) ? $json.length : ($json.tickets_count || ($json.tickets || []).length || 0) }}",
                            "rightValue": 0,
                            "operator": {"type": "number", "operation": "equals"},
                        }
                    ],
                    "combinator": "and",
                },
                "options": {},
            },
            "id": "if-no-ticket",
            "name": "No Open Ticket?",
            "type": "n8n-nodes-base.if",
            "typeVersion": 2,
            "position": [1200, 280],
        },
        {
            "parameters": {
                "method": "POST",
                "url": "https://support.cloudigan.net/api/v1/tickets",
                "authentication": "genericCredentialType",
                "genericAuthType": "httpHeaderAuth",
                "sendBody": True,
                "specifyBody": "json",
                "jsonBody": '={\n  "title": "{{ $(\'Parse Alert\').item.json.title }}",\n  "group": "Users",\n  "customer": "cory@cloudigan.com",\n  "tags": "{{ $(\'Parse Alert\').item.json.tag }}, monitoring, prometheus, automated",\n  "article": {\n    "subject": "Prometheus Alert: {{ $(\'Parse Alert\').item.json.labels.alertname }}",\n    "body": "Alert: {{ $(\'Parse Alert\').item.json.labels.alertname }}\\nSeverity: {{ $(\'Parse Alert\').item.json.labels.severity }}\\nInstance: {{ $(\'Parse Alert\').item.json.labels.instance }}\\nApp: {{ $(\'Parse Alert\').item.json.labels.app || \'n/a\' }}\\nContainer: {{ $(\'Parse Alert\').item.json.labels.container || \'n/a\' }}\\n\\nSummary: {{ $(\'Parse Alert\').item.json.ann.summary }}\\nDescription: {{ $(\'Parse Alert\').item.json.ann.description }}\\nStarted: {{ $(\'Parse Alert\').item.json.startsAt }}\\n\\nGrafana: https://grafana.cloudigan.net\\nPrometheus: https://prometheus.cloudigan.net\\n\\nAuto-created by Alertmanager → n8n.",\n    "type": "note",\n    "internal": false\n  },\n  "priority_id": 3,\n  "state_id": 2\n}',
                "options": {},
            },
            "id": "create-ticket",
            "name": "Create Zammad Ticket",
            "type": "n8n-nodes-base.httpRequest",
            "typeVersion": 4.2,
            "position": [1440, 200],
            "credentials": {"httpHeaderAuth": {"id": ZAMMAD_CRED, "name": "Zammad API Token"}},
        },
        {
            "parameters": {
                "method": "PUT",
                "url": "https://tasks.cloudigan.net/api/v1/projects/1/tasks",
                "authentication": "genericCredentialType",
                "genericAuthType": "httpHeaderAuth",
                "sendBody": True,
                "specifyBody": "json",
                "jsonBody": '={\n  "title": "{{ $(\'Parse Alert\').item.json.title }}",\n  "description": "**Prometheus alert**\\n\\n{{ $(\'Parse Alert\').item.json.ann.summary }}\\n\\n{{ $(\'Parse Alert\').item.json.ann.description }}\\n\\n<!-- alert:{\\"alertname\\":\\"{{ $(\'Parse Alert\').item.json.labels.alertname }}\\",\\"instance\\":\\"{{ $(\'Parse Alert\').item.json.labels.instance }}\\",\\"fp\\":\\"{{ $(\'Parse Alert\').item.json.fp }}\\"} -->",\n  "priority": 3,\n  "project_id": 1\n}',
                "options": {},
            },
            "id": "create-vikunja",
            "name": "Create Vikunja Task",
            "type": "n8n-nodes-base.httpRequest",
            "typeVersion": 4.2,
            "position": [1440, 360],
            "credentials": {"httpHeaderAuth": {"id": VIKUNJA_CRED, "name": "Vikunja API Token"}},
        },
        {
            "parameters": {
                "method": "GET",
                "url": "https://support.cloudigan.net/api/v1/tickets/search",
                "authentication": "genericCredentialType",
                "genericAuthType": "httpHeaderAuth",
                "sendQuery": True,
                "queryParameters": {
                    "parameters": [{"name": "query", "value": "={{ $json.searchQuery }}"}, {"name": "limit", "value": "1"}]
                },
                "options": {},
            },
            "id": "search-open-resolved",
            "name": "Search Ticket To Close",
            "type": "n8n-nodes-base.httpRequest",
            "typeVersion": 4.2,
            "position": [960, 520],
            "credentials": {"httpHeaderAuth": {"id": ZAMMAD_CRED, "name": "Zammad API Token"}},
        },
        {
            "parameters": {
                "conditions": {
                    "options": {"caseSensitive": True, "typeValidation": "loose"},
                    "conditions": [
                        {
                            "id": "has-ticket",
                            "leftValue": "={{ Array.isArray($json) ? $json.length : ($json.tickets_count || ($json.tickets || []).length || 0) }}",
                            "rightValue": 0,
                            "operator": {"type": "number", "operation": "gt"},
                        }
                    ],
                    "combinator": "and",
                },
                "options": {},
            },
            "id": "if-has-ticket",
            "name": "Has Open Ticket?",
            "type": "n8n-nodes-base.if",
            "typeVersion": 2,
            "position": [1200, 520],
        },
        {
            "parameters": {
                "method": "PUT",
                "url": "=https://support.cloudigan.net/api/v1/tickets/{{ Array.isArray($json) ? $json[0].id : $json.tickets[0].id }}",
                "authentication": "genericCredentialType",
                "genericAuthType": "httpHeaderAuth",
                "sendBody": True,
                "specifyBody": "json",
                "jsonBody": '={\n  "state_id": 4,\n  "article": {\n    "body": ' + json.dumps(close_article_body)[1:-1] + ',\n    "type": "note",\n    "internal": false\n  }\n}',
                "options": {},
            },
            "id": "close-ticket",
            "name": "Close Zammad Ticket",
            "type": "n8n-nodes-base.httpRequest",
            "typeVersion": 4.2,
            "position": [1440, 480],
            "credentials": {"httpHeaderAuth": {"id": ZAMMAD_CRED, "name": "Zammad API Token"}},
        },
        {
            "parameters": {
                "respondWith": "json",
                "responseBody": '={ "success": true, "action": "firing", "ticket": {{ $json.id || null }} }',
                "options": {},
            },
            "id": "resp-firing",
            "name": "Response - Firing",
            "type": "n8n-nodes-base.respondToWebhook",
            "typeVersion": 1.1,
            "position": [1680, 280],
        },
        {
            "parameters": {
                "respondWith": "json",
                "responseBody": '={ "success": true, "action": "resolved", "closed": {{ $json.id || null }} }',
                "options": {},
            },
            "id": "resp-resolved",
            "name": "Response - Resolved",
            "type": "n8n-nodes-base.respondToWebhook",
            "typeVersion": 1.1,
            "position": [1680, 520],
        },
        {
            "parameters": {
                "respondWith": "json",
                "responseBody": '={ "success": true, "action": "firing-skipped", "reason": "open ticket exists" }',
                "options": {},
            },
            "id": "resp-firing-skip",
            "name": "Response - Already Open",
            "type": "n8n-nodes-base.respondToWebhook",
            "typeVersion": 1.1,
            "position": [1440, 320],
        },
        {
            "parameters": {
                "respondWith": "json",
                "responseBody": '={ "success": true, "action": "resolved-noop", "reason": "no open ticket" }',
                "options": {},
            },
            "id": "resp-resolved-noop",
            "name": "Response - Nothing To Close",
            "type": "n8n-nodes-base.respondToWebhook",
            "typeVersion": 1.1,
            "position": [1440, 580],
        },
    ]

    # Fix close ticket jsonBody - use simpler expression
    for n in nodes:
        if n["id"] == "close-ticket":
            n["parameters"]["jsonBody"] = (
                '={\n  "state_id": 4,\n  "article": {\n'
                '"body": "Alert resolved automatically.\\n\\nAlert: {{ $(\'Parse Alert\').item.json.labels.alertname }}\\n'
                'Instance: {{ $(\'Parse Alert\').item.json.labels.instance }}\\n'
                'Resolved: {{ $(\'Parse Alert\').item.json.endsAt }}\\n\\n'
                '{{ $(\'Parse Alert\').item.json.ann.summary }}\\n\\n'
                'Condition cleared in Prometheus (auto-heal / watchdog / manual fix).",\n'
                '"type": "note",\n    "internal": false\n  }\n}'
            )

    connections = {
        "Webhook - Prometheus Alert": {"main": [[{"node": "Parse Alert", "type": "main", "index": 0}]]},
        "Parse Alert": {"main": [[{"node": "Is Firing?", "type": "main", "index": 0}]]},
        "Is Firing?": {
            "main": [
                [{"node": "Search Open Ticket", "type": "main", "index": 0}],
                [{"node": "Search Ticket To Close", "type": "main", "index": 0}],
            ]
        },
        "Search Open Ticket": {"main": [[{"node": "No Open Ticket?", "type": "main", "index": 0}]]},
        "No Open Ticket?": {
            "main": [
                [
                    {"node": "Create Zammad Ticket", "type": "main", "index": 0},
                    {"node": "Create Vikunja Task", "type": "main", "index": 0},
                ],
                [{"node": "Response - Already Open", "type": "main", "index": 0}],
            ]
        },
        "Create Zammad Ticket": {"main": [[{"node": "Response - Firing", "type": "main", "index": 0}]]},
        "Create Vikunja Task": {"main": [[{"node": "Response - Firing", "type": "main", "index": 0}]]},
        "Search Ticket To Close": {"main": [[{"node": "Has Open Ticket?", "type": "main", "index": 0}]]},
        "Has Open Ticket?": {
            "main": [
                [{"node": "Close Zammad Ticket", "type": "main", "index": 0}],
                [{"node": "Response - Nothing To Close", "type": "main", "index": 0}],
            ]
        },
        "Close Zammad Ticket": {"main": [[{"node": "Response - Resolved", "type": "main", "index": 0}]]},
    }

    return {
        "name": "Prometheus Alerts → Zammad + Vikunja",
        "nodes": nodes,
        "connections": connections,
        "settings": {"executionOrder": "v1"},
    }


def build_kuma_workflow() -> dict:
    parse_code = r"""
const body = $input.first().json.body || $input.first().json;
const monitor = body.monitor || {};
const heartbeat = body.heartbeat || {};
const name = monitor.name || 'unknown';
const fp = name.replace(/[^a-zA-Z0-9._-]+/g, '-');
const tag = `alert-fp-uptime-${fp}`;
const searchQuery = `tag:${tag} AND state.name:open`;
const isDown = heartbeat.status === 0 || heartbeat.status === '0' || String(heartbeat.status).toLowerCase() === 'down';
return [{ json: { isDown, tag, searchQuery, monitor, heartbeat, name, fp } }];
"""

    nodes = [
        {
            "parameters": {"httpMethod": "POST", "path": "uptime-kuma-alert", "responseMode": "responseNode", "options": {}},
            "id": "webhook-kuma",
            "name": "Webhook",
            "type": "n8n-nodes-base.webhook",
            "typeVersion": 2,
            "position": [240, 400],
            "webhookId": "uptime-kuma-alert",
        },
        {
            "parameters": {"jsCode": parse_code},
            "id": "parse-kuma",
            "name": "Parse Heartbeat",
            "type": "n8n-nodes-base.code",
            "typeVersion": 2,
            "position": [480, 400],
        },
        {
            "parameters": {
                "conditions": {
                    "options": {"caseSensitive": True, "typeValidation": "strict"},
                    "conditions": [
                        {
                            "id": "down",
                            "leftValue": "={{ $json.isDown }}",
                            "rightValue": True,
                            "operator": {"type": "boolean", "operation": "true"},
                        }
                    ],
                    "combinator": "and",
                },
                "options": {},
            },
            "id": "if-down",
            "name": "Is Down?",
            "type": "n8n-nodes-base.if",
            "typeVersion": 2,
            "position": [720, 400],
        },
        {
            "parameters": {
                "method": "GET",
                "url": "https://support.cloudigan.net/api/v1/tickets/search",
                "authentication": "genericCredentialType",
                "genericAuthType": "httpHeaderAuth",
                "sendQuery": True,
                "queryParameters": {
                    "parameters": [{"name": "query", "value": "={{ $json.searchQuery }}"}, {"name": "limit", "value": "1"}]
                },
                "options": {},
            },
            "id": "kuma-search-open",
            "name": "Search Open Ticket",
            "type": "n8n-nodes-base.httpRequest",
            "typeVersion": 4.2,
            "position": [960, 280],
            "credentials": {"httpHeaderAuth": {"id": ZAMMAD_CRED, "name": "Zammad API Token"}},
        },
        {
            "parameters": {
                "conditions": {
                    "options": {"typeValidation": "loose"},
                    "conditions": [
                        {
                            "id": "none",
                            "leftValue": "={{ Array.isArray($json) ? $json.length : ($json.tickets_count || ($json.tickets || []).length || 0) }}",
                            "rightValue": 0,
                            "operator": {"type": "number", "operation": "equals"},
                        }
                    ],
                    "combinator": "and",
                },
                "options": {},
            },
            "id": "kuma-no-ticket",
            "name": "No Open Ticket?",
            "type": "n8n-nodes-base.if",
            "typeVersion": 2,
            "position": [1200, 280],
        },
        {
            "parameters": {
                "method": "POST",
                "url": "https://support.cloudigan.net/api/v1/tickets",
                "authentication": "genericCredentialType",
                "genericAuthType": "httpHeaderAuth",
                "sendBody": True,
                "specifyBody": "json",
                "jsonBody": '={\n  "title": "{{ $(\'Parse Heartbeat\').item.json.name }} is DOWN",\n  "group": "Users",\n  "customer": "cory@cloudigan.com",\n  "tags": "{{ $(\'Parse Heartbeat\').item.json.tag }}, monitoring, uptime-kuma, automated",\n  "article": {\n    "subject": "Uptime Kuma: {{ $(\'Parse Heartbeat\').item.json.name }}",\n    "body": "Service: {{ $(\'Parse Heartbeat\').item.json.name }}\\nStatus: DOWN\\nURL: {{ $(\'Parse Heartbeat\').item.json.monitor.url || \'n/a\' }}\\nTime: {{ $(\'Parse Heartbeat\').item.json.heartbeat.time }}\\nMessage: {{ $(\'Parse Heartbeat\').item.json.heartbeat.msg }}\\n\\n— Uptime Kuma → n8n",\n    "type": "note",\n    "internal": false\n  },\n  "priority_id": 3,\n  "state_id": 2\n}',
                "options": {},
            },
            "id": "kuma-create",
            "name": "Create Zammad Ticket",
            "type": "n8n-nodes-base.httpRequest",
            "typeVersion": 4.2,
            "position": [1440, 220],
            "credentials": {"httpHeaderAuth": {"id": ZAMMAD_CRED, "name": "Zammad API Token"}},
        },
        {
            "parameters": {
                "method": "GET",
                "url": "https://support.cloudigan.net/api/v1/tickets/search",
                "authentication": "genericCredentialType",
                "genericAuthType": "httpHeaderAuth",
                "sendQuery": True,
                "queryParameters": {
                    "parameters": [{"name": "query", "value": "={{ $json.searchQuery }}"}, {"name": "limit", "value": "1"}]
                },
                "options": {},
            },
            "id": "kuma-search-close",
            "name": "Search Ticket To Close",
            "type": "n8n-nodes-base.httpRequest",
            "typeVersion": 4.2,
            "position": [960, 520],
            "credentials": {"httpHeaderAuth": {"id": ZAMMAD_CRED, "name": "Zammad API Token"}},
        },
        {
            "parameters": {
                "conditions": {
                    "options": {"typeValidation": "loose"},
                    "conditions": [
                        {
                            "id": "has",
                            "leftValue": "={{ Array.isArray($json) ? $json.length : ($json.tickets_count || ($json.tickets || []).length || 0) }}",
                            "rightValue": 0,
                            "operator": {"type": "number", "operation": "gt"},
                        }
                    ],
                    "combinator": "and",
                },
                "options": {},
            },
            "id": "kuma-has-ticket",
            "name": "Has Open Ticket?",
            "type": "n8n-nodes-base.if",
            "typeVersion": 2,
            "position": [1200, 520],
        },
        {
            "parameters": {
                "method": "PUT",
                "url": "=https://support.cloudigan.net/api/v1/tickets/{{ Array.isArray($json) ? $json[0].id : $json.tickets[0].id }}",
                "authentication": "genericCredentialType",
                "genericAuthType": "httpHeaderAuth",
                "sendBody": True,
                "specifyBody": "json",
                "jsonBody": '={\n  "state_id": 4,\n  "article": {\n    "body": "Service recovered — Uptime Kuma reports UP.\\n\\nMonitor: {{ $(\'Parse Heartbeat\').item.json.name }}\\nURL: {{ $(\'Parse Heartbeat\').item.json.monitor.url || \'n/a\' }}\\nRecovered: {{ $(\'Parse Heartbeat\').item.json.heartbeat.time }}\\n\\nAuto-closed by n8n.",\n    "type": "note",\n    "internal": false\n  }\n}',
                "options": {},
            },
            "id": "kuma-close",
            "name": "Close Zammad Ticket",
            "type": "n8n-nodes-base.httpRequest",
            "typeVersion": 4.2,
            "position": [1440, 500],
            "credentials": {"httpHeaderAuth": {"id": ZAMMAD_CRED, "name": "Zammad API Token"}},
        },
        {
            "parameters": {"respondWith": "json", "responseBody": '={ "success": true, "action": "down" }', "options": {}},
            "id": "kuma-resp-down",
            "name": "Webhook Response Down",
            "type": "n8n-nodes-base.respondToWebhook",
            "typeVersion": 1.1,
            "position": [1680, 280],
        },
        {
            "parameters": {"respondWith": "json", "responseBody": '={ "success": true, "action": "up-closed" }', "options": {}},
            "id": "kuma-resp-up",
            "name": "Webhook Response Up",
            "type": "n8n-nodes-base.respondToWebhook",
            "typeVersion": 1.1,
            "position": [1680, 520],
        },
        {
            "parameters": {"respondWith": "json", "responseBody": '={ "success": true, "action": "down-skip" }', "options": {}},
            "id": "kuma-resp-skip",
            "name": "Webhook Response Skip",
            "type": "n8n-nodes-base.respondToWebhook",
            "typeVersion": 1.1,
            "position": [1440, 340],
        },
        {
            "parameters": {"respondWith": "json", "responseBody": '={ "success": true, "action": "up-noop" }', "options": {}},
            "id": "kuma-resp-noop",
            "name": "Webhook Response Noop",
            "type": "n8n-nodes-base.respondToWebhook",
            "typeVersion": 1.1,
            "position": [1440, 580],
        },
    ]

    connections = {
        "Webhook": {"main": [[{"node": "Parse Heartbeat", "type": "main", "index": 0}]]},
        "Parse Heartbeat": {"main": [[{"node": "Is Down?", "type": "main", "index": 0}]]},
        "Is Down?": {
            "main": [
                [{"node": "Search Open Ticket", "type": "main", "index": 0}],
                [{"node": "Search Ticket To Close", "type": "main", "index": 0}],
            ]
        },
        "Search Open Ticket": {"main": [[{"node": "No Open Ticket?", "type": "main", "index": 0}]]},
        "No Open Ticket?": {
            "main": [[{"node": "Create Zammad Ticket", "type": "main", "index": 0}], [{"node": "Webhook Response Skip", "type": "main", "index": 0}]]
        },
        "Create Zammad Ticket": {"main": [[{"node": "Webhook Response Down", "type": "main", "index": 0}]]},
        "Search Ticket To Close": {"main": [[{"node": "Has Open Ticket?", "type": "main", "index": 0}]]},
        "Has Open Ticket?": {
            "main": [[{"node": "Close Zammad Ticket", "type": "main", "index": 0}], [{"node": "Webhook Response Noop", "type": "main", "index": 0}]]
        },
        "Close Zammad Ticket": {"main": [[{"node": "Webhook Response Up", "type": "main", "index": 0}]]},
    }

    return {
        "name": "Uptime Kuma → Zammad Ticket Creation",
        "nodes": nodes,
        "connections": connections,
        "settings": {"executionOrder": "v1"},
    }


def main() -> None:
    if not TOKEN:
        print("N8N_API_TOKEN required", file=sys.stderr)
        sys.exit(1)
    for wf_id, builder in [(PROM_WORKFLOW_ID, build_prometheus_workflow), (KUMA_WORKFLOW_ID, build_kuma_workflow)]:
        payload = builder()
        result = api("PUT", f"workflows/{wf_id}", payload)
        api("POST", f"workflows/{wf_id}/activate", {})
        print(f"Updated and activated: {result.get('name', wf_id)} ({wf_id})")


if __name__ == "__main__":
    main()
