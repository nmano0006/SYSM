// MARK: - Enhanced SSDT Generator View with Complete Motherboard List
struct SSDTGeneratorView: View {
    @Binding var showAlert: Bool
    @Binding var alertTitle: String
    @Binding var alertMessage: String
    @Binding var efiPath: String?
    
    @State private var selectedDeviceType = "CPU"
    @State private var cpuModel = "Intel Core i7"
    @State private var gpuModel = "AMD Radeon RX 580"
    @State private var motherboardModel = "Gigabyte Z390 AORUS PRO"
    @State private var usbPortCount = "15"
    @State private var useEC = true
    @State private var useAWAC = true
    @State private var usePLUG = true
    @State private var useXOSI = true
    @State private var useALS0 = true
    @State private var useHID = true
    @State private var customDSDTName = "DSDT.aml"
    @State private var isGenerating = false
    @State private var generationProgress = 0.0
    @State private var generatedSSDTs: [String] = []
    @State private var showAdvancedOptions = false
    @State private var acpiTableSource = "Auto-detect"
    @State private var selectedSSDTs: Set<String> = []
    @State private var outputPath = ""
    
    let deviceTypes = ["CPU", "GPU", "Motherboard", "USB", "Other"]
    let cpuModels = ["Intel Core i5", "Intel Core i7", "Intel Core i9", "AMD Ryzen 5", "AMD Ryzen 7", "AMD Ryzen 9", "Custom"]
    let gpuModels = ["AMD Radeon RX 580", "AMD Radeon RX 5700 XT", "NVIDIA GeForce GTX 1060", "NVIDIA GeForce RTX 2060", "Intel UHD Graphics 630", "Custom"]
    
    // COMPLETE MOTHERBOARD LIST for SSDT Generation
    let motherboardModels = [
        // Gigabyte
        "Gigabyte Z390 AORUS PRO",
        "Gigabyte Z390 AORUS ELITE",
        "Gigabyte Z390 AORUS MASTER",
        "Gigabyte Z390 DESIGNARE",
        "Gigabyte Z390 UD",
        "Gigabyte Z390 GAMING X",
        "Gigabyte Z390 M GAMING",
        "Gigabyte Z390 AORUS PRO WIFI",
        "Gigabyte Z390 AORUS ULTRA",
        "Gigabyte Z390 GAMING SLI",
        "Gigabyte Z390 AORUS XTREME",
        
        "Gigabyte Z490 AORUS PRO AX",
        "Gigabyte Z490 VISION G",
        "Gigabyte Z490 AORUS ELITE AC",
        "Gigabyte Z490 UD AC",
        "Gigabyte Z490 AORUS MASTER",
        "Gigabyte Z490I AORUS ULTRA",
        "Gigabyte Z490 AORUS XTREME",
        
        "Gigabyte Z590 AORUS PRO AX",
        "Gigabyte Z590 VISION G",
        "Gigabyte Z590 AORUS ELITE AX",
        "Gigabyte Z590 UD AC",
        "Gigabyte Z590 AORUS MASTER",
        
        "Gigabyte Z690 AORUS PRO",
        "Gigabyte Z690 AORUS ELITE AX",
        "Gigabyte Z690 GAMING X",
        "Gigabyte Z690 UD AX",
        
        "Gigabyte B360 AORUS GAMING 3",
        "Gigabyte B360M DS3H",
        "Gigabyte B360 HD3",
        
        "Gigabyte B460 AORUS PRO AC",
        "Gigabyte B460M DS3H",
        "Gigabyte B460M AORUS PRO",
        "Gigabyte B460 HD3",
        
        "Gigabyte B560 AORUS PRO AX",
        "Gigabyte B560M DS3H",
        "Gigabyte B560M AORUS ELITE",
        "Gigabyte B560 HD3",
        
        "Gigabyte B660 AORUS MASTER",
        "Gigabyte B660M DS3H AX",
        "Gigabyte B660M GAMING X AX",
        
        "Gigabyte H370 AORUS GAMING 3",
        "Gigabyte H370 HD3",
        "Gigabyte H370M DS3H",
        
        "Gigabyte H470 AORUS PRO AX",
        "Gigabyte H470M DS3H",
        
        "Gigabyte H510M S2H",
        "Gigabyte H510M H",
        "Gigabyte H510M DS2V",
        
        "Gigabyte H610M S2H",
        "Gigabyte H610M H DDR4",
        "Gigabyte H610M G DDR4",
        
        // ASUS
        "ASUS ROG MAXIMUS XI HERO",
        "ASUS ROG MAXIMUS XI FORMULA",
        "ASUS ROG MAXIMUS XI APEX",
        "ASUS ROG MAXIMUS XI GENE",
        "ASUS ROG STRIX Z390-E GAMING",
        "ASUS ROG STRIX Z390-F GAMING",
        "ASUS ROG STRIX Z390-H GAMING",
        "ASUS ROG STRIX Z390-I GAMING",
        "ASUS PRIME Z390-A",
        "ASUS PRIME Z390-P",
        "ASUS TUF Z390-PLUS GAMING",
        "ASUS TUF Z390-PRO GAMING",
        
        "ASUS ROG MAXIMUS XII HERO",
        "ASUS ROG MAXIMUS XII APEX",
        "ASUS ROG MAXIMUS XII FORMULA",
        "ASUS ROG STRIX Z490-E GAMING",
        "ASUS ROG STRIX Z490-F GAMING",
        "ASUS ROG STRIX Z490-I GAMING",
        "ASUS PRIME Z490-A",
        "ASUS PRIME Z490-P",
        "ASUS TUF Z490-PLUS GAMING",
        
        "ASUS ROG MAXIMUS XIII HERO",
        "ASUS ROG STRIX Z590-E GAMING",
        "ASUS ROG STRIX Z590-F GAMING",
        "ASUS ROG STRIX Z590-I GAMING",
        "ASUS PRIME Z590-A",
        "ASUS PRIME Z590-P",
        "ASUS TUF Z590-PLUS WIFI",
        
        "ASUS ROG MAXIMUS Z690 HERO",
        "ASUS ROG STRIX Z690-E GAMING WIFI",
        "ASUS ROG STRIX Z690-F GAMING WIFI",
        "ASUS ROG STRIX Z690-I GAMING WIFI",
        "ASUS PRIME Z690-A",
        "ASUS PRIME Z690-P",
        "ASUS TUF Z690-PLUS WIFI",
        
        "ASUS ROG STRIX B360-F GAMING",
        "ASUS ROG STRIX B360-G GAMING",
        "ASUS ROG STRIX B360-I GAMING",
        "ASUS PRIME B360-PLUS",
        "ASUS PRIME B360M-A",
        "ASUS TUF B360-PRO GAMING",
        
        "ASUS ROG STRIX B460-F GAMING",
        "ASUS ROG STRIX B460-G GAMING",
        "ASUS ROG STRIX B460-I GAMING",
        "ASUS PRIME B460-PLUS",
        "ASUS PRIME B460M-A",
        "ASUS TUF B460-PRO GAMING",
        
        "ASUS ROG STRIX B560-F GAMING WIFI",
        "ASUS ROG STRIX B560-G GAMING WIFI",
        "ASUS ROG STRIX B560-I GAMING WIFI",
        "ASUS PRIME B560-PLUS",
        "ASUS PRIME B560M-A",
        "ASUS TUF GAMING B560-PLUS WIFI",
        
        "ASUS ROG STRIX B660-F GAMING WIFI",
        "ASUS ROG STRIX B660-G GAMING WIFI",
        "ASUS ROG STRIX B660-I GAMING WIFI",
        "ASUS PRIME B660-PLUS D4",
        "ASUS PRIME B660M-A D4",
        "ASUS TUF GAMING B660-PLUS WIFI D4",
        
        "ASUS ROG STRIX H370-F GAMING",
        "ASUS ROG STRIX H370-I GAMING",
        "ASUS PRIME H370-PLUS",
        "ASUS PRIME H370M-PLUS",
        
        "ASUS ROG STRIX H470-F GAMING",
        "ASUS ROG STRIX H470-I GAMING",
        "ASUS PRIME H470-PLUS",
        "ASUS PRIME H470M-PLUS",
        
        // ASRock
        "ASRock Z390 Taichi",
        "ASRock Z390 Phantom Gaming SLI",
        "ASRock Z390 Phantom Gaming 4",
        "ASRock Z390 Steel Legend",
        "ASRock Z390 Pro4",
        "ASRock Z390 Extreme4",
        "ASRock Z390M Pro4",
        
        "ASRock Z490 Taichi",
        "ASRock Z490 Phantom Gaming 4",
        "ASRock Z490 Steel Legend",
        "ASRock Z490 Extreme4",
        "ASRock Z490M Pro4",
        
        "ASRock Z590 Taichi",
        "ASRock Z590 Phantom Gaming 4",
        "ASRock Z590 Steel Legend",
        "ASRock Z590 Extreme",
        "ASRock Z590 Pro4",
        
        "ASRock Z690 Taichi",
        "ASRock Z690 Phantom Gaming 4",
        "ASRock Z690 Steel Legend",
        "ASRock Z690 Extreme",
        "ASRock Z690 Pro RS",
        
        "ASRock B360 Pro4",
        "ASRock B360M Pro4",
        "ASRock B360M HDV",
        "ASRock B360M-ITX/ac",
        
        "ASRock B460 Pro4",
        "ASRock B460M Pro4",
        "ASRock B460M Steel Legend",
        "ASRock B460M-ITX/ac",
        
        "ASRock B560 Pro4",
        "ASRock B560M Pro4",
        "ASRock B560M Steel Legend",
        "ASRock B560M-ITX/ac",
        
        "ASRock B660 Pro RS",
        "ASRock B660M Pro RS",
        "ASRock B660M Steel Legend",
        "ASRock B660M-ITX/ac",
        
        "ASRock H370 Pro4",
        "ASRock H370M-ITX/ac",
        "ASRock H370M Pro4",
        
        "ASRock H470M Pro4",
        "ASRock H470M-ITX/ac",
        
        // MSI
        "MSI MEG Z390 GODLIKE",
        "MSI MEG Z390 ACE",
        "MSI MPG Z390 GAMING PRO CARBON AC",
        "MSI MPG Z390 GAMING EDGE AC",
        "MSI MPG Z390 GAMING PLUS",
        "MSI MPG Z390I GAMING EDGE AC",
        "MSI MAG Z390 TOMAHAWK",
        "MSI MAG Z390M MORTAR",
        
        "MSI MEG Z490 GODLIKE",
        "MSI MEG Z490 ACE",
        "MSI MPG Z490 GAMING CARBON WIFI",
        "MSI MPG Z490 GAMING EDGE WIFI",
        "MSI MPG Z490 GAMING PLUS",
        "MSI MAG Z490 TOMAHAWK",
        "MSI MAG Z490M MORTAR WIFI",
        
        "MSI MEG Z590 GODLIKE",
        "MSI MEG Z590 ACE",
        "MSI MPG Z590 GAMING CARBON WIFI",
        "MSI MPG Z590 GAMING EDGE WIFI",
        "MSI MPG Z590 GAMING PLUS",
        "MSI MAG Z590 TOMAHAWK WIFI",
        
        "MSI MEG Z690 GODLIKE",
        "MSI MEG Z690 ACE",
        "MSI MPG Z690 CARBON WIFI",
        "MSI MPG Z690 EDGE WIFI",
        "MSI MAG Z690 TOMAHAWK WIFI",
        "MSI PRO Z690-A WIFI",
        
        "MSI B360 GAMING PLUS",
        "MSI B360M MORTAR",
        "MSI B360M PRO-VDH",
        "MSI B360M BAZOOKA",
        
        "MSI B460 GAMING PLUS",
        "MSI B460M MORTAR",
        "MSI B460M PRO-VDH WIFI",
        "MSI B460M BAZOOKA",
        
        "MSI B560 GAMING PLUS",
        "MSI B560M PRO-VDH WIFI",
        "MSI B560M MORTAR",
        "MSI B560M-A PRO",
        
        "MSI B660 GAMING PLUS WIFI",
        "MSI B660M MORTAR WIFI",
        "MSI B660M-A PRO WIFI",
        "MSI PRO B660M-A WIFI",
        
        "MSI H370 GAMING PLUS",
        "MSI H370M BAZOOKA",
        "MSI H370M MORTAR",
        
        "MSI H470 GAMING PLUS",
        "MSI H470M PRO",
        
        // Intel
        "Intel NUC8i7BEH",
        "Intel NUC8i5BEH",
        "Intel NUC8i3BEH",
        "Intel NUC10i7FNH",
        "Intel NUC10i5FNH",
        "Intel NUC11PAHi7",
        "Intel NUC11PAHi5",
        "Intel NUC12WSHi7",
        "Intel NUC12WSHi5",
        
        // AMD Motherboards
        "ASUS ROG CROSSHAIR VIII HERO",
        "ASUS ROG CROSSHAIR VIII DARK HERO",
        "ASUS ROG CROSSHAIR VIII FORMULA",
        "ASUS ROG STRIX X570-E GAMING",
        "ASUS ROG STRIX X570-F GAMING",
        "ASUS ROG STRIX X570-I GAMING",
        "ASUS PRIME X570-PRO",
        "ASUS PRIME X570-P",
        "ASUS TUF GAMING X570-PLUS",
        "ASUS TUF GAMING X570-PRO",
        
        "ASUS ROG CROSSHAIR VII HERO",
        "ASUS ROG STRIX X470-F GAMING",
        "ASUS ROG STRIX X470-I GAMING",
        "ASUS PRIME X470-PRO",
        "ASUS TUF X470-PLUS GAMING",
        
        "Gigabyte X570 AORUS MASTER",
        "Gigabyte X570 AORUS ELITE",
        "Gigabyte X570 AORUS PRO WIFI",
        "Gigabyte X570 AORUS ULTRA",
        "Gigabyte X570 GAMING X",
        "Gigabyte X570 UD",
        
        "Gigabyte X470 AORUS GAMING 7 WIFI",
        "Gigabyte X470 AORUS ULTRA GAMING",
        "Gigabyte X470 AORUS GAMING 5 WIFI",
        
        "ASRock X570 Taichi",
        "ASRock X570 Phantom Gaming X",
        "ASRock X570 Steel Legend",
        "ASRock X570 Pro4",
        "ASRock X570M Pro4",
        
        "ASRock X470 Taichi",
        "ASRock X470 Master SLI",
        "ASRock X470 Gaming K4",
        
        "MSI MEG X570 GODLIKE",
        "MSI MEG X570 ACE",
        "MSI MPG X570 GAMING PRO CARBON WIFI",
        "MSI MPG X570 GAMING EDGE WIFI",
        "MSI MPG X570 GAMING PLUS",
        "MSI MAG X570 TOMAHAWK WIFI",
        
        "MSI X470 GAMING M7 AC",
        "MSI X470 GAMING PRO CARBON",
        "MSI X470 GAMING PLUS",
        
        // B550 Motherboards
        "ASUS ROG STRIX B550-F GAMING",
        "ASUS ROG STRIX B550-F GAMING WIFI II",
        "ASUS ROG STRIX B550-I GAMING",
        "ASUS ROG STRIX B550-E GAMING",
        "ASUS TUF GAMING B550-PLUS",
        "ASUS TUF GAMING B550-PLUS WIFI II",
        "ASUS PRIME B550-PLUS",
        "ASUS PRIME B550M-A",
        
        "Gigabyte B550 AORUS MASTER",
        "Gigabyte B550 AORUS ELITE AX V2",
        "Gigabyte B550 AORUS PRO AC",
        "Gigabyte B550 AORUS PRO AX",
        "Gigabyte B550 GAMING X V2",
        "Gigabyte B550M DS3H",
        "Gigabyte B550M AORUS ELITE",
        
        "MSI MPG B550 GAMING CARBON WIFI",
        "MSI MPG B550 GAMING EDGE WIFI",
        "MSI MPG B550 GAMING PLUS",
        "MSI MAG B550 TOMAHAWK",
        "MSI MAG B550M MORTAR",
        "MSI MAG B550M MORTAR WIFI",
        
        "ASRock B550 Taichi",
        "ASRock B550 Steel Legend",
        "ASRock B550 Extreme4",
        "ASRock B550 Pro4",
        "ASRock B550M Pro4",
        "ASRock B550M-ITX/ac",
        
        // B450 Motherboards
        "ASUS ROG STRIX B450-F GAMING",
        "ASUS ROG STRIX B450-I GAMING",
        "ASUS TUF B450-PRO GAMING",
        "ASUS TUF B450-PLUS GAMING",
        "ASUS PRIME B450-PLUS",
        "ASUS PRIME B450M-A",
        
        "Gigabyte B450 AORUS PRO WIFI",
        "Gigabyte B450 AORUS ELITE",
        "Gigabyte B450 AORUS M",
        "Gigabyte B450 GAMING X",
        "Gigabyte B450M DS3H",
        "Gigabyte B450M S2H",
        
        "MSI B450 GAMING PRO CARBON AC",
        "MSI B450 TOMAHAWK MAX",
        "MSI B450M MORTAR MAX",
        "MSI B450M PRO-VDH MAX",
        "MSI B450-A PRO MAX",
        
        "ASRock B450 Steel Legend",
        "ASRock B450 Gaming K4",
        "ASRock B450 Pro4",
        "ASRock B450M Pro4",
        "ASRock B450M-HDV",
        
        // A520 Motherboards
        "ASUS PRIME A520M-A",
        "ASUS TUF GAMING A520M-PLUS",
        "Gigabyte A520M DS3H",
        "Gigabyte A520M S2H",
        "MSI A520M-A PRO",
        "ASRock A520M Pro4",
        
        // Server/Workstation
        "Supermicro X11SSM-F",
        "Supermicro X11SSL-F",
        "Supermicro X11SPM-TPF",
        "Supermicro X11DPi-N",
        
        // Other Brands
        "EVGA Z390 DARK",
        "EVGA Z390 FTW",
        "EVGA Z390 MICRO",
        
        "Biostar B360GT3S",
        "Biostar B450MH",
        "Biostar X470GT8",
        
        "ECS H310H5-M2",
        "ECS B365H4-M",
        
        // Custom/Other
        "Custom",
        "Other/Not Listed"
    ]
    
    let usbPortCounts = ["5", "7", "9", "11", "13", "15", "20", "25", "30", "Custom"]
    
    // Common SSDTs for different device types
    let ssdtTemplates = [
        "CPU": [
            "SSDT-PLUG": "CPU Power Management (Essential)",
            "SSDT-EC-USBX": "Embedded Controller Fix (Essential)",
            "SSDT-AWAC": "AWAC Clock Fix (Essential)",
            "SSDT-PMC": "NVRAM Support (300+ Series)",
            "SSDT-RTC0": "RTC Fix",
            "SSDT-PTSWAK": "Sleep/Wake Fix",
            "SSDT-PM": "Power Management",
            "SSDT-CPUR": "CPU Renaming",
            "SSDT-XCPM": "XCPM Power Management"
        ],
        "GPU": [
            "SSDT-GPU": "GPU Device Properties",
            "SSDT-PCI0": "PCI Device Renaming",
            "SSDT-IGPU": "Intel GPU Fix (for iGPU)",
            "SSDT-DGPU": "Discrete GPU Power Management",
            "SSDT-PEG0": "PCIe Graphics Slot",
            "SSDT-NDGP": "NVIDIA GPU Power Management",
            "SSDT-AMDGPU": "AMD GPU Power Management"
        ],
        "Motherboard": [
            "SSDT-XOSI": "Windows OSI Method (Essential)",
            "SSDT-ALS0": "Ambient Light Sensor",
            "SSDT-HID": "Keyboard/Mouse Devices (Essential)",
            "SSDT-SBUS": "SMBus Controller",
            "SSDT-DMAC": "DMA Controller",
            "SSDT-MEM2": "Memory Mapping",
            "SSDT-PMCR": "Power Management Controller",
            "SSDT-LPCB": "LPC Bridge",
            "SSDT-PPMC": "Platform Power Management",
            "SSDT-PWRB": "Power Button",
            "SSDT-SLPB": "Sleep Button",
            "SSDT-RP0": "PCIe Root Port 0",
            "SSDT-RP1": "PCIe Root Port 1",
            "SSDT-RP2": "PCIe Root Port 2"
        ],
        "USB": [
            "SSDT-USBX": "USB Power Properties (Essential)",
            "SSDT-UIAC": "USB Port Mapping (Essential)",
            "SSDT-EHCx": "USB 2.0 Controller Renaming",
            "SSDT-XHCI": "XHCI Controller (USB 3.0)",
            "SSDT-RHUB": "USB Root Hub",
            "SSDT-XHC": "XHCI Extended Controller",
            "SSDT-PRT": "USB Port Renaming"
        ],
        "Other": [
            "SSDT-DTGP": "DTGP Method (Helper)",
            "SSDT-GPRW": "Wake Fix (USB Wake)",
            "SSDT-PM": "Power Management",
            "SSDT-SLPB": "Sleep Button",
            "SSDT-PWRB": "Power Button",
            "SSDT-TB3": "Thunderbolt 3",
            "SSDT-NVME": "NVMe Power Management",
            "SSDT-SATA": "SATA Controller",
            "SSDT-LAN": "Ethernet Controller",
            "SSDT-WIFI": "WiFi/Bluetooth",
            "SSDT-AUDIO": "Audio Controller"
        ]
    ]
    
    var availableSSDTs: [String] {
        return ssdtTemplates[selectedDeviceType]?.map { $0.key } ?? []
    }
    
    // Motherboard specific recommendations
    var motherboardRecommendations: [String] {
        var recommendations: [String] = []
        
        // Gigabyte Z390
        if motherboardModel.contains("Gigabyte Z390") {
            recommendations.append("SSDT-EC-USBX (Required)")
            recommendations.append("SSDT-AWAC (Required)")
            recommendations.append("SSDT-PLUG (Required)")
            recommendations.append("SSDT-PMC (For NVRAM)")
            recommendations.append("SSDT-RTC0 (If AWAC fails)")
        }
        
        // ASUS Z390
        if motherboardModel.contains("ASUS Z390") {
            recommendations.append("SSDT-EC-USBX (Required)")
            recommendations.append("SSDT-AWAC (Required)")
            recommendations.append("SSDT-PLUG (Required)")
            recommendations.append("SSDT-XOSI (For sleep)")
            recommendations.append("SSDT-PMCR (For power management)")
        }
        
        // AMD X570/B550
        if motherboardModel.contains("X570") || motherboardModel.contains("B550") {
            recommendations.append("SSDT-EC (Required for AMD)")
            recommendations.append("SSDT-PLUG (CPU Power Management)")
            recommendations.append("SSDT-CPUR (CPU Renaming)")
            recommendations.append("SSDT-USBX (USB Power)")
        }
        
        // Intel 600 Series
        if motherboardModel.contains("Z690") || motherboardModel.contains("B660") {
            recommendations.append("SSDT-PLUG (Required)")
            recommendations.append("SSDT-EC-USBX (Required)")
            recommendations.append("SSDT-RTC0 (RTC Fix)")
            recommendations.append("SSDT-AWAC (Clock Fix)")
            recommendations.append("SSDT-PMC (NVRAM)")
        }
        
        return recommendations.isEmpty ? ["Select SSDTs based on your needs"] : recommendations
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("SSDT Generator")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("Generate custom SSDTs for your Hackintosh")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                
                // Device Selection
                VStack(alignment: .leading, spacing: 16) {
                    Text("Device Configuration")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Device Type")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Picker("", selection: $selectedDeviceType) {
                                ForEach(deviceTypes, id: \.self) { type in
                                    Text(type).tag(type)
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(width: 200)
                            .onChange(of: selectedDeviceType) { _ in
                                selectedSSDTs.removeAll()
                            }
                        }
                        
                        Spacer()
                        
                        // Dynamic fields based on device type
                        VStack(alignment: .leading, spacing: 8) {
                            if selectedDeviceType == "CPU" {
                                Text("CPU Model")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Picker("", selection: $cpuModel) {
                                    ForEach(cpuModels, id: \.self) { model in
                                        Text(model).tag(model)
                                    }
                                }
                                .pickerStyle(.menu)
                                .frame(width: 200)
                            } else if selectedDeviceType == "GPU" {
                                Text("GPU Model")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Picker("", selection: $gpuModel) {
                                    ForEach(gpuModels, id: \.self) { model in
                                        Text(model).tag(model)
                                    }
                                }
                                .pickerStyle(.menu)
                                .frame(width: 200)
                            } else if selectedDeviceType == "Motherboard" {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Motherboard Model")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    Picker("", selection: $motherboardModel) {
                                        ForEach(motherboardModels, id: \.self) { model in
                                            Text(model).tag(model)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                    .frame(width: 300)
                                    
                                    // Show motherboard recommendations
                                    if !motherboardRecommendations.isEmpty {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Recommended for \(motherboardModel):")
                                                .font(.caption2)
                                                .foregroundColor(.blue)
                                                .padding(.top, 4)
                                            
                                            ForEach(motherboardRecommendations.prefix(3), id: \.self) { rec in
                                                Text("• \(rec)")
                                                    .font(.caption2)
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                    }
                                }
                            } else if selectedDeviceType == "USB" {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("USB Port Count")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    Picker("", selection: $usbPortCount) {
                                        ForEach(usbPortCounts, id: \.self) { count in
                                            Text("\(count) ports").tag(count)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                    .frame(width: 150)
                                    
                                    if usbPortCount == "Custom" {
                                        TextField("Enter custom port count", text: $usbPortCount)
                                            .textFieldStyle(.roundedBorder)
                                            .frame(width: 100)
                                    }
                                }
                            } else {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Custom DSDT Name")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    TextField("DSDT.aml", text: $customDSDTName)
                                        .textFieldStyle(.roundedBorder)
                                        .frame(width: 200)
                                }
                            }
                        }
                    }
                }
                .padding()
                .background(Color(.controlBackgroundColor))
                .cornerRadius(12)
                
                // Essential SSDT Options
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("Essential SSDTs")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Spacer()
                        
                        HStack(spacing: 8) {
                            Button("Select All") {
                                useEC = true
                                useAWAC = true
                                usePLUG = true
                                useXOSI = true
                                useALS0 = true
                                useHID = true
                            }
                            .font(.caption)
                            
                            Button("Clear All") {
                                useEC = false
                                useAWAC = false
                                usePLUG = false
                                useXOSI = false
                                useALS0 = false
                                useHID = false
                            }
                            .font(.caption)
                        }
                    }
                    
                    VStack(spacing: 12) {
                        HStack {
                            Toggle("SSDT-EC (Embedded Controller)", isOn: $useEC)
                                .toggleStyle(.switch)
                            Spacer()
                            Text("Essential")
                                .font(.caption)
                                .foregroundColor(.red)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(4)
                        }
                        
                        HStack {
                            Toggle("SSDT-AWAC (AWAC Clock)", isOn: $useAWAC)
                                .toggleStyle(.switch)
                            Spacer()
                            Text("300+ Series")
                                .font(.caption)
                                .foregroundColor(.orange)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.orange.opacity(0.1))
                                .cornerRadius(4)
                        }
                        
                        HStack {
                            Toggle("SSDT-PLUG (CPU Power)", isOn: $usePLUG)
                                .toggleStyle(.switch)
                            Spacer()
                            Text("Essential")
                                .font(.caption)
                                .foregroundColor(.red)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(4)
                        }
                        
                        HStack {
                            Toggle("SSDT-XOSI (Windows OSI)", isOn: $useXOSI)
                                .toggleStyle(.switch)
                            Spacer()
                            Text("Sleep/Wake")
                                .font(.caption)
                                .foregroundColor(.blue)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(4)
                        }
                        
                        HStack {
                            Toggle("SSDT-ALS0 (Ambient Light)", isOn: $useALS0)
                                .toggleStyle(.switch)
                            Spacer()
                            Text("Laptops")
                                .font(.caption)
                                .foregroundColor(.green)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.green.opacity(0.1))
                                .cornerRadius(4)
                        }
                        
                        HStack {
                            Toggle("SSDT-HID (Input Devices)", isOn: $useHID)
                                .toggleStyle(.switch)
                            Spacer()
                            Text("Keyboards/Mice")
                                .font(.caption)
                                .foregroundColor(.purple)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.purple.opacity(0.1))
                                .cornerRadius(4)
                        }
                    }
                }
                .padding()
                .background(Color(.controlBackgroundColor))
                .cornerRadius(12)
                
                // SSDT Selection
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("Available SSDT Templates")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Spacer()
                        
                        HStack(spacing: 12) {
                            Text("\(selectedSSDTs.count) selected")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Button("Select All") {
                                selectedSSDTs = Set(availableSSDTs)
                            }
                            .font(.caption)
                            
                            Button("Clear All") {
                                selectedSSDTs.removeAll()
                            }
                            .font(.caption)
                        }
                    }
                    
                    if availableSSDTs.isEmpty {
                        VStack {
                            Image(systemName: "doc.text.magnifyingglass")
                                .font(.largeTitle)
                                .foregroundColor(.orange)
                            Text("No SSDTs available for \(selectedDeviceType)")
                                .foregroundColor(.secondary)
                                .italic()
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(availableSSDTs, id: \.self) { ssdt in
                                    SSDTTemplateCard(
                                        name: ssdt,
                                        description: ssdtTemplates[selectedDeviceType]?[ssdt] ?? "Unknown",
                                        isSelected: selectedSSDTs.contains(ssdt),
                                        isEssential: ssdt.contains("EC") || ssdt.contains("PLUG") || ssdt.contains("AWAC"),
                                        isDisabled: isGenerating
                                    ) {
                                        toggleSSDTSelection(ssdt)
                                    }
                                }
                            }
                        }
                        .frame(height: 120)
                    }
                }
                .padding()
                .background(Color(.controlBackgroundColor))
                .cornerRadius(12)
                
                // Advanced Options
                VStack(alignment: .leading, spacing: 16) {
                    DisclosureGroup("Advanced Options", isExpanded: $showAdvancedOptions) {
                        VStack(spacing: 12) {
                            HStack {
                                Text("ACPI Table Source:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Picker("", selection: $acpiTableSource) {
                                    Text("Auto-detect").tag("Auto-detect")
                                    Text("Extract from system").tag("Extract from system")
                                    Text("Custom file").tag("Custom file")
                                }
                                .pickerStyle(.menu)
                                .frame(width: 200)
                            }
                            
                            HStack {
                                Text("Output Path:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                TextField("Leave empty for default", text: $outputPath)
                                    .textFieldStyle(.roundedBorder)
                                Button("Browse...") {
                                    browseForOutputPath()
                                }
                                .buttonStyle(.bordered)
                            }
                            
                            // Generation Options
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Generation Options:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                HStack {
                                    Toggle("Include comments", isOn: .constant(true))
                                        .toggleStyle(.switch)
                                        .font(.caption)
                                    
                                    Toggle("Optimize for size", isOn: .constant(false))
                                        .toggleStyle(.switch)
                                        .font(.caption)
                                    
                                    Toggle("Validate syntax", isOn: .constant(true))
                                        .toggleStyle(.switch)
                                        .font(.caption)
                                }
                            }
                        }
                        .padding(.top, 8)
                    }
                }
                .padding()
                .background(Color(.controlBackgroundColor))
                .cornerRadius(12)
                
                // Generation Progress
                if isGenerating {
                    VStack(spacing: 8) {
                        ProgressView(value: generationProgress, total: 100)
                            .progressViewStyle(.linear)
                            .padding(.horizontal)
                        Text("Generating SSDTs... \(Int(generationProgress))%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color.blue.opacity(0.05))
                    .cornerRadius(8)
                }
                
                // Generated SSDTs
                if !generatedSSDTs.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Generated Files")
                            .font(.headline)
                        
                        ScrollView {
                            VStack(spacing: 8) {
                                ForEach(generatedSSDTs, id: \.self) { ssdt in
                                    HStack {
                                        Image(systemName: "doc.text.fill")
                                            .foregroundColor(.blue)
                                        Text(ssdt)
                                            .font(.caption)
                                            .fontWeight(.medium)
                                        Spacer()
                                        HStack(spacing: 8) {
                                            Button("Open") {
                                                openGeneratedFile(ssdt)
                                            }
                                            .font(.caption2)
                                            .buttonStyle(.bordered)
                                            
                                            Button("Copy") {
                                                copySSDTToClipboard(ssdt)
                                            }
                                            .font(.caption2)
                                            .buttonStyle(.bordered)
                                        }
                                    }
                                    .padding(.vertical, 4)
                                    .padding(.horizontal, 8)
                                    .background(Color.gray.opacity(0.05))
                                    .cornerRadius(6)
                                }
                            }
                        }
                        .frame(height: min(CGFloat(generatedSSDTs.count) * 50, 200))
                    }
                    .padding()
                    .background(Color.green.opacity(0.05))
                    .cornerRadius(8)
                }
                
                // Action Buttons
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        Button(action: generateSSDTs) {
                            HStack {
                                if isGenerating {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                    Text("Generating...")
                                } else {
                                    Image(systemName: "cpu.fill")
                                    Text("Generate SSDTs")
                                }
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        .disabled(isGenerating)
                        
                        Button(action: validateSSDTs) {
                            HStack {
                                Image(systemName: "checkmark.shield.fill")
                                Text("Validate")
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        .disabled(isGenerating)
                    }
                    
                    HStack(spacing: 12) {
                        Button(action: installToEFI) {
                            HStack {
                                Image(systemName: "externaldrive.fill.badge.plus")
                                Text("Install to EFI")
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.purple)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        .disabled(isGenerating || efiPath == nil)
                        
                        Button(action: openSSDTGuide) {
                            HStack {
                                Image(systemName: "book.fill")
                                Text("Open Guide")
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.orange)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                    }
                }
                .padding()
                .background(Color(.controlBackgroundColor))
                .cornerRadius(12)
                
                // Motherboard Specific Tips
                if selectedDeviceType == "Motherboard" {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Motherboard Tips")
                            .font(.headline)
                        
                        VStack(alignment: .leading, spacing: 6) {
                            if motherboardModel.contains("Gigabyte") {
                                Text("• Gigabyte boards often need SSDT-EC-USBX for USB power")
                                Text("• Enable Above 4G Decoding in BIOS")
                                Text("• Disable CFG Lock if available")
                            } else if motherboardModel.contains("ASUS") {
                                Text("• ASUS boards may need custom EC patches")
                                Text("• Check for BIOS updates for better compatibility")
                                Text("• Enable XMP for RAM")
                            } else if motherboardModel.contains("ASRock") {
                                Text("• ASRock boards work well with OpenCore")
                                Text("• May need RTC fix (SSDT-RTC0)")
                                Text("• Check BIOS for AMD CBS options (for AMD)")
                            } else if motherboardModel.contains("MSI") {
                                Text("• MSI boards often need specific DSDT patches")
                                Text("• Disable Fast Boot in BIOS")
                                Text("• Enable Windows 10/11 WHQL Support")
                            } else if motherboardModel.contains("AMD") || motherboardModel.contains("X570") || motherboardModel.contains("B550") {
                                Text("• AMD boards need SSDT-EC (not EC-USBX)")
                                Text("• Enable Above 4G Decoding")
                                Text("• Disable CSM (Compatibility Support Module)")
                                Text("• Set PCIe to Gen3 if using RX 5000/6000 series")
                            } else if motherboardModel.contains("Intel") {
                                Text("• Intel boards need SSDT-PLUG for CPU power")
                                Text("• Enable VT-d in BIOS")
                                Text("• Disable Secure Boot")
                            }
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color.blue.opacity(0.05))
                    .cornerRadius(8)
                }
                
                Spacer()
            }
            .padding()
        }
    }
    
    // MARK: - Enhanced SSDT Template Card Component
    struct SSDTTemplateCard: View {
        let name: String
        let description: String
        let isSelected: Bool
        let isEssential: Bool
        let isDisabled: Bool
        let action: () -> Void
        
        var body: some View {
            Button(action: action) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(name)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(isSelected ? (isEssential ? .red : .blue) : .primary)
                        
                        Spacer()
                        
                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(isEssential ? .red : .blue)
                                .font(.caption)
                        }
                    }
                    
                    Text(description)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                    
                    if isEssential {
                        Text("Essential")
                            .font(.caption2)
                            .foregroundColor(.red)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(4)
                    }
                }
                .padding()
                .frame(width: 180, height: 100)
                .background(isSelected ? (isEssential ? Color.red.opacity(0.1) : Color.blue.opacity(0.1)) : Color.gray.opacity(0.05))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSelected ? (isEssential ? Color.red : Color.blue) : Color.clear, lineWidth: 2)
                )
            }
            .buttonStyle(.plain)
            .disabled(isDisabled)
        }
    }
    
    // MARK: - Action Functions
    private func toggleSSDTSelection(_ ssdtName: String) {
        if selectedSSDTs.contains(ssdtName) {
            selectedSSDTs.remove(ssdtName)
        } else {
            selectedSSDTs.insert(ssdtName)
        }
    }
    
    private func browseForOutputPath() {
        let panel = NSOpenPanel()
        panel.title = "Select Output Folder"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                outputPath = url.path
            }
        }
    }
    
    private func generateSSDTs() {
        isGenerating = true
        generationProgress = 0
        generatedSSDTs.removeAll()
        
        // Collect selected SSDTs
        var ssdtsToGenerate: [String] = []
        
        // Add essential SSDTs if selected
        if useEC { ssdtsToGenerate.append("SSDT-EC-USBX") }
        if useAWAC { ssdtsToGenerate.append("SSDT-AWAC") }
        if usePLUG { ssdtsToGenerate.append("SSDT-PLUG") }
        if useXOSI { ssdtsToGenerate.append("SSDT-XOSI") }
        if useALS0 { ssdtsToGenerate.append("SSDT-ALS0") }
        if useHID { ssdtsToGenerate.append("SSDT-HID") }
        
        // Add template SSDTs
        ssdtsToGenerate.append(contentsOf: selectedSSDTs)
        
        if ssdtsToGenerate.isEmpty {
            alertTitle = "No SSDTs Selected"
            alertMessage = "Please select at least one SSDT to generate.\n\nRecommended for \(motherboardModel):\n• SSDT-EC-USBX\n• SSDT-PLUG\n• SSDT-AWAC (for 300+ series)"
            showAlert = true
            isGenerating = false
            return
        }
        
        DispatchQueue.global(qos: .background).async {
            // Simulate generation process with detailed progress
            for (index, ssdt) in ssdtsToGenerate.enumerated() {
                // Update progress
                let progress = Double(index + 1) / Double(ssdtsToGenerate.count) * 100
                DispatchQueue.main.async {
                    generationProgress = progress
                }
                
                // Simulate generation time (faster for smaller SSDTs)
                let delay = ssdt.contains("EC") || ssdt.contains("PLUG") ? 800000 : 400000
                usleep(useconds_t(delay))
                
                // Generate filename
                let filename = "\(ssdt).aml"
                
                DispatchQueue.main.async {
                    generatedSSDTs.append(filename)
                }
                
                // Create dummy SSDT file
                createDummySSDTFile(ssdt: ssdt)
            }
            
            DispatchQueue.main.async {
                isGenerating = false
                generationProgress = 0
                
                // Generate recommendations based on motherboard
                var recommendations = ""
                if motherboardModel.contains("Gigabyte") && !ssdtsToGenerate.contains("SSDT-PMC") {
                    recommendations += "\n• Consider adding SSDT-PMC for NVRAM support"
                }
                if motherboardModel.contains("AMD") && !ssdtsToGenerate.contains("SSDT-EC") {
                    recommendations += "\n• AMD boards need SSDT-EC (not EC-USBX)"
                }
                
                alertTitle = "SSDTs Generated"
                alertMessage = """
                Successfully generated \(generatedSSDTs.count) SSDTs for \(motherboardModel):
                
                \(generatedSSDTs.joined(separator: "\n"))
                
                Files saved to: \(getOutputDirectory())
                
                \(recommendations)
                
                Next steps:
                1. Copy SSDTs to EFI/OC/ACPI/
                2. Add to config.plist → ACPI → Add
                3. Enable Patch → FixMask in config.plist
                4. Rebuild kernel cache
                5. Restart system
                
                Note: These are template SSDTs. You may need to customize them for your specific hardware.
                """
                showAlert = true
            }
        }
    }
    
    private func createDummySSDTFile(ssdt: String) {
        let outputDir = getOutputDirectory()
        let filePath = "\(outputDir)/\(ssdt).aml"
        let url = URL(fileURLWithPath: filePath)
        
        // Create dummy content based on SSDT type
        var content = """
        /*
         * \(ssdt).aml
         * Generated by SystemMaintenance
         * Date: \(Date().formatted(date: .long, time: .shortened))
         * Motherboard: \(motherboardModel)
         * Device Type: \(selectedDeviceType)
         */
        
        DefinitionBlock ("", "SSDT", 2, "ACDT", "\(ssdt.replacingOccurrences(of: "SSDT-", with: ""))", 0x00000000)
        {
        """
        
        // Add content based on SSDT type
        if ssdt == "SSDT-EC-USBX" {
            content += """
                External (_SB_.PCI0.LPCB.EC0_, DeviceObj)
                
                Scope (_SB.PCI0.LPCB)
                {
                    Device (EC0)
                    {
                        Name (_HID, "ACID0001")  // _HID: Hardware ID
                        Name (_UID, Zero)  // _UID: Unique ID
                        Method (_STA, 0, NotSerialized)  // _STA: Status
                        {
                            If (_OSI ("Darwin"))
                            {
                                Return (0x0F)
                            }
                            Else
                            {
                                Return (Zero)
                            }
                        }
                    }
                }
                
                Scope (\_SB.PCI0)
                {
                    Device (USBX)
                    {
                        Name (_ADR, Zero)
                        Name (_S3D, 0x03)
                        Name (_S4D, 0x03)
                        Method (_DSM, 4, Serialized)
                        {
                            If (LEqual (Arg2, Zero))
                            {
                                Return (Buffer (One) { 0x03 })
                            }
                            Return (Package (0x02)
                            {
                                "usb-connector-type",
                                Buffer (0x02) { 0x00, 0x00 }
                            })
                        }
                    }
                }
            """
        } else if ssdt == "SSDT-PLUG" {
            content += """
                External (_SB_.PR00, ProcessorObj)
                External (_SB_.PR01, ProcessorObj)
                
                Method (_SB.PCI0.LPCB.PMEE, 0, NotSerialized)
                {
                    If (_OSI ("Darwin"))
                    {
                        Return (One)
                    }
                    Return (Zero)
                }
                
                Scope (\_SB.PR00)
                {
                    Method (_DSM, 4, Serialized)
                    {
                        If (LEqual (Arg2, Zero))
                        {
                            Return (Buffer (One) { 0x03 })
                        }
                        Return (Package (0x02)
                        {
                            "plugin-type",
                            One
                        })
                    }
                }
            """
        } else {
            // Generic SSDT content
            content += """
                /*
                 * Placeholder for \(ssdt)
                 * This is a template. Customize for your hardware.
                 * Refer to Dortania guides for implementation details.
                 */
                
                Scope (\_SB)
                {
                    // Add your device definitions here
                }
            """
        }
        
        content += "\n}"
        
        do {
            try content.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            print("Failed to create SSDT file: \(error)")
        }
    }
    
    private func getOutputDirectory() -> String {
        if !outputPath.isEmpty {
            return outputPath
        }
        
        let downloadsDir = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
        let ssdtDir = downloadsDir?.appendingPathComponent("Generated_SSDTs")
        
        // Create directory if it doesn't exist
        if let ssdtDir = ssdtDir {
            try? FileManager.default.createDirectory(at: ssdtDir, withIntermediateDirectories: true)
            return ssdtDir.path
        }
        
        return NSHomeDirectory() + "/Downloads/Generated_SSDTs"
    }
    
    private func openGeneratedFile(_ filename: String) {
        let filePath = "\(getOutputDirectory())/\(filename)"
        let url = URL(fileURLWithPath: filePath)
        
        if FileManager.default.fileExists(atPath: filePath) {
            NSWorkspace.shared.open(url)
        } else {
            alertTitle = "File Not Found"
            alertMessage = "Generated file not found at: \(filePath)"
            showAlert = true
        }
    }
    
    private func copySSDTToClipboard(_ filename: String) {
        let filePath = "\(getOutputDirectory())/\(filename)"
        
        if FileManager.default.fileExists(atPath: filePath) {
            do {
                let content = try String(contentsOfFile: filePath, encoding: .utf8)
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.setString(content, forType: .string)
                
                alertTitle = "Copied"
                alertMessage = "\(filename) content copied to clipboard"
                showAlert = true
            } catch {
                alertTitle = "Error"
                alertMessage = "Failed to read file: \(error.localizedDescription)"
                showAlert = true
            }
        }
    }
    
    private func validateSSDTs() {
        DispatchQueue.global(qos: .background).async {
            var validationMessages: [String] = ["SSDT Validation Report:"]
            
            // Check for common issues
            validationMessages.append("\n1. Checking required SSDTs...")
            
            let requiredSSDTs = ["SSDT-EC", "SSDT-PLUG", "SSDT-AWAC"]
            for ssdt in requiredSSDTs {
                let exists = selectedSSDTs.contains(ssdt) ||
                           (ssdt == "SSDT-EC" && useEC) ||
                           (ssdt == "SSDT-PLUG" && usePLUG) ||
                           (ssdt == "SSDT-AWAC" && useAWAC)
                validationMessages.append("   \(exists ? "✅" : "❌") \(ssdt) \(exists ? "" : "(Recommended)")")
            }
            
            validationMessages.append("\n2. Checking motherboard compatibility...")
            
            // Add motherboard-specific validations
            if motherboardModel.contains("300") || motherboardModel.contains("400") || motherboardModel.contains("500") || motherboardModel.contains("600") {
                if !useAWAC && !selectedSSDTs.contains("SSDT-AWAC") {
                    validationMessages.append("   ⚠️  \(motherboardModel) may need SSDT-AWAC for clock")
                }
            }
            
            if motherboardModel.contains("AMD") {
                if useEC {
                    validationMessages.append("   ⚠️  AMD boards should use SSDT-EC (not EC-USBX)")
                }
                if !selectedSSDTs.contains("SSDT-CPUR") {
                    validationMessages.append("   ℹ️  Consider SSDT-CPUR for CPU renaming")
                }
            }
            
            if motherboardModel.contains("Intel") && cpuModel.contains("Intel") {
                if !usePLUG && !selectedSSDTs.contains("SSDT-PLUG") {
                    validationMessages.append("   ❌ SSDT-PLUG is essential for Intel CPUs")
                }
            }
            
            validationMessages.append("\n3. Configuration Recommendations:")
            validationMessages.append("   • Add SSDTs to config.plist → ACPI → Add")
            validationMessages.append("   • Enable FixMask in Kernel → Quirks")
            validationMessages.append("   • Set MinKernel/MaxKernel if needed")
            validationMessages.append("   • Rebuild kernel cache after installation")
            
            DispatchQueue.main.async {
                alertTitle = "SSDT Validation"
                alertMessage = validationMessages.joined(separator: "\n")
                showAlert = true
            }
        }
    }
    
    private func installToEFI() {
        guard let efiPath = efiPath else {
            alertTitle = "EFI Not Mounted"
            alertMessage = "Please mount EFI partition from System tab first."
            showAlert = true
            return
        }
        
        if generatedSSDTs.isEmpty {
            alertTitle = "No SSDTs Generated"
            alertMessage = "Please generate SSDTs first before installing to EFI."
            showAlert = true
            return
        }
        
        let acpiPath = "\(efiPath)/EFI/OC/ACPI/"
        
        DispatchQueue.global(qos: .background).async {
            var installMessages: [String] = ["Installing SSDTs to EFI:"]
            var successCount = 0
            var failCount = 0
            
            // Create ACPI directory if it doesn't exist
            let _ = ShellHelper.runCommand("mkdir -p \"\(acpiPath)\"", needsSudo: true)
            
            for ssdtFile in generatedSSDTs {
                let sourcePath = "\(getOutputDirectory())/\(ssdtFile)"
                let destPath = "\(acpiPath)\(ssdtFile)"
                
                if FileManager.default.fileExists(atPath: sourcePath) {
                    let command = "cp \"\(sourcePath)\" \"\(destPath)\""
                    let result = ShellHelper.runCommand(command, needsSudo: true)
                    
                    if result.success {
                        installMessages.append("✅ \(ssdtFile)")
                        successCount += 1
                    } else {
                        installMessages.append("❌ \(ssdtFile): \(result.output)")
                        failCount += 1
                    }
                } else {
                    installMessages.append("❌ \(ssdtFile): Source file not found")
                    failCount += 1
                }
            }
            
            DispatchQueue.main.async {
                alertTitle = "EFI Installation"
                installMessages.append("\n📊 Summary: \(successCount)/\(generatedSSDTs.count) SSDTs installed")
                
                if failCount > 0 {
                    installMessages.append("⚠️  \(failCount) files failed to install")
                }
                
                installMessages.append("\n📍 Location: \(acpiPath)")
                installMessages.append("\n⚠️  Important Next Steps:")
                installMessages.append("   1. Add SSDTs to config.plist → ACPI → Add")
                installMessages.append("   2. Set Enabled = True for each SSDT")
                installMessages.append("   3. Enable FixMask in ACPI → Patch")
                installMessages.append("   4. Rebuild kernel cache: sudo kextcache -i /")
                installMessages.append("   5. Restart system")
                
                if motherboardModel.contains("Gigabyte") || motherboardModel.contains("ASUS") {
                    installMessages.append("\n💡 Tip for \(motherboardModel.split(separator: " ").first ?? "your board"):")
                    installMessages.append("   • Check BIOS for Above 4G Decoding")
                    installMessages.append("   • Disable CSM for better compatibility")
                }
                
                alertMessage = installMessages.joined(separator: "\n")
                showAlert = true
            }
        }
    }
    
    private func openSSDTGuide() {
        if let url = URL(string: "https://dortania.github.io/Getting-Started-With-ACPI/") {
            NSWorkspace.shared.open(url)
        }
    }
}