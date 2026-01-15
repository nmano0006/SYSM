import Foundation
import SwiftUI

class DriveManager: ObservableObject {
    static let shared = DriveManager()
    
    @Published var allDrives: [DriveInfo] = []
    @Published var isLoading = false
    
    var mountSelection: [DriveInfo] {
        allDrives.filter { $0.isSelectedForMount }
    }
    
    var unmountSelection: [DriveInfo] {
        allDrives.filter { $0.isSelectedForUnmount }
    }
    
    private init() {}
    
    func refreshDrives() {
        isLoading = true
        DispatchQueue.global(qos: .userInitiated).async {
            let drives = ShellHelper.getAllDrives()
            DispatchQueue.main.async {
                self.allDrives = drives
                self.isLoading = false
            }
        }
    }
    
    func toggleMountSelection(for drive: DriveInfo) {
        if let index = allDrives.firstIndex(where: { $0.id == drive.id }) {
            allDrives[index].isSelectedForMount.toggle()
            // If we're selecting for mount, ensure it's not selected for unmount
            if allDrives[index].isSelectedForMount {
                allDrives[index].isSelectedForUnmount = false
            }
        }
    }
    
    func toggleUnmountSelection(for drive: DriveInfo) {
        if let index = allDrives.firstIndex(where: { $0.id == drive.id }) {
            allDrives[index].isSelectedForUnmount.toggle()
            // If we're selecting for unmount, ensure it's not selected for mount
            if allDrives[index].isSelectedForUnmount {
                allDrives[index].isSelectedForMount = false
            }
        }
    }
    
    func clearAllSelections() {
        for index in allDrives.indices {
            allDrives[index].isSelectedForMount = false
            allDrives[index].isSelectedForUnmount = false
        }
    }
    
    func selectAllForUnmount() {
        for index in allDrives.indices {
            let drive = allDrives[index]
            if drive.isMounted && 
               !drive.mountPoint.contains("/System/Volumes/") &&
               drive.mountPoint != "/" &&
               !drive.mountPoint.contains("home") &&
               !drive.mountPoint.contains("private/var") &&
               !drive.mountPoint.contains("Library/Developer") {
                allDrives[index].isSelectedForUnmount = true
                allDrives[index].isSelectedForMount = false
            }
        }
    }
    
    func mountSelectedDrives() -> (success: Bool, message: String) {
        let selected = allDrives.filter { $0.isSelectedForMount && !$0.isMounted }
        return ShellHelper.mountSelectedDrives(drives: selected)
    }
    
    func unmountSelectedDrives() -> (success: Bool, message: String) {
        let selected = allDrives.filter { $0.isSelectedForUnmount && $0.isMounted }
        return ShellHelper.unmountSelectedDrives(drives: selected)
    }
    
    func mountAllExternal() -> (success: Bool, message: String) {
        return ShellHelper.mountAllExternalDrives()
    }
    
    func unmountAllExternal() -> (success: Bool, message: String) {
        return ShellHelper.unmountAllExternalDrives()
    }
}