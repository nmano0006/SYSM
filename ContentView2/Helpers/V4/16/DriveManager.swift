import Foundation
import SwiftUI
import Combine

class DriveManager: ObservableObject {
    static let shared = DriveManager()
    
    @Published var allDrives: [DriveInfo] = []
    @Published var isLoading = false
    @Published var mountSelection: Set<String> = []
    @Published var unmountSelection: Set<String> = []
    @Published var showEFIDrives: Bool = true
    @Published var alertMessage: String = ""
    @Published var showAlert: Bool = false
    
    private init() {
        refreshDrives()
    }
    
    func refreshDrives() {
        guard !isLoading else { return }
        
        isLoading = true
        print("🔄 Starting drive refresh...")
        
        DispatchQueue.global(qos: .userInitiated).async {
            let drives = ShellHelper.getAllDrives()
            
            DispatchQueue.main.async {
                var updatedDrives: [DriveInfo] = []
                for drive in drives {
                    let updatedDrive = DriveInfo(
                        name: drive.name,
                        identifier: drive.identifier,
                        size: drive.size,
                        type: drive.type,
                        mountPoint: drive.mountPoint,
                        isInternal: drive.isInternal,
                        isEFI: drive.isEFI,
                        partitions: drive.partitions,
                        isMounted: drive.isMounted,
                        isSelectedForMount: self.mountSelection.contains(drive.identifier),
                        isSelectedForUnmount: self.unmountSelection.contains(drive.identifier)
                    )
                    updatedDrives.append(updatedDrive)
                }
                
                // SIMPLIFIED FILTER LOGIC - Only filter what we really need
                self.allDrives = updatedDrives.filter { drive in
                    // Always show EFI drives if showEFIDrives is true
                    if self.showEFIDrives && drive.isEFI {
                        return true
                    }
                    
                    // If not showing EFI and this is EFI, skip it
                    if !self.showEFIDrives && drive.isEFI {
                        return false
                    }
                    
                    // Skip system internal partitions (but allow user to see them if they want)
                    // We'll show them but mark them as non-selectable in the UI
                    if drive.mountPoint.hasPrefix("/System/Volumes/") && 
                       drive.mountPoint != "/System/Volumes/Data" {
                        return false  // Hide system volumes like Preboot, VM, Update
                    }
                    
                    // Skip CoreSimulator volumes
                    if drive.mountPoint.contains("CoreSimulator") {
                        return false
                    }
                    
                    // Skip AssetData volumes
                    if drive.name.contains("ASSETS") || drive.name.contains("AssetData") {
                        return false
                    }
                    
                    // Show everything else
                    return true
                }
                
                // Sort drives: mounted first, then EFI, then unmounted
                self.allDrives.sort { d1, d2 in
                    if d1.isMounted != d2.isMounted {
                        return d1.isMounted && !d2.isMounted
                    }
                    if d1.isEFI != d2.isEFI {
                        return d1.isEFI && !d2.isEFI
                    }
                    return d1.identifier < d2.identifier
                }
                
                self.isLoading = false
                print("✅ Drive refresh complete. Found \(self.allDrives.count) drives")
                print("🔍 EFI drives: \(self.allDrives.filter { $0.isEFI }.count)")
                print("🔍 Mounted drives: \(self.allDrives.filter { $0.isMounted }.count)")
                
                // Debug: List all found drives
                for drive in self.allDrives {
                    let status = drive.isMounted ? "Mounted at \(drive.mountPoint)" : "Unmounted"
                    let type = drive.isEFI ? "EFI" : drive.type
                    print("   - \(drive.identifier): \(drive.name) (\(type)) \(status)")
                }
            }
        }
    }
    
    func toggleMountSelection(for drive: DriveInfo) {
        print("🔘 Toggle mount selection for: \(drive.identifier)")
        
        guard !drive.isMounted else {
            showAlert(message: "Drive is already mounted")
            return
        }
        
        if !drive.canMount {
            showAlert(message: "This drive cannot be mounted")
            return
        }
        
        if let index = allDrives.firstIndex(where: { $0.identifier == drive.identifier }) {
            var updatedDrive = allDrives[index]
            
            if mountSelection.contains(drive.identifier) {
                mountSelection.remove(drive.identifier)
                updatedDrive.isSelectedForMount = false
                print("❌ Removed from mount selection")
            } else {
                if unmountSelection.contains(drive.identifier) {
                    unmountSelection.remove(drive.identifier)
                    updatedDrive.isSelectedForUnmount = false
                }
                
                mountSelection.insert(drive.identifier)
                updatedDrive.isSelectedForMount = true
                print("✅ Added to mount selection")
            }
            
            allDrives[index] = updatedDrive
            objectWillChange.send()
        }
    }
    
    func toggleUnmountSelection(for drive: DriveInfo) {
        print("🔘 Toggle unmount selection for: \(drive.identifier)")
        
        guard drive.isMounted else {
            showAlert(message: "Drive is not mounted")
            return
        }
        
        if !drive.canUnmount {
            showAlert(message: "This drive cannot be unmounted")
            return
        }
        
        if let index = allDrives.firstIndex(where: { $0.identifier == drive.identifier }) {
            var updatedDrive = allDrives[index]
            
            if unmountSelection.contains(drive.identifier) {
                unmountSelection.remove(drive.identifier)
                updatedDrive.isSelectedForUnmount = false
                print("❌ Removed from unmount selection")
            } else {
                if mountSelection.contains(drive.identifier) {
                    mountSelection.remove(drive.identifier)
                    updatedDrive.isSelectedForMount = false
                }
                
                unmountSelection.insert(drive.identifier)
                updatedDrive.isSelectedForUnmount = true
                print("✅ Added to unmount selection")
            }
            
            allDrives[index] = updatedDrive
            objectWillChange.send()
        }
    }
    
    func selectAllForUnmount() {
        print("🔘 Select all for unmount")
        
        mountSelection.removeAll()
        unmountSelection.removeAll()
        
        var updatedDrives: [DriveInfo] = []
        
        for drive in allDrives {
            let shouldSelectForUnmount = drive.isMounted && drive.canUnmount
            
            if shouldSelectForUnmount {
                unmountSelection.insert(drive.identifier)
            }
            
            let updatedDrive = DriveInfo(
                name: drive.name,
                identifier: drive.identifier,
                size: drive.size,
                type: drive.type,
                mountPoint: drive.mountPoint,
                isInternal: drive.isInternal,
                isEFI: drive.isEFI,
                partitions: drive.partitions,
                isMounted: drive.isMounted,
                isSelectedForMount: false,
                isSelectedForUnmount: shouldSelectForUnmount
            )
            
            updatedDrives.append(updatedDrive)
        }
        
        allDrives = updatedDrives
        objectWillChange.send()
    }
    
    func clearAllSelections() {
        print("🔘 Clear all selections")
        
        mountSelection.removeAll()
        unmountSelection.removeAll()
        
        var updatedDrives: [DriveInfo] = []
        
        for drive in allDrives {
            let updatedDrive = DriveInfo(
                name: drive.name,
                identifier: drive.identifier,
                size: drive.size,
                type: drive.type,
                mountPoint: drive.mountPoint,
                isInternal: drive.isInternal,
                isEFI: drive.isEFI,
                partitions: drive.partitions,
                isMounted: drive.isMounted,
                isSelectedForMount: false,
                isSelectedForUnmount: false
            )
            
            updatedDrives.append(updatedDrive)
        }
        
        allDrives = updatedDrives
        objectWillChange.send()
    }
    
    func mountSelectedDrives() -> (success: Bool, message: String) {
        print("🚀 Mounting selected drives")
        
        let drivesToMount = allDrives.filter { $0.isSelectedForMount && !$0.isMounted }
        
        if drivesToMount.isEmpty {
            return (false, "No drives selected for mounting")
        }
        
        print("📦 Drives to mount: \(drivesToMount.count)")
        
        var result: (success: Bool, message: String) = (false, "")
        
        // Perform on background thread
        DispatchQueue.global(qos: .userInitiated).async {
            result = ShellHelper.mountSelectedDrives(drives: drivesToMount)
            
            DispatchQueue.main.async {
                // Refresh after operation
                self.refreshDrives()
                self.clearAllSelections()
                
                // Show result
                self.showAlert(message: result.message)
            }
        }
        
        return result
    }
    
    func unmountSelectedDrives() -> (success: Bool, message: String) {
        print("🚀 Unmounting selected drives")
        
        let drivesToUnmount = allDrives.filter { $0.isSelectedForUnmount && $0.isMounted }
        
        if drivesToUnmount.isEmpty {
            return (false, "No drives selected for unmounting")
        }
        
        print("📦 Drives to unmount: \(drivesToUnmount.count)")
        
        var result: (success: Bool, message: String) = (false, "")
        
        DispatchQueue.global(qos: .userInitiated).async {
            result = ShellHelper.unmountSelectedDrives(drives: drivesToUnmount)
            
            DispatchQueue.main.async {
                // Refresh after operation
                self.refreshDrives()
                self.clearAllSelections()
                
                // Show result
                self.showAlert(message: result.message)
            }
        }
        
        return result
    }
    
    func mountAllExternal() -> (success: Bool, message: String) {
        print("🚀 Mount all external drives")
        
        var result: (success: Bool, message: String) = (false, "")
        
        DispatchQueue.global(qos: .userInitiated).async {
            result = ShellHelper.mountAllExternalDrives()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self.refreshDrives()
                self.showAlert(message: result.message)
            }
        }
        
        return result
    }
    
    func unmountAllExternal() -> (success: Bool, message: String) {
        print("🚀 Unmount all external drives")
        
        var result: (success: Bool, message: String) = (false, "")
        
        DispatchQueue.global(qos: .userInitiated).async {
            result = ShellHelper.unmountAllExternalDrives()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self.refreshDrives()
                self.showAlert(message: result.message)
            }
        }
        
        return result
    }
    
    func getDriveBy(id: String) -> DriveInfo? {
        return allDrives.first { $0.identifier == id }
    }
    
    func toggleEFIVisibility() {
        showEFIDrives.toggle()
        refreshDrives()
        print("🔘 EFI visibility: \(showEFIDrives ? "ON" : "OFF")")
    }
    
    func mountEFIPartition(for identifier: String) -> (success: Bool, message: String) {
        print("🔧 Attempting to mount EFI partition: \(identifier)")
        
        var result: (success: Bool, message: String) = (false, "")
        
        DispatchQueue.global(qos: .userInitiated).async {
            result = ShellHelper.mountEFIDrive(identifier)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.refreshDrives()
                self.showAlert(message: result.message)
            }
        }
        
        return result
    }
    
    func showAlert(message: String) {
        alertMessage = message
        showAlert = true
    }
    
    // Debug function - FIXED VERSION
    func testEFIDetection() {
        print("🧪 Testing EFI detection...")
        
        DispatchQueue.global(qos: .userInitiated).async {
            let currentDrives = self.allDrives
            let debugInfo = """
            === CURRENT DRIVES IN MEMORY ===
            Total: \(currentDrives.count)
            
            """
            
            let driveDetails = currentDrives.map { drive in
                return "- \(drive.identifier): \(drive.name) (\(drive.type)) \(drive.isMounted ? "Mounted at \(drive.mountPoint)" : "Unmounted")"
            }.joined(separator: "\n")
            
            let testResult = ShellHelper.runCommand("""
            echo "=== SYSTEM PROFILER (JSON) ==="
            system_profiler SPStorageDataType -json 2>/dev/null | head -100
            echo ""
            echo "=== DF -H OUTPUT ==="
            df -h | grep '/dev/disk'
            echo ""
            echo "=== DISKUTIL LIST (WITH SUDO IF NEEDED) ==="
            diskutil list 2>&1 || sudo diskutil list 2>&1
            echo ""
            echo "=== ALL MOUNTED VOLUMES ==="
            mount | grep '/dev/disk'
            echo ""
            echo "=== POSSIBLE EFI PARTITIONS ==="
            for disk in disk0s1 disk1s1 disk2s1 disk3s1 disk4s1 disk5s1 disk6s1 disk7s1 disk8s1 disk9s1 disk10s1 disk11s1 disk12s1 disk13s1; do
                if diskutil info /dev/\$disk 2>/dev/null | grep -q "Volume Size:"; then
                    echo "Checking \$disk:"
                    diskutil info /dev/\$disk 2>/dev/null | grep -E '(Volume Size|Type \\(Bundle\\)|Volume Name):'
                fi
            done
            """)
            
            DispatchQueue.main.async {
                self.showAlert(message: debugInfo + driveDetails + "\n\n" + testResult.output)
            }
        }
    }
}