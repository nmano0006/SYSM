#!/bin/bash

# Complete GitHub Release for SYSM v1.0.1
cd /Users/z790/Desktop/SystemMaintenanceMac/SystemMaintenance

echo "=== Releasing SYSM v1.0.1 to GitHub ==="
echo ""

# Check current status
echo "1. Checking Git status..."
git status

echo ""
echo "2. Adding all changes..."
git add .

echo ""
echo "3. Committing v1.0.1..."
git commit -m "Release v1.0.1

- Updated version from 1.0 to 1.0.1
- Bug fixes and improvements
- Performance enhancements
- Updated documentation"

echo ""
echo "4. Pushing to main branch..."
git push origin main

echo ""
echo "5. Creating and pushing tag v1.0.1..."
git tag -a "v1.0.1" -m "System Maintenance Tool v1.0.1

Release Highlights:
- Enhanced system monitoring
- Improved user interface
- Better error handling
- Performance optimizations

System Requirements:
- macOS 10.15 or later
- 64-bit processor"

git push origin v1.0.1

echo ""
echo "=== Git operations completed successfully! ==="