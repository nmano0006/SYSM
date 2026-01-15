#!/bin/bash

TOKEN="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"
DMG_PATH="/Users/z790/Desktop/SystemMaintenanceMac/SystemMaintenance/Products/SystemMaintenance.dmg"

echo "🚀 Creating release v1.0.0..."

# Create release
RESPONSE=$(curl -s -X POST \
  -H "Authorization: token $TOKEN" \
  -H "Accept: application/vnd.github.v3+json" \
  https://api.github.com/repos/nmano0006/SYSM/releases \
  -d '{
    "tag_name": "v1.0.0",
    "name": "SYSM v1.0.0",
    "body": "SYSM macOS System Maintenance Tool",
    "draft": false,
    "prerelease": false
  }')

echo "📦 Response received"

# Extract upload URL from response
UPLOAD_URL=$(echo "$RESPONSE" | grep -o '"upload_url":"[^"]*"' | head -1 | sed 's/"upload_url":"//' | sed 's/"//' | sed 's/{.*}//')

if [ -z "$UPLOAD_URL" ]; then
  echo "❌ Failed to create release or get upload URL"
  echo "Response: $RESPONSE"
  exit 1
fi

echo "✅ Release created! Upload URL: $UPLOAD_URL"
echo "📤 Uploading DMG file..."

# Upload DMG
UPLOAD_RESULT=$(curl -s -X POST \
  -H "Authorization: token $TOKEN" \
  -H "Content-Type: application/octet-stream" \
  -H "Accept: application/vnd.github.v3+json" \
  --data-binary @"$DMG_PATH" \
  "${UPLOAD_URL}?name=SYSM.dmg")

if echo "$UPLOAD_RESULT" | grep -q '"state":"uploaded"'; then
  echo "🎉 SUCCESS! DMG uploaded!"
  echo "🔗 Download URL: https://github.com/nmano0006/SYSM/releases/download/v1.0.0/SYSM.dmg"
else
  echo "❌ Upload failed"
  echo "Response: $UPLOAD_RESULT"
fi