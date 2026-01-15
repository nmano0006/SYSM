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
    
    // Add property to control EFI visibility
    @Published var showEFIDrives: Bool = false
    
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
                
                // Filter out system partitions but keep EFI if showEFIDrives is true
                self.allDrives = updatedDrives.filter { drive in
                    // Always filter out system recovery partitions
                    if drive.name.contains("Recovery") ||
                       drive.name.contains("VM") ||
                       drive.name.contains("Preboot") ||
                       drive.name.contains("Update") ||
                       drive.name.contains("Apple_APFS_ISC") {
                        return false
                    }
                    
                    // Show EFI partitions if showEFIDrives is true
                    if drive.isEFI || drive.name.contains("EFI") {
                        return self.showEFIDrives
                    }
                    
                    return true
                }
                
                self.isLoading = false
                
                print("🔄 Drive refresh complete. Found \(self.allDrives.count) drives")
            }
        }
    }
    
    func toggleMountSelection(for drive: DriveInfo) {
        print("🔘 Toggle mount selection for: \(drive.identifier)")
        
        // Don't allow mounting of mounted drives
        guard !drive.isMounted else {
            print("⚠️ Drive is already mounted")
            return
        }
        
        // Special handling for EFI partitions
        if drive.isEFI {
            print("⚠️ EFI partition detected - using special mount method")
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
        
        // Don't allow unmounting of unmounted drives
        guard drive.isMounted else {
            print("⚠️ Drive is not mounted")
            return
        }
        
        // Don't allow unmounting of internal system drives (except EFI)
        if drive.isInternal && !drive.isEFI {
            print("⚠️ Cannot unmount internal system drive")
            return
        }
        
        // Special check for root filesystem
        if drive.mountPoint == "/" {
            print("⚠️ Cannot unmount root filesystem")
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
        
        // Check for EFI partitions
        let efiDrives = drivesToMount.filter { $0.isEFI }
        let nonEfiDrives = drivesToMount.filter { !$0.isEFI }
        
        var allMessages: [String] = []
        var overallSuccess = true
        
        // Mount non-EFI drives first
        if !nonEfiDrives.isEmpty {
            let result = ShellHelper.mountSelectedDrives(drives: nonEfiDrives)
            allMessages.append(result.message)
            overallSuccess = overallSuccess && result.success
        }
        
        // Mount EFI drives (if any)
        if !efiDrives.isEmpty {
            for efiDrive in efiDrives {
                let result = ShellHelper.mountEFIDrive(efiDrive.identifier)
                allMessages.append(result.message)
                overallSuccess = overallSuccess && result.success
                
                // Small delay between EFI mounts
                Thread.sleep(forTimeInterval: 0.5)
            }
        }
        
        // Refresh drives after operation
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.refreshDrives()
            self.clearAllSelections()
        }
        
        let combinedMessage = allMessages.joined(separator: "\n\n")
        return (overallSuccess, combinedMessage)
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
    
    // New method to toggle EFI drive visibility
    func toggleEFIVisibility() {
        showEFIDrives.toggle()
        refreshDrives()
        print("🔘 EFI visibility: \(showEFIDrives ? "ON" : "OFF")")
    }
    
    // New method to specifically mount EFI partitions
    func mountEFIPartition(for identifier: String) -> (success: Bool, message: String) {
        print("🔧 Attempting to mount EFI partition: \(identifier)")
        
        // Verify it's actually an EFI partition
        guard let drive = getDriveBy(id: identifier), drive.isEFI else {
            return (false, "Not an EFI partition")
        }
        
        let result = ShellHelper.mountEFIDrive(identifier)
        
        // Refresh after mount
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.refreshDrives()
        }
        
        return result
    }
}