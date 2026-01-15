# Check current version
/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" \
  SystemMaintenance/Info.plist

# Update to v1.0.1
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString 1.0.1" \
  SystemMaintenance/Info.plist

# Update build number (increment by 1)
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion 2" \
  SystemMaintenance/Info.plist