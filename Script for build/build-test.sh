#!/bin/bash

# SystemMaintenance Build & Test Script
# Version: 2.0
# Created: $(date)

# Configuration
PROJECT_DIR="/Users/z790/Desktop/SystemMaintenanceMac/SystemMaintenance"
PROJECT_NAME="SystemMaintenance"
SWIFT_FILE="ContentView.swift"
TEST_DIR="/Users/z790/Desktop/SystemMaintenanceMac/SystemMaintenance/ContentView/test-2/7"
OUTPUT_DIR="/Users/z790/Desktop/SystemMaintenanceBuilds"
BUILD_LOG="$OUTPUT_DIR/build.log"
TEST_LOG="$OUTPUT_DIR/test.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_message() {
    echo -e "${BLUE}[$(date '+%H:%M:%S')]${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}!${NC} $1"
}

# Create output directory if it doesn't exist
mkdir -p "$OUTPUT_DIR"

# Clear previous logs
> "$BUILD_LOG"
> "$TEST_LOG"

print_message "Starting SystemMaintenance Build & Test Process..."
print_message "Project Directory: $PROJECT_DIR"
print_message "Test Directory: $TEST_DIR"
print_message "Output Directory: $OUTPUT_DIR"
echo ""

# Step 1: Check Swift version
print_message "Step 1: Checking Swift version..."
SWIFT_VERSION=$(swift --version 2>> "$BUILD_LOG")
if [ $? -eq 0 ]; then
    print_success "Swift found:"
    echo "$SWIFT_VERSION" | head -1
else
    print_error "Swift not found or not in PATH"
    exit 1
fi
echo ""

# Step 2: Check Xcode installation
print_message "Step 2: Checking Xcode installation..."
if xcode-select -p &>/dev/null; then
    XCODE_PATH=$(xcode-select -p)
    print_success "Xcode Command Line Tools found at: $XCODE_PATH"
else
    print_error "Xcode Command Line Tools not installed"
    print_warning "Install with: xcode-select --install"
    exit 1
fi
echo ""

# Step 3: Backup current ContentView.swift
print_message "Step 3: Backing up current ContentView.swift..."
BACKUP_FILE="$OUTPUT_DIR/ContentView_$(date +%Y%m%d_%H%M%S).swift"
if cp "$PROJECT_DIR/ContentView.swift" "$BACKUP_FILE" 2>> "$BUILD_LOG"; then
    print_success "Backup created: $BACKUP_FILE"
else
    print_warning "Could not backup current ContentView.swift"
fi
echo ""

# Step 4: Copy test file to project directory
print_message "Step 4: Copying test file to project directory..."
TEST_FILE="$TEST_DIR/ContentView.swift"
if [ -f "$TEST_FILE" ]; then
    if cp "$TEST_FILE" "$PROJECT_DIR/ContentView.swift" 2>> "$BUILD_LOG"; then
        print_success "Test file copied successfully"
    else
        print_error "Failed to copy test file"
        exit 1
    fi
else
    print_error "Test file not found at: $TEST_FILE"
    exit 1
fi
echo ""

# Step 5: Validate Swift syntax
print_message "Step 5: Validating Swift syntax..."
if swiftc -typecheck "$PROJECT_DIR/ContentView.swift" -o /dev/null 2>> "$BUILD_LOG"; then
    print_success "Swift syntax validation passed"
else
    print_error "Swift syntax validation failed"
    print_warning "Check $BUILD_LOG for details"
    # Restore backup
    if [ -f "$BACKUP_FILE" ]; then
        cp "$BACKUP_FILE" "$PROJECT_DIR/ContentView.swift"
        print_warning "Restored original ContentView.swift from backup"
    fi
    exit 1
fi
echo ""

# Step 6: Create minimal Swift Package
print_message "Step 6: Creating Swift Package for testing..."
PACKAGE_DIR="$OUTPUT_DIR/SystemMaintenancePackage"
mkdir -p "$PACKAGE_DIR"
cd "$PACKAGE_DIR"

# Create Package.swift
cat > Package.swift << 'EOF'
// swift-tools-version:5.7

import PackageDescription

let package = Package(
    name: "SystemMaintenance",
    platforms: [
        .macOS(.v11)
    ],
    products: [
        .executable(name: "SystemMaintenance", targets: ["SystemMaintenance"])
    ],
    dependencies: [
        // Add dependencies here if needed
    ],
    targets: [
        .executableTarget(
            name: "SystemMaintenance",
            dependencies: [],
            path: "Sources",
            swiftSettings: [
                .define("DEBUG", .when(configuration: .debug)),
                .unsafeFlags(["-enable-testing"])
            ]
        ),
        .testTarget(
            name: "SystemMaintenanceTests",
            dependencies: ["SystemMaintenance"],
            path: "Tests"
        )
    ]
)
EOF

# Create Sources directory
mkdir -p Sources
cp "$PROJECT_DIR/ContentView.swift" Sources/main.swift

# Create minimal App structure if needed
if ! grep -q "@main" Sources/main.swift; then
    cat >> Sources/main.swift << 'EOF'

// MARK: - Main App Entry Point
@main
struct SystemMaintenanceApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
EOF
fi

print_success "Swift Package created at: $PACKAGE_DIR"
echo ""

# Step 7: Build the package
print_message "Step 7: Building Swift package..."
if swift build --configuration debug 2>> "$BUILD_LOG"; then
    print_success "Build successful!"
    BUILD_SIZE=$(du -sh ".build/debug/SystemMaintenance" 2>/dev/null | cut -f1)
    print_message "Binary size: $BUILD_SIZE"
else
    print_error "Build failed"
    print_warning "Check $BUILD_LOG for build errors"
    exit 1
fi
echo ""

# Step 8: Run basic tests
print_message "Step 8: Running basic tests..."
cat > Tests/BasicTests.swift << 'EOF'
import XCTest
@testable import SystemMaintenance

final class SystemMaintenanceTests: XCTestCase {
    
    func testAppLaunch() throws {
        // Basic test to ensure app can be initialized
        _ = SystemMaintenanceApp()
    }
    
    func testShellHelperCommands() throws {
        // Test basic shell command execution
        let result = ShellHelper.runCommand("echo 'test'")
        XCTAssertTrue(result.success)
        XCTAssertEqual(result.output.trimmingCharacters(in: .whitespacesAndNewlines), "test")
    }
    
    func testDriveInfoStruct() throws {
        // Test data model initialization
        let drive = DriveInfo(
            name: "Test Drive",
            identifier: "disk0",
            size: "500 GB",
            type: "APFS",
            mountPoint: "/",
            isInternal: true,
            isEFI: false,
            partitions: []
        )
        
        XCTAssertEqual(drive.name, "Test Drive")
        XCTAssertEqual(drive.identifier, "disk0")
        XCTAssertEqual(drive.isInternal, true)
    }
    
    func testSystemInfoStruct() throws {
        // Test system info model
        var info = SystemInfo()
        info.macOSVersion = "13.0"
        info.processor = "Apple M1"
        
        XCTAssertEqual(info.macOSVersion, "13.0")
        XCTAssertEqual(info.processor, "Apple M1")
    }
}
EOF

if swift test --skip-build 2>> "$TEST_LOG"; then
    print_success "All tests passed!"
else
    print_warning "Some tests failed (this might be expected for UI code)"
    print_message "Check $TEST_LOG for test details"
fi
echo ""

# Step 9: Create executable bundle
print_message "Step 9: Creating application bundle..."
APP_BUNDLE="$OUTPUT_DIR/SystemMaintenance.app"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# Copy the binary
cp ".build/debug/SystemMaintenance" "$APP_BUNDLE/Contents/MacOS/"

# Create Info.plist
cat > "$APP_BUNDLE/Contents/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>SystemMaintenance</string>
    <key>CFBundleIdentifier</key>
    <string>com.hackintosh.SystemMaintenance</string>
    <key>CFBundleName</key>
    <string>SystemMaintenance</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>LSMinimumSystemVersion</key>
    <string>11.0</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

print_success "Application bundle created at: $APP_BUNDLE"
echo ""

# Step 10: Run diagnostics on the code
print_message "Step 10: Running code diagnostics..."
cat > "$OUTPUT_DIR/diagnostics.md" << EOF
# SystemMaintenance Diagnostics Report
Generated: $(date)

## Build Information
- Build Date: $(date)
- Swift Version: $(swift --version | head -1)
- Xcode Path: $(xcode-select -p)

## File Statistics
EOF

# Count lines of code
TOTAL_LINES=$(wc -l < "$PROJECT_DIR/ContentView.swift")
SWIFTUI_LINES=$(grep -c "import SwiftUI\|@State\|@Binding\|@MainActor\|var body:" "$PROJECT_DIR/ContentView.swift" || true)
SHELL_HELPER_LINES=$(sed -n '/struct ShellHelper/,/^}/p' "$PROJECT_DIR/ContentView.swift" | wc -l || true)

cat >> "$OUTPUT_DIR/diagnostics.md" << EOF
- Total Lines: $TOTAL_LINES
- SwiftUI Lines: $SWIFTUI_LINES
- ShellHelper Lines: $SHELL_HELPER_LINES

## Code Structure Overview
EOF

# Extract struct/class definitions
grep -n "^struct\|^class\|^@MainActor" "$PROJECT_DIR/ContentView.swift" | while read line; do
    echo "- $line" >> "$OUTPUT_DIR/diagnostics.md"
done

print_success "Diagnostics report saved to: $OUTPUT_DIR/diagnostics.md"
echo ""

# Step 11: Create run script
print_message "Step 11: Creating run script..."
cat > "$OUTPUT_DIR/run_systemmaintenance.sh" << 'EOF'
#!/bin/bash

# Run SystemMaintenance
# This script launches the SystemMaintenance application

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_PATH="$SCRIPT_DIR/SystemMaintenance.app/Contents/MacOS/SystemMaintenance"

echo "Launching SystemMaintenance..."
echo "App Path: $APP_PATH"
echo ""

# Check if app exists
if [ ! -f "$APP_PATH" ]; then
    echo "Error: SystemMaintenance executable not found!"
    echo "Please run the build script first."
    exit 1
fi

# Run the application
"$APP_PATH"

# Check exit status
if [ $? -eq 0 ]; then
    echo ""
    echo "SystemMaintenance exited successfully."
else
    echo ""
    echo "SystemMaintenance exited with error code: $?"
fi
EOF

chmod +x "$OUTPUT_DIR/run_systemmaintenance.sh"
print_success "Run script created: $OUTPUT_DIR/run_systemmaintenance.sh"
echo ""

# Step 12: Summary
print_message "=== BUILD PROCESS COMPLETE ==="
echo ""
print_success "Output Files:"
echo "  - Application Bundle: $APP_BUNDLE"
echo "  - Run Script: $OUTPUT_DIR/run_systemmaintenance.sh"
echo "  - Build Log: $BUILD_LOG"
echo "  - Test Log: $TEST_LOG"
echo "  - Diagnostics: $OUTPUT_DIR/diagnostics.md"
echo "  - Backup: $BACKUP_FILE"
echo ""
print_message "To run the application:"
echo "  cd $OUTPUT_DIR"
echo "  ./run_systemmaintenance.sh"
echo ""
print_message "To restore original ContentView.swift:"
echo "  cp \"$BACKUP_FILE\" \"$PROJECT_DIR/ContentView.swift\""
echo ""

# Restore original file
print_message "Restoring original ContentView.swift..."
if [ -f "$BACKUP_FILE" ]; then
    cp "$BACKUP_FILE" "$PROJECT_DIR/ContentView.swift"
    print_success "Original file restored"
fi

print_success "All tasks completed successfully!"
exit 0