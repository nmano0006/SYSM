// MARK: - PlistHelper.swift
import Foundation

class PlistHelper {
    static func loadPlist(from url: URL) throws -> [String: Any] {
        let data = try Data(contentsOf: url)
        guard let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] else {
            throw NSError(domain: "PlistHelper", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to parse plist"])
        }
        return plist
    }
    
    static func savePlist(_ plist: [String: Any], to url: URL) throws {
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try data.write(to: url)
    }
    
    static func createEmptyOpenCoreConfig() -> [String: Any] {
        return [
            "ACPI": [
                "Add": [],
                "Delete": [],
                "Patch": [],
                "Quirks": [:]
            ],
            "Booter": [
                "MmioWhitelist": [],
                "Patch": [],
                "Quirks": [:]
            ],
            "DeviceProperties": [
                "Add": [:],
                "Delete": [:]
            ],
            "Kernel": [
                "Add": [],
                "Block": [],
                "Patch": [],
                "Quirks": [:],
                "Scheme": [:]
            ],
            "Misc": [
                "Boot": [:],
                "Debug": [:],
                "Security": [:],
                "Tools": []
            ],
            "NVRAM": [
                "Add": [:],
                "Delete": [:]
            ],
            "PlatformInfo": [
                "Generic": [:]
            ],
            "UEFI": [
                "APFS": [:],
                "Drivers": [],
                "Input": [:],
                "Output": [:],
                "ProtocolOverrides": [:],
                "Quirks": [:]
            ]
        ]
    }
}