#!/usr/bin/env python3
"""Deploy Ops Hub n8n workflows (Zammad↔Vikunja, Kimai timer, capture, morning briefing)."""
from __future__ import annotations

import json
import os
import sys
import urllib.error
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
IDS_FILE = ROOT / "workflows" / "ops" / "workflow-ids.json"

API = os.environ.get("N8N_API_URL", "http://10.92.3.79:5678/api/v1").replace(
    "https://n8n.cloudigan.net/api/v1", "http://10.92.3.79:5678/api/v1"
).rstrip("/")
TOKEN = os.environ.get("N8N_API_TOKEN", "")

ZAMMAD_CRED = "g9DGyY5zBJy8ruQn"
VIKUNJA_CRED = "BRJWKbv7F1KUu5y3"
ZAMMAD_CREATE_WF = "6mcHbtq1wHF8dzBe"

NTFY_URL = os.environ.get("NTFY_URL", "https://push.cloudigan.net")
NTFY_TOPIC = os.environ.get("NTFY_TOPIC", "cory-daily-briefing")
OPS_HUB_URL = os.environ.get("OPS_HUB_URL", "https://ops.cloudigan.net")
KIMai_USER = os.environ.get("KIMAI_API_USER", "cory@cloudigan.com")


def api(method: str, path: str, data: dict | None = None) -> dict:
    url = f"{API}/{path.lstrip('/')}"
    body = json.dumps(data).encode() if data is not None else None
    req = urllib.request.Request(
        url,
        data=body,
        method=method,
        headers={
            "X-N8N-API-KEY": TOKEN,
            "Content-Type": "application/json",
            "Accept": "application/json",
        },
    )
    try:
        with urllib.request.urlopen(req, timeout=120) as resp:
            raw = resp.read()
            return json.loads(raw) if raw else {}
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode()
        raise RuntimeError(f"n8n API {method} {path} failed ({exc.code}): {detail}") from exc


def load_ids() -> dict:
    if IDS_FILE.exists():
        return json.loads(IDS_FILE.read_text())
    return {}


def save_ids(ids: dict) -> None:
    IDS_FILE.parent.mkdir(parents=True, exist_ok=True)
    IDS_FILE.write_text(json.dumps(ids, indent=2) + "\n")


def upsert_workflow(key: str, builder, ids: dict) -> str:
    payload = builder()
    wf_id = ids.get(key)
    if wf_id:
        result = api("PUT", f"workflows/{wf_id}", payload)
    else:
        result = api("POST", "workflows", payload)
        wf_id = result["id"]
        ids[key] = wf_id
    api("POST", f"workflows/{wf_id}/activate", {})
    print(f"  ✓ {payload['name']} ({wf_id})")
    return wf_id


def build_zammad_vikunja_create() -> dict:
    """Update existing workflow — adds zammad metadata block for reverse sync."""
    description_tpl = (
        "**Zammad Ticket:** https://support.cloudigan.net/#ticket/zoom/{{ $json.body.ticket.id }}\\n\\n"
        "**Customer:** {{ $json.body.ticket.customer }}\\n"
        "**Priority:** {{ $json.body.ticket.priority }}\\n"
        "**Group:** {{ $json.body.ticket.group }}\\n\\n"
        "**Description:**\\n{{ $json.body.article.body }}\\n\\n"
        "---\\n"
        "*Auto-created from Zammad ticket #{{ $json.body.ticket.number }}*\\n"
        "<!-- zammad:{\\\"ticket_id\\\":{{ $json.body.ticket.id }},"
        "\\\"ticket_number\\\":\\\"{{ $json.body.ticket.number }}\\\"} -->"
    )
    return {
        "name": "Zammad → Vikunja Task Creation",
        "nodes": [
            {
                "parameters": {
                    "httpMethod": "POST",
                    "path": "zammad-ticket",
                    "responseMode": "responseNode",
                    "options": {},
                },
                "id": "webhook-zammad",
                "name": "Webhook - Zammad Ticket",
                "type": "n8n-nodes-base.webhook",
                "typeVersion": 1.1,
                "position": [250, 300],
                "webhookId": "zammad-ticket",
            },
            {
                "parameters": {
                    "method": "PUT",
                    "url": "https://tasks.cloudigan.net/api/v1/projects/1/tasks",
                    "authentication": "genericCredentialType",
                    "genericAuthType": "httpHeaderAuth",
                    "sendHeaders": True,
                    "headerParameters": {"parameters": [{"name": "Content-Type", "value": "application/json"}]},
                    "sendBody": True,
                    "specifyBody": "json",
                    "jsonBody": (
                        '={\n  "title": "Ticket #{{ $json.body.ticket.number }}: '
                        '{{ $json.body.ticket.title }}",\n  "description": "'
                        + description_tpl
                        + '",\n  "priority": 2,\n  "project_id": 1\n}'
                    ),
                    "options": {},
                },
                "id": "create-vikunja-task",
                "name": "Create Vikunja Task",
                "type": "n8n-nodes-base.httpRequest",
                "typeVersion": 4.2,
                "position": [450, 300],
                "credentials": {"httpHeaderAuth": {"id": VIKUNJA_CRED, "name": "Vikunja API Token"}},
            },
            {
                "parameters": {
                    "respondWith": "json",
                    "responseBody": (
                        '={ "success": true, "task_id": {{ $json.id }}, '
                        '"message": "Vikunja task created successfully" }'
                    ),
                    "options": {},
                },
                "id": "webhook-response",
                "name": "Webhook Response",
                "type": "n8n-nodes-base.respondToWebhook",
                "typeVersion": 1.1,
                "position": [650, 300],
            },
        ],
        "connections": {
            "Webhook - Zammad Ticket": {"main": [[{"node": "Create Vikunja Task", "type": "main", "index": 0}]]},
            "Create Vikunja Task": {"main": [[{"node": "Webhook Response", "type": "main", "index": 0}]]},
        },
        "settings": {"executionOrder": "v1", "timezone": "America/New_York"},
    }


def build_vikunja_zammad_close() -> dict:
    parse_code = r"""
const payload = $input.first().json.body || $input.first().json;
const event = payload.event_name || '';
const task = payload.data?.task || payload.task || {};
const wasDone = Boolean(task.done);
if (event !== 'task.updated' || !wasDone) {
  return [{ json: { skip: true, reason: 'not a completion event' } }];
}
const desc = task.description || '';
let ticketId = null;
const meta = desc.match(/<!-- zammad:(\{.*?\}) -->/);
if (meta) {
  try { ticketId = JSON.parse(meta[1]).ticket_id; } catch (e) {}
}
if (!ticketId) {
  const link = desc.match(/#ticket\/zoom\/(\d+)/);
  if (link) ticketId = parseInt(link[1], 10);
}
if (!ticketId) {
  return [{ json: { skip: true, reason: 'no zammad ticket link', task_id: task.id } }];
}
return [{
  json: {
    skip: false,
    ticket_id: ticketId,
    task_id: task.id,
    task_title: task.title
  }
}];
"""
    close_body = (
        "Ticket closed automatically — linked Vikunja task marked done.\n\n"
        "Task: {{ $json.task_title }} (ID {{ $json.task_id }})\n\n"
        "— Ops Hub (Vikunja → n8n → Zammad)"
    )
    return {
        "name": "Vikunja → Zammad Ticket Close",
        "nodes": [
            {
                "parameters": {"httpMethod": "POST", "path": "vikunja-task-updated", "options": {}},
                "id": "webhook-vikunja",
                "name": "Webhook - Vikunja Task Updated",
                "type": "n8n-nodes-base.webhook",
                "typeVersion": 2,
                "position": [240, 300],
                "webhookId": "vikunja-task-updated",
            },
            {
                "parameters": {"jsCode": parse_code},
                "id": "parse-vikunja",
                "name": "Parse Vikunja Event",
                "type": "n8n-nodes-base.code",
                "typeVersion": 2,
                "position": [480, 300],
            },
            {
                "parameters": {
                    "conditions": {
                        "options": {"caseSensitive": True, "typeValidation": "strict"},
                        "conditions": [
                            {
                                "id": "not-skip",
                                "leftValue": "={{ $json.skip }}",
                                "rightValue": False,
                                "operator": {"type": "boolean", "operation": "equals"},
                            }
                        ],
                        "combinator": "and",
                    },
                    "options": {},
                },
                "id": "if-zammad",
                "name": "Linked Zammad Ticket?",
                "type": "n8n-nodes-base.if",
                "typeVersion": 2,
                "position": [720, 300],
            },
            {
                "parameters": {
                    "method": "PUT",
                    "url": "=https://support.cloudigan.net/api/v1/tickets/{{ $json.ticket_id }}",
                    "authentication": "genericCredentialType",
                    "genericAuthType": "httpHeaderAuth",
                    "sendBody": True,
                    "specifyBody": "json",
                    "jsonBody": (
                        '={\n  "state_id": 4,\n  "article": {\n    "body": "'
                        + close_body.replace('"', '\\"')
                        + '",\n    "type": "note",\n    "internal": true\n  }\n}'
                    ),
                    "options": {},
                },
                "id": "close-zammad",
                "name": "Close Zammad Ticket",
                "type": "n8n-nodes-base.httpRequest",
                "typeVersion": 4.2,
                "position": [960, 220],
                "credentials": {"httpHeaderAuth": {"id": ZAMMAD_CRED, "name": "Zammad API Token"}},
            },
            {
                "parameters": {"options": {}},
                "id": "noop-skip",
                "name": "Skip (no Zammad link)",
                "type": "n8n-nodes-base.noOp",
                "typeVersion": 1,
                "position": [960, 400],
            },
        ],
        "connections": {
            "Webhook - Vikunja Task Updated": {"main": [[{"node": "Parse Vikunja Event", "type": "main", "index": 0}]]},
            "Parse Vikunja Event": {"main": [[{"node": "Linked Zammad Ticket?", "type": "main", "index": 0}]]},
            "Linked Zammad Ticket?": {
                "main": [[{"node": "Close Zammad Ticket", "type": "main", "index": 0}], [{"node": "Skip (no Zammad link)", "type": "main", "index": 0}]]
            },
        },
        "settings": {"executionOrder": "v1", "timezone": "America/New_York"},
    }


def build_zammad_vikunja_close() -> dict:
    parse_code = r"""
const body = $input.first().json.body || $input.first().json;
const ticket = body.ticket || {};
const ticketId = ticket.id;
const ticketNumber = ticket.number;
if (!ticketId) {
  return [{ json: { skip: true, reason: 'no ticket in payload' } }];
}
return [{
  json: {
    skip: false,
    ticket_id: ticketId,
    ticket_number: ticketNumber,
    search: ticketNumber ? `Ticket #${ticketNumber}` : `#ticket/zoom/${ticketId}`
  }
}];
"""
    complete_code = r"""
const tasks = $input.first().json;
const list = Array.isArray(tasks) ? tasks : (tasks.tasks || []);
const ctx = $('Parse Zammad Close').first().json;
const needle = String(ctx.ticket_number || ctx.ticket_id);
const match = list.find(t => {
  const title = t.title || '';
  const desc = t.description || '';
  return title.includes(`Ticket #${needle}`) || desc.includes(`#ticket/zoom/${ctx.ticket_id}`);
});
if (!match) {
  return [{ json: { skip: true, reason: 'no matching vikunja task', ticket_id: ctx.ticket_id } }];
}
return [{ json: { skip: false, task_id: match.id, task_title: match.title, ticket_id: ctx.ticket_id } }];
"""
    return {
        "name": "Zammad → Vikunja Task Complete",
        "nodes": [
            {
                "parameters": {"httpMethod": "POST", "path": "zammad-ticket-closed", "options": {}},
                "id": "webhook-zammad-close",
                "name": "Webhook - Zammad Ticket Closed",
                "type": "n8n-nodes-base.webhook",
                "typeVersion": 2,
                "position": [240, 300],
                "webhookId": "zammad-ticket-closed",
            },
            {
                "parameters": {"jsCode": parse_code},
                "id": "parse-zammad-close",
                "name": "Parse Zammad Close",
                "type": "n8n-nodes-base.code",
                "typeVersion": 2,
                "position": [480, 300],
            },
            {
                "parameters": {
                    "method": "GET",
                    "url": "https://tasks.cloudigan.net/api/v1/projects/1/tasks",
                    "authentication": "genericCredentialType",
                    "genericAuthType": "httpHeaderAuth",
                    "options": {},
                },
                "id": "list-inbox-tasks",
                "name": "List Inbox Tasks",
                "type": "n8n-nodes-base.httpRequest",
                "typeVersion": 4.2,
                "position": [720, 300],
                "credentials": {"httpHeaderAuth": {"id": VIKUNJA_CRED, "name": "Vikunja API Token"}},
            },
            {
                "parameters": {"jsCode": complete_code},
                "id": "find-task",
                "name": "Find Matching Task",
                "type": "n8n-nodes-base.code",
                "typeVersion": 2,
                "position": [960, 300],
            },
            {
                "parameters": {
                    "conditions": {
                        "options": {"caseSensitive": True, "typeValidation": "strict"},
                        "conditions": [
                            {
                                "id": "found",
                                "leftValue": "={{ $json.skip }}",
                                "rightValue": False,
                                "operator": {"type": "boolean", "operation": "equals"},
                            }
                        ],
                        "combinator": "and",
                    },
                    "options": {},
                },
                "id": "if-found",
                "name": "Task Found?",
                "type": "n8n-nodes-base.if",
                "typeVersion": 2,
                "position": [1200, 300],
            },
            {
                "parameters": {
                    "method": "POST",
                    "url": "=https://tasks.cloudigan.net/api/v1/tasks/{{ $json.task_id }}",
                    "authentication": "genericCredentialType",
                    "genericAuthType": "httpHeaderAuth",
                    "sendBody": True,
                    "specifyBody": "json",
                    "jsonBody": '={ "done": true }',
                    "options": {},
                },
                "id": "complete-vikunja",
                "name": "Complete Vikunja Task",
                "type": "n8n-nodes-base.httpRequest",
                "typeVersion": 4.2,
                "position": [1440, 220],
                "credentials": {"httpHeaderAuth": {"id": VIKUNJA_CRED, "name": "Vikunja API Token"}},
            },
            {
                "parameters": {"options": {}},
                "id": "noop-not-found",
                "name": "Skip (not found)",
                "type": "n8n-nodes-base.noOp",
                "typeVersion": 1,
                "position": [1440, 400],
            },
        ],
        "connections": {
            "Webhook - Zammad Ticket Closed": {"main": [[{"node": "Parse Zammad Close", "type": "main", "index": 0}]]},
            "Parse Zammad Close": {"main": [[{"node": "List Inbox Tasks", "type": "main", "index": 0}]]},
            "List Inbox Tasks": {"main": [[{"node": "Find Matching Task", "type": "main", "index": 0}]]},
            "Find Matching Task": {"main": [[{"node": "Task Found?", "type": "main", "index": 0}]]},
            "Task Found?": {
                "main": [[{"node": "Complete Vikunja Task", "type": "main", "index": 0}], [{"node": "Skip (not found)", "type": "main", "index": 0}]]
            },
        },
        "settings": {"executionOrder": "v1", "timezone": "America/New_York"},
    }


def build_kimai_timer() -> dict:
    token = os.environ.get("KIMAI_API_TOKEN", "")
    if not token:
        raise ValueError("KIMAI_API_TOKEN required for Kimai timer workflow")
    kimai_code = f"""
const body = $input.first().json.body || $input.first().json;
const action = (body.action || 'status').toLowerCase();
const base = 'https://time.cloudigan.net/api';
const headers = {{
  Authorization: 'Bearer {token}',
  Accept: 'application/json',
  'Content-Type': 'application/json',
}};

async function api(method, path, payload) {{
  const opts = {{ method, url: base + path, headers, json: true }};
  if (payload !== undefined) opts.body = payload;
  return await this.helpers.httpRequest(opts);
}}

function localNow() {{
  // Kimai expects naive local time in the user's timezone; n8n's container clock is UTC.
  const parts = new Intl.DateTimeFormat('en-US', {{
    timeZone: 'America/New_York', hourCycle: 'h23',
    year: 'numeric', month: '2-digit', day: '2-digit', hour: '2-digit', minute: '2-digit', second: '2-digit',
  }}).formatToParts(new Date());
  const g = (t) => parts.find(p => p.type === t).value;
  return `${{g('year')}}-${{g('month')}}-${{g('day')}}T${{g('hour')}}:${{g('minute')}}:${{g('second')}}`;
}}

async function findProject(name) {{
  if (!name) return null;
  const projects = await api.call(this, 'GET', '/projects?visible=1&size=50');
  const list = Array.isArray(projects) ? projects : (projects.data || []);
  return list.find(p => (p.name || '').toLowerCase().includes(String(name).toLowerCase())) || list[0] || null;
}}

async function findActivity(name, projectId) {{
  const q = projectId ? `/activities?project=${{projectId}}&visible=1&size=50` : '/activities?visible=1&size=50';
  const activities = await api.call(this, 'GET', q);
  const list = Array.isArray(activities) ? activities : (activities.data || []);
  if (name) {{
    const hit = list.find(a => (a.name || '').toLowerCase().includes(String(name).toLowerCase()));
    if (hit) return hit;
  }}
  return list[0] || null;
}}

try {{
  const active = await api.call(this, 'GET', '/timesheets/active');
  const running = Array.isArray(active) ? active[0] : (active?.id ? active : null);

  if (action === 'status') {{
    return [{{ json: {{ ok: true, action, running: running || null }} }}];
  }}

  if (action === 'stop') {{
    if (!running?.id) {{
      return [{{ json: {{ ok: true, action, message: 'No active timer' }} }}];
    }}
    const stopped = await api.call(this, 'PATCH', `/timesheets/${{running.id}}`, {{ end: localNow() }});
    return [{{ json: {{ ok: true, action, stopped }} }}];
  }}

  if (action === 'start') {{
    if (running?.id) {{
      await api.call(this, 'PATCH', `/timesheets/${{running.id}}`, {{ end: localNow() }});
    }}
    const project = await findProject.call(this, body.project || body.customer || 'Cloudigan');
    if (!project?.id) {{
      return [{{ json: {{ ok: false, error: 'No Kimai project found — create one in time.cloudigan.net' }} }}];
    }}
    const activity = await findActivity.call(this, body.activity || 'General', project.id);
    if (!activity?.id) {{
      return [{{ json: {{ ok: false, error: 'No Kimai activity found for project' }} }}];
    }}
    const started = await api.call(this, 'POST', '/timesheets', {{
      project: project.id,
      activity: activity.id,
      begin: localNow(),
      description: body.description || '',
    }});
    return [{{ json: {{ ok: true, action, started, project: project.name, activity: activity.name }} }}];
  }}

  return [{{ json: {{ ok: false, error: `Unknown action: ${{action}}` }} }}];
}} catch (err) {{
  return [{{ json: {{ ok: false, error: err.message || String(err) }} }}];
}}
"""
    return {
        "name": "Ops Hub · Kimai Timer",
        "nodes": [
            {
                "parameters": {"httpMethod": "POST", "path": "ops-kimai-timer", "responseMode": "responseNode", "options": {}},
                "id": "webhook-kimai",
                "name": "Webhook - Kimai Timer",
                "type": "n8n-nodes-base.webhook",
                "typeVersion": 2,
                "position": [240, 300],
                "webhookId": "ops-kimai-timer",
            },
            {
                "parameters": {"jsCode": kimai_code},
                "id": "kimai-logic",
                "name": "Kimai Timer Logic",
                "type": "n8n-nodes-base.code",
                "typeVersion": 2,
                "position": [520, 300],
            },
            {
                "parameters": {
                    "respondWith": "json",
                    "responseBody": "={{ $json }}",
                    "options": {},
                },
                "id": "kimai-response",
                "name": "Webhook Response",
                "type": "n8n-nodes-base.respondToWebhook",
                "typeVersion": 1.1,
                "position": [760, 300],
            },
        ],
        "connections": {
            "Webhook - Kimai Timer": {"main": [[{"node": "Kimai Timer Logic", "type": "main", "index": 0}]]},
            "Kimai Timer Logic": {"main": [[{"node": "Webhook Response", "type": "main", "index": 0}]]},
        },
        "settings": {"executionOrder": "v1", "timezone": "America/New_York"},
    }


def build_ops_capture() -> dict:
    parse_code = r"""
const body = $input.first().json.body || $input.first().json;
const destinations = body.destinations || ['vikunja'];
return [{
  json: {
    title: body.title || 'Untitled',
    description: body.description || '',
    due: body.due || null,
    destinations,
    project_id: body.project_id || 1,
    kimai: body.kimai || {},
    calendar: body.calendar || 'google_personal',
    duration_minutes: body.duration_minutes || 60
  }
}];
"""
    return {
        "name": "Ops Hub · Quick Capture Router",
        "nodes": [
            {
                "parameters": {"httpMethod": "POST", "path": "ops-capture", "responseMode": "responseNode", "options": {}},
                "id": "webhook-capture",
                "name": "Webhook - Ops Capture",
                "type": "n8n-nodes-base.webhook",
                "typeVersion": 2,
                "position": [240, 300],
                "webhookId": "ops-capture",
            },
            {
                "parameters": {"jsCode": parse_code},
                "id": "parse-capture",
                "name": "Parse Capture",
                "type": "n8n-nodes-base.code",
                "typeVersion": 2,
                "position": [480, 300],
            },
            {
                "parameters": {
                    "conditions": {
                        "options": {"caseSensitive": True, "typeValidation": "loose"},
                        "conditions": [
                            {
                                "id": "has-vikunja",
                                "leftValue": "={{ $json.destinations }}",
                                "rightValue": "vikunja",
                                "operator": {"type": "array", "operation": "contains"},
                            }
                        ],
                        "combinator": "and",
                    },
                    "options": {},
                },
                "id": "if-vikunja",
                "name": "Create Vikunja Task?",
                "type": "n8n-nodes-base.if",
                "typeVersion": 2,
                "position": [720, 300],
            },
            {
                "parameters": {
                    "method": "PUT",
                    "url": "=https://tasks.cloudigan.net/api/v1/projects/{{ $json.project_id }}/tasks",
                    "authentication": "genericCredentialType",
                    "genericAuthType": "httpHeaderAuth",
                    "sendBody": True,
                    "specifyBody": "json",
                    "jsonBody": (
                        '={\n  "title": "{{ $json.title }}",\n  "description": "{{ $json.description }}",\n'
                        '  "due_date": {{ $json.due ? "\\"" + $json.due + "\\"" : "null" }}\n}'
                    ),
                    "options": {},
                },
                "id": "create-task",
                "name": "Create Vikunja Task",
                "type": "n8n-nodes-base.httpRequest",
                "typeVersion": 4.2,
                "position": [960, 220],
                "credentials": {"httpHeaderAuth": {"id": VIKUNJA_CRED, "name": "Vikunja API Token"}},
            },
            {
                "parameters": {
                    "respondWith": "json",
                    "responseBody": '={ "success": true, "results": {{ $json }} }',
                    "options": {},
                },
                "id": "capture-response",
                "name": "Webhook Response",
                "type": "n8n-nodes-base.respondToWebhook",
                "typeVersion": 1.1,
                "position": [1200, 300],
            },
            {
                "parameters": {"options": {}},
                "id": "capture-skip",
                "name": "Skip Vikunja",
                "type": "n8n-nodes-base.noOp",
                "typeVersion": 1,
                "position": [960, 420],
            },
        ],
        "connections": {
            "Webhook - Ops Capture": {"main": [[{"node": "Parse Capture", "type": "main", "index": 0}]]},
            "Parse Capture": {"main": [[{"node": "Create Vikunja Task?", "type": "main", "index": 0}]]},
            "Create Vikunja Task?": {
                "main": [[{"node": "Create Vikunja Task", "type": "main", "index": 0}], [{"node": "Skip Vikunja", "type": "main", "index": 0}]]
            },
            "Create Vikunja Task": {"main": [[{"node": "Webhook Response", "type": "main", "index": 0}]]},
            "Skip Vikunja": {"main": [[{"node": "Webhook Response", "type": "main", "index": 0}]]},
        },
        "settings": {"executionOrder": "v1", "timezone": "America/New_York"},
    }


OPS_SYNC_INTERNAL = os.environ.get("OPS_SYNC_INTERNAL_URL", "http://10.92.3.83:3002").rstrip("/")


def _ntfy_node(node_id: str, name: str, position: list[int]) -> dict:
    """HTTP node that pushes $json.{title,message,priority} to ntfy."""
    return {
        "parameters": {
            "method": "POST",
            "url": f"={NTFY_URL}/{{{{ $json.topic || '{NTFY_TOPIC}' }}}}",
            "sendHeaders": True,
            "headerParameters": {
                "parameters": [
                    {"name": "Title", "value": "={{ $json.title }}"},
                    {"name": "Priority", "value": "={{ $json.priority || '3' }}"},
                    {"name": "Click", "value": "={{ $json.click || '" + OPS_HUB_URL + "' }}"},
                ]
            },
            "sendBody": True,
            "contentType": "raw",
            "rawContentType": "text/plain",
            "body": "={{ $json.message }}",
            "options": {"timeout": 20000},
        },
        "id": node_id,
        "name": name,
        "type": "n8n-nodes-base.httpRequest",
        "typeVersion": 4.2,
        "position": position,
    }


def _if_gt_zero(node_id: str, name: str, expr: str, position: list[int]) -> dict:
    return {
        "parameters": {
            "conditions": {
                "options": {"caseSensitive": True, "leftValue": "", "typeValidation": "loose"},
                "conditions": [
                    {
                        "id": f"{node_id}-c1",
                        "leftValue": f"={{{{ {expr} }}}}",
                        "rightValue": 0,
                        "operator": {"type": "number", "operation": "gt"},
                    }
                ],
                "combinator": "and",
            },
            "options": {},
        },
        "id": node_id,
        "name": name,
        "type": "n8n-nodes-base.if",
        "typeVersion": 2,
        "position": position,
    }


def build_morning_briefing() -> dict:
    """07:00 ET: ops-sync composes the whole briefing (tasks, calendar, conflicts, Kimai, bills, optional LLM)."""
    return {
        "name": "Ops Hub · Morning Briefing",
        "nodes": [
            {
                "parameters": {"rule": {"interval": [{"field": "cronExpression", "expression": "0 7 * * *"}]}},
                "id": "schedule-briefing",
                "name": "Schedule 07:00 ET",
                "type": "n8n-nodes-base.scheduleTrigger",
                "typeVersion": 1.2,
                "position": [240, 300],
            },
            {
                "parameters": {
                    "method": "GET",
                    "url": f"{OPS_SYNC_INTERNAL}/briefing/text",
                    "options": {"timeout": 90000},
                },
                "id": "fetch-briefing",
                "name": "Compose Briefing (ops-sync)",
                "type": "n8n-nodes-base.httpRequest",
                "typeVersion": 4.2,
                "position": [480, 300],
            },
            _ntfy_node("ntfy-push", "Push ntfy", [720, 300]),
        ],
        "connections": {
            "Schedule 07:00 ET": {"main": [[{"node": "Compose Briefing (ops-sync)", "type": "main", "index": 0}]]},
            "Compose Briefing (ops-sync)": {"main": [[{"node": "Push ntfy", "type": "main", "index": 0}]]},
        },
        "settings": {
            "executionOrder": "v1",
            "timezone": "America/New_York",
            "saveExecutionProgress": True,
            "saveManualExecutions": True,
        },
    }


def build_time_gaps() -> dict:
    """17:30 (today) and 07:05 (yesterday's evening blocks): create Vikunja tasks for unlogged client time; nudge only when new tasks were created."""
    return {
        "name": "Ops Hub · Time Gaps",
        "nodes": [
            {
                "parameters": {
                    "rule": {
                        "interval": [
                            {"field": "cronExpression", "expression": "30 17 * * 1-5"},
                            {"field": "cronExpression", "expression": "5 7 * * *"},
                        ]
                    }
                },
                "id": "schedule-gaps",
                "name": "Schedule 17:30 / 07:05 ET",
                "type": "n8n-nodes-base.scheduleTrigger",
                "typeVersion": 1.2,
                "position": [240, 300],
            },
            {
                "parameters": {
                    "method": "POST",
                    "url": f"{OPS_SYNC_INTERNAL}/timelog/tasks",
                    "sendBody": True,
                    "specifyBody": "json",
                    "jsonBody": "={{ JSON.stringify({ date: $now.hour < 12 ? 'yesterday' : 'today' }) }}",
                    "options": {"timeout": 60000},
                },
                "id": "timelog-tasks",
                "name": "Analyze + Create Gap Tasks",
                "type": "n8n-nodes-base.httpRequest",
                "typeVersion": 4.2,
                "position": [480, 300],
            },
            _if_gt_zero("if-gaps", "New gap tasks?", "($json.created || []).length", [720, 300]),
            _ntfy_node("ntfy-gaps", "Push ntfy", [960, 200]),
        ],
        "connections": {
            "Schedule 17:30 / 07:05 ET": {"main": [[{"node": "Analyze + Create Gap Tasks", "type": "main", "index": 0}]]},
            "Analyze + Create Gap Tasks": {"main": [[{"node": "New gap tasks?", "type": "main", "index": 0}]]},
            "New gap tasks?": {"main": [[{"node": "Push ntfy", "type": "main", "index": 0}], []]},
        },
        "settings": {"executionOrder": "v1", "timezone": "America/New_York", "saveManualExecutions": True},
    }


def build_monthly_bills() -> dict:
    """Daily 06:00: idempotently create Vikunja tasks for bills in ops-sync/bills.json (this month + next); notify only when new tasks were created."""
    return {
        "name": "Ops Hub · Bill Reminders",
        "nodes": [
            {
                "parameters": {"rule": {"interval": [{"field": "cronExpression", "expression": "0 6 * * *"}]}},
                "id": "schedule-bills",
                "name": "Schedule 06:00 ET",
                "type": "n8n-nodes-base.scheduleTrigger",
                "typeVersion": 1.2,
                "position": [240, 300],
            },
            {
                "parameters": {
                    "method": "POST",
                    "url": f"{OPS_SYNC_INTERNAL}/bills/generate",
                    "sendBody": True,
                    "specifyBody": "json",
                    "jsonBody": "={{ JSON.stringify({}) }}",
                    "options": {"timeout": 60000},
                },
                "id": "bills-generate",
                "name": "Generate Bill Tasks",
                "type": "n8n-nodes-base.httpRequest",
                "typeVersion": 4.2,
                "position": [480, 300],
            },
            _if_gt_zero("if-bills", "New bill tasks?", "$json.createdCount", [720, 300]),
            _ntfy_node("ntfy-bills", "Push ntfy", [960, 200]),
        ],
        "connections": {
            "Schedule 06:00 ET": {"main": [[{"node": "Generate Bill Tasks", "type": "main", "index": 0}]]},
            "Generate Bill Tasks": {"main": [[{"node": "New bill tasks?", "type": "main", "index": 0}]]},
            "New bill tasks?": {"main": [[{"node": "Push ntfy", "type": "main", "index": 0}], []]},
        },
        "settings": {"executionOrder": "v1", "timezone": "America/New_York", "saveManualExecutions": True},
    }


def build_new_client() -> dict:
    """Webhook: create Kimai customer/project + Vikunja onboarding tasks via ops-sync."""
    return {
        "name": "Ops Hub · New Client",
        "nodes": [
            {
                "parameters": {"httpMethod": "POST", "path": "ops-new-client", "responseMode": "responseNode", "options": {}},
                "id": "webhook-client",
                "name": "Webhook - New Client",
                "type": "n8n-nodes-base.webhook",
                "typeVersion": 2,
                "position": [240, 300],
                "webhookId": "ops-new-client",
            },
            {
                "parameters": {
                    "method": "POST",
                    "url": f"{OPS_SYNC_INTERNAL}/clients/onboard",
                    "sendBody": True,
                    "specifyBody": "json",
                    "jsonBody": "={{ JSON.stringify($json.body || $json) }}",
                    "options": {"timeout": 90000},
                },
                "id": "onboard-client",
                "name": "Onboard Client (ops-sync)",
                "type": "n8n-nodes-base.httpRequest",
                "typeVersion": 4.2,
                "position": [480, 300],
            },
            {
                "parameters": {
                    "respondWith": "json",
                    "responseBody": "={{ $json }}",
                    "options": {},
                },
                "id": "client-response",
                "name": "Webhook Response",
                "type": "n8n-nodes-base.respondToWebhook",
                "typeVersion": 1.1,
                "position": [720, 300],
            },
            _if_gt_zero("if-client-tasks", "Seeded tasks?", "$json.taskCount", [720, 480]),
            _ntfy_node("ntfy-client", "Push ntfy", [960, 480]),
        ],
        "connections": {
            "Webhook - New Client": {"main": [[{"node": "Onboard Client (ops-sync)", "type": "main", "index": 0}]]},
            "Onboard Client (ops-sync)": {
                "main": [
                    [
                        {"node": "Webhook Response", "type": "main", "index": 0},
                        {"node": "Seeded tasks?", "type": "main", "index": 0},
                    ]
                ]
            },
            "Seeded tasks?": {"main": [[{"node": "Push ntfy", "type": "main", "index": 0}], []]},
        },
        "settings": {"executionOrder": "v1", "timezone": "America/New_York", "saveManualExecutions": True},
    }


def build_alert_healer() -> dict:
    """Every 10 min: close Vikunja + Zammad alert tickets whose Prometheus alert is no longer firing."""
    return {
        "name": "Ops Hub · Alert Healer",
        "nodes": [
            {
                "parameters": {"rule": {"interval": [{"field": "minutes", "minutesInterval": 10}]}},
                "id": "schedule-heal",
                "name": "Every 10 min",
                "type": "n8n-nodes-base.scheduleTrigger",
                "typeVersion": 1.2,
                "position": [240, 300],
            },
            {
                "parameters": {
                    "method": "POST",
                    "url": f"{OPS_SYNC_INTERNAL}/alerts/heal",
                    "sendBody": True,
                    "specifyBody": "json",
                    "jsonBody": "={{ JSON.stringify({}) }}",
                    "options": {"timeout": 90000},
                },
                "id": "heal-alerts",
                "name": "Heal Recovered Alerts",
                "type": "n8n-nodes-base.httpRequest",
                "typeVersion": 4.2,
                "position": [480, 300],
            },
            _if_gt_zero("if-healed", "Closed anything?", "$json.createdCount", [720, 300]),
            _ntfy_node("ntfy-heal", "Push ntfy", [960, 200]),
        ],
        "connections": {
            "Every 10 min": {"main": [[{"node": "Heal Recovered Alerts", "type": "main", "index": 0}]]},
            "Heal Recovered Alerts": {"main": [[{"node": "Closed anything?", "type": "main", "index": 0}]]},
            "Closed anything?": {"main": [[{"node": "Push ntfy", "type": "main", "index": 0}], []]},
        },
        "settings": {"executionOrder": "v1", "timezone": "America/New_York", "saveManualExecutions": True},
    }


def build_quota_alerts() -> dict:
    """Weekday 08:00: ntfy when a client is at/over purchased hours (snoozed 3 days per level)."""
    return {
        "name": "Ops Hub · Hours Quota",
        "nodes": [
            {
                "parameters": {"rule": {"interval": [{"field": "cronExpression", "expression": "0 8 * * 1-5"}]}},
                "id": "schedule-quotas",
                "name": "Schedule 08:00 ET weekdays",
                "type": "n8n-nodes-base.scheduleTrigger",
                "typeVersion": 1.2,
                "position": [240, 300],
            },
            {
                "parameters": {
                    "method": "POST",
                    "url": f"{OPS_SYNC_INTERNAL}/quotas/alerts",
                    "sendBody": True,
                    "specifyBody": "json",
                    "jsonBody": "={{ JSON.stringify({}) }}",
                    "options": {"timeout": 60000},
                },
                "id": "quota-alerts",
                "name": "Check Hour Quotas",
                "type": "n8n-nodes-base.httpRequest",
                "typeVersion": 4.2,
                "position": [480, 300],
            },
            _if_gt_zero("if-quotas", "Fresh alerts?", "$json.freshCount", [720, 300]),
            _ntfy_node("ntfy-quotas", "Push ntfy", [960, 200]),
        ],
        "connections": {
            "Schedule 08:00 ET weekdays": {"main": [[{"node": "Check Hour Quotas", "type": "main", "index": 0}]]},
            "Check Hour Quotas": {"main": [[{"node": "Fresh alerts?", "type": "main", "index": 0}]]},
            "Fresh alerts?": {"main": [[{"node": "Push ntfy", "type": "main", "index": 0}], []]},
        },
        "settings": {"executionOrder": "v1", "timezone": "America/New_York", "saveManualExecutions": True},
    }


def configure_vikunja_webhook() -> None:
    """Register Vikunja Inbox webhook → n8n (requires VIKUNJA_API_TOKEN)."""
    token = os.environ.get("VIKUNJA_API_TOKEN", "")
    if not token:
        print("  ⚠ VIKUNJA_API_TOKEN not set — skip Vikunja webhook registration")
        return
    base = os.environ.get("VIKUNJA_API_URL", "https://tasks.cloudigan.net/api/v1").rstrip("/")
    webhook_url = "https://flows.cloudigan.net/webhook/vikunja-task-updated"
    payload = {
        "target_url": webhook_url,
        "events": ["task.updated"],
    }
    req = urllib.request.Request(
        f"{base}/projects/1/webhooks",
        data=json.dumps(payload).encode(),
        method="PUT",
        headers={
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json",
            "Accept": "application/json",
        },
    )
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            result = json.loads(resp.read())
            print(f"  ✓ Vikunja Inbox webhook → {webhook_url} (id={result.get('id')})")
    except urllib.error.HTTPError as exc:
        print(f"  ⚠ Vikunja webhook registration failed ({exc.code}): {exc.read().decode()[:200]}")


def main() -> None:
    if not TOKEN:
        print("N8N_API_TOKEN required in environment", file=sys.stderr)
        sys.exit(1)

    ids = load_ids()
    print("Deploying Ops Hub n8n workflows…")

    # Update existing Zammad → Vikunja workflow
    api("PUT", f"workflows/{ZAMMAD_CREATE_WF}", build_zammad_vikunja_create())
    api("POST", f"workflows/{ZAMMAD_CREATE_WF}/activate", {})
    print(f"  ✓ Zammad → Vikunja Task Creation ({ZAMMAD_CREATE_WF}) — updated with metadata")

    upsert_workflow("vikunja_zammad_close", build_vikunja_zammad_close, ids)
    upsert_workflow("zammad_vikunja_close", build_zammad_vikunja_close, ids)
    upsert_workflow("ops_capture", build_ops_capture, ids)
    upsert_workflow("morning_briefing", build_morning_briefing, ids)
    upsert_workflow("time_gaps", build_time_gaps, ids)
    upsert_workflow("monthly_bills", build_monthly_bills, ids)
    upsert_workflow("new_client", build_new_client, ids)
    upsert_workflow("quota_alerts", build_quota_alerts, ids)
    upsert_workflow("alert_healer", build_alert_healer, ids)
    # Kimai timer needs Kimai credential in n8n — deploy skeleton only
    if os.environ.get("KIMAI_API_TOKEN"):
        upsert_workflow("kimai_timer", build_kimai_timer, ids)
    else:
        print("  ⚠ KIMAI_API_TOKEN not set — skip Kimai timer workflow (add token then re-run)")

    save_ids(ids)
    configure_vikunja_webhook()
    print("\nDone. Webhooks:")
    print("  POST https://flows.cloudigan.net/webhook/vikunja-task-updated")
    print("  POST https://flows.cloudigan.net/webhook/zammad-ticket-closed  (configure Zammad trigger)")
    print("  POST https://flows.cloudigan.net/webhook/ops-capture")
    print("  POST https://flows.cloudigan.net/webhook/ops-kimai-timer")
    print("  POST https://flows.cloudigan.net/webhook/ops-new-client")


if __name__ == "__main__":
    main()
