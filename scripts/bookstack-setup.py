#!/usr/bin/env python3
"""
BookStack Structure Setup Script
Creates shelves, books, and pages for Cloudigan knowledge base
"""

import requests
import json
import time

# BookStack API configuration
BOOKSTACK_URL = "https://kb.cloudigan.net"
TOKEN_ID = "57ScUrLRW80LzpCnBSSvwKfetq2QE2US"
TOKEN_SECRET = "aiM8NyBwlcuezst1znCPlPuGb79FiXvH"

headers = {
    "Authorization": f"Token {TOKEN_ID}:{TOKEN_SECRET}",
    "Content-Type": "application/json"
}

def create_page(book_id, name, html_content):
    """Create a page in BookStack"""
    url = f"{BOOKSTACK_URL}/api/pages"
    data = {
        "book_id": book_id,
        "name": name,
        "html": html_content
    }
    response = requests.post(url, headers=headers, json=data)
    if response.status_code in [200, 201]:
        print(f"✓ Created page: {name}")
        return response.json()
    else:
        print(f"✗ Failed to create page {name}: {response.text}")
        return None

def update_shelf(shelf_id, book_ids):
    """Add books to a shelf"""
    url = f"{BOOKSTACK_URL}/api/shelves/{shelf_id}"
    data = {
        "name": "Internal Operations",
        "description_html": "<p>Internal documentation for Cloudigan infrastructure, services, and operational procedures.</p>",
        "books": book_ids
    }
    response = requests.put(url, headers=headers, json=data)
    if response.status_code == 200:
        print(f"✓ Updated shelf with books: {book_ids}")
        return response.json()
    else:
        print(f"✗ Failed to update shelf: {response.text}")
        return None

def create_book(name, description):
    """Create a book in BookStack"""
    url = f"{BOOKSTACK_URL}/api/books"
    data = {
        "name": name,
        "description_html": f"<p>{description}</p>"
    }
    response = requests.post(url, headers=headers, json=data)
    if response.status_code in [200, 201]:
        print(f"✓ Created book: {name}")
        return response.json()
    else:
        print(f"✗ Failed to create book {name}: {response.text}")
        return None

def create_shelf(name, description):
    """Create a shelf in BookStack"""
    url = f"{BOOKSTACK_URL}/api/shelves"
    data = {
        "name": name,
        "description_html": f"<p>{description}</p>"
    }
    response = requests.post(url, headers=headers, json=data)
    if response.status_code in [200, 201]:
        print(f"✓ Created shelf: {name}")
        return response.json()
    else:
        print(f"✗ Failed to create shelf {name}: {response.text}")
        return None

# Main setup
print("Setting up BookStack structure...\n")

# Add Container Inventory page to Infrastructure Documentation (book 15)
container_inventory_html = """
<h1>Container Inventory</h1>
<p>Complete list of all Proxmox LXC containers in the Cloudigan infrastructure.</p>

<h2>Production Applications</h2>
<table>
<tr><th>Name</th><th>CTID</th><th>IP</th><th>Purpose</th></tr>
<tr><td>ldc-prod</td><td>133</td><td>10.92.3.x</td><td>LDC Tools Production</td></tr>
<tr><td>ldc-staging</td><td>135</td><td>10.92.3.x</td><td>LDC Tools Staging</td></tr>
<tr><td>theoshift-blue</td><td>134</td><td>10.92.3.24</td><td>TheoShift Blue</td></tr>
<tr><td>theoshift-green</td><td>132</td><td>10.92.3.22</td><td>TheoShift Green</td></tr>
<tr><td>quantshift-blue</td><td>137</td><td>10.92.3.29</td><td>QuantShift Web Blue</td></tr>
<tr><td>quantshift-green</td><td>138</td><td>10.92.3.30</td><td>QuantShift Web Green</td></tr>
<tr><td>quantshift-bot-primary</td><td>100</td><td>10.92.3.27</td><td>Trading Bot Primary</td></tr>
<tr><td>quantshift-bot-standby</td><td>101</td><td>10.92.3.28</td><td>Trading Bot Standby</td></tr>
</table>

<h2>Infrastructure Services</h2>
<table>
<tr><th>Name</th><th>CTID</th><th>IP</th><th>Purpose</th></tr>
<tr><td>monitoring-stack</td><td>150</td><td>10.92.3.2</td><td>Grafana, Prometheus, Loki, Uptime Kuma</td></tr>
<tr><td>nginx-proxy</td><td>121</td><td>10.92.3.3</td><td>NPM Reverse Proxy (Debian 13, v2.14.0)</td></tr>
<tr><td>netbox</td><td>118</td><td>10.92.3.18</td><td>IPAM & DCIM</td></tr>
<tr><td>bookstack</td><td>130</td><td>10.92.3.50</td><td>Knowledge Base (this system)</td></tr>
<tr><td>ansible</td><td>190</td><td>10.92.3.90</td><td>Semaphore Automation Platform</td></tr>
<tr><td>postgresql</td><td>131</td><td>10.92.3.21</td><td>PostgreSQL 17 Primary</td></tr>
<tr><td>postgres-replica</td><td>151</td><td>10.92.3.31</td><td>PostgreSQL 17 Replica</td></tr>
<tr><td>haproxy</td><td>136</td><td>10.92.3.26</td><td>HAProxy MASTER (VIP 10.92.3.33)</td></tr>
<tr><td>haproxy-standby</td><td>139</td><td>10.92.3.32</td><td>HAProxy BACKUP</td></tr>
</table>
"""

create_page(15, "Container Inventory", container_inventory_html)
time.sleep(1)

# Add PostgreSQL HA page to Service Runbooks (book 17)
postgresql_html = """
<h1>PostgreSQL High Availability Setup</h1>

<h2>Overview</h2>
<p>PostgreSQL 17 streaming replication with Prometheus-based automatic failover.</p>

<h2>Architecture</h2>
<ul>
<li><strong>Primary:</strong> CT131 (postgresql @ 10.92.3.21)</li>
<li><strong>Replica:</strong> CT151 (postgres-replica @ 10.92.3.31)</li>
<li><strong>Replication:</strong> Streaming async, sub-millisecond lag</li>
<li><strong>Failover Time:</strong> ~30 seconds</li>
</ul>

<h2>Databases</h2>
<ul>
<li>ldc_tools</li>
<li>theoshift_scheduler</li>
<li>quantshift</li>
<li>bni_toolkit</li>
<li>netbox</li>
<li>bookstack</li>
</ul>

<h2>Failover Process</h2>
<ol>
<li>Prometheus detects CT131 down (postgres_up == 0)</li>
<li>Alertmanager triggers webhook to CT150</li>
<li>Webhook receiver calls Semaphore playbook</li>
<li>Ansible promotes CT151 to primary via pg_ctl promote</li>
<li>Applications reconnect automatically</li>
</ol>

<h2>Monitoring</h2>
<ul>
<li><strong>Exporter:</strong> postgres_exporter on CT131:9187</li>
<li><strong>Metrics:</strong> Scraped by Prometheus every 15s</li>
<li><strong>Alerts:</strong> Defined in homelab.yml</li>
</ul>
"""

create_page(17, "PostgreSQL HA Setup", postgresql_html)
time.sleep(1)

# Create Standards & Conventions book
standards_book = create_book("Standards & Conventions", "Infrastructure standards, naming conventions, and deployment procedures")
if standards_book:
    time.sleep(1)
    
    # Add Container Naming Standard page
    naming_html = """
<h1>Container Naming Standard</h1>

<h2>Naming Convention</h2>
<p><code>{function}-{role}[-{instance}]</code></p>

<h2>CTID Ranges by Function</h2>
<table>
<tr><th>Function</th><th>CTID Range</th><th>Description</th></tr>
<tr><td>bot</td><td>100-109</td><td>Bot & automation containers</td></tr>
<tr><td>dev</td><td>110-119</td><td>Development & testing</td></tr>
<tr><td>media</td><td>120-129</td><td>Media management stack</td></tr>
<tr><td>core</td><td>130-139</td><td>Core infrastructure</td></tr>
<tr><td>network</td><td>140-149</td><td>Network & proxy services</td></tr>
<tr><td>monitoring</td><td>150-159</td><td>Monitoring & observability</td></tr>
<tr><td>storage</td><td>160-169</td><td>Storage & backup</td></tr>
<tr><td>security</td><td>170-179</td><td>Security & access</td></tr>
<tr><td>utility</td><td>180-189</td><td>Utility services</td></tr>
<tr><td>automation</td><td>190-199</td><td>Automation platforms</td></tr>
</table>

<h2>Examples</h2>
<ul>
<li><code>quantshift-bot-primary</code> (CT100)</li>
<li><code>bni-toolkit-dev</code> (CT119)</li>
<li><code>nginx-proxy</code> (CT121)</li>
<li><code>bookstack</code> (CT130)</li>
<li><code>monitoring-stack</code> (CT150)</li>
<li><code>ansible</code> (CT190)</li>
</ul>
"""
    
    create_page(standards_book['id'], "Container Naming Standard", naming_html)
    time.sleep(1)

# Update shelf to include all books
update_shelf(14, [15, 17, standards_book['id'] if standards_book else 0])

print("\n✅ BookStack structure setup complete!")
print(f"\nView at: {BOOKSTACK_URL}")
