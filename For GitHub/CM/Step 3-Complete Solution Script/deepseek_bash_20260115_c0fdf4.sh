#!/bin/bash

cd /Users/z790/Desktop/SystemMaintenanceMac/SystemMaintenance
TOKEN="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"
REPO_URL="https://${TOKEN}@github.com/nmano0006/SYSM.git"

echo "=== Handling GitHub Sync ==="
echo ""

# 1. First, try to pull
echo "1. Pulling from GitHub..."
if git pull $REPO_URL main --allow-unrelated-histories; then
    echo "✓ Pull successful"
else
    echo "⚠ Pull had conflicts, continuing..."
fi

echo ""

# 2. Add all local changes
echo "2. Adding local files..."
git add .

echo ""

# 3. Commit
echo "3. Committing v1.0.1..."
git commit -m "SYSM v1.0.1 Release

Version: 1.0.1
Date: $(date +%Y-%m-%d)

Features:
- System monitoring tools
- Drive management
- Kext management
- Hex/Base64 calculator"

echo ""

# 4. Force push (overwrite remote)
echo "4. Pushing to GitHub (overwrites remote)..."
git push --force $REPO_URL main

echo ""

# 5. Create tag
echo "5. Creating and pushing tag v1.0.1..."
git tag -f v1.0.1 -m "SYSM v1.0.1 Release"
git push --force $REPO_URL v1.0.1

echo ""
echo "=== SUCCESS ==="
echo "Repository updated: https://github.com/nmano0006/SYSM"
echo "Tag created: v1.0.1"
echo ""
echo "Now create release at: https://github.com/nmano0006/SYSM/releases/new"