// Models/DriveInfo.swift
import Foundation

// MARK: - Drive Info Model
struct DriveInfo: Identifiable, Codable, Hashable {
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
    
    // Add this initializer to match the one in ShellHelper.swift
    init(
        name: String,
        identifier: String,
        size: String,
        type: String,
        mountPoint: String,
        isInternal: Bool,
        isEFI: Bool,
        partitions: [String],
        isMounted: Bool,
        isSelectedForMount: Bool = false,
        isSelectedForUnmount: Bool = false
    ) {
        self.name = name
        self.identifier = identifier
        self.size = size
        self.type = type
        self.mountPoint = mountPoint
        self.isInternal = isInternal
        self.isEFI = isEFI
        self.partitions = partitions
        self.isMounted = isMounted
        self.isSelectedForMount = isSelectedForMount
        self.isSelectedForUnmount = isSelectedForUnmount
    }
}