static func getCompleteDiagnostics() -> String {
    var diagnostics = "=== SystemMaintenance Complete Diagnostics Report ===\n"
    diagnostics += "Generated: \(Date().formatted(date: .complete, time: .complete))\n\n"
    
    // Get complete system info
    let sysInfo = getCompleteSystemInfo()
    
    // System Information
    diagnostics += "--- System Information ---\n"
    diagnostics += "macOS Version: \(sysInfo.macOSVersion)\n"
    diagnostics += "Build Number: \(sysInfo.buildNumber)\n"
    diagnostics += "Kernel Version: \(sysInfo.kernelVersion)\n"
    diagnostics += "Model Identifier: \(sysInfo.modelIdentifier)\n"
    diagnostics += "Processor: \(sysInfo.processor)\n"
    diagnostics += "Processor Details: \(sysInfo.processorDetails)\n"
    diagnostics += "Memory: \(sysInfo.memory)\n"
    diagnostics += "Boot Mode: \(sysInfo.bootMode)\n"
    diagnostics += "System UUID: \(sysInfo.systemUUID)\n"
    diagnostics += "Platform UUID: \(sysInfo.platformUUID)\n"
    diagnostics += "Serial Number: \(sysInfo.serialNumber)\n"
    diagnostics += "Boot ROM Version: \(sysInfo.bootROMVersion)\n"
    diagnostics += "SMC Version: \(sysInfo.smcVersion)\n"
    diagnostics += "SIP Status: \(isSIPDisabled() ? "Disabled" : "Enabled")\n\n"
    
    // Graphics Information
    diagnostics += "--- Graphics Information ---\n"
    diagnostics += "\(sysInfo.gpuInfo)\n\n"
    
    // Network Information
    diagnostics += "--- Network Information ---\n"
    diagnostics += "\(sysInfo.networkInfo)\n\n"
    
    // Wireless Network Controller
    diagnostics += "--- Wireless Network Controller ---\n"
    diagnostics += "\(sysInfo.wirelessInfo)\n\n"
    
    // Storage Controllers
    diagnostics += "--- Storage Controllers ---\n"
    diagnostics += "\(sysInfo.storageInfo)\n\n"
    
    // USB Information
    diagnostics += "--- USB Information ---\n"
    diagnostics += "\(sysInfo.usbInfo)\n\n"
    
    // USB eXtensible Host-Controller
    diagnostics += "--- USB eXtensible Host-Controller ---\n"
    diagnostics += "\(sysInfo.usbXHCInfo)\n\n"
    
    // Thunderbolt Information
    diagnostics += "--- Thunderbolt Information ---\n"
    diagnostics += "\(sysInfo.thunderboltInfo)\n\n"
    
    // Ethernet Controller
    diagnostics += "--- Ethernet Controller ---\n"
    diagnostics += "\(sysInfo.ethernetInfo)\n\n"
    
    // NVMe Controller
    diagnostics += "--- NVMe Controller ---\n"
    diagnostics += "\(sysInfo.nvmeInfo)\n\n"
    
    // AHCI/SATA Controller
    diagnostics += "--- AHCI/SATA Controller ---\n"
    diagnostics += "\(sysInfo.ahciInfo)\n\n"
    
    // Audio Information
    diagnostics += "--- Audio Information ---\n"
    diagnostics += "\(sysInfo.audioInfo)\n\n"
    
    // Bluetooth Information
    diagnostics += "--- Bluetooth Information ---\n"
    diagnostics += "\(sysInfo.bluetoothInfo)\n\n"
    
    // PCI Devices
    diagnostics += "--- PCI Devices ---\n"
    diagnostics += "\(sysInfo.pciDevices)\n\n"
    
    // Audio Kext Status
    diagnostics += "--- Audio Kext Status ---\n"
    diagnostics += "Lilu: \(checkKextLoaded("Lilu") ? "Loaded" : "Not loaded")\n"
    diagnostics += "AppleALC: \(checkKextLoaded("AppleALC") ? "Loaded" : "Not loaded")\n"
    diagnostics += "AppleHDA: \(checkKextLoaded("AppleHDA") ? "Loaded" : "Not loaded")\n\n"
    
    // Drive Information
    diagnostics += "--- Drive Information ---\n"
    let drives = getAllDrives()
    for (index, drive) in drives.enumerated() {
        diagnostics += "Drive \(index + 1): \(drive.name)\n"
        diagnostics += "  ID: \(drive.identifier)\n"
        diagnostics += "  Size: \(drive.size)\n"
        diagnostics += "  Type: \(drive.type)\n"
        diagnostics += "  Mount: \(drive.mountPoint)\n"
        diagnostics += "  Internal: \(drive.isInternal)\n"
        if !drive.partitions.isEmpty {
            diagnostics += "  Partitions:\n"
            for partition in drive.partitions {
                diagnostics += "    - \(partition.name) (\(partition.identifier)): \(partition.size) [\(partition.type)]\n"
            }
        }
        diagnostics += "\n"
    }
    
    // EFI Status
    diagnostics += "--- EFI Status ---\n"
    if let efiPath = getEFIPath() {
        diagnostics += "Mounted: Yes\n"
        diagnostics += "Path: \(efiPath)\n"
        
        // Check EFI structure
        let efiContents = runCommand("ls -la \"\(efiPath)/\"")
        diagnostics += "Contents: \(efiContents.output)\n"
    } else {
        diagnostics += "Mounted: No\n"
    }
    
    diagnostics += "\n=== End of Report ===\n"
    return diagnostics
}