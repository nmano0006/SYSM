// DriveManager.swift
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
                
                // Filter logic
                self.allDrives = updatedDrives.filter { drive in
                    // Always show EFI drives if showEFIDrives is true
                    if self.showEFIDrives && drive.isEFI {
                        return true
                    }
                    
                    // Filter out system partitions
                    let isSystemPartition = drive.name.contains("Recovery") ||
                                           drive.name.contains("VM") ||
                                           drive.name.contains("Preboot") ||
                                           drive.name.contains("Update") ||
                                           drive.name.contains("Apple_APFS_ISC") ||
                                           drive.name.contains("Snapshot")
                    
                    if isSystemPartition {
                        return false
                    }
                    
                    // Filter out EFI if not showing
                    if !self.showEFIDrives && drive.isEFI {
                        return false
                    }
                    
                    return true
                }
                
                self.isLoading = false
                print("✅ Drive refresh complete. Found \(self.allDrives.count) drives")
                print("🔍 EFI drives: \(self.allDrives.filter { $0.isEFI }.count)")
                print("🔍 Mounted drives: \(self.allDrives.filter { $0.isMounted }.count)")
            }
        }
    }
    
    func toggleMountSelection(for drive: DriveInfo) {
        print("🔘 Toggle mount selection for: \(drive.identifier)")
        
        guard !drive.isMounted else {
            showAlert(message: "Drive is already mounted")
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
        
        if drive.isInternal && !drive.isEFI {
            showAlert(message: "Cannot unmount internal system drive")
            return
        }
        
        if drive.mountPoint == "/" {
            showAlert(message: "Cannot unmount root filesystem")
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
            let shouldSelectForUnmount = drive.isMounted && 
                                        !drive.isInternal && 
                                        drive.mountPoint != "/" &&
                                        !drive.mountPoint.contains("/System/Volumes/")
            
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
    
    // Debug function
    func testEFIDetection() {
        print("🧪 Testing EFI detection...")
        
        DispatchQueue.global(qos: .userInitiated).async {
            let testResult = ShellHelper.runCommand("""
            echo "=== DISKUTIL LIST ==="
            diskutil list
            echo ""
            echo "=== EFI PARTITIONS ==="
            diskutil list | grep -i 'efi' || echo "No EFI found"
            echo ""
            echo "=== S1 PARTITIONS (usually EFI) ==="
            diskutil list | grep -E 'disk[0-9]+s1' || echo "No s1 partitions"
            echo ""
            echo "=== MOUNTED VOLUMES ==="
            df -h | grep -E '/dev/disk|/Volumes' | head -20
            echo ""
            echo "=== ALL PARTITIONS ==="
            diskutil list | grep -E 'disk[0-9]+s[0-9]+' || echo "No partitions"
            """)
            
            DispatchQueue.main.async {
                self.showAlert(message: testResult.output)
            }
        }
    }
}