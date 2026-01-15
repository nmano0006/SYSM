# Find the built app
APP_PATH=$(find /Users/z790/Desktop/SystemMaintenanceMac -name "SystemMaintenance.app" -type d 2>/dev/null | grep -v "test-" | head -1)

if [ -n "$APP_PATH" ]; then
    echo "Found app at: $APP_PATH"
    echo "Version:"
    /usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$APP_PATH/Contents/Info.plist"
    echo "Build:"
    /usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$APP_PATH/Contents/Info.plist"
else
    echo "App not found yet. Did you build it in Xcode?"
fi