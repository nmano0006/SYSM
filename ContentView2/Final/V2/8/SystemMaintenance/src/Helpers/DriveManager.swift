import Foundation
import SwiftUI
import Combine

class DriveManager: ObservableObject {
    static let shared = DriveManager()
    
    @Published var allDrives: [DriveInfo] = []
    @Published var isLoading = false
    @Published var mountSelection: Set<String> = []
    @Published var unmountSelection: Set<String> = []
    
    private init() {}
    
    func refreshDrives() {
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
                self.allDrives = updatedDrives
                self.isLoading = false
                
                print("🔄 Drive refresh complete. Found \(self.allDrives.count) drives:")
                for drive in self.allDrives {
                    let selection = drive.isSelectedForMount ? "✅ Mount" : (drive.isSelectedForUnmount ? "✅ Unmount" : "⬜ None")
                    print("   - \(drive.name) (\(drive.identifier)): \(drive.isMounted ? "📌 Mounted" : "📦 Unmounted") - \(selection)")
                }
            }
        }
    }
    
    func toggleMountSelection(for drive: DriveInfo) {
        print("🔘 Toggle mount selection for: \(drive.identifier)")
        
        if let index = allDrives.firstIndex(where: { $0.identifier == drive.identifier }) {
            let currentDrive = allDrives[index]
            
            if currentDrive.isMounted {
                print("⚠️ Drive is already mounted, cannot select for mount")
                return
            }
            
            let newIsSelectedForMount = !currentDrive.isSelectedForMount
            var newIsSelectedForUnmount = currentDrive.isSelectedForUnmount
            
            if newIsSelectedForMount && currentDrive.isSelectedForUnmount {
                newIsSelectedForUnmount = false
                unmountSelection.remove(drive.identifier)
            }
            
            if newIsSelectedForMount {
                mountSelection.insert(drive.identifier)
                print("✅ Added \(drive.identifier) to mount selection")
            } else {
                mountSelection.remove(drive.identifier)
                print("❌ Removed \(drive.identifier) from mount selection")
            }
            
            allDrives[index] = DriveInfo(
                name: currentDrive.name,
                identifier: currentDrive.identifier,
                size: currentDrive.size,
                type: currentDrive.type,
                mountPoint: currentDrive.mountPoint,
                isInternal: currentDrive.isInternal,
                isEFI: currentDrive.isEFI,
                partitions: currentDrive.partitions,
                isMounted: currentDrive.isMounted,
                isSelectedForMount: newIsSelectedForMount,
                isSelectedForUnmount: newIsSelectedForUnmount
            )
            
            objectWillChange.send()
        }
    }
    
    func toggleUnmountSelection(for drive: DriveInfo) {
        print("🔘 Toggle unmount selection for: \(drive.identifier)")
        
        if let index = allDrives.firstIndex(where: { $0.identifier == drive.identifier }) {
            let currentDrive = allDrives[index]
            
            if !currentDrive.isMounted {
                print("⚠️ Drive is not mounted, cannot select for unmount")
                return
            }
            
            if currentDrive.mountPoint.contains("/System/Volumes/") || 
               currentDrive.mountPoint == "/" ||
               currentDrive.mountPoint.contains("home") ||
               currentDrive.mountPoint.contains("private/var") ||
               currentDrive.mountPoint.contains("Library/Developer") {
                print("⚠️ Cannot unmount system volume: \(currentDrive.mountPoint)")
                return
            }
            
            let newIsSelectedForUnmount = !currentDrive.isSelectedForUnmount
            var newIsSelectedForMount = currentDrive.isSelectedForMount
            
            if newIsSelectedForUnmount && currentDrive.isSelectedForMount {
                newIsSelectedForMount = false
                mountSelection.remove(drive.identifier)
            }
            
            if newIsSelectedForUnmount {
                unmountSelection.insert(drive.identifier)
                print("✅ Added \(drive.identifier) to unmount selection")
            } else {
                unmountSelection.remove(drive.identifier)
                print("❌ Removed \(drive.identifier) from unmount selection")
            }
            
            allDrives[index] = DriveInfo(
                name: currentDrive.name,
                identifier: currentDrive.identifier,
                size: currentDrive.size,
                type: currentDrive.type,
                mountPoint: currentDrive.mountPoint,
                isInternal: currentDrive.isInternal,
                isEFI: currentDrive.isEFI,
                partitions: currentDrive.partitions,
                isMounted: currentDrive.isMounted,
                isSelectedForMount: newIsSelectedForMount,
                isSelectedForUnmount: newIsSelectedForUnmount
            )
            
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
                                         !drive.mountPoint.contains("/System/Volumes/") &&
                                         drive.mountPoint != "/" &&
                                         !drive.mountPoint.contains("home") &&
                                         !drive.mountPoint.contains("private/var") &&
                                         !drive.mountPoint.contains("Library/Developer")
            
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
            
            if shouldSelectForUnmount {
                unmountSelection.insert(drive.identifier)
            }
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
        let drivesToMount = allDrives.filter { $0.isSelectedForMount }
        print("📦 Drives to mount: \(drivesToMount.count)")
        
        for drive in drivesToMount {
            print("   - \(drive.name) (\(drive.identifier))")
        }
        
        let result = ShellHelper.mountSelectedDrives(drives: drivesToMount)
        if result.success {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                self.refreshDrives()
                self.clearAllSelections()
            }
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.refreshDrives()
            }
        }
        return (result.success, result.message)
    }
    
    func unmountSelectedDrives() -> (success: Bool, message: String) {
        print("🚀 Unmounting selected drives")
        let drivesToUnmount = allDrives.filter { $0.isSelectedForUnmount }
        print("📦 Drives to unmount: \(drivesToUnmount.count)")
        
        for drive in drivesToUnmount {
            print("   - \(drive.name) (\(drive.identifier))")
        }
        
        let result = ShellHelper.unmountSelectedDrives(drives: drivesToUnmount)
        if result.success {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                self.refreshDrives()
                self.clearAllSelections()
            }
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.refreshDrives()
            }
        }
        return (result.success, result.message)
    }
    
    func mountAllExternal() -> (success: Bool, message: String) {
        print("🚀 Mount all external drives")
        let result = ShellHelper.mountAllExternalDrives()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.refreshDrives()
        }
        return (result.success, result.message)
    }
    
    func unmountAllExternal() -> (success: Bool, message: String) {
        print("🚀 Unmount all external drives")
        let result = ShellHelper.unmountAllExternalDrives()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.refreshDrives()
        }
        return (result.success, result.message)
    }
    
    func getDriveBy(id: String) -> DriveInfo? {
        return allDrives.first { $0.identifier == id }
    }
}