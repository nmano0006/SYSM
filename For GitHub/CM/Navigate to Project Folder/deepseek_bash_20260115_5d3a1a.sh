# Look for Info.plist in the source directory (not in Products/)
find /Users/z790/Desktop/SystemMaintenanceMac/SystemMaintenance -name "Info.plist" -type f \
  | grep -v "Products" | grep -v "ContentView"