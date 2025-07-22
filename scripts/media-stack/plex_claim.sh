#!/bin/bash
# Automated Plex Server Claim Script

echo "=== Plex Server Claim Script ==="
echo ""

# Check if claim token was provided
if [ -z "$1" ]; then
    echo "❌ Error: No claim token provided"
    echo ""
    echo "Usage: $0 <claim_token>"
    echo ""
    echo "Steps:"
    echo "1. Go to: https://plex.tv/claim"
    echo "2. Copy the claim token"
    echo "3. Run: $0 claim-xxxxxxxxxxxxxxxxxx"
    echo ""
    exit 1
fi

CLAIM_TOKEN="$1"
PLEX_SERVER="10.92.3.17:32400"

echo "🎯 Attempting to claim Plex server..."
echo "Server: $PLEX_SERVER"
echo "Token: ${CLAIM_TOKEN:0:10}..."
echo ""

# Test server connectivity first
echo "Testing server connectivity..."
if curl -s --connect-timeout 5 "http://$PLEX_SERVER/identity" >/dev/null; then
    echo "✅ Server is accessible"
else
    echo "❌ Cannot connect to Plex server at $PLEX_SERVER"
    exit 1
fi

echo ""
echo "Claiming server..."

# Attempt to claim the server
RESPONSE=$(curl -s -X POST "http://$PLEX_SERVER/myplex/claim?token=$CLAIM_TOKEN" 2>&1)
CURL_EXIT_CODE=$?

echo ""
echo "=== Claim Response ==="
echo "$RESPONSE"
echo ""

# Check if claim was successful
if [ $CURL_EXIT_CODE -eq 0 ]; then
    echo "✅ Claim command executed successfully"
    
    # Wait a moment and check server status
    echo "Waiting for server to update..."
    sleep 5
    
    echo "Checking server claim status..."
    SERVER_STATUS=$(curl -s "http://$PLEX_SERVER/identity" 2>/dev/null)
    
    if echo "$SERVER_STATUS" | grep -q 'claimed="1"'; then
        echo "🎉 SUCCESS! Server has been claimed!"
        echo ""
        echo "✅ Your Plex server is now claimed and should appear in your account"
        echo "✅ Access it at: http://$PLEX_SERVER/web"
        echo "✅ It should now show as 'allens_media' in your Plex apps"
        echo ""
        echo "Next steps:"
        echo "1. Check your Plex app - 'allens_media' should be back online"
        echo "2. Verify your libraries are there"
        echo "3. Test media playback"
    elif echo "$SERVER_STATUS" | grep -q 'claimed="0"'; then
        echo "⚠️  Server responded but is still unclaimed"
        echo "This might mean:"
        echo "- The claim token expired (get a fresh one)"
        echo "- There was a network issue during claiming"
        echo "- The token format was incorrect"
        echo ""
        echo "Try getting a fresh token from https://plex.tv/claim and run again"
    else
        echo "❓ Cannot determine claim status"
        echo "Server response: $SERVER_STATUS"
    fi
else
    echo "❌ Claim command failed with exit code: $CURL_EXIT_CODE"
    echo "Response: $RESPONSE"
fi

echo ""
echo "=== Claim Attempt Complete ==="
