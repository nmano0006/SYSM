// ShellHelper.swift
import Foundation
import AppKit

struct OpenCoreInfo {
    let version: String
    let mode: String
    let secureBootModel: String
    let sipStatus: String
    let bootArgs: String
    let isHackintosh: Bool
    let efiMountPath: String?
}

struct BootloaderInfo {
    let name: String
    let version: String
    let mode: String
}

struct SystemInfo {
    let systemVersion: String
    let modelIdentifier: String
    let processorName: String
    let physicalMemory: String
    let bootVolume: String
    let uptime: String
}

struct ShellHelper {
    
    // MARK: - Basic Command Execution
    
    @discardableResult
    static func runCommand(_ command: String) -> (output: String, success: Bool) {
        print("💻 Executing: \(command)")
        
        let process = Process()
        let pipe = Pipe()
        
        process.standardOutput = pipe
        process.standardError = pipe
        process.arguments = ["-c", command]
        process.launchPath = "/bin/zsh"
        process.standardInput = nil
        
        do {
            try process.run()
        } catch {
            print("❌ Failed to run command: \(error)")
            return ("Command failed: \(error)", false)
        }
        
        process.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        
        let success = process.terminationStatus == 0
        if !success {
            print("❌ Command failed with exit code: \(process.terminationStatus)")
        }
        
        return (output, success)
    }
    
    @discardableResult
    static func runCommandWithPrivileges(_ command: String) -> (output: String, success: Bool) {
        print("🔐 Executing privileged command...")
        
        let script = "do shell script \"\(command)\" with administrator privileges"
        
        let appleScript = NSAppleScript(source: script)
        var error: NSDictionary?
        
        if let result = appleScript?.executeAndReturnError(&error) {
            let output = result.stringValue ?? ""
            print("✅ Privileged command executed successfully")
            return (output, true)
        } else {
            let errorMessage = error?["NSAppleScriptErrorMessage"] as? String ?? "Unknown error"
            print("❌ Privileged command failed: \(errorMessage)")
            return (errorMessage, false)
        }
    }
    
    // MARK: - Security & Permissions
    
    static func checkFullDiskAccess() -> Bool {
        print("🔐 Checking Full Disk Access permissions...")
        
        // Method 1: Try to access a protected directory
        let testPath = "/Library/Application Support"
        let testCommand = "ls '\(testPath)' 2>&1 | head -5"
        let result = runCommand(testCommand)
        
        // Check for permission denied errors
        if result.output.contains("Operation not permitted") || 
           result.output.contains("Permission denied") {
            print("❌ Full Disk Access NOT granted")
            print("💡 Error message: \(result.output)")
            return false
        }
        
        // Method 2: Try to read system logs
        let logTest = runCommand("ls /var/log/system.log 2>&1")
        if logTest.output.contains("Operation not permitted") || 
           logTest.output.contains("Permission denied") {
            print("❌ No access to system logs")
            return false
        }
        
        // Method 3: Try to list users directory
        let usersCheck = runCommand("ls /Users 2>&1")
        
        // If we can access /Library/Application Support without permission errors, 
        // and we can list /Users, we likely have Full Disk Access
        if !result.output.contains("No such file") && 
           !usersCheck.output.contains("Permission denied") {
            print("✅ Full Disk Access appears to be granted")
            return true
        }
        
        print("⚠️ Unable to determine Full Disk Access status")
        return false
    }
    
    // MARK: - System Functions
    
    static func getSystemInfo() -> SystemInfo {
        print("📊 Getting system information...")
        
        // System Version
        let osVersion = runCommand("sw_vers -productVersion").output.trimmingCharacters(in: .whitespacesAndNewlines)
        let buildVersion = runCommand("sw_vers -buildVersion").output.trimmingCharacters(in: .whitespacesAndNewlines)
        let systemVersion = "\(osVersion) (\(buildVersion))"
        
        // Model Identifier
        let modelIdentifier = runCommand("sysctl -n hw.model").output.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Processor
        let processorName = runCommand("sysctl -n machdep.cpu.brand_string").output.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Memory
        let memoryBytes = Int(runCommand("sysctl -n hw.memsize").output.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
        let memoryGB = Double(memoryBytes) / 1_073_741_824.0
        let physicalMemory = String(format: "%.1f GB", memoryGB)
        
        // Boot Volume
        let bootVolume = runCommand("diskutil info / | grep 'Volume Name:' | awk '{print $3}'").output.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Uptime
        let uptimeSeconds = Int(runCommand("sysctl -n kern.boottime | awk '{print $4}'").output.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
        let currentTime = Int(Date().timeIntervalSince1970)
        let uptime = currentTime - uptimeSeconds
        
        let days = uptime / (24 * 3600)
        let hours = (uptime % (24 * 3600)) / 3600
        let minutes = (uptime % 3600) / 60
        
        let uptimeString: String
        if days > 0 {
            uptimeString = "\(days)d \(hours)h \(minutes)m"
        } else if hours > 0 {
            uptimeString = "\(hours)h \(minutes)m"
        } else {
            uptimeString = "\(minutes)m"
        }
        
        return SystemInfo(
            systemVersion: systemVersion,
            modelIdentifier: modelIdentifier,
            processorName: processorName,
            physicalMemory: physicalMemory,
            bootVolume: bootVolume,
            uptime: uptimeString
        )
    }
    
    static func detectBootloader() -> BootloaderInfo {
        print("🔍 Detecting bootloader...")
        
        // Check for OpenCore in NVRAM
        let openCoreCheck = runCommand("nvram 4D1FDA02-38C7-4A6A-9CC6-4BCCA8B30102:opencore-version 2>/dev/null || echo ''")
        
        if !openCoreCheck.output.isEmpty && !openCoreCheck.output.contains("error") {
            let version = openCoreCheck.output.trimmingCharacters(in: .whitespacesAndNewlines)
            print("✅ OpenCore detected: \(version)")
            return BootloaderInfo(name: "OpenCore", version: version, mode: "Native")
        }
        
        // Check for Clover
        let cloverCheck = runCommand("nvram 4D1FDA02-38C7-4A6A-9CC6-4BCCA8B38C14:Clover.Settings 2>/dev/null || echo ''")
        
        if !cloverCheck.output.isEmpty && !cloverCheck.output.contains("error") {
            print("✅ Clover detected")
            return BootloaderInfo(name: "Clover", version: "Unknown", mode: "Legacy")
        }
        
        // Check for Apple's boot.efi
        let bootEfiCheck = runCommand("nvram boot-args 2>/dev/null | grep -q 'no-compat' && echo 'Apple Silicon' || echo 'Intel'")
        let bootMode = bootEfiCheck.output.trimmingCharacters(in: .whitespacesAndNewlines)
        
        print("✅ Apple Boot.efi detected (\(bootMode))")
        return BootloaderInfo(name: "Apple Boot.efi", version: "Native", mode: bootMode)
    }
    
    // MARK: - Bootloader Details
    
    static func getBootloaderDetails() -> String {
        print("🔍 Getting bootloader details...")
        
        let bootloader = detectBootloader()
        var details = "Bootloader: \(bootloader.name)\n"
        details += "Version: \(bootloader.version)\n"
        details += "Mode: \(bootloader.mode)\n\n"
        
        // Get NVRAM variables for additional details
        let nvramResult = runCommand("nvram -p 2>/dev/null | head -20")
        details += "NVRAM Variables (first 20):\n"
        details += nvramResult.output
        
        return details
    }
    
    // MARK: - OpenCore Configuration Functions
    
    static func getOpenCoreConfig() -> [String: Any]? {
        print("📖 Reading OpenCore configuration...")
        
        // First, try to mount an EFI partition
        let mountResult = mountEFIForConfig()
        var efiMounted = false
        var efiMountPath: String?
        
        if !mountResult.output.isEmpty {
            efiMounted = true
            efiMountPath = mountResult.output.trimmingCharacters(in: .whitespacesAndNewlines)
            print("✅ Mounted EFI at: \(efiMountPath ?? "Unknown")")
        }
        
        // Check standard OpenCore config locations
        let configPaths = getOpenCoreConfigPaths(efiMountPath: efiMountPath)
        var foundConfig: [String: Any]? = nil
        
        for configPath in configPaths {
            print("🔍 Checking for config at: \(configPath)")
            
            if FileManager.default.fileExists(atPath: configPath) {
                print("✅ Found config at: \(configPath)")
                
                do {
                    let data = try Data(contentsOf: URL(fileURLWithPath: configPath))
                    if let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] {
                        foundConfig = plist
                        print("📊 Successfully parsed config with \(plist.count) top-level keys")
                        break
                    }
                } catch {
                    print("❌ Failed to parse config at \(configPath): \(error)")
                }
            }
        }
        
        // Unmount EFI if we mounted it
        if efiMounted, let mountPath = efiMountPath {
            print("⏬ Unmounting EFI...")
            _ = runCommand("diskutil unmount '\(mountPath)' 2>/dev/null")
        }
        
        // If no config found in EFI, check user directories
        if foundConfig == nil {
            print("🔍 Checking user directories for OpenCore config...")
            foundConfig = getUserOpenCoreConfig()
        }
        
        return foundConfig
    }
    
    private static func mountEFIForConfig() -> (output: String, success: Bool) {
        print("🔧 Mounting EFI for config reading...")
        
        // Try to find and mount an EFI partition
        let findEFI = runCommand("""
        for disk in $(diskutil list | grep -i efi | grep -oE 'disk[0-9]+s[0-9]+' | head -1); do
            echo "Found EFI: $disk"
            # Try to mount
            diskutil mount /dev/$disk 2>/dev/null
            if [ $? -eq 0 ]; then
                mount | grep "/dev/$disk" | awk '{print $3}'
                exit 0
            fi
        done
        echo ""
        """)
        
        return findEFI
    }
    
    private static func getOpenCoreConfigPaths(efiMountPath: String?) -> [String] {
        var paths: [String] = []
        
        if let efiPath = efiMountPath {
            paths.append(contentsOf: [
                "\(efiPath)/EFI/OC/config.plist",
                "\(efiPath)/EFI/OC/Config.plist",
                "\(efiPath)/EFI/BOOT/config.plist",
                "\(efiPath)/EFI/BOOT/Config.plist",
                "\(efiPath)/config.plist",
                "\(efiPath)/Config.plist"
            ])
        } else {
            // If no specific mount path, check common mount points
            let commonMounts = ["/Volumes/EFI", "/Volumes/ESP"]
            for mount in commonMounts {
                paths.append(contentsOf: [
                    "\(mount)/EFI/OC/config.plist",
                    "\(mount)/EFI/OC/Config.plist",
                    "\(mount)/EFI/BOOT/config.plist",
                    "\(mount)/EFI/BOOT/Config.plist"
                ])
            }
        }
        
        return paths
    }
    
    private static func getUserOpenCoreConfig() -> [String: Any]? {
        print("🔍 Checking user directories for OpenCore config...")
        
        let userHome = FileManager.default.homeDirectoryForCurrentUser.path
        let userConfigPaths = [
            "\(userHome)/Documents/OpenCore/config.plist",
            "\(userHome)/Downloads/OpenCore/config.plist",
            "\(userHome)/Desktop/OpenCore/config.plist",
            "\(userHome)/Library/Application Support/OpenCore/config.plist"
        ]
        
        for configPath in userConfigPaths {
            if FileManager.default.fileExists(atPath: configPath) {
                print("✅ Found user config at: \(configPath)")
                
                do {
                    let data = try Data(contentsOf: URL(fileURLWithPath: configPath))
                    if let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] {
                        print("📊 Successfully parsed user config")
                        return plist
                    }
                } catch {
                    print("❌ Failed to parse user config: \(error)")
                }
            }
        }
        
        return nil
    }
    
    static func saveOpenCoreConfig(_ config: [String: Any], to path: String? = nil) -> Bool {
        print("💾 Saving OpenCore configuration...")
        
        var savePath = path
        
        // If no path specified, try to find the original config location
        if savePath == nil {
            savePath = findExistingOpenCoreConfigPath()
        }
        
        // If still no path, use a default user location
        if savePath == nil {
            let userHome = FileManager.default.homeDirectoryForCurrentUser.path
            savePath = "\(userHome)/Documents/OpenCore/config.plist"
            
            // Create directory if it doesn't exist
            let directory = (savePath! as NSString).deletingLastPathComponent
            try? FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true, attributes: nil)
        }
        
        guard let finalPath = savePath else {
            print("❌ No save path available")
            return false
        }
        
        print("📝 Saving config to: \(finalPath)")
        
        do {
            let data = try PropertyListSerialization.data(fromPropertyList: config, format: .xml, options: 0)
            try data.write(to: URL(fileURLWithPath: finalPath))
            print("✅ Config saved successfully")
            return true
        } catch {
            print("❌ Failed to save config: \(error)")
            return false
        }
    }
    
    private static func findExistingOpenCoreConfigPath() -> String? {
        print("🔍 Looking for existing OpenCore config...")
        
        // Check EFI first
        let mountResult = mountEFIForConfig()
        var efiMounted = false
        var efiMountPath: String?
        
        if !mountResult.output.isEmpty {
            efiMounted = true
            efiMountPath = mountResult.output.trimmingCharacters(in: .whitespacesAndNewlines)
            
            let configPaths = getOpenCoreConfigPaths(efiMountPath: efiMountPath)
            for configPath in configPaths {
                if FileManager.default.fileExists(atPath: configPath) {
                    // Unmount EFI before returning
                    if efiMounted, let mountPath = efiMountPath {
                        _ = runCommand("diskutil unmount '\(mountPath)' 2>/dev/null")
                    }
                    return configPath
                }
            }
            
            // Unmount EFI if we didn't find config
            if efiMounted, let mountPath = efiMountPath {
                _ = runCommand("diskutil unmount '\(mountPath)' 2>/dev/null")
            }
        }
        
        // Check user directories
        let userHome = FileManager.default.homeDirectoryForCurrentUser.path
        let userConfigPaths = [
            "\(userHome)/Documents/OpenCore/config.plist",
            "\(userHome)/Downloads/OpenCore/config.plist",
            "\(userHome)/Desktop/OpenCore/config.plist",
            "\(userHome)/Library/Application Support/OpenCore/config.plist"
        ]
        
        for configPath in userConfigPaths {
            if FileManager.default.fileExists(atPath: configPath) {
                return configPath
            }
        }
        
        return nil
    }
    
    static func validateOpenCoreConfig(_ config: [String: Any]) -> (isValid: Bool, errors: [String]) {
        print("🔍 Validating OpenCore configuration...")
        
        var errors: [String] = []
        var isValid = true
        
        // Check for required top-level keys
        let requiredKeys = ["ACPI", "Booter", "DeviceProperties", "Kernel", "Misc", "NVRAM", "PlatformInfo", "UEFI"]
        for key in requiredKeys {
            if config[key] == nil {
                errors.append("Missing required section: \(key)")
                isValid = false
            }
        }
        
        // Check ACPI section
        if let acpi = config["ACPI"] as? [String: Any] {
            if let add = acpi["Add"] as? [[String: Any]], add.isEmpty {
                errors.append("ACPI/Add array is empty")
            }
            if let patch = acpi["Patch"] as? [[String: Any]], patch.isEmpty {
                print("⚠️ ACPI/Patch array is empty (this might be intentional)")
            }
        }
        
        // Check Kernel section
        if let kernel = config["Kernel"] as? [String: Any] {
            if let add = kernel["Add"] as? [[String: Any]], add.isEmpty {
                errors.append("Kernel/Add array is empty (no kexts)")
                isValid = false
            }
        }
        
        // Check UEFI section
        if let uefi = config["UEFI"] as? [String: Any] {
            if let drivers = uefi["Drivers"] as? [[String: Any]], drivers.isEmpty {
                errors.append("UEFI/Drivers array is empty")
                isValid = false
            }
        }
        
        if isValid {
            print("✅ OpenCore config validation passed")
        } else {
            print("❌ OpenCore config validation failed: \(errors.joined(separator: ", "))")
        }
        
        return (isValid, errors)
    }
    
    static func backupOpenCoreConfig() -> String? {
        print("💾 Creating OpenCore config backup...")
        
        guard let config = getOpenCoreConfig() else {
            print("❌ No OpenCore config found to backup")
            return nil
        }
        
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .medium)
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .replacingOccurrences(of: " ", with: "_")
        
        let backupDir = "\(FileManager.default.homeDirectoryForCurrentUser.path)/Documents/OpenCore/Backups"
        let backupPath = "\(backupDir)/config_backup_\(timestamp).plist"
        
        // Create backup directory if it doesn't exist
        try? FileManager.default.createDirectory(atPath: backupDir, withIntermediateDirectories: true, attributes: nil)
        
        do {
            let data = try PropertyListSerialization.data(fromPropertyList: config, format: .xml, options: 0)
            try data.write(to: URL(fileURLWithPath: backupPath))
            print("✅ Config backed up to: \(backupPath)")
            return backupPath
        } catch {
            print("❌ Failed to create backup: \(error)")
            return nil
        }
    }
    
    static func restoreOpenCoreConfig(from path: String) -> Bool {
        print("🔄 Restoring OpenCore config from backup: \(path)")
        
        guard FileManager.default.fileExists(atPath: path) else {
            print("❌ Backup file not found: \(path)")
            return false
        }
        
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: path))
            guard let config = try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] else {
                print("❌ Failed to parse backup file")
                return false
            }
            
            // Validate the backup
            let validation = validateOpenCoreConfig(config)
            if !validation.isValid {
                print("❌ Backup validation failed: \(validation.errors.joined(separator: ", "))")
                return false
            }
            
            // Save the config
            return saveOpenCoreConfig(config)
            
        } catch {
            print("❌ Failed to restore backup: \(error)")
            return false
        }
    }
    
    static func getOpenCoreVersion() -> String? {
        print("🔍 Getting OpenCore version...")
        
        // Try NVRAM first
        let nvramResult = runCommand("nvram 4D1FDA02-38C7-4A6A-9CC6-4BCCA8B30102:opencore-version 2>/dev/null || echo ''")
        if !nvramResult.output.isEmpty && !nvramResult.output.contains("error") {
            let version = nvramResult.output.trimmingCharacters(in: .whitespacesAndNewlines)
            print("✅ OpenCore version from NVRAM: \(version)")
            return version
        }
        
        // Try to read from EFI
        let mountResult = mountEFIForConfig()
        
        if !mountResult.output.isEmpty {
            let efiMountPath = mountResult.output.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Check for OpenCore.efi
            let versionResult = runCommand("""
            if [ -f "\(efiMountPath)/EFI/OC/OpenCore.efi" ]; then
                strings "\(efiMountPath)/EFI/OC/OpenCore.efi" | grep -i 'opencore.*version' | head -1
            fi
            """)
            
            // Unmount EFI
            _ = runCommand("diskutil unmount '\(efiMountPath)' 2>/dev/null")
            
            if !versionResult.output.isEmpty {
                print("✅ OpenCore version from EFI: \(versionResult.output)")
                return versionResult.output.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        
        print("❌ Could not determine OpenCore version")
        return nil
    }
    
    // MARK: - OpenCore Utilities
    
    static func checkOpenCoreBootStatus() -> (isBooted: Bool, details: String) {
        print("🔍 Checking OpenCore boot status...")
        
        let bootloader = detectBootloader()
        var details = "Bootloader: \(bootloader.name)\nVersion: \(bootloader.version)\nMode: \(bootloader.mode)"
        
        if bootloader.name.contains("OpenCore") {
            // Get additional OpenCore details
            let secureBoot = runCommand("nvram 7C436110-AB2A-4BBB-A880-FE41995C9F82:SecureBootModel 2>/dev/null || echo 'Disabled'")
            details += "\nSecure Boot: \(secureBoot.output.trimmingCharacters(in: .whitespacesAndNewlines))"
            
            let bootArgs = runCommand("nvram boot-args 2>/dev/null || echo 'None'")
            details += "\nBoot Args: \(bootArgs.output.trimmingCharacters(in: .whitespacesAndNewlines))"
            
            print("✅ System appears to be booted with OpenCore")
            return (true, details)
        }
        
        print("❌ System not booted with OpenCore")
        return (false, details)
    }
    
    static func getOpenCoreDrivers() -> [String] {
        print("🔍 Getting OpenCore drivers...")
        
        var drivers: [String] = []
        
        // Try to mount EFI and read drivers
        let mountResult = mountEFIForConfig()
        if !mountResult.output.isEmpty {
            let efiMountPath = mountResult.output.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Check OC drivers directory
            let driversResult = runCommand("""
            if [ -d "\(efiMountPath)/EFI/OC/Drivers" ]; then
                ls "\(efiMountPath)/EFI/OC/Drivers"/*.efi 2>/dev/null | xargs -n1 basename
            fi
            """)
            
            // Unmount EFI
            _ = runCommand("diskutil unmount '\(efiMountPath)' 2>/dev/null")
            
            if !driversResult.output.isEmpty {
                drivers = driversResult.output.components(separatedBy: "\n").filter { !$0.isEmpty }
                print("✅ Found \(drivers.count) OpenCore drivers")
            }
        }
        
        return drivers
    }
    
    static func getOpenCoreKexts() -> [String] {
        print("🔍 Getting OpenCore kexts...")
        
        var kexts: [String] = []
        
        // Try to mount EFI and read kexts
        let mountResult = mountEFIForConfig()
        if !mountResult.output.isEmpty {
            let efiMountPath = mountResult.output.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Check OC kexts directory
            let kextsResult = runCommand("""
            if [ -d "\(efiMountPath)/EFI/OC/Kexts" ]; then
                ls -d "\(efiMountPath)/EFI/OC/Kexts"/*.kext 2>/dev/null | xargs -n1 basename
            fi
            """)
            
            // Unmount EFI
            _ = runCommand("diskutil unmount '\(efiMountPath)' 2>/dev/null")
            
            if !kextsResult.output.isEmpty {
                kexts = kextsResult.output.components(separatedBy: "\n").filter { !$0.isEmpty }
                print("✅ Found \(kexts.count) OpenCore kexts")
            }
        }
        
        return kexts
    }
    
    // MARK: - OpenCore Config Editor Helper Methods
    
    static func createDefaultOpenCoreConfig() -> [String: Any] {
        print("📝 Creating default OpenCore configuration...")
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        _ = dateFormatter.string(from: Date())
        
        let defaultConfig: [String: Any] = [
            "ACPI": [
                "Add": [],
                "Delete": [],
                "Patch": [],
                "Quirks": [
                    "FadtEnableReset": false,
                    "NormalizeHeaders": false,
                    "RebaseRegions": false,
                    "ResetHwSig": false,
                    "ResetLogoStatus": false
                ]
            ],
            "Booter": [
                "MmioWhitelist": [],
                "Patch": [],
                "Quirks": [
                    "AvoidRuntimeDefrag": true,
                    "DevirtualiseMmio": false,
                    "DisableSingleUser": false,
                    "DisableVariableWrite": false,
                    "DiscardHibernateMap": false,
                    "EnableSafeModeSlide": true,
                    "EnableWriteUnprotector": true,
                    "ForceExitBootServices": false,
                    "ProtectCsmRegion": false,
                    "ProvideCustomSlide": true,
                    "ProvideMaxSlide": 0,
                    "RebuildAppleMemoryMap": true,
                    "SetupVirtualMap": true,
                    "SignalAppleOS": false,
                    "SyncRuntimePermissions": true
                ]
            ],
            "DeviceProperties": [:],
            "Kernel": [
                "Add": [],
                "Block": [],
                "Emulate": [:],
                "Force": [],
                "Patch": [],
                "Quirks": [
                    "AppleCpuPmCfgLock": false,
                    "AppleXcpmCfgLock": false,
                    "AppleXcpmExtraMsrs": false,
                    "AppleXcpmForceBoost": false,
                    "CustomPciSerialDevice": false,
                    "DisableIoMapper": false,
                    "DisableLinkeditJettison": true,
                    "DisableRtcChecksum": false,
                    "ExtendBTFeatureFlags": false,
                    "ExternalDiskIcons": false,
                    "ForceAquantiaEthernet": false,
                    "ForceSecureBootScheme": false,
                    "IncreasePciBarSize": false,
                    "LapicKernelPanic": false,
                    "LegacyCommpage": false,
                    "PanicNoKextDump": true,
                    "PowerTimeoutKernelPanic": true,
                    "ThirdPartyDrives": false,
                    "XhciPortLimit": false
                ],
                "Scheme": [
                    "CustomKernel": false,
                    "FuzzyMatch": true
                ]
            ],
            "Misc": [
                "Boot": [
                    "ConsoleAttributes": 0,
                    "HibernateMode": "None",
                    "HideAuxiliary": true,
                    "PickerAttributes": 0,
                    "PickerAudioAssist": false,
                    "PickerMode": "Builtin",
                    "PickerVariant": "Auto",
                    "PollAppleHotKeys": true,
                    "ShowPicker": true,
                    "TakeoffDelay": 0,
                    "Timeout": 5
                ],
                "Debug": [
                    "AppleDebug": false,
                    "ApplePanic": false,
                    "DisableWatchDog": false,
                    "DisplayDelay": 0,
                    "DisplayLevel": 0,
                    "SerialInit": false,
                    "SysReport": false,
                    "Target": 0
                ],
                "Security": [
                    "AllowNvramReset": true,
                    "AllowSetDefault": true,
                    "ApECID": 0,
                    "AuthRestart": false,
                    "BlacklistAppleUpdate": true,
                    "BootProtect": "None",
                    "DmgLoading": "Signed",
                    "ExposeSensitiveData": 6,
                    "HaltLevel": 2147483648,
                    "PasswordHash": Data(),
                    "PasswordSalt": Data(),
                    "Vault": "Optional",
                    "ScanPolicy": 0
                ],
                "Tools": []
            ],
            "NVRAM": [
                "Add": [
                    "4D1EDE05-38C7-4A6A-9CC6-4BCCA8B38C14": [
                        "DefaultBackgroundColor": [0, 0, 0]
                    ],
                    "7C436110-AB2A-4BBB-A880-FE41995C9F82": [
                        "boot-args": "",
                        "csr-active-config": "00000000",
                        "prev-lang:kbd": "en-US:0"
                    ]
                ],
                "Delete": [],
                "LegacyEnable": false,
                "LegacyOverwrite": false,
                "LegacySchema": [:]
            ],
            "PlatformInfo": [
                "Automatic": true,
                "CustomMemory": false,
                "Generic": [
                    "AdviseFeatures": false,
                    "MLB": "",
                    "MaxBIOSVersion": false,
                    "ProcessorType": 0,
                    "ROM": Data(),
                    "SpoofVendor": true,
                    "SystemMemoryStatus": "Auto",
                    "SystemProductName": "iMacPro1,1",
                    "SystemSerialNumber": "",
                    "SystemUUID": ""
                ],
                "UpdateDataHub": true,
                "UpdateNVRAM": true,
                "UpdateSMBIOS": true,
                "UpdateSMBIOSMode": "Create"
            ],
            "UEFI": [
                "Audio": [
                    "AudioCodec": 0,
                    "AudioDevice": "",
                    "AudioOutMask": 0,
                    "AudioSupport": false,
                    "MaximumGain": -1,
                    "MinimumVolume": -1,
                    "PlayChime": "Auto",
                    "ResetTrafficClass": false
                ],
                "ConnectDrivers": true,
                "Drivers": [],
                "Input": [
                    "KeyFiltering": false,
                    "KeyForgetThreshold": 5,
                    "KeyMergeThreshold": 2,
                    "KeySupport": true,
                    "KeySupportMode": "Auto",
                    "KeySwap": false,
                    "PointerSupport": false,
                    "PointerSupportMode": "ASUS",
                    "TimerResolution": 0
                ],
                "Output": [
                    "ClearScreenOnModeSwitch": false,
                    "ConsoleMode": "",
                    "DirectGopRendering": false,
                    "IgnoreTextInGraphics": false,
                    "ProvideConsoleGop": true,
                    "ReconnectOnResChange": false,
                    "ReplaceTabWithSpace": false,
                    "Resolution": "Max",
                    "SanitiseClearScreen": false,
                    "TextRenderer": "BuiltinGraphics",
                    "UgaPassThrough": false
                ],
                "ProtocolOverrides": [
                    "AppleAudio": false,
                    "AppleBootPolicy": false,
                    "AppleDebugLog": false,
                    "AppleEvent": false,
                    "AppleFramebufferInfo": false,
                    "AppleImageConversion": false,
                    "AppleKeyMap": false,
                    "AppleRtcRam": false,
                    "AppleSmcIo": false,
                    "AppleUserInterfaceTheme": false,
                    "DataHub": false,
                    "DeviceProperties": false,
                    "FirmwareVolume": false,
                    "HashServices": false,
                    "OSInfo": false,
                    "UnicodeCollation": false
                ],
                "Quirks": [
                    "ActivateHpetSupport": false,
                    "EnableVectorAcceleration": false,
                    "ExitBootServicesDelay": 0,
                    "ForceOcWriteFlash": false,
                    "ForgeUefiSupport": false,
                    "IgnoreInvalidFlexRatio": false,
                    "ReleaseUsbOwnership": false,
                    "RequestBootVarRouting": true,
                    "ResizeGpuBars": -1,
                    "TscSyncTimeout": 0,
                    "UnblockFsConnect": false
                ],
                "ReservedMemory": []
            ]
        ]
        
        print("✅ Default OpenCore config created")
        return defaultConfig
    }
    
    // MARK: - Drive Management Functions
    
    static func getAllDrives() -> [DriveInfo] {
        print("🔍 Getting all drives...")
        
        let drivesResult = runCommand("""
        diskutil list -plist 2>/dev/null | plutil -convert json -o - - | python3 -c "
        import json
        import sys
        import subprocess
        import os
        
        data = json.load(sys.stdin)
        drives = []
        
        # Get mount info first
        mount_info = {}
        try:
            mount_output = subprocess.check_output(['mount'], universal_newlines=True)
            for line in mount_output.split('\\n'):
                if '/dev/disk' in line:
                    parts = line.split()
                    if len(parts) >= 3:
                        device = parts[0].replace('/dev/', '')
                        mount_point = parts[2]
                        mount_info[device] = mount_point
        except:
            pass
        
        # Get EFI partitions
        efi_partitions = set()
        try:
            efi_output = subprocess.check_output(['diskutil', 'list'], universal_newlines=True)
            for line in efi_output.split('\\n'):
                if 'EFI' in line and 'disk' in line:
                    parts = line.split()
                    for part in parts:
                        if 'disk' in part and 's' in part:
                            efi_partitions.add(part)
        except:
            pass
        
        for disk in data.get('AllDisksAndPartitions', []):
            # Main disk info
            disk_name = disk.get('VolumeName', '')
            identifier = disk.get('DeviceIdentifier', '')
            size = disk.get('Size', 0)
            size_gb = f\"{size / 1_000_000_000:.1f} GB\" if size > 0 else \"Unknown\"
            mount_point = disk.get('MountPoint', '')
            
            # Determine disk type
            is_internal = 'internal' in disk.get('DeviceIdentifier', '').lower() or 'Internal' in str(disk.get('DeviceTreePath', ''))
            is_efi = identifier in efi_partitions or disk_name == 'EFI'
            
            # Check if mounted
            is_mounted = mount_point != '' or mount_info.get(identifier, '') != ''
            if not is_mounted and identifier in mount_info:
                mount_point = mount_info[identifier]
                is_mounted = True
            
            # Get disk type
            content = disk.get('Content', '')
            type_str = 'Unknown'
            if 'Apple_APFS' in content:
                type_str = 'APFS'
            elif 'Apple_HFS' in content:
                type_str = 'HFS+'
            elif 'EFI' in content:
                type_str = 'EFI'
            elif 'Microsoft Basic Data' in content:
                type_str = 'FAT32/NTFS'
            
            # Get partitions
            partitions = []
            for part in disk.get('Partitions', []):
                part_name = part.get('VolumeName', part.get('DeviceIdentifier', ''))
                if part_name:
                    partitions.append(part_name)
            
            drives.append({
                'name': disk_name,
                'identifier': identifier,
                'size': size_gb,
                'type': type_str,
                'mountPoint': mount_point,
                'isInternal': is_internal,
                'isEFI': is_efi,
                'partitions': partitions,
                'isMounted': is_mounted
            })
        
        print(json.dumps(drives))
        " 2>/dev/null || echo '[]'
        """)
        
        do {
            if let jsonData = drivesResult.output.data(using: .utf8) {
                let jsonArray = try JSONSerialization.jsonObject(with: jsonData, options: []) as? [[String: Any]] ?? []
                
                var drives: [DriveInfo] = []
                for dict in jsonArray {
                    let drive = DriveInfo(
                        name: dict["name"] as? String ?? "",
                        identifier: dict["identifier"] as? String ?? "",
                        size: dict["size"] as? String ?? "Unknown",
                        type: dict["type"] as? String ?? "Unknown",
                        mountPoint: dict["mountPoint"] as? String ?? "",
                        isInternal: dict["isInternal"] as? Bool ?? false,
                        isEFI: dict["isEFI"] as? Bool ?? false,
                        partitions: dict["partitions"] as? [String] ?? [],
                        isMounted: dict["isMounted"] as? Bool ?? false,
                        isSelectedForMount: false,
                        isSelectedForUnmount: false
                    )
                    drives.append(drive)
                }
                
                print("✅ Found \(drives.count) drives")
                return drives
            }
        } catch {
            print("❌ Error parsing drives JSON: \(error)")
        }
        
        return []
    }
    
    static func mountSelectedDrives(drives: [DriveInfo]) -> (success: Bool, message: String) {
        print("🔧 Mounting \(drives.count) drives...")
        
        var mountedCount = 0
        var errors: [String] = []
        
        for drive in drives {
            print("📂 Mounting: \(drive.identifier) - \(drive.name)")
            
            let result = runCommand("diskutil mount /dev/\(drive.identifier) 2>&1")
            
            if result.success {
                mountedCount += 1
                print("✅ Successfully mounted: \(drive.identifier)")
            } else {
                let errorMsg = "Failed to mount \(drive.identifier): \(result.output)"
                errors.append(errorMsg)
                print("❌ \(errorMsg)")
            }
        }
        
        if mountedCount == drives.count {
            return (true, "Successfully mounted all \(mountedCount) drives")
        } else if mountedCount > 0 {
            return (false, "Mounted \(mountedCount) of \(drives.count) drives. Errors: \(errors.joined(separator: "; "))")
        } else {
            return (false, "Failed to mount any drives. Errors: \(errors.joined(separator: "; "))")
        }
    }
    
    static func unmountSelectedDrives(drives: [DriveInfo]) -> (success: Bool, message: String) {
        print("🔧 Unmounting \(drives.count) drives...")
        
        var unmountedCount = 0
        var errors: [String] = []
        
        for drive in drives {
            print("📂 Unmounting: \(drive.identifier) - \(drive.name)")
            
            let result = runCommand("diskutil unmount /dev/\(drive.identifier) 2>&1")
            
            if result.success {
                unmountedCount += 1
                print("✅ Successfully unmounted: \(drive.identifier)")
            } else {
                let errorMsg = "Failed to unmount \(drive.identifier): \(result.output)"
                errors.append(errorMsg)
                print("❌ \(errorMsg)")
            }
        }
        
        if unmountedCount == drives.count {
            return (true, "Successfully unmounted all \(unmountedCount) drives")
        } else if unmountedCount > 0 {
            return (false, "Unmounted \(unmountedCount) of \(drives.count) drives. Errors: \(errors.joined(separator: "; "))")
        } else {
            return (false, "Failed to unmount any drives. Errors: \(errors.joined(separator: "; "))")
        }
    }
    
    static func mountAllExternalDrives() -> (success: Bool, message: String) {
        print("🔧 Mounting all external drives...")
        
        let result = runCommand("""
        count=0
        for disk in $(diskutil list | grep -E 'external|USB|FireWire|Thunderbolt' | grep -oE 'disk[0-9]+' | sort -u); do
            if diskutil mountDisk /dev/$disk 2>/dev/null; then
                echo "Mounted: $disk"
                ((count++))
            fi
        done
        echo "Total mounted: $count"
        """)
        
        if result.success {
            let count = Int(result.output.components(separatedBy: "Total mounted: ").last ?? "0") ?? 0
            return (true, "Mounted \(count) external drives")
        }
        
        return (false, "Failed to mount external drives: \(result.output)")
    }
    
    static func unmountAllExternalDrives() -> (success: Bool, message: String) {
        print("🔧 Unmounting all external drives...")
        
        let result = runCommand("""
        count=0
        for disk in $(diskutil list | grep -E 'external|USB|FireWire|Thunderbolt' | grep -oE 'disk[0-9]+' | sort -u); do
            if diskutil unmountDisk /dev/$disk 2>/dev/null; then
                echo "Unmounted: $disk"
                ((count++))
            fi
        done
        echo "Total unmounted: $count"
        """)
        
        if result.success {
            let count = Int(result.output.components(separatedBy: "Total unmounted: ").last ?? "0") ?? 0
            return (true, "Unmounted \(count) external drives")
        }
        
        return (false, "Failed to unmount external drives: \(result.output)")
    }
    
    static func mountEFIDrive(_ identifier: String) -> (success: Bool, message: String) {
        print("🔧 Mounting EFI drive: \(identifier)")
        
        let result = runCommand("diskutil mount /dev/\(identifier) 2>&1")
        
        if result.success {
            return (true, "Successfully mounted EFI partition: \(identifier)")
        }
        
        return (false, "Failed to mount EFI: \(result.output)")
    }
    
    // MARK: - Other utility functions
    
    static func getBootLog() -> String {
        print("📝 Getting boot log...")
        
        let result = runCommand("log show --predicate 'eventMessage contains \"boot\"' --last 1h --style syslog 2>/dev/null | head -100")
        
        if !result.output.isEmpty {
            print("✅ Retrieved boot log")
            return result.output
        }
        
        return "No boot log available"
    }
    
    static func getKernelExtensions() -> [String] {
        print("🔍 Getting loaded kernel extensions...")
        
        let result = runCommand("kextstat | grep -v com.apple | head -20")
        
        if !result.output.isEmpty {
            let kexts = result.output.components(separatedBy: "\n").filter { !$0.isEmpty }
            print("✅ Found \(kexts.count) third-party kexts")
            return kexts
        }
        
        return []
    }
    
    static func clearNVRAM() -> (success: Bool, message: String) {
        print("🧹 Clearing NVRAM...")
        
        let result = runCommandWithPrivileges("nvram -c")
        
        if result.success {
            return (true, "NVRAM cleared successfully. Please restart your computer.")
        }
        
        return (false, "Failed to clear NVRAM: \(result.output)")
    }
}