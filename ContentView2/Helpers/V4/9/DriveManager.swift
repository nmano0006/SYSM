// DriveManager.swift - Fix the filtering logic
import Foundation
import SwiftUI
import Combine

class DriveManager: ObservableObject {
    static let shared = DriveManager()
    
    @Published var allDrives: [DriveInfo] = []
    @Published var isLoading = false
    @Published var mountSelection: Set<String> = []
    @Published var unmountSelection: Set<String> = []
    @Published var showEFIDrives: Bool = true // Default to true to see EFI
    
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
                
                // IMPORTANT: Don't filter out EFI partitions - we want to see them
                self.allDrives = updatedDrives.filter { drive in
                    // Only filter out certain system partitions
                    let shouldFilter = drive.name.contains("Recovery") ||
                                      drive.name.contains("VM") ||
                                      drive.name.contains("Preboot") ||
                                      drive.name.contains("Update") ||
                                      drive.name.contains("Apple_APFS_ISC")
                    
                    // If showEFIDrives is false AND it's an EFI partition, filter it out
                    if !self.showEFIDrives && (drive.isEFI || drive.name.contains("EFI")) {
                        return false
                    }
                    
                    return !shouldFilter
                }
                
                self.isLoading = false
                
                print("🔄 Drive refresh complete. Found \(self.allDrives.count) drives")
                print("🔍 EFI drives found: \(self.allDrives.filter { $0.isEFI }.count)")
            }
        }
    }
    
    // Rest of the functions remain the same...
    func toggleMountSelection(for drive: DriveInfo) {
        print("🔘 Toggle mount selection for: \(drive.identifier)")
        
        // Allow mounting of unmounted drives
        guard !drive.isMounted else {
            print("⚠️ Drive is already mounted")
            return
        }
        
        if let index = allDrives.firstIndex(where: { $0.identifier == drive.identifier }) {
            var updatedDrive = allDrives[index]
            
            // Toggle mount selection
            if mountSelection.contains(drive.identifier) {
                mountSelection.remove(drive.identifier)
                updatedDrive.isSelectedForMount = false
                print("❌ Removed \(drive.identifier) from mount selection")
            } else {
                // Clear any unmount selection first
                if unmountSelection.contains(drive.identifier) {
                    unmountSelection.remove(drive.identifier)
                    updatedDrive.isSelectedForUnmount = false
                }
                
                mountSelection.insert(drive.identifier)
                updatedDrive.isSelectedForMount = true
                print("✅ Added \(drive.identifier) to mount selection")
            }
            
            allDrives[index] = updatedDrive
            objectWillChange.send()
        }
    }
    
    func toggleUnmountSelection(for drive: DriveInfo) {
        print("🔘 Toggle unmount selection for: \(drive.identifier)")
        
        // Allow unmounting of mounted drives
        guard drive.isMounted else {
            print("⚠️ Drive is not mounted")
            return
        }
        
        if let index = allDrives.firstIndex(where: { $0.identifier == drive.identifier }) {
            var updatedDrive = allDrives[index]
            
            // Toggle unmount selection
            if unmountSelection.contains(drive.identifier) {
                unmountSelection.remove(drive.identifier)
                updatedDrive.isSelectedForUnmount = false
                print("❌ Removed \(drive.identifier) from unmount selection")
            } else {
                // Clear any mount selection first
                if mountSelection.contains(drive.identifier) {
                    mountSelection.remove(drive.identifier)
                    updatedDrive.isSelectedForMount = false
                }
                
                unmountSelection.insert(drive.identifier)
                updatedDrive.isSelectedForUnmount = true
                print("✅ Added \(drive.identifier) to unmount selection")
            }
            
            allDrives[index] = updatedDrive
            objectWillChange.send()
        }
    }
    
    func mountSelectedDrives() -> (success: Bool, message: String) {
        print("🚀 Mounting selected drives")
        
        let drivesToMount = allDrives.filter { $0.isSelectedForMount && !$0.isMounted }
        
        if drivesToMount.isEmpty {
            return (false, "No drives selected for mounting")
        }
        
        print("📦 Drives to mount: \(drivesToMount.count)")
        
        let result = ShellHelper.mountSelectedDrives(drives: drivesToMount)
        
        // Refresh drives after operation
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.refreshDrives()
            self.clearAllSelections()
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
        
        let result = ShellHelper.unmountSelectedDrives(drives: drivesToUnmount)
        
        // Refresh drives after operation
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.refreshDrives()
            self.clearAllSelections()
        }
        
        return result
    }
    
    // Rest of functions...
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
    
    func mountAllExternal() -> (success: Bool, message: String) {
        print("🚀 Mount all external drives")
        
        let result = ShellHelper.mountAllExternalDrives()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.refreshDrives()
        }
        
        return result
    }
    
    func unmountAllExternal() -> (success: Bool, message: String) {
        print("🚀 Unmount all external drives")
        
        let result = ShellHelper.unmountAllExternalDrives()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.refreshDrives()
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
        
        let result = ShellHelper.mountEFIDrive(identifier)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.refreshDrives()
        }
        
        return result
    }
}