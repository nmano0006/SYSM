struct ShellHelper {
    // ... keep all existing functions above ...
    
    // MARK: - Enhanced System Information Gathering
    
    static func getCompleteSystemInfo() -> SystemInfo {
        var info = SystemInfo()
        
        // macOS Version
        let versionResult = runCommand("sw_vers -productVersion 2>/dev/null || echo 'Unknown'")
        info.macOSVersion = versionResult.success ? versionResult.output.trimmingCharacters(in: .whitespacesAndNewlines) : "Unknown"
        
        // Build Number
        let buildResult = runCommand("sw_vers -buildVersion 2>/dev/null || echo 'Unknown'")
        info.buildNumber = buildResult.success ? buildResult.output.trimmingCharacters(in: .whitespacesAndNewlines) : "Unknown"
        
        // Kernel Version
        let kernelResult = runCommand("uname -r 2>/dev/null || echo 'Unknown'")
        info.kernelVersion = kernelResult.success ? kernelResult.output.trimmingCharacters(in: .whitespacesAndNewlines) : "Unknown"
        
        // Model Identifier
        let modelResult = runCommand("sysctl -n hw.model 2>/dev/null || echo 'Unknown'")
        info.modelIdentifier = modelResult.success ? modelResult.output.trimmingCharacters(in: .whitespacesAndNewlines) : "Unknown"
        
        // Processor
        let cpuResult = runCommand("sysctl -n machdep.cpu.brand_string 2>/dev/null || echo 'Unknown'")
        info.processor = cpuResult.success ? cpuResult.output.trimmingCharacters(in: .whitespacesAndNewlines) : "Unknown"
        
        // Processor Details
        let cpuCoresResult = runCommand("sysctl -n hw.ncpu 2>/dev/null || echo 'Unknown'")
        let cpuCores = cpuCoresResult.success ? cpuCoresResult.output.trimmingCharacters(in: .whitespacesAndNewlines) : "Unknown"
        let cpuThreadsResult = runCommand("sysctl -n machdep.cpu.thread_count 2>/dev/null || echo 'Unknown'")
        let cpuThreads = cpuThreadsResult.success ? cpuThreadsResult.output.trimmingCharacters(in: .whitespacesAndNewlines) : "Unknown"
        info.processorDetails = "\(cpuCores) Cores, \(cpuThreads) Threads"
        
        // Memory
        let memResult = runCommand("sysctl -n hw.memsize 2>/dev/null")
        if memResult.success, let bytes = Int64(memResult.output.trimmingCharacters(in: .whitespacesAndNewlines)) {
            let gb = Double(bytes) / 1_073_741_824
            info.memory = String(format: "%.0f GB", gb)
        } else {
            info.memory = "Unknown"
        }
        
        // Boot Mode
        let bootResult = runCommand("""
        if diskutil info / 2>/dev/null | grep -q 'Volume Name:.*[Uu][Ss][Bb]'; then
            echo "USB Boot"
        else
            echo "Internal Boot"
        fi
        """)
        info.bootMode = bootResult.output.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // GPU Information
        info.gpuInfo = getGPUInfo()
        
        // Network Information
        info.networkInfo = getNetworkInfo()
        
        // Storage Controllers
        info.storageInfo = getStorageControllerInfo()
        
        // USB Information
        info.usbInfo = getUSBInfo()
        
        // Thunderbolt Information
        info.thunderboltInfo = getThunderboltInfo()
        
        // Ethernet Controller
        info.ethernetInfo = getEthernetControllerInfo()
        
        // NVMe Controller
        info.nvmeInfo = getNVMeControllerInfo()
        
        // AHCI/SATA Controller
        info.ahciInfo = getAHCIControllerInfo()
        
        // Audio Information
        info.audioInfo = getAudioInfo()
        
        // Bluetooth Information
        info.bluetoothInfo = getBluetoothInfo()
        
        // PCI Devices
        info.pciDevices = getPCIDevices()
        
        // Wireless Network Controller
        info.wirelessInfo = getWirelessInfo()
        
        // USB eXtensible Host-Controller
        info.usbXHCInfo = getUSBXHCInfo()
        
        // System UUID
        let uuidResult = runCommand("""
        system_profiler SPHardwareDataType 2>/dev/null | grep 'Hardware UUID' | awk '{print $3}' || echo 'Unknown'
        """)
        info.systemUUID = uuidResult.success ? uuidResult.output.trimmingCharacters(in: .whitespacesAndNewlines) : "Unknown"
        
        // Boot ROM Version
        let bootROMResult = runCommand("""
        system_profiler SPHardwareDataType 2>/dev/null | grep 'Boot ROM Version' | awk -F': ' '{print $2}' || echo 'Unknown'
        """)
        info.bootROMVersion = bootROMResult.success ? bootROMResult.output.trimmingCharacters(in: .whitespacesAndNewlines) : "Unknown"
        
        // SMC Version
        let smcResult = runCommand("""
        system_profiler SPHardwareDataType 2>/dev/null | grep 'SMC Version' | awk -F': ' '{print $2}' || echo 'Unknown'
        """)
        info.smcVersion = smcResult.success ? smcResult.output.trimmingCharacters(in: .whitespacesAndNewlines) : "Unknown"
        
        // Serial Number
        let serialResult = runCommand("""
        system_profiler SPHardwareDataType 2>/dev/null | grep 'Serial Number' | awk -F': ' '{print $2}' || echo 'Unknown'
        """)
        info.serialNumber = serialResult.success ? serialResult.output.trimmingCharacters(in: .whitespacesAndNewlines) : "Unknown"
        
        // Platform UUID
        let platformUUIDResult = runCommand("""
        ioreg -rd1 -c IOPlatformExpertDevice 2>/dev/null | grep IOPlatformUUID | awk -F'\"' '{print $4}' | head -1 || echo 'Unknown'
        """)
        info.platformUUID = platformUUIDResult.success ? platformUUIDResult.output.trimmingCharacters(in: .whitespacesAndNewlines) : "Unknown"
        
        return info
    }
    
    static func getGPUInfo() -> String {
        let result = runCommand("""
        system_profiler SPDisplaysDataType 2>/dev/null | grep -E '(Chipset Model:|VRAM .Total:|Vendor:|Metal:|Displays:|Resolution:|Framebuffer Depth:|Mirror:|Online:)' | head -30 || echo 'No GPU information available'
        """)
        
        if result.success {
            let lines = result.output.components(separatedBy: "\n").filter { !$0.isEmpty }
            if lines.isEmpty {
                return "No GPU information available"
            }
            
            var gpuInfo = ""
            for line in lines {
                gpuInfo += "\(line)\n"
            }
            return gpuInfo.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        // Alternative method using ioreg
        let ioregResult = runCommand("""
        ioreg -l 2>/dev/null | grep -i 'vendor-id\\|device-id\\|model\\|ATY\\|NVDA' | head -10 || echo 'GPU: Not detected or using integrated graphics'
        """)
        
        if ioregResult.success && !ioregResult.output.isEmpty {
            return "GPU detected via IORegistry:\n\(ioregResult.output)"
        }
        
        return "GPU: Not detected or using integrated graphics"
    }
    
    static func getNetworkInfo() -> String {
        let result = runCommand("""
        system_profiler SPNetworkDataType 2>/dev/null | grep -E '(Type:|Hardware:|BSD Device Name:|IPv4 Addresses:|State:|Wi-Fi:|Ethernet:)' | head -40 || echo 'No network information available'
        """)
        
        if result.success {
            let lines = result.output.components(separatedBy: "\n").filter { !$0.isEmpty }
            if lines.isEmpty {
                return "No network information available"
            }
            
            var networkInfo = ""
            for (index, line) in lines.enumerated() {
                if index < 30 {
                    networkInfo += "\(line)\n"
                }
            }
            return networkInfo.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        return "Network: Unknown"
    }
    
    static func getStorageControllerInfo() -> String {
        let result = runCommand("""
        system_profiler SPSerialATADataType 2>/dev/null | grep -E '(Model:|Revision:|Physical Interconnect:|Negotiated Link Speed:|Bay Name:|Volumes:)' | head -25 || echo 'No SATA controller information'
        """)
        
        if result.success {
            let output = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
            return output.isEmpty ? "No SATA controller information" : output
        }
        
        // Check for NVMe
        let nvmeResult = runCommand("""
        system_profiler SPNVMeDataType 2>/dev/null | grep -E '(Model:|Revision:|Link Width:|Link Speed:)' | head -10 || echo 'No NVMe information'
        """)
        
        if nvmeResult.success && !nvmeResult.output.isEmpty {
            return nvmeResult.output.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        return "Storage Controllers: Not detected"
    }
    
    static func getUSBInfo() -> String {
        let result = runCommand("""
        system_profiler SPUSBDataType 2>/dev/null | grep -E '(Host Controller Location:|Vendor ID:|Product ID:|Speed:|Manufacturer:|Location ID:|Product Version:)' | head -40 || echo 'No USB information available'
        """)
        
        if result.success {
            let lines = result.output.components(separatedBy: "\n").filter { !$0.isEmpty }
            if lines.isEmpty {
                return "No USB information available"
            }
            
            var usbInfo = ""
            for (index, line) in lines.enumerated() {
                if index < 30 {
                    usbInfo += "\(line)\n"
                }
            }
            return usbInfo.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        return "USB: Not detected"
    }
    
    static func getThunderboltInfo() -> String {
        let result = runCommand("""
        system_profiler SPThunderboltDataType 2>/dev/null | grep -E '(Connected:|Device Name:|Vendor Name:|UID:|Firmware Version:|Port:|Status:)' | head -25 || echo 'No Thunderbolt devices detected'
        """)
        
        if result.success {
            let output = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
            return output.isEmpty ? "No Thunderbolt devices detected" : output
        }
        
        return "Thunderbolt: Not detected or not available"
    }
    
    static func getEthernetControllerInfo() -> String {
        let result = runCommand("""
        system_profiler SPNetworkDataType 2>/dev/null | grep -B3 -A3 'Ethernet' | grep -E '(Type:|Hardware:|BSD Name:|IPv4:|State:)' | head -20 || echo 'No Ethernet controller detected'
        """)
        
        if result.success {
            let lines = result.output.components(separatedBy: "\n").filter { !$0.isEmpty }
            if lines.isEmpty {
                return "No Ethernet controller detected"
            }
            
            var ethernetInfo = ""
            for line in lines {
                ethernetInfo += "\(line)\n"
            }
            return ethernetInfo.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        // Check via network interfaces
        let interfaceResult = runCommand("""
        ifconfig 2>/dev/null | grep -E '^(en[0-9]|eth[0-9])' | head -5 || echo 'No Ethernet interfaces'
        """)
        
        if interfaceResult.success && !interfaceResult.output.isEmpty {
            return "Ethernet interfaces detected:\n\(interfaceResult.output)"
        }
        
        return "Ethernet: Not detected"
    }
    
    static func getNVMeControllerInfo() -> String {
        let result = runCommand("""
        system_profiler SPNVMeDataType 2>/dev/null | grep -E '(Model:|Revision:|Link Width:|Link Speed:|Capacity:|Physical Interconnect:)' | head -15 || echo 'No NVMe controller information'
        """)
        
        if result.success && !result.output.isEmpty {
            return result.output.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        // Check via diskutil
        let diskutilResult = runCommand("""
        diskutil list 2>/dev/null | grep -i 'nvme' | head -5 || echo 'No NVMe devices found'
        """)
        
        if diskutilResult.success && !diskutilResult.output.isEmpty {
            return "NVMe devices detected via diskutil:\n\(diskutilResult.output)"
        }
        
        return "NVMe Controller: Not detected"
    }
    
    static func getAHCIControllerInfo() -> String {
        let result = runCommand("""
        system_profiler SPSerialATADataType 2>/dev/null | grep -i 'AHCI\\|SATA' | head -10 || echo 'No AHCI/SATA information'
        """)
        
        if result.success && !result.output.isEmpty {
            return result.output.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        // Check via IORegistry
        let ioregResult = runCommand("""
        ioreg -p IODeviceTree -n SATA -r 2>/dev/null | grep -i 'class\\|name' | head -5 || echo 'No AHCI/SATA controller found'
        """)
        
        if ioregResult.success && !ioregResult.output.isEmpty {
            return "AHCI/SATA Controller detected via IORegistry:\n\(ioregResult.output)"
        }
        
        return "AHCI Controller: Not detected or using NVMe"
    }
    
    static func getAudioInfo() -> String {
        let result = runCommand("""
        system_profiler SPAudioDataType 2>/dev/null | grep -E '(Default Output Device:|Default System Output Device:|Manufacturer:|Output Source:|Sample Rate:)' | head -15 || echo 'No audio output devices detected'
        """)
        
        if result.success {
            let output = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
            return output.isEmpty ? "No audio output devices detected" : output
        }
        
        return "Audio: Not detected"
    }
    
    static func getBluetoothInfo() -> String {
        let result = runCommand("""
        system_profiler SPBluetoothDataType 2>/dev/null | grep -E '(Apple Bluetooth Software Version:|State:|Discoverable:|Connectable:|Address:|Name:)' | head -15 || echo 'Bluetooth not available'
        """)
        
        if result.success {
            let output = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
            return output.isEmpty ? "Bluetooth not available" : output
        }
        
        return "Bluetooth: Not detected"
    }
    
    static func getPCIDevices() -> String {
        let result = runCommand("""
        system_profiler SPPCIDataType 2>/dev/null | grep -E '(Name:|Type:|Driver Installed:|Link Width:|Link Speed:|Slot:)' | head -50 || echo 'No PCI device information available'
        """)
        
        if result.success {
            let lines = result.output.components(separatedBy: "\n").filter { !$0.isEmpty }
            if lines.isEmpty {
                return "No PCI device information available"
            }
            
            var pciInfo = ""
            for (index, line) in lines.enumerated() {
                if index < 40 {
                    pciInfo += "\(line)\n"
                }
            }
            return pciInfo.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        return "PCI Devices: Not detected"
    }
    
    static func getWirelessInfo() -> String {
        let result = runCommand("""
        system_profiler SPNetworkDataType 2>/dev/null | grep -B2 -A2 'Wi-Fi\\|AirPort' | grep -E '(Type:|Hardware:|BSD Name:|State:|Supported PHY Modes:)' | head -15 || echo 'No wireless adapter detected'
        """)
        
        if result.success {
            let output = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
            return output.isEmpty ? "No wireless adapter detected" : output
        }
        
        // Check for Airport
        let airportResult = runCommand("""
        networksetup -listallhardwareports 2>/dev/null | grep -A2 'Wi-Fi\\|AirPort' || echo 'No wireless hardware found'
        """)
        
        if airportResult.success && !airportResult.output.isEmpty {
            return "Wireless Hardware:\n\(airportResult.output)"
        }
        
        return "Wireless Network Controller: Not detected"
    }
    
    static func getUSBXHCInfo() -> String {
        let result = runCommand("""
        ioreg -p IODeviceTree -n XHC -r 2>/dev/null | grep -i 'model\\|name\\|vendor-id\\|device-id' | head -10 || echo 'No XHC information'
        """)
        
        if result.success && !result.output.isEmpty {
            return "USB eXtensible Host-Controller (XHC) detected:\n\(result.output)"
        }
        
        // Alternative check
        let usbResult = runCommand("""
        system_profiler SPUSBDataType 2>/dev/null | grep -i 'xhci\\|extensible' | head -5 || echo 'No XHCI controller found'
        """)
        
        if usbResult.success && !usbResult.output.isEmpty {
            return "USB XHCI Controller:\n\(usbResult.output)"
        }
        
        return "USB eXtensible Host-Controller: Not specifically detected"
    }
    
    // ... keep rest of the file the same ...
}