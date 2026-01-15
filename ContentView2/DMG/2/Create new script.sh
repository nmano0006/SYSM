cat > create_dmg.sh << 'EOF'
#!/usr/bin/env bash

# Configuration
APP_NAME="SystemMaintenance"
APP_PATH="/Users/z790/Desktop/SystemMaintenanceMac/SystemMaintenance/Products/Debug/SystemMaintenance.app"
OUTPUT_DIR="/Users/z790/Desktop"
DMG_NAME="${APP_NAME}.dmg"

# Check if create-dmg is installed
if ! command -v create-dmg &> /dev/null; then
    echo "Installing create-dmg..."
    brew install create-dmg
fi

# Create DMG
create-dmg \
    --volname "System Maintenance" \
    --window-pos 200 120 \
    --window-size 800 400 \
    --icon-size 100 \
    --icon "${APP_NAME}.app" 200 190 \
    --hide-extension "${APP_NAME}.app" \
    --app-drop-link 600 185 \
    --no-internet-enable \
    "${OUTPUT_DIR}/${DMG_NAME}" \
    "${APP_PATH}"

echo "✅ DMG created: ${OUTPUT_DIR}/${DMG_NAME}"
EOF