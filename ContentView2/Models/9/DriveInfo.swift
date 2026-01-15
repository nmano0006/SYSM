import Foundation
import SwiftUI

struct DriveInfo: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let identifier: String
    let size: String
    let type: String
    let mountPoint: String
    let isInternal: Bool
    let isEFI: Bool
    let partitions: [DriveInfo]
    let isMounted: Bool
    var isSelectedForMount: Bool
    var isSelectedForUnmount: Bool
    
    // Computed properties
    var displayName: String {
        if name == "Disk \(identifier)" || name.isEmpty {
            return "Partition \(identifier)"
        }
        return name
    }
    
    var iconName: String {
        if isEFI {
            return "lock.shield"
        } else if isInternal {
            return "internaldrive"
        } else {
            return "externaldrive"
        }
    }
    
    var iconColor: Color {
        if isEFI {
            return .purple
        } else if isInternal {
            return .blue
        } else {
            return .orange
        }
    }
    
    var canMount: Bool {
        return !isMounted && !isInternal && mountPoint != "/"
    }
    
    var canUnmount: Bool {
        return isMounted && !isInternal && mountPoint != "/" && !mountPoint.hasPrefix("/System/Volumes/")
    }
    
    static func == (lhs: DriveInfo, rhs: DriveInfo) -> Bool {
        return lhs.identifier == rhs.identifier
    }
}