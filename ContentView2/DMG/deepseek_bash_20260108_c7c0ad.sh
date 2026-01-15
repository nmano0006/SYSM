#!/bin/bash
APP_NAME="SystemMaintenance"
APP_PATH="./build/MyApp.app"
DMG_PATH="./dist/${APP_NAME}.dmg"
VOLUME_NAME="${APP_NAME}"
BACKGROUND_IMG="./resources/dmg-background.png"

# Create distribution directory
mkdir -p ./dist

# Create DMG using create-dmg
create-dmg \
  --volname "${VOLUME_NAME}" \
  --background "${BACKGROUND_IMG}" \
  --window-size 800 400 \
  --icon-size 100 \
  --icon "${APP_NAME}.app" 200 190 \
  --hide-extension "${APP_NAME}.app" \
  --app-drop-link 600 185 \
  "${DMG_PATH}" \
  "${APP_PATH}"

echo "DMG created at: ${DMG_PATH}"
