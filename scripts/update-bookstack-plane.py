#!/usr/bin/env python3
"""
Update BookStack with Plane Project Management documentation.
Uses urllib (built-in) to avoid external dependencies.
"""
import urllib.request
import json
import sys

def update_bookstack():
    # Read the markdown content
    try:
        with open('/tmp/plane-kb-updated.md', 'r') as f:
            markdown_content = f.read()
    except FileNotFoundError:
        print("❌ Error: /tmp/plane-kb-updated.md not found")
        sys.exit(1)
    
    # BookStack API details
    api_url = "https://kb.cloudigan.net/api/pages"
    token_id = "57ScUrLRW80LzpCnBSSvwKfetq2QE2US"
    token_secret = "aiM8NyBwlcuezst1znCPlPuGb79FiXvH"
    
    # Prepare the request
    payload = {
        "book_id": 22,  # MSP Platform Services
        "name": "Plane Project Management",
        "markdown": markdown_content
    }
    
    data = json.dumps(payload).encode('utf-8')
    req = urllib.request.Request(api_url, data=data, method='POST')
    req.add_header('Authorization', f'Token {token_id}:{token_secret}')
    req.add_header('Content-Type', 'application/json')
    
    print("📚 Updating BookStack with Plane documentation...")
    print(f"   Content length: {len(markdown_content)} characters")
    
    try:
        with urllib.request.urlopen(req) as response:
            result = json.loads(response.read().decode('utf-8'))
            print(f"\n✅ Success! Page created in BookStack")
            print(f"   Page ID: {result.get('id')}")
            print(f"   Page Name: {result.get('name')}")
            if 'url' in result:
                print(f"   URL: https://kb.cloudigan.net{result.get('url')}")
            return 0
    except urllib.error.HTTPError as e:
        error_body = e.read().decode('utf-8')
        print(f"\n❌ HTTP Error {e.code}")
        try:
            error_json = json.loads(error_body)
            print(f"   Message: {error_json.get('message', 'Unknown error')}")
            if 'error' in error_json:
                print(f"   Details: {error_json['error']}")
        except:
            print(f"   Response: {error_body}")
        return 1
    except Exception as e:
        print(f"\n❌ Error: {str(e)}")
        return 1

if __name__ == "__main__":
    sys.exit(update_bookstack())
