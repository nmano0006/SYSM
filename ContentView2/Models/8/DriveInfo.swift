// DriveInfo.swift
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
    let partitions: [String]
    let isMounted: Bool
    var isSelectedForMount: Bool
    var isSelectedForUnmount: Bool
    
    // Computed properties for UI
    var iconName: String {
        if isEFI {
            return "lock.shield.fill"
        } else if isInternal {
            return "internaldrive.fill"
        } else {
            return "externaldrive.fill"
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
    
    var displayName: String {
        if name.isEmpty || name == identifier {
            return "Disk \(identifier)"
        }
        return name
    }
    
    var canMount: Bool {
        return !isMounted && (isEFI || !isInternal)
    }
    
    var canUnmount: Bool {
        return isMounted && (isEFI || !isInternal) && mountPoint != "/"
    }
    
    static func == (lhs: DriveInfo, rhs: DriveInfo) -> Bool {
        return lhs.identifier == rhs.identifier
    }
}