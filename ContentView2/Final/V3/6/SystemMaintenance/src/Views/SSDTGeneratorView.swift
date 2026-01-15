import SwiftUI
import UniformTypeIdentifiers
import Foundation
import AppKit

// MARK: - Enhanced SSDT Generator View
struct SSDTGeneratorView: View {
    @Binding var showAlert: Bool
    @Binding var alertTitle: String
    @Binding var alertMessage: String
    
    @State private var selectedDeviceType = "CPU"
    @State private var cpuModel = "Intel Core i7"
    @State private var gpuModel = "AMD Radeon RX 580"
    @State private var motherboardModel = "Gigabyte Z390 AORUS PRO"
    @State private var usbPortCount = "15"
    @State private var useEC = true
    @State private var useAWAC = true
    @State private var usePLUG = true
    @State private var useXOSI = true
    @State private var useALS0 = false
    @State private var useHID = false
    @State private var useFWHD = false
    @State private var useMEM2 = false
    @State private var useTMR = false
    @State private var useHDEF = false
    @State private var customDSDTName = "DSDT.aml"
    @State private var isGenerating = false
    @State private var generationProgress = 0.0
    @State private var generatedSSDTs: [String] = []
    @State private var showAdvancedOptions = false
    @State private var acpiTableSource = "Auto-detect"
    @State private var selectedSSDTs: Set<String> = []
    @State private var outputPath = ""
    @State private var includeCompilation = true
    @State private var compilationResult = ""
    @State private var selectedMotherboardPreset = "Auto"
    @State private var gpuConnectorType = "PCIe x16"
    @State private var gpuMemorySize = "8"
    @State private var useGpuSpoof = false
    @State private var spoofDeviceID = "0x67DF"
    @State private var selectedChipset = "Intel Z790"
    @State private var audioCodec = "Realtek ALC1220"
    @State private var audioLayoutID = "0x07"
    @State private var selectedUSBPortConfig = "15"
    @State private var usbControllerType = "XHCI"
    @State private var usbWakeFix = true
    @State private var usbInjector = true
    @State private var usbPowerProperties = true
    
    let deviceTypes = ["CPU", "GPU", "Motherboard", "USB", "Audio", "Storage", "Other"]
    
    let cpuModels = ["Intel Core i5", "Intel Core i7", "Intel Core i9", "AMD Ryzen 5", "AMD Ryzen 7", "AMD Ryzen 9", "Custom"]
    
    let gpuModels = [
        "Intel UHD Graphics 630", "Intel UHD Graphics 730", "Intel UHD Graphics 750",
        "Intel UHD Graphics 770", "Intel Iris Xe Graphics", "Intel HD Graphics 530",
        "Intel HD Graphics 630", "Intel Iris Graphics 550", "Intel Iris Plus Graphics",
        "AMD Radeon RX 560", "AMD Radeon RX 570", "AMD Radeon RX 580",
        "AMD Radeon RX 590", "AMD Radeon RX 5500 XT", "AMD Radeon RX 5600 XT",
        "AMD Radeon RX 5700", "AMD Radeon RX 5700 XT", "AMD Radeon RX 6600",
        "AMD Radeon RX 6600 XT", "AMD Radeon RX 6700 XT", "AMD Radeon RX 6800",
        "AMD Radeon RX 6800 XT", "AMD Radeon RX 6900 XT", "AMD Radeon RX 7900 XT",
        "AMD Radeon Vega 56", "AMD Radeon Vega 64", "AMD Radeon Pro W5700",
        "AMD Radeon Pro W6800", "AMD Radeon RX 550", "AMD Radeon RX 460",
        "AMD Radeon RX 470", "AMD Radeon RX 480",
        "NVIDIA GeForce GT 710", "NVIDIA GeForce GT 730", "NVIDIA GeForce GT 1030",
        "NVIDIA GeForce GTX 1050", "NVIDIA GeForce GTX 1050 Ti", "NVIDIA GeForce GTX 1060",
        "NVIDIA GeForce GTX 1070", "NVIDIA GeForce GTX 1070 Ti", "NVIDIA GeForce GTX 1080",
        "NVIDIA GeForce GTX 1080 Ti", "NVIDIA GeForce GTX 1650", "NVIDIA GeForce GTX 1660",
        "NVIDIA GeForce GTX 1660 Ti", "NVIDIA GeForce GTX 1660 Super", "NVIDIA Quadro P400",
        "NVIDIA Quadro P620", "NVIDIA Quadro P1000", "NVIDIA Quadro P2000",
        "Custom/Other GPU", "Dual GPU Setup", "Multiple GPUs", "APU Only"
    ]
    
    let chipsets = [
        "Intel Z790", "Intel Z690", "Intel Z590", "Intel Z490", "Intel Z390",
        "Intel B760", "Intel B660", "Intel B560", "Intel B460", "Intel B365",
        "Intel H770", "Intel H670", "Intel H610", "Intel H510", "Intel H410",
        "AMD X670", "AMD X570", "AMD X470", "AMD X370", "AMD B650", "AMD B550",
        "AMD B450", "AMD B350", "AMD A520"
    ]
    
    let audioCodecs = [
        "Realtek ALC1220", "Realtek ALC1200", "Realtek ALC1150", "Realtek ALC892",
        "Realtek ALC887", "Realtek ALC885", "Realtek ALC883", "Realtek ALC662",
        "Realtek ALC898", "Realtek ALC897", "Realtek ALC4080", "Realtek ALC4082",
        "VIA VT2021", "VIA VT1828S", "VIA VT1708S", "Conexant CX20590",
        "Conexant CX20751", "Conexant CX20757", "IDT 92HD91BXX", "IDT 92HD87B1",
        "Cirrus Logic CS4208", "Cirrus Logic CS4213"
    ]
    
    let motherboardModels = [
        "Gigabyte Z790 AORUS XTREME X", "Gigabyte Z790 AORUS MASTER", "Gigabyte Z790 AORUS ELITE AX",
        "Gigabyte Z790 GAMING X AX", "Gigabyte Z790 UD AC", "Gigabyte Z790 AERO G",
        "Gigabyte Z790 AORUS TACHYON", "Gigabyte Z790 AORUS PRO X", "Gigabyte Z790M AORUS ELITE AX",
        "Gigabyte Z690 AORUS MASTER", "Gigabyte Z690 AORUS ELITE AX", "Gigabyte Z690 GAMING X",
        "Gigabyte Z690 UD AX", "Gigabyte Z690 AERO G", "Gigabyte Z690 GAMING X DDR4",
        "Gigabyte Z590 AORUS MASTER", "Gigabyte Z590 AORUS ELITE AX", "Gigabyte Z590 VISION G",
        "Gigabyte Z590 UD AC", "Gigabyte Z590 AORUS PRO AX",
        "Gigabyte Z490 AORUS XTREME", "Gigabyte Z490 AORUS MASTER", "Gigabyte Z490 VISION G",
        "Gigabyte Z490 AORUS PRO AX", "Gigabyte Z490 AORUS ELITE AC", "Gigabyte Z490 UD AC",
        "Gigabyte Z490I AORUS ULTRA",
        "Gigabyte Z390 AORUS XTREME", "Gigabyte Z390 AORUS MASTER", "Gigabyte Z390 DESIGNARE",
        "Gigabyte Z390 AORUS PRO", "Gigabyte Z390 AORUS ELITE", "Gigabyte Z390 AORUS PRO WIFI",
        "Gigabyte Z390 UD", "Gigabyte Z390 GAMING X", "Gigabyte Z390 M GAMING",
        "ASUS ROG MAXIMUS Z790 HERO", "ASUS ROG STRIX Z790-E GAMING WIFI", "ASUS ROG STRIX Z790-F GAMING WIFI",
        "ASUS ROG STRIX Z790-H GAMING WIFI", "ASUS ROG STRIX Z790-I GAMING WIFI", "ASUS PRIME Z790-P WIFI",
        "ASUS PRIME Z790-A WIFI", "ASUS TUF GAMING Z790-PLUS WIFI", "ASUS TUF GAMING Z790-PRO WIFI",
        "ASUS ROG MAXIMUS Z690 HERO", "ASUS ROG STRIX Z690-E GAMING WIFI", "ASUS ROG STRIX Z690-F GAMING WIFI",
        "ASUS ROG STRIX Z690-A GAMING WIFI D4", "ASUS PRIME Z690-P WIFI", "ASUS PRIME Z690-A WIFI",
        "ASUS TUF GAMING Z690-PLUS WIFI", "ASUS TUF GAMING Z690-PRO WIFI",
        "ASUS ROG MAXIMUS Z590 HERO", "ASUS ROG STRIX Z590-E GAMING WIFI", "ASUS ROG STRIX Z590-F GAMING WIFI",
        "ASUS PRIME Z590-P", "ASUS PRIME Z590-A", "ASUS TUF GAMING Z590-PLUS WIFI",
        "ASUS ROG MAXIMUS XII HERO", "ASUS ROG STRIX Z490-E GAMING", "ASUS ROG STRIX Z490-F GAMING",
        "ASUS ROG STRIX Z490-H GAMING", "ASUS ROG STRIX Z490-I GAMING", "ASUS PRIME Z490-A",
        "ASUS PRIME Z490-P", "ASUS TUF GAMING Z490-PLUS WIFI",
        "ASUS ROG MAXIMUS XI HERO", "ASUS ROG STRIX Z390-E GAMING", "ASUS ROG STRIX Z390-F GAMING",
        "ASUS ROG STRIX Z390-H GAMING", "ASUS ROG STRIX Z390-I GAMING", "ASUS PRIME Z390-A",
        "ASUS PRIME Z390-P", "ASUS TUF Z390-PLUS GAMING",
        "MSI MEG Z790 GODLIKE", "MSI MEG Z790 ACE", "MSI MPG Z790 CARBON WIFI",
        "MSI MPG Z790 EDGE WIFI", "MSI MAG Z790 TOMAHAWK WIFI", "MSI PRO Z790-P WIFI",
        "MSI PRO Z790-A WIFI", "MSI MPG Z790I EDGE WIFI",
        "MSI MEG Z690 GODLIKE", "MSI MEG Z690 UNIFY", "MSI MPG Z690 CARBON WIFI",
        "MSI MPG Z690 EDGE WIFI", "MSI MAG Z690 TOMAHAWK WIFI", "MSI PRO Z690-A WIFI",
        "MSI PRO Z690-P WIFI",
        "MSI MEG Z590 GODLIKE", "MSI MEG Z590 ACE", "MSI MPG Z590 GAMING CARBON WIFI",
        "MSI MPG Z590 GAMING EDGE WIFI", "MSI MAG Z590 TOMAHAWK WIFI", "MSI MAG Z590 TORPEDO",
        "MSI PRO Z590-A PRO",
        "MSI MEG Z490 GODLIKE", "MSI MEG Z490 ACE", "MSI MPG Z490 GAMING CARBON WIFI",
        "MSI MPG Z490 GAMING EDGE WIFI", "MSI MPG Z490 GAMING PLUS", "MSI MAG Z490 TOMAHAWK",
        "MSI PRO Z490-A PRO",
        "MSI MEG Z390 GODLIKE", "MSI MEG Z390 ACE", "MSI MPG Z390 GAMING PRO CARBON",
        "MSI MPG Z390 GAMING EDGE AC", "MSI MPG Z390 GAMING PLUS", "MSI MAG Z390 TOMAHAWK",
        "MSI MAG Z390M MORTAR",
        "ASRock Z790 Taichi Carrara", "ASRock Z790 Taichi", "ASRock Z790 Steel Legend WiFi",
        "ASRock Z790 PG Lightning", "ASRock Z790 PG Riptide", "ASRock Z790 Pro RS",
        "ASRock Z790 LiveMixer",
        "ASRock Z690 Taichi", "ASRock Z690 Extreme WiFi", "ASRock Z690 Steel Legend WiFi",
        "ASRock Z690 Phantom Gaming 4", "ASRock Z690 Pro RS", "ASRock Z690M PG Riptide",
        "ASRock Z590 Taichi", "ASRock Z590 Extreme WiFi 6E", "ASRock Z590 Steel Legend WiFi 6E",
        "ASRock Z590 Phantom Gaming 4", "ASRock Z590 Pro4", "ASRock Z590M Pro4",
        "ASRock Z490 Taichi", "ASRock Z490 Extreme4", "ASRock Z490 Steel Legend",
        "ASRock Z490 Phantom Gaming 4", "ASRock Z490 Pro4", "ASRock Z490M Pro4",
        "ASRock Z390 Taichi", "ASRock Z390 Phantom Gaming 9", "ASRock Z390 Phantom Gaming SLI",
        "ASRock Z390 Steel Legend", "ASRock Z390 Extreme4", "ASRock Z390 Pro4",
        "Dell OptiPlex 7010", "Dell OptiPlex 7020", "Dell OptiPlex 7050",
        "Dell OptiPlex 7060", "Dell OptiPlex 7070", "Dell OptiPlex 7080",
        "Dell OptiPlex 7090", "Dell Precision T3610", "Dell Precision T5810",
        "Dell Precision T7910", "Dell XPS 8930",
        "HP EliteDesk 800 G1", "HP EliteDesk 800 G2", "HP EliteDesk 800 G3",
        "HP EliteDesk 800 G4", "HP EliteDesk 800 G5", "HP EliteDesk 800 G6",
        "HP Z240 Workstation", "HP Z440 Workstation", "HP Z640 Workstation",
        "HP ProDesk 600 G1", "HP ProDesk 600 G2", "HP ProDesk 600 G3",
        "Lenovo ThinkCentre M93p", "Lenovo ThinkCentre M73", "Lenovo ThinkCentre M83",
        "Lenovo ThinkCentre M900", "Lenovo ThinkCentre M910", "Lenovo ThinkCentre M920",
        "Lenovo ThinkCentre M920q", "Lenovo ThinkCentre M720q", "Lenovo ThinkStation P320",
        "Lenovo ThinkStation P520", "Lenovo ThinkStation P720",
        "Intel NUC8i7BEH", "Intel NUC8i5BEH", "Intel NUC8i3BEH",
        "Intel NUC10i7FNH", "Intel NUC10i5FNH", "Intel NUC10i3FNH",
        "Intel NUC11PHKi7", "Intel NUC11PAHi7", "Intel NUC12WSHi7",
        "Gigabyte X670E AORUS MASTER", "Gigabyte X670E AORUS PRO AX", "Gigabyte X670 AORUS ELITE AX",
        "ASUS ROG CROSSHAIR X670E HERO", "ASUS ROG STRIX X670E-E GAMING WIFI", "ASUS TUF GAMING X670E-PLUS WIFI",
        "MSI MEG X670E ACE", "MSI MPG X670E CARBON WIFI", "MSI MAG X670E TOMAHAWK WIFI",
        "Gigabyte X570 AORUS XTREME", "Gigabyte X570 AORUS MASTER", "Gigabyte X570 AORUS PRO",
        "ASUS ROG CROSSHAIR VIII HERO", "ASUS ROG STRIX X570-E GAMING", "ASUS TUF GAMING X570-PLUS",
        "MSI MEG X570 GODLIKE", "MSI MEG X570 ACE", "MSI MPG X570 GAMING PRO CARBON WIFI",
        "Custom Build", "Other/Unknown Motherboard", "Generic Desktop PC",
        "All-in-One PC", "Mini PC", "Laptop", "Server Board"
    ]
    
    let motherboardPresets = [
        "Auto", "Gigabyte Z790", "ASUS Z790", "MSI Z790", "ASRock Z790",
        "Gigabyte Z690", "ASUS Z690", "MSI Z690", "ASRock Z690",
        "Gigabyte Z590", "ASUS Z590", "MSI Z590", "ASRock Z590",
        "Gigabyte Z490", "ASUS Z490", "MSI Z490", "ASRock Z490",
        "Gigabyte Z390", "ASUS Z390", "MSI Z390", "ASRock Z390",
        "AMD X670", "AMD X570", "AMD X470",
        "Dell OptiPlex", "HP EliteDesk", "Lenovo ThinkCentre",
        "Intel NUC", "Laptop", "Custom"
    ]
    
    let usbPortCounts = ["5", "7", "9", "11", "13", "15", "20", "25", "30", "Custom"]
    
    let gpuConnectorTypes = ["PCIe x16", "PCIe x8", "PCIe x4", "PCIe x1", "Integrated"]
    let gpuMemorySizes = ["1", "2", "3", "4", "6", "8", "11", "12", "16", "24"]
    
    let usbControllerTypes = ["XHCI", "EHCI", "USB2", "USB3", "USB3.1", "USB3.2"]
    
    let ssdtTemplates = [
        "CPU": [
            "SSDT-PLUG": "CPU Power Management (Essential)",
            "SSDT-EC-USBX": "Embedded Controller Fix (Essential)",
            "SSDT-AWAC": "AWAC Clock Fix (300+ Series)",
            "SSDT-PMC": "NVRAM Support (300+ Series)",
            "SSDT-RTC0": "RTC Fix",
            "SSDT-PTSWAK": "Sleep/Wake Fix",
            "SSDT-PM": "CPU Power Management",
            "SSDT-CPUR": "CPU Renaming",
            "SSDT-XCPM": "XCPM Power Management",
            "SSDT-PLNF": "CPU Performance States",
            "SSDT-CPU0": "CPU Device Properties",
            "SSDT-LANC": "CPU Cache Configuration"
        ],
        "GPU": [
            "SSDT-GPU-DISABLE": "Disable Unused GPU (iGPU+dGPU)",
            "SSDT-GPU-PCI": "GPU PCI Properties and Renaming",
            "SSDT-IGPU": "Intel Integrated Graphics (Essential)",
            "SSDT-DGPU": "Discrete GPU Power Management",
            "SSDT-PEG0": "PCIe Graphics Slot Configuration",
            "SSDT-NDGP": "NVIDIA GPU Power Management",
            "SSDT-AMDGPU": "AMD GPU Power Management",
            "SSDT-GPIO": "GPU Power/Backlight GPIO Pins",
            "SSDT-PNLF": "Backlight Control (Laptops)",
            "SSDT-GFX0": "Graphics Device Renaming"
        ],
        "Motherboard": [
            "SSDT-XOSI": "Windows OSI Method (Essential)",
            "SSDT-ALS0": "Ambient Light Sensor (Laptops)",
            "SSDT-HID": "Keyboard/Mouse Devices",
            "SSDT-SBUS": "SMBus Controller",
            "SSDT-DMAC": "DMA Controller",
            "SSDT-MEM2": "Memory Controller",
            "SSDT-PMCR": "Power Management Controller",
            "SSDT-LPCB": "LPC Bridge Controller",
            "SSDT-PPMC": "Platform Power Management",
            "SSDT-PWRB": "Power Button",
            "SSDT-SLPB": "Sleep Button",
            "SSDT-FWHD": "Firmware Hub Device",
            "SSDT-PCIB": "PCI Bridge",
            "SSDT-PCI0": "PCI Root Bridge",
            "SSDT-SATA": "SATA Controller (AHCI)",
            "SSDT-NVME": "NVMe Controller Power Management",
            "SSDT-RTC0": "Real Time Clock Fix",
            "SSDT-TMR": "Timer Fix",
            "SSDT-PIC": "Programmable Interrupt Controller"
        ],
        "USB": [
            "SSDT-USBX": "USB Power Properties (Essential)",
            "SSDT-UIAC": "USB Port Mapping (Essential)",
            "SSDT-EHCx": "USB 2.0 Controller Renaming",
            "SSDT-XHCI": "XHCI Controller (USB 3.0+)",
            "SSDT-RHUB": "USB Root Hub",
            "SSDT-XHC": "XHCI Extended Controller",
            "SSDT-PRT": "USB Port Renaming",
            "SSDT-USB-PWR": "USB Port Power Management",
            "SSDT-TYPEC": "USB Type-C Port Configuration",
            "SSDT-TB3": "Thunderbolt 3 Support",
            "SSDT-GPRW": "USB Wake Fix"
        ],
        "Audio": [
            "SSDT-HDEF": "High Definition Audio Controller",
            "SSDT-HDAS": "HD Audio Device Properties",
            "SSDT-HDAC": "HD Audio Codec Configuration",
            "SSDT-AUDIO": "Audio Controller Properties",
            "SSDT-CX20590": "Conexant Audio Fix",
            "SSDT-ALC1220": "Realtek ALC1220 Configuration",
            "SSDT-ALC892": "Realtek ALC892 Configuration",
            "SSDT-ALC887": "Realtek ALC887 Configuration"
        ],
        "Storage": [
            "SSDT-SATA": "SATA/AHCI Controller",
            "SSDT-NVME": "NVMe SSD Configuration",
            "SSDT-AHCI": "AHCI Controller Properties",
            "SSDT-RPXX": "PCIe Root Port Configuration",
            "SSDT-PCI0": "PCI Root Bridge",
            "SSDT-PXSX": "PCIe Device Properties",
            "SSDT-PCIB": "PCI Bridge Configuration"
        ],
        "Other": [
            "SSDT-DTGP": "DTGP Method (Helper)",
            "SSDT-GPRW": "Wake Fix (USB Wake)",
            "SSDT-PM": "Power Management",
            "SSDT-SLPB": "Sleep Button",
            "SSDT-PWRB": "Power Button",
            "SSDT-TB3": "Thunderbolt 3",
            "SSDT-WIFI": "WiFi/Bluetooth",
            "SSDT-LAN": "Ethernet Controller",
            "SSDT-BT": "Bluetooth Configuration"
        ]
    ]
    
    var availableSSDTs: [String] {
        return ssdtTemplates[selectedDeviceType]?.map { $0.key } ?? []
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header Section
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Advanced SSDT Generator")
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Spacer()
                        
                        Button(action: {
                            openSSDTGuide()
                        }) {
                            HStack {
                                Image(systemName: "info.circle")
                                Text("Help")
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.blue.opacity(0.1))
                            .foregroundColor(.blue)
                            .cornerRadius(8)
                        }
                    }
                    
                    Text("Generate custom SSDTs for your Hackintosh")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                
                // Device Configuration Section
                VStack(alignment: .leading, spacing: 16) {
                    Text("Device Configuration")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    HStack(spacing: 20) {
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
                            .frame(width: 180)
                        }
                        
                        Spacer()
                        
                        deviceSpecificConfiguration
                    }
                }
                .padding()
                .background(Color(.controlBackgroundColor))
                .cornerRadius(12)
                
                // Essential SSDTs Section
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("Essential SSDTs")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Spacer()
                        
                        HStack(spacing: 8) {
                            Button("Select All") {
                                selectAllEssentialSSDTs()
                            }
                            .font(.caption)
                            
                            Button("Clear All") {
                                clearAllEssentialSSDTs()
                            }
                            .font(.caption)
                        }
                    }
                    
                    essentialSSDTToggles
                }
                .padding()
                .background(Color(.controlBackgroundColor))
                .cornerRadius(12)
                
                // USB Port Configuration (if USB device type)
                if selectedDeviceType == "USB" {
                    usbPortConfigurationSection
                }
                
                // Available SSDT Templates Section
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
                            .disabled(availableSSDTs.isEmpty)
                            
                            Button("Clear All") {
                                selectedSSDTs.removeAll()
                            }
                            .font(.caption)
                            .disabled(selectedSSDTs.isEmpty)
                        }
                    }
                    
                    if availableSSDTs.isEmpty {
                        emptySSDTView
                    } else {
                        ssdtTemplateGrid
                    }
                }
                .padding()
                .background(Color(.controlBackgroundColor))
                .cornerRadius(12)
                
                // Advanced Options Section
                advancedOptionsSection
                
                // Generation Progress
                if isGenerating {
                    generationProgressView
                }
                
                // Generated Files Section
                if !generatedSSDTs.isEmpty {
                    generatedFilesSection
                }
                
                // Action Buttons Section
                actionButtonsSection
                
                // PayPal Donation Section (Tiny shape at bottom)
                paypalDonationSection
            }
            .padding()
        }
        .onChange(of: selectedDeviceType) { oldValue, newValue in
            selectedSSDTs.removeAll()
        }
        .onChange(of: selectedMotherboardPreset) { oldValue, newValue in
            applyMotherboardPreset(newValue)
        }
    }
    
    // MARK: - Subviews
    
    @ViewBuilder
    private var deviceSpecificConfiguration: some View {
        switch selectedDeviceType {
        case "CPU":
            VStack(alignment: .leading, spacing: 8) {
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
            }
            
        case "GPU":
            VStack(alignment: .leading, spacing: 8) {
                Text("GPU Model")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Picker("", selection: $gpuModel) {
                    ForEach(gpuModels, id: \.self) { model in
                        Text(model).tag(model)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 220)
                
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Connector")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Picker("", selection: $gpuConnectorType) {
                            ForEach(gpuConnectorTypes, id: \.self) { type in
                                Text(type).tag(type)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 100)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Memory (GB)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Picker("", selection: $gpuMemorySize) {
                            ForEach(gpuMemorySizes, id: \.self) { size in
                                Text(size).tag(size)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 80)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Spoof ID")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Toggle("", isOn: $useGpuSpoof)
                            .toggleStyle(.switch)
                            .labelsHidden()
                    }
                }
            }
            
        case "Motherboard":
            VStack(alignment: .leading, spacing: 8) {
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
                
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Chipset")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Picker("", selection: $selectedChipset) {
                            ForEach(chipsets, id: \.self) { chipset in
                                Text(chipset).tag(chipset)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 150)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Preset")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Picker("", selection: $selectedMotherboardPreset) {
                            ForEach(motherboardPresets, id: \.self) { preset in
                                Text(preset).tag(preset)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 150)
                    }
                }
            }
            
        case "USB":
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("USB Port Count")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Picker("", selection: $selectedUSBPortConfig) {
                            ForEach(usbPortCounts, id: \.self) { count in
                                Text("\(count) ports").tag(count)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 150)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Controller Type")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Picker("", selection: $usbControllerType) {
                            ForEach(usbControllerTypes, id: \.self) { type in
                                Text(type).tag(type)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 120)
                    }
                }
                
                HStack(spacing: 16) {
                    Toggle("USB Wake Fix", isOn: $usbWakeFix)
                        .toggleStyle(.switch)
                        .font(.caption)
                    
                    Toggle("USB Injector", isOn: $usbInjector)
                        .toggleStyle(.switch)
                        .font(.caption)
                    
                    Toggle("Power Properties", isOn: $usbPowerProperties)
                        .toggleStyle(.switch)
                        .font(.caption)
                }
                .padding(.top, 4)
            }
            
        case "Audio":
            VStack(alignment: .leading, spacing: 8) {
                Text("Audio Codec")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Picker("", selection: $audioCodec) {
                    ForEach(audioCodecs, id: \.self) { codec in
                        Text(codec).tag(codec)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 200)
                
                HStack {
                    Text("Layout ID:")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    TextField("0x07", text: $audioLayoutID)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                }
            }
            
        default:
            VStack(alignment: .leading, spacing: 8) {
                Text("Custom DSDT Name")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                TextField("DSDT.aml", text: $customDSDTName)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 200)
            }
        }
    }
    
    private var essentialSSDTToggles: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                SSDTToggleCard(
                    title: "SSDT-EC",
                    description: "Embedded Controller",
                    isEnabled: $useEC,
                    isEssential: true
                )
                
                SSDTToggleCard(
                    title: "SSDT-AWAC",
                    description: "AWAC Clock Fix",
                    isEnabled: $useAWAC,
                    isEssential: true
                )
                
                SSDTToggleCard(
                    title: "SSDT-PLUG",
                    description: "CPU Power Management",
                    isEnabled: $usePLUG,
                    isEssential: true
                )
                
                SSDTToggleCard(
                    title: "SSDT-XOSI",
                    description: "Windows OSI Method",
                    isEnabled: $useXOSI,
                    isEssential: true
                )
                
                SSDTToggleCard(
                    title: "SSDT-ALS0",
                    description: "Ambient Light Sensor",
                    isEnabled: $useALS0,
                    isEssential: false
                )
                
                SSDTToggleCard(
                    title: "SSDT-HID",
                    description: "Keyboard/Mouse",
                    isEnabled: $useHID,
                    isEssential: false
                )
                
                SSDTToggleCard(
                    title: "SSDT-FWHD",
                    description: "Firmware Hub",
                    isEnabled: $useFWHD,
                    isEssential: false
                )
                
                SSDTToggleCard(
                    title: "SSDT-MEM2",
                    description: "Memory Controller",
                    isEnabled: $useMEM2,
                    isEssential: false
                )
                
                SSDTToggleCard(
                    title: "SSDT-TMR",
                    description: "System Timer",
                    isEnabled: $useTMR,
                    isEssential: false
                )
                
                SSDTToggleCard(
                    title: "SSDT-HDEF",
                    description: "Audio Controller",
                    isEnabled: $useHDEF,
                    isEssential: false
                )
                
                if selectedDeviceType == "USB" {
                    SSDTToggleCard(
                        title: "SSDT-GPRW",
                        description: "USB Wake Fix",
                        isEnabled: $usbWakeFix,
                        isEssential: false
                    )
                    
                    SSDTToggleCard(
                        title: "SSDT-USBX",
                        description: "USB Power",
                        isEnabled: $usbPowerProperties,
                        isEssential: true
                    )
                }
            }
            .padding(.vertical, 4)
        }
    }
    
    private var usbPortConfigurationSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("USB Port Configuration")
                .font(.title2)
                .fontWeight(.semibold)
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Selected Configuration: \(selectedUSBPortConfig) ports")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("This will generate SSDT-UIAC for port mapping")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button("Generate USB Config") {
                    generateUSBSSDT()
                }
                .buttonStyle(.borderedProminent)
            }
            
            if !generatedSSDTs.isEmpty && generatedSSDTs.contains(where: { $0.contains("XHC") || $0.contains("USB") }) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Generated USB SSDTs:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(generatedSSDTs.filter { $0.contains("XHC") || $0.contains("USB") }, id: \.self) { ssdt in
                                Text(ssdt)
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(4)
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color.blue.opacity(0.05))
        .cornerRadius(12)
    }
    
    private var emptySSDTView: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.largeTitle)
                .foregroundColor(.orange)
            Text("No SSDTs available for \(selectedDeviceType)")
                .foregroundColor(.secondary)
                .italic()
        }
        .frame(maxWidth: .infinity)
        .padding()
    }
    
    private var ssdtTemplateGrid: some View {
        LazyVGrid(columns: [
            GridItem(.adaptive(minimum: 180, maximum: 200), spacing: 12)
        ], spacing: 12) {
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
    
    private var advancedOptionsSection: some View {
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
                    
                    Toggle("Compile DSL to AML (requires iasl)", isOn: $includeCompilation)
                        .toggleStyle(.switch)
                        .font(.caption)
                    
                    if !compilationResult.isEmpty {
                        ScrollView {
                            Text(compilationResult)
                                .font(.system(.caption, design: .monospaced))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                                .background(Color.black.opacity(0.05))
                                .cornerRadius(6)
                        }
                        .frame(height: 80)
                    }
                }
                .padding(.top, 8)
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(12)
    }
    
    private var generationProgressView: some View {
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
    
    private var generatedFilesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Generated Files")
                    .font(.headline)
                
                Spacer()
                
                Button("Open Folder") {
                    openGeneratedFolder()
                }
                .font(.caption)
                .buttonStyle(.bordered)
            }
            
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(generatedSSDTs, id: \.self) { ssdt in
                        HStack {
                            Image(systemName: ssdt.hasSuffix(".aml") ? "cpu.fill" : "doc.text.fill")
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
    
    private var actionButtonsSection: some View {
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
                Button(action: saveToFile) {
                    HStack {
                        Image(systemName: "square.and.arrow.down")
                        Text("Save to File")
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.purple)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .disabled(isGenerating || generatedSSDTs.isEmpty)
                
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
                
                Button(action: generateFromPreset) {
                    HStack {
                        Image(systemName: "magicwand")
                        Text("Auto Generate")
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.indigo)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .disabled(isGenerating)
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(12)
    }
    
    private var paypalDonationSection: some View {
        VStack(spacing: 8) {
            Divider()
            
            HStack(spacing: 6) {
                Text("Support my work:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Button(action: {
                    if let url = URL(string: "https://www.paypal.com/donate/?business=H3PV9HX92AVMJ&no_recurring=0&item_name=Support+my+open-source+development+work.+Donations+help+fund+testing+devices%2C+server+costs%2C+and+ongoing+maintenance+for+all+my+projects.&currency_code=CAD") {
                        NSWorkspace.shared.open(url)
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.red)
                        Text("Donate via PayPal")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 8)
    }
    
    // MARK: - Helper Components
    
    struct SSDTToggleCard: View {
        let title: String
        let description: String
        @Binding var isEnabled: Bool
        let isEssential: Bool
        
        var body: some View {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Toggle(title, isOn: $isEnabled)
                        .toggleStyle(.switch)
                        .font(.caption)
                        .fontWeight(.medium)
                    
                    if isEssential {
                        Text("Essential")
                            .font(.caption2)
                            .foregroundColor(.red)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(4)
                    }
                }
                
                Text(description)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            .padding(8)
            .frame(width: 160)
            .background(isEnabled ? Color.blue.opacity(0.1) : Color.gray.opacity(0.05))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isEnabled ? Color.blue : Color.clear, lineWidth: 1)
            )
        }
    }
    
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
                .frame(height: 100)
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
    
    // MARK: - Core Functions
    
    private func toggleSSDTSelection(_ ssdtName: String) {
        if selectedSSDTs.contains(ssdtName) {
            selectedSSDTs.remove(ssdtName)
        } else {
            selectedSSDTs.insert(ssdtName)
        }
    }
    
    private func selectAllEssentialSSDTs() {
        useEC = true
        useAWAC = true
        usePLUG = true
        useXOSI = true
        useALS0 = true
        useHID = true
        useFWHD = true
        useMEM2 = true
        useTMR = true
        useHDEF = true
    }
    
    private func clearAllEssentialSSDTs() {
        useEC = false
        useAWAC = false
        usePLUG = false
        useXOSI = false
        useALS0 = false
        useHID = false
        useFWHD = false
        useMEM2 = false
        useTMR = false
        useHDEF = false
    }
    
    private func browseForOutputPath() {
        let panel = NSOpenPanel()
        panel.title = "Select Output Folder"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        
        if panel.runModal() == .OK {
            outputPath = panel.url?.path ?? ""
        }
    }
    
    private func applyMotherboardPreset(_ preset: String) {
        switch preset {
        case "Gigabyte Z790", "ASUS Z790", "MSI Z790", "ASRock Z790":
            selectedSSDTs = Set(["SSDT-EC-USBX", "SSDT-PLUG", "SSDT-AWAC", "SSDT-PMC", "SSDT-XOSI", "SSDT-SATA", "SSDT-NVME", "SSDT-HDEF"])
            selectAllEssentialSSDTs()
            selectedChipset = "Intel Z790"
            
        case "Gigabyte Z690", "ASUS Z690", "MSI Z690", "ASRock Z690":
            selectedSSDTs = Set(["SSDT-EC-USBX", "SSDT-PLUG", "SSDT-AWAC", "SSDT-PMC", "SSDT-XOSI", "SSDT-SATA", "SSDT-NVME", "SSDT-HDEF"])
            selectAllEssentialSSDTs()
            selectedChipset = "Intel Z690"
            
        case "Gigabyte Z590", "ASUS Z590", "MSI Z590", "ASRock Z590":
            selectedSSDTs = Set(["SSDT-EC-USBX", "SSDT-PLUG", "SSDT-AWAC", "SSDT-PMC", "SSDT-XOSI", "SSDT-SATA"])
            selectAllEssentialSSDTs()
            selectedChipset = "Intel Z590"
            
        case "Gigabyte Z390", "ASUS Z390", "MSI Z390", "ASRock Z390":
            selectedSSDTs = Set(["SSDT-EC-USBX", "SSDT-PLUG", "SSDT-AWAC", "SSDT-PMC", "SSDT-XOSI", "SSDT-SATA"])
            selectAllEssentialSSDTs()
            selectedChipset = "Intel Z390"
            audioCodec = "Realtek ALC1220"
            audioLayoutID = "0x07"
            
        case "AMD X670", "AMD X570", "AMD X470":
            selectedSSDTs = Set(["SSDT-EC-USBX", "SSDT-PLUG", "SSDT-XOSI", "SSDT-SATA", "SSDT-NVME", "SSDT-HDEF"])
            useEC = true
            usePLUG = true
            useXOSI = true
            useAWAC = false
            useHDEF = true
            selectedChipset = preset
            
        case "Dell OptiPlex", "HP EliteDesk", "Lenovo ThinkCentre":
            selectedSSDTs = Set(["SSDT-EC-USBX", "SSDT-PLUG", "SSDT-XOSI", "SSDT-SATA", "SSDT-RTC0", "SSDT-PMCR"])
            useEC = true
            usePLUG = true
            useXOSI = true
            useAWAC = false
            useFWHD = true
            useMEM2 = true
            useTMR = true
            
        case "Intel NUC":
            selectedSSDTs = Set(["SSDT-EC-USBX", "SSDT-PLUG", "SSDT-XOSI", "SSDT-PNLF", "SSDT-IGPU", "SSDT-HDEF"])
            useEC = true
            usePLUG = true
            useXOSI = true
            useALS0 = true
            useHID = true
            
        case "Laptop":
            selectedSSDTs = Set(["SSDT-EC-USBX", "SSDT-PLUG", "SSDT-PNLF", "SSDT-XOSI", "SSDT-ALS0", "SSDT-HID", "SSDT-IGPU"])
            useEC = true
            usePLUG = true
            useXOSI = true
            useALS0 = true
            useHID = true
            useFWHD = true
            
        default:
            selectedSSDTs = Set(["SSDT-EC-USBX", "SSDT-PLUG", "SSDT-XOSI"])
            useEC = true
            usePLUG = true
            useXOSI = true
        }
        
        if let matchingModel = motherboardModels.first(where: { $0.contains(preset.replacingOccurrences(of: " ", with: "")) }) {
            motherboardModel = matchingModel
        }
    }
    
    private func generateFromPreset() {
        isGenerating = true
        generationProgress = 0
        generatedSSDTs.removeAll()
        compilationResult = ""
        
        applyMotherboardPreset(selectedMotherboardPreset)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            generateSSDTs()
        }
    }
    
    private func generateUSBSSDT() {
        isGenerating = true
        generationProgress = 0
        generatedSSDTs.removeAll()
        compilationResult = ""
        
        Task {
            let outputDir = getOutputDirectory()
            var compilationMessages: [String] = []
            
            if usbPowerProperties {
                let usbxContent = generateUSBX()
                let usbxPath = "\(outputDir)/SSDT-USBX.dsl"
                
                do {
                    try usbxContent.write(toFile: usbxPath, atomically: true, encoding: .utf8)
                    await MainActor.run {
                        generatedSSDTs.append("SSDT-USBX.dsl")
                    }
                    
                    if includeCompilation {
                        let result = compileDSLToAML(dslPath: usbxPath, amlPath: usbxPath.replacingOccurrences(of: ".dsl", with: ".aml"))
                        if result.success {
                            compilationMessages.append("✅ SSDT-USBX: Compiled successfully")
                            await MainActor.run {
                                generatedSSDTs.append("SSDT-USBX.aml")
                            }
                        } else {
                            compilationMessages.append("⚠️ SSDT-USBX: Compilation failed - \(result.output)")
                        }
                    }
                } catch {
                    compilationMessages.append("❌ SSDT-USBX: Failed to create file - \(error.localizedDescription)")
                }
            }
            
            if let portCount = Int(selectedUSBPortConfig) {
                let usbSSDTContent = generateUSBPortSSDT(portCount: portCount)
                let ssdtName = "SSDT-XHC\(portCount)"
                let ssdtPath = "\(outputDir)/\(ssdtName).dsl"
                
                do {
                    try usbSSDTContent.write(toFile: ssdtPath, atomically: true, encoding: .utf8)
                    await MainActor.run {
                        generatedSSDTs.append("\(ssdtName).dsl")
                    }
                    
                    if includeCompilation {
                        let result = compileDSLToAML(dslPath: ssdtPath, amlPath: ssdtPath.replacingOccurrences(of: ".dsl", with: ".aml"))
                        if result.success {
                            compilationMessages.append("✅ \(ssdtName): Compiled successfully")
                            await MainActor.run {
                                generatedSSDTs.append("\(ssdtName).aml")
                            }
                        } else {
                            compilationMessages.append("⚠️ \(ssdtName): Compilation failed - \(result.output)")
                        }
                    }
                } catch {
                    compilationMessages.append("❌ \(ssdtName): Failed to create file - \(error.localizedDescription)")
                }
            }
            
            if usbInjector {
                let uiacContent = generateUIAC()
                let uiacPath = "\(outputDir)/SSDT-UIAC.dsl"
                
                do {
                    try uiacContent.write(toFile: uiacPath, atomically: true, encoding: .utf8)
                    await MainActor.run {
                        generatedSSDTs.append("SSDT-UIAC.dsl")
                    }
                    
                    if includeCompilation {
                        let result = compileDSLToAML(dslPath: uiacPath, amlPath: uiacPath.replacingOccurrences(of: ".dsl", with: ".aml"))
                        if result.success {
                            compilationMessages.append("✅ SSDT-UIAC: Compiled successfully")
                            await MainActor.run {
                                generatedSSDTs.append("SSDT-UIAC.aml")
                            }
                        } else {
                            compilationMessages.append("⚠️ SSDT-UIAC: Compilation failed - \(result.output)")
                        }
                    }
                } catch {
                    compilationMessages.append("❌ SSDT-UIAC: Failed to create file - \(error.localizedDescription)")
                }
            }
            
            if usbWakeFix {
                let gprwContent = generateGPRW()
                let gprwPath = "\(outputDir)/SSDT-GPRW.dsl"
                
                do {
                    try gprwContent.write(toFile: gprwPath, atomically: true, encoding: .utf8)
                    await MainActor.run {
                        generatedSSDTs.append("SSDT-GPRW.dsl")
                    }
                    
                    if includeCompilation {
                        let result = compileDSLToAML(dslPath: gprwPath, amlPath: gprwPath.replacingOccurrences(of: ".dsl", with: ".aml"))
                        if result.success {
                            compilationMessages.append("✅ SSDT-GPRW: Compiled successfully")
                            await MainActor.run {
                                generatedSSDTs.append("SSDT-GPRW.aml")
                            }
                        } else {
                            compilationMessages.append("⚠️ SSDT-GPRW: Compilation failed - \(result.output)")
                        }
                    }
                } catch {
                    compilationMessages.append("❌ SSDT-GPRW: Failed to create file - \(error.localizedDescription)")
                }
            }
            
            await MainActor.run {
                isGenerating = false
                generationProgress = 0
                
                compilationResult = compilationMessages.joined(separator: "\n")
                
                alertTitle = "USB SSDTs Generated"
                alertMessage = """
                Successfully generated \(generatedSSDTs.count) USB SSDTs for \(selectedUSBPortConfig) ports.
                
                • SSDT-USBX: USB Power Properties
                • SSDT-XHC\(selectedUSBPortConfig): \(selectedUSBPortConfig)-port configuration
                • SSDT-UIAC: USB Port Mapping
                • SSDT-GPRW: USB Wake Fix
                
                📁 Files saved to: \(outputDir)
                
                \(!compilationMessages.isEmpty ? "📊 Compilation Results:\n\(compilationResult)" : "")
                
                ⚠️ Important:
                1. Install these SSDTs to EFI/OC/ACPI/
                2. Add to config.plist → ACPI → Add
                3. Enable USB port limit patches in config.plist
                4. Rebuild kernel cache and restart
                """
                showAlert = true
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    openGeneratedFolder()
                }
            }
        }
    }
    
    private func generateSSDTs() {
        if includeCompilation {
            let iaslCheck = ShellHelper.runCommand("which iasl")
            if !iaslCheck.success {
                alertTitle = "iasl Not Found"
                alertMessage = "⚠️ iasl compiler not found. DSL files will be generated but not compiled to AML.\n\nInstall with: brew install acpica\n\nContinue anyway?"
                showAlert = true
                
                includeCompilation = false
            }
        }
        
        if selectedDeviceType == "USB" {
            generateUSBSSDT()
            return
        }
        
        var ssdtsToGenerate: [String] = []
        
        if useEC { ssdtsToGenerate.append("SSDT-EC") }
        if useAWAC { ssdtsToGenerate.append("SSDT-AWAC") }
        if usePLUG { ssdtsToGenerate.append("SSDT-PLUG") }
        if useXOSI { ssdtsToGenerate.append("SSDT-XOSI") }
        if useALS0 { ssdtsToGenerate.append("SSDT-ALS0") }
        if useHID { ssdtsToGenerate.append("SSDT-HID") }
        if useFWHD { ssdtsToGenerate.append("SSDT-FWHD") }
        if useMEM2 { ssdtsToGenerate.append("SSDT-MEM2") }
        if useTMR { ssdtsToGenerate.append("SSDT-TMR") }
        if useHDEF { ssdtsToGenerate.append("SSDT-HDEF") }
        
        ssdtsToGenerate.append(contentsOf: selectedSSDTs)
        
        if ssdtsToGenerate.isEmpty {
            alertTitle = "No SSDTs Selected"
            alertMessage = "Please select at least one SSDT to generate.\n\nRecommended for \(motherboardModel):\n• SSDT-EC-USBX\n• SSDT-PLUG\n• SSDT-AWAC (for 300+ series)\n• SSDT-XOSI"
            showAlert = true
            isGenerating = false
            return
        }
        
        isGenerating = true
        generationProgress = 0
        generatedSSDTs.removeAll()
        compilationResult = ""
        
        Task {
            let outputDir = getOutputDirectory()
            var compilationMessages: [String] = []
            
            for (index, ssdt) in ssdtsToGenerate.enumerated() {
                let progress = Double(index + 1) / Double(ssdtsToGenerate.count) * 100
                await MainActor.run {
                    generationProgress = progress
                }
                
                let dslFilename = "\(ssdt).dsl"
                let dslFilePath = "\(outputDir)/\(dslFilename)"
                
                let dslContent = generateValidDSLContent(for: ssdt)
                
                do {
                    try dslContent.write(toFile: dslFilePath, atomically: true, encoding: .utf8)
                    
                    await MainActor.run {
                        generatedSSDTs.append(dslFilename)
                    }
                    
                    if includeCompilation {
                        let amlFilename = "\(ssdt).aml"
                        let amlFilePath = "\(outputDir)/\(amlFilename)"
                        
                        let result = compileDSLToAML(dslPath: dslFilePath, amlPath: amlFilePath)
                        
                        if result.success {
                            compilationMessages.append("✅ \(ssdt): Compiled successfully")
                            await MainActor.run {
                                generatedSSDTs.append(amlFilename)
                            }
                        } else {
                            compilationMessages.append("⚠️ \(ssdt): Compilation failed - \(result.output)")
                        }
                    }
                } catch {
                    compilationMessages.append("❌ \(ssdt): Failed to create DSL file - \(error.localizedDescription)")
                }
            }
            
            await MainActor.run {
                isGenerating = false
                generationProgress = 0
                
                compilationResult = compilationMessages.joined(separator: "\n")
                
                alertTitle = "SSDTs Generated"
                alertMessage = """
                Successfully generated \(generatedSSDTs.count) files for \(motherboardModel):
                
                • DSL source files: \(ssdtsToGenerate.count)
                • AML binary files: \(includeCompilation ? "\(compilationMessages.filter { $0.contains("✅") }.count)" : "Compilation disabled")
                
                📁 Files saved to: \(outputDir)
                
                \(!compilationMessages.isEmpty ? "📊 Compilation Results:\n\(compilationResult)" : "")
                
                ⚠️ Important:
                These are template SSDTs. You MUST:
                1. Review and customize them for your specific hardware
                2. Test each SSDT individually
                3. Add to config.plist → ACPI → Add
                4. Rebuild kernel cache and restart
                """
                showAlert = true
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    openGeneratedFolder()
                }
            }
        }
    }
    
    // MARK: - USB SSDT Generation Functions
    
    private func generateUSBX() -> String {
        return """
        DefinitionBlock ("", "SSDT", 2, "SYSM", "USBX", 0x00000000)
        {
            External (_SB_.PC00, DeviceObj)
            
            Scope (\\_SB.PC00)
            {
                Device (USBX)
                {
                    Name (_HID, "XHCPWR")
                    Method (_STA, 0, NotSerialized)
                    {
                        Return (0x0F)
                    }
                    
                    Name (_DSD, Package (0x02)
                    {
                        ToUUID ("daffd814-6eba-4d8c-8a91-bc9bbf4aa301"),
                        Package (0x04)
                        {
                            "usb2-port-power-off", 
                            Package (0x02)
                            {
                                0x00, 
                                0x00
                            }, 
                            "usb2-port-power-on", 
                            Package (0x02)
                            {
                                0x01, 
                                0x01
                            }, 
                            "usb3-port-power-off", 
                            Package (0x02)
                            {
                                0x00, 
                                0x00
                            }, 
                            "usb3-port-power-on", 
                            Package (0x02)
                            {
                                0x01, 
                                0x01
                            }
                        }
                    })
                }
            }
        }
        """
    }
    
    private func generateUSBPortSSDT(portCount: Int) -> String {
        let ssdtName = "XHC\(portCount)"
        
        var hsDevices = ""
        var ssDevices = ""
        
        for i in 1...portCount {
            hsDevices += """
                    Device (HS\(String(format: "%02d", i)))
                    {
                        Name (_ADR, \(i))
                        Name (_UPC, Package (0x04) { 0xFF, 0x00, Zero, Zero })
                        Name (_PLD, Package (0x01)
                        {
                            Buffer (0x10)
                            {
                                /* 0000 */  0x81, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
                                /* 0008 */  0x30, 0x1C, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
                            }
                        })
                    }
            
            """
        }
        
        for i in 1...portCount {
            ssDevices += """
                    Device (SS\(String(format: "%02d", i)))
                    {
                        Name (_ADR, 0x\(String(format: "%02X", i + 0x10)))
                        Name (_UPC, Package (0x04) { 0xFF, 0x03, Zero, Zero })
                    }
            
            """
        }
        
        let rootHubDepth = 0x14 + (portCount / 5) * 2
        
        return """
        DefinitionBlock ("", "SSDT", 2, "SYSM", "\(ssdtName)", 0x00000000)
        {
            External (_SB_.PC00.XHCI, DeviceObj)
            External (_SB_.PC00.XHCI.RHUB, DeviceObj)
            External (DTGP, MethodObj)

            Scope (\\_SB.PC00.XHCI)
            {
                Scope (RHUB)
                {
                    Method (_STA, 0, NotSerialized)
                    {
                        If (_OSI ("Darwin"))
                        {
                            Return (Zero)
                        }
                        Else
                        {
                            Return (0x0F)
                        }
                    }
                }

                Device (XHC)
                {
                    Name (_ADR, Zero)
                    
                    Method (_STA, 0, NotSerialized)
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

                    // USB 2.0 Ports (HSxx)
        \(hsDevices)
                    // USB 3.0+ Ports (SSxx)
        \(ssDevices)
                }
                
                Method (_DSM, 4, NotSerialized)
                {
                    Store (Package (0x18)
                    {
                        "AAPL,current-available", 
                        0x0834, 
                        "AAPL,current-extra", 
                        0x0A8C, 
                        "AAPL,current-in-sleep", 
                        0x0A8C, 
                        "AAPL,max-port-current-in-sleep", 
                        0x0834, 
                        "AAPL,device-internal", 
                        Zero, 
                        "AAPL,clock-id", 
                        Buffer (One) { 0x01 }, 
                        "AAPL,root-hub-depth", 
                        0x\(String(format: "%02X", rootHubDepth)), 
                        "AAPL,XHC-clock-id", 
                        One, 
                        "model", 
                        Buffer () { "XHCI Controller - \(portCount) Ports" }, 
                        "name", 
                        Buffer () { "XHCI" }, 
                        "AAPL,slot-name", 
                        Buffer () { "Built In" }, 
                        "device_type", 
                        Buffer () { "USB Controller" }, 
                        "built-in", 
                        Buffer (One) { 0x01 }
                    }, Local0)
                    
                    DTGP (Arg0, Arg1, Arg2, Arg3, RefOf (Local0))
                    Return (Local0)
                }
            }
        }
        """
    }
    
    private func generateUIAC() -> String {
        return """
        DefinitionBlock ("", "SSDT", 2, "SYSM", "UIAC", 0x00000000)
        {
            External (_SB_.PC00.XHCI, DeviceObj)
            
            Scope (\\_SB.PC00.XHCI)
            {
                Method (_DSM, 4, NotSerialized)
                {
                    Store (Package (0x02)
                    {
                        "AAPL,current-available", 
                        0x0834, 
                        "AAPL,current-extra", 
                        0x0A8C
                    }, Local0)
                    
                    Return (Local0)
                }
            }
        }
        """
    }
    
    private func generateGPRW() -> String {
        return """
        DefinitionBlock ("", "SSDT", 2, "SYSM", "GPRW", 0x00000000)
        {
            // Fix for USB wake issues
            Scope (\\)
            {
                Method (GPRW, 2, NotSerialized)
                {
                    If (LAnd (LEqual (Arg0, 0x0D), LEqual (Arg1, 0x03)))
                    {
                        Return (Package (0x02) { 0x03, Zero })
                    }
                    
                    If (LAnd (LEqual (Arg0, 0x0D), LEqual (Arg1, 0x04)))
                    {
                        Return (Package (0x02) { 0x04, Zero })
                    }
                    
                    Return (Package (0x02) { Arg0, Arg1 })
                }
            }
        }
        """
    }
    
    private func generateValidDSLContent(for ssdt: String) -> String {
        switch ssdt {
        case "SSDT-DTGP":
            return generateDTGP()
        case "SSDT-ALS0":
            return generateALS0()
        case "SSDT-AWAC":
            return generateAWAC()
        case "SSDT-EC", "SSDT-EC-USBX":
            return generateEC()
        case "SSDT-FWHD":
            return generateFWHD()
        case "SSDT-HID":
            return generateHIDD()
        case "SSDT-LPCB":
            return generateLPCB()
        case "SSDT-MEM2":
            return generateMEM2()
        case "SSDT-NVME":
            return generateNVME()
        case "SSDT-PCI0":
            return generatePCI0()
        case "SSDT-PLUG":
            return generatePLUG()
        case "SSDT-PMCR":
            return generatePMCR()
        case "SSDT-PPMC":
            return generatePPMC()
        case "SSDT-PWRB":
            return generatePWRB()
        case "SSDT-RTC0":
            return generateRTC0()
        case "SSDT-SATA":
            return generateSATA()
        case "SSDT-SBUS":
            return generateSBUS()
        case "SSDT-TMR":
            return generateTMR()
        case "SSDT-XOSI":
            return generateXOSI()
        case "SSDT-HDEF":
            return generateHDEF()
        default:
            return generateGenericSSDT(for: ssdt)
        }
    }
    
    // MARK: - SSDT Generation Functions
    
    private func generateDTGP() -> String {
        return """
        DefinitionBlock ("", "SSDT", 2, "SYSM", "DTPG", 0x00001000)
        {
            Method (DTGP, 5, NotSerialized)
            {
                If ((Arg0 == ToUUID ("a0b5b7c6-1318-441c-b0c9-fe695eaf949b") /* Unknown UUID */))
                {
                    If ((Arg1 == One))
                    {
                        If ((Arg2 == Zero))
                        {
                            Arg4 = Buffer (One)
                                {
                                     0x03                                             // .
                                }
                            Return (One)
                        }

                        If ((Arg2 == One))
                        {
                            Return (One)
                        }
                    }
                }

                Arg4 = Buffer (One)
                    {
                         0x00                                             // .
                    }
                Return (Zero)
            }
        }
        """
    }
    
    private func generateALS0() -> String {
        return """
        DefinitionBlock ("", "SSDT", 2, "SYSM", "ALS0", 0)
        {
            Scope (\\)
            {
                Device (ALS0)
                {
                    Name (_HID, "ACPI0008")
                    Name (_CID, "PNP0C50")
                    Method (_STA, 0, NotSerialized)
                    {
                        If (_OSI ("Darwin"))
                        {
                            Return (0x0F)
                        }
                        Return (0)
                    }
                    Name (_ALI, 0x0140)
                }
            }
        }
        """
    }
    
    private func generateAWAC() -> String {
        return """
        DefinitionBlock ("", "SSDT", 2, "SYSM", "AWAC", 0x00000000)
        {
            External (_SB_.PC00, DeviceObj)

            Scope (\\_SB.PC00)
            {
                Device (RTC)
                {
                    Name (_HID, "PNP0B00" /* AT Real-Time Clock */)
                    Name (_CRS, ResourceTemplate ()
                    {
                        IO (Decode16,
                            0x0070,
                            0x0070,
                            0x01,
                            0x02,
                            )
                        IO (Decode16,
                            0x0072,
                            0x0072,
                            0x01,
                            0x06,
                            )
                    })
                    Name (_STA, 0x0B)
                }

                Device (AWAC)
                {
                    Name (_HID, "ACPI000E" /* Time and Alarm Device */)
                    Name (_STA, Zero)
                }
            }
        }
        """
    }
    
    private func generateEC() -> String {
        return """
        DefinitionBlock ("", "SSDT", 2, "SYSM", "EC", 0x00000000)
        {
            External (_SB_.PC00.LPCB, DeviceObj)
            External (_SB_.PC00.LPCB.H_EC, DeviceObj)

            Device (EC)
            {
                Name (_HID, EisaId ("PNP0C09") /* Embedded Controller Device */)
                Name (_UID, One)
                Name (_CRS, ResourceTemplate ()
                {
                    IO (Decode16,
                        0x0062,
                        0x0062,
                        0x01,
                        0x01,
                        )
                    IO (Decode16,
                        0x0066,
                        0x0066,
                        0x01,
                        0x01,
                        )
                })
                Method (_STA, 0, NotSerialized)
                {
                    Return (0x0F)
                }

                Method (_REG, 2, NotSerialized)
                {
                }
            }
        }
        """
    }
    
    private func generateFWHD() -> String {
        return """
        DefinitionBlock ("", "SSDT", 2, "SYSM", "FWHD", 0x00000000)
        {
            External (_SB_.PC00, DeviceObj)
            External (_SB_.PC00.LPCB, DeviceObj)

            Scope (\\_SB.PC00.LPCB)
            {
                Device (FWHD)
                {
                    Name (_HID, EisaId ("INT0800"))
                    Name (_CID, EisaId ("PNP0C02"))
                    Name (_UID, 0x01)
                    
                    Method (_STA, 0, NotSerialized)
                    {
                        If (_OSI ("Darwin"))
                        {
                            Return (0x0F)
                        }
                        Else
                        {
                            Return (0x00)
                        }
                    }
                    
                    Name (_CRS, ResourceTemplate ()
                    {
                        Memory32Fixed (ReadWrite,
                            0xFED10000,
                            0x00001000,
                            )
                            
                        Memory32Fixed (ReadWrite,
                            0xFED18000,
                            0x00001000,
                            )
                    })
                    
                    Method (_DSM, 4, Serialized)
                    {
                        Local0 = Package (0x02)
                        {
                            ToUUID ("1F1B4BC5-8B86-48B5-816D-184C131D9D8E"),
                            
                            Package ()
                            {
                                "fwhub-state",
                                Buffer (0x01) { 0x01 }
                            }
                        }
                        Return (Local0)
                    }
                }
            }
        }
        """
    }
    
    private func generateHIDD() -> String {
        return """
        DefinitionBlock ("", "SSDT", 2, "SYSM", "HIDD", 0x00000000)
        {
            External (_SB_.PC00, DeviceObj)
            External (_SB_.PC00.LPCB, DeviceObj)

            Scope (\\_SB.PC00.LPCB)
            {
                Device (HIDD)
                {
                    Name (_HID, "PNP0C50")
                    Name (_CID, "MSFT0001")
                    Name (_UID, One)
                    
                    Method (_STA, 0, NotSerialized)
                    {
                        If (_OSI ("Darwin"))
                        {
                            Return (0x0B)
                        }
                        Return (Zero)
                    }
                    
                    Name (_CRS, ResourceTemplate ()
                    {
                        IO (Decode16, 0x0060, 0x0060, 0x01, 0x01)
                        IO (Decode16, 0x0064, 0x0064, 0x01, 0x01)
                        IRQ (Edge, ActiveHigh, Exclusive, ) {1}
                    })
                    
                    Method (_DSM, 4, Serialized)
                    {
                        Return (Package (0x02)
                        {
                            ToUUID ("3D6D021E-F9B9-4B44-AD8F-B0ABE4FCFFD1"),
                            Package ()
                            {
                                "HIDWakeup",
                                Buffer (One) { 0x01 }
                            }
                        })
                    }
                }
            }
        }
        """
    }
    
    private func generateLPCB() -> String {
        return """
        DefinitionBlock ("", "SSDT", 2, "SYSM", "LPCB", 0x00000000)
        {
            External (_SB_.PC00, DeviceObj)
            External (_SB_.PC00.LPCB, DeviceObj)

            Scope (_SB.PC00.LPCB)
            {
                Method (_DSM, 4, NotSerialized)
                {
                    If (!Arg2)
                    {
                        Return (Buffer (One)
                        {
                             0x03
                        })
                    }

                    Return (Package (0x0A)
                    {
                        "device-id",
                        Buffer (0x04)
                        {
                             0x04, 0x7A, 0x00, 0x00
                        },

                        "AAPL,slot-name",
                        Buffer (0x08)
                        {
                            "LPC Bus"
                        },

                        "model-name",
                        Buffer (0x15)
                        {
                            "Intel LPC Controller"
                        },

                        "name",
                        Buffer (0x10)
                        {
                            "pci8086,7a04"
                        },

                        "compatible",
                        Buffer (0x0D)
                        {
                            "pci8086,7a04"
                        }
                    })
                }
            }
        }
        """
    }
    
    private func generateMEM2() -> String {
        return """
        DefinitionBlock ("", "SSDT", 2, "SYSM", "MEM2", 0x00000000)
        {
            Scope (\\_SB)
            {
                Device (MEM0)
                {
                    Name (_HID, "PNP0C80")
                    
                    Method (_STA, 0, NotSerialized)
                    {
                        Return (0x0F)
                    }
                    
                    Name (_CRS, ResourceTemplate ()
                    {
                        QWordMemory (ResourceConsumer, PosDecode, MinFixed, MaxFixed, Cacheable, ReadWrite,
                            0x0000000000000000,
                            0x0000000000000000,
                            0xFFFFFFFFFFFFFFFF,
                            0x0000000000000000,
                            0x0000000800000000,
                            ,, , AddressRangeMemory, TypeStatic)
                    })
                }
            }
        }
        """
    }
    
    private func generateNVME() -> String {
        return """
        DefinitionBlock ("", "SSDT", 2, "SYSM", "NVME", 0x00000000)
        {
            Scope (\\_SB.PC00.RP01)
            {
                Device (NVME)
                {
                    Name (_ADR, Zero)
                    
                    Method (_STA, 0, NotSerialized)
                    {
                        Return (0x0F)
                    }
                    
                    Name (_SUN, 0x01)
                    
                    Name (_PRW, Package (0x02)
                    {
                        0x09,
                        0x03
                    })
                    
                    Method (_INI, 0, NotSerialized)
                    {
                        Store (0x01, PCEJ)
                    }
                    
                    Method (_DSM, 4, Serialized)
                    {
                        Local0 = Package (0x02)
                        {
                            ToUUID ("C5DCDA2A-53C2-481F-BAB5-9F6C79D7C2F5"),
                            
                            Package (0x04)
                            {
                                "model",
                                Buffer (0x20)
                                {
                                    "Samsung SSD 970 EVO Plus 1TB"
                                },
                                
                                "serial-number",
                                Buffer (0x14)
                                {
                                    "S4EWNF0MC12345"
                                },
                                
                                "device-type",
                                Buffer (0x04)
                                {
                                    0x01, 0x00, 0x00, 0x00
                                },
                                
                                "built-in",
                                Buffer (0x04)
                                {
                                    0x01, 0x00, 0x00, 0x00
                                }
                            }
                        }
                        Return (Local0)
                    }
                }
                
                Device (NVMF)
                {
                    Name (_ADR, 0x00010000)
                    
                    Method (_STA, 0, NotSerialized)
                    {
                        Return (0x0F)
                    }
                    
                    Name (_SUN, 0x02)
                }
            }
            
            Scope (\\_SB.PC00.RP02)
            {
                Device (NVME)
                {
                    Name (_ADR, Zero)
                    
                    Method (_STA, 0, NotSerialized)
                    {
                        Return (0x0F)
                    }
                    
                    Name (_SUN, 0x03)
                    
                    Method (_DSM, 4, Serialized)
                    {
                        Local0 = Package (0x02)
                        {
                            ToUUID ("C5DCDA2A-53C2-481F-BAB5-9F6C79D7C2F5"),
                            
                            Package (0x03)
                            {
                                "model",
                                Buffer (0x20)
                                {
                                    "WD Black SN850 2TB"
                                },
                                
                                "serial-number",
                                Buffer (0x14)
                                {
                                    "223121801234"
                                },
                                
                                "built-in",
                                Buffer (0x04) { 0x01, 0x00, 0x00, 0x00 }
                            }
                        }
                        Return (Local0)
                    }
                }
            }
        }
        """
    }
    
    private func generatePCI0() -> String {
        return """
        DefinitionBlock ("", "SSDT", 2, "SYSM", "PCI0", 0x00000000)
        {
            External (_SB_.PC00, DeviceObj)
            External (_SB_.PC00.SAT0, DeviceObj)
            External (_SB_.PC00.XHCI, DeviceObj)
            External (DTGP, MethodObj)

            Method (_SB.PC00.XHCI._DSM, 4, NotSerialized)
            {
                Local0 = Package (0x1B)
                    {
                        "AAPL,slot-name",
                        Buffer (0x09)
                        {
                            "Built In"
                        },

                        "built-in",
                        Buffer (One)
                        {
                             0x00
                        },

                        "device-id",
                        Buffer (0x04)
                        {
                             0x7A, 0x60, 0x00, 0x00
                        },

                        "name",
                        Buffer (0x34)
                        {
                            "ASMedia / Intel Z790 Series Chipset XHCI Controller"
                        },

                        "model",
                        Buffer (0x34)
                        {
                            "ASMedia ASM1074 / Intel Z790 Series Chipset USB 3.2"
                        },

                        "AAPL,current-available",
                        0x0834,
                        "AAPL,current-extra",
                        0x0A8C,
                        "AAPL,current-in-sleep",
                        0x0A8C,
                        "AAPL,max-port-current-in-sleep",
                        0x0834,
                        "AAPL,device-internal",
                        Zero,
                        "AAPL,clock-id",
                        Buffer (One)
                        {
                             0x01
                        },

                        "AAPL,root-hub-depth",
                        0x1A,
                        "AAPL,XHC-clock-id",
                        One,
                        Buffer (One)
                        {
                             0x00
                        }
                    }
                DTGP (Arg0, Arg1, Arg2, Arg3, RefOf (Local0))
                Return (Local0)
            }

            Method (_SB.PC00.SAT0._DSM, 4, NotSerialized)
            {
                Local0 = Package (0x0C)
                    {
                        "AAPL,slot-name",
                        Buffer (0x09)
                        {
                            "Built In"
                        },

                        "built-in",
                        Buffer (One)
                        {
                             0x00
                        },

                        "name",
                        Buffer (0x16)
                        {
                            "Intel AHCI Controller"
                        },

                        "model",
                        Buffer (0x1F)
                        {
                            "Intel Z790 Series Chipset SATA"
                        },

                        "device_type",
                        Buffer (0x15)
                        {
                            "AHCI SATA Controller"
                        },

                        "compatible",
                        Buffer (0x0D)
                        {
                            "pci8086,a182"
                        }
                    }
                DTGP (Arg0, Arg1, Arg2, Arg3, RefOf (Local0))
                Return (Local0)
            }
        }
        """
    }
    
    private func generatePLUG() -> String {
        return """
        DefinitionBlock ("", "SSDT", 2, "SYSM", "PLUG", 0x00000000)
        {
            External (_SB_.CP00, ProcessorObj)

            Scope (\\_SB.CP00)
            {
                Method (_DSM, 4, NotSerialized)
                {
                    If (!Arg2)
                    {
                        Return (Buffer (One)
                        {
                             0x03
                        })
                    }

                    Return (Package (0x02)
                    {
                        "plugin-type",
                        One
                    })
                }
            }
        }
        """
    }
    
    private func generatePMCR() -> String {
        return """
        DefinitionBlock ("", "SSDT", 2, "SYSM", "PMCR", 0x00000000)
        {
            External (_SB_.PC00.LPCB, DeviceObj)

            Scope (\\_SB.PC00.LPCB)
            {
                Device (PMCR)
                {
                    Name (_HID, EisaId ("APP9876"))
                    Method (_STA, 0, NotSerialized)
                    {
                        If (_OSI ("Darwin"))
                        {
                            Return (0x0B)
                        }
                        Else
                        {
                            Return (Zero)
                        }
                    }

                    Name (_CRS, ResourceTemplate ()
                    {
                        Memory32Fixed (ReadWrite,
                            0xFE000000,
                            0x00010000,
                            )
                    })
                }
            }
        }
        """
    }
    
    private func generatePPMC() -> String {
        return """
        DefinitionBlock ("", "SSDT", 2, "SYSM", "PPMC", 0x00000000)
        {
            External (_SB_.PC00, DeviceObj)
            External (_SB_.PC00.LPCB, DeviceObj)
            
            Scope (\\_SB.PC00.LPCB)
            {
                Device (PPMC)
                {
                    Name (_HID, "INT3A0D")
                    Name (_CID, "PNP0C02")
                    Name (_UID, One)
                    
                    Method (_STA, 0, NotSerialized)
                    {
                        If (_OSI ("Darwin"))
                        {
                            Return (0x0B)
                        }
                        Return (Zero)
                    }
                    
                    Name (_CRS, ResourceTemplate ()
                    {
                        Memory32Fixed (ReadWrite, 0xFED10000, 0x1000, )
                        Memory32Fixed (ReadWrite, 0xFED18000, 0x1000, )
                    })
                    
                    Method (_PTS, 1, NotSerialized)
                    {
                        Store (Arg0, PMSL)
                    }
                    
                    Method (_WAK, 1, NotSerialized)
                    {
                        Store (0x00, PMSL)
                        Return (Package (0x02){0x00, 0x00})
                    }
                    
                    Name (PMSL, 0x00)
                }
            }
        }
        """
    }
    
    private func generatePWRB() -> String {
        return """
        DefinitionBlock ("", "SSDT", 2, "SYSM", "PWRB", 0x00000000)
        {
            External (_SB_.PC00, DeviceObj)
            External (_SB_.PC00.LPCB, DeviceObj)
            External (_SB_.PC00.LPCB.EC, DeviceObj)
            
            Scope (\\_SB.PC00.LPCB.EC)
            {
                Device (PWRB)
                {
                    Name (_HID, EisaId ("PNP0C0C"))
                    Name (_CID, "PNP0C0C")
                    Name (_UID, 0x01)
                    
                    Method (_STA, 0, NotSerialized)
                    {
                        Return (0x0F)
                    }
                    
                    Name (_PRS, Package (0x02)
                    {
                        0x00,
                        0x01
                    })
                    
                    Method (_PRW, 0, NotSerialized)
                    {
                        Return (Package (0x02)
                        {
                            0x1B,
                            0x03
                        })
                    }
                    
                    Method (_PSW, 1, NotSerialized)
                    {
                        Store (Arg0, PWEN)
                    }
                    
                    Method (_PSB, 0, NotSerialized)
                    {
                        Notify (\\_SB.PWRB, 0x80)
                    }
                    
                    Name (PWEN, 0x01)
                }
            }
        }
        """
    }
    
    private func generateRTC0() -> String {
        return """
        DefinitionBlock ("", "SSDT", 2, "SYSM", "RTC0", 0x00000000)
        {
            External (_SB_.PC00, DeviceObj)
            External (_SB_.PC00.LPCB, DeviceObj)
            
            Scope (\\_SB.PC00.LPCB)
            {
                Device (RTC0)
                {
                    Name (_HID, "PNP0B00")
                    Name (_CID, "PNP0B00")
                    
                    Method (_STA, 0, NotSerialized)
                    {
                        Return (0x0F)
                    }
                    
                    Name (_CRS, ResourceTemplate ()
                    {
                        IO (Decode16, 0x0070, 0x0070, 0x01, 0x02)
                        IO (Decode16, 0x0071, 0x0071, 0x01, 0x02)
                        IRQ (Edge, ActiveHigh, Exclusive, ) {8}
                    })
                }
            }
        }
        """
    }
    
    private func generateSATA() -> String {
        return """
        DefinitionBlock ("", "SSDT", 2, "SYSM", "SATA", 0x00000000)
        {
            External (_SB_.PC00, DeviceObj)
            External (_SB_.PC00.SAT0, DeviceObj)
            External (DTGP, MethodObj)
            
            Method (_SB.PC00.SAT0._DSM, 4, NotSerialized)
            {
                Local0 = Package (0x0C)
                    {
                        "AAPL,slot-name",
                        Buffer (0x09)
                        {
                            "Built In"
                        },

                        "built-in",
                        Buffer (One)
                        {
                             0x00
                        },

                        "name",
                        Buffer (0x16)
                        {
                            "Intel AHCI Controller"
                        },

                        "model",
                        Buffer (0x1F)
                        {
                            "Intel Z790 Series Chipset SATA"
                        },

                        "device_type",
                        Buffer (0x15)
                        {
                            "AHCI SATA Controller"
                        },

                        "compatible",
                        Buffer (0x0D)
                        {
                            "pci8086,a182"
                        }
                    }
                DTGP (Arg0, Arg1, Arg2, Arg3, RefOf (Local0))
                Return (Local0)
            }
        }
        """
    }
    
    private func generateSBUS() -> String {
        return """
        DefinitionBlock ("", "SSDT", 2, "SYSM", "SBUS", 0x00000000)
        {
            External (_SB_.PC00, DeviceObj)
            External (_SB_.PC00.SBUS, DeviceObj)

            Device (_SB.PC00.SBUS.BUS0)
            {
                Name (_CID, "smbus")
                Name (_ADR, Zero)
                Device (DVL0)
                {
                    Name (_ADR, 0x57)
                    Name (_CID, "diagsvault")
                    Method (_DSM, 4, NotSerialized)
                    {
                        If (!Arg2)
                        {
                            Return (Buffer (One)
                            {
                                 0x57
                            })
                        }

                        Return (Package (0x02)
                        {
                            "address",
                            0x57
                        })
                    }
                }
            }
        }
        """
    }
    
    private func generateTMR() -> String {
        return """
        DefinitionBlock ("", "SSDT", 2, "SYSM", "TMR", 0x00000000)
        {
            External (_SB_.PC00, DeviceObj)
            External (_SB_.PC00.LPCB, DeviceObj)
            
            Scope (\\_SB.PC00.LPCB)
            {
                Device (TMR)
                {
                    Name (_HID, "PNP0100")
                    Name (_CID, "PNP0100")
                    
                    Method (_STA, 0, NotSerialized)
                    {
                        Return (0x0F)
                    }
                    
                    Name (_CRS, ResourceTemplate ()
                    {
                        IO (Decode16, 0x0040, 0x0040, 0x01, 0x01)
                        IO (Decode16, 0x0041, 0x0041, 0x01, 0x01)
                        IO (Decode16, 0x0042, 0x0042, 0x01, 0x01)
                        IO (Decode16, 0x0043, 0x0043, 0x01, 0x01)
                        IRQ (Edge, ActiveHigh, Exclusive, ) {0}
                    })
                }
            }
        }
        """
    }
    
    private func generateXOSI() -> String {
        return """
        DefinitionBlock ("", "SSDT", 2, "SYSM", "XOSI", 0x00000000)
        {
            Method (XOSI, 1, NotSerialized)
            {
                Local0 = Package (0x0D)
                    {
                        "Windows 2000",
                        "Windows 2001",
                        "Windows 2001 SP1",
                        "Windows 2001.1",
                        "Windows 2001 SP2",
                        "Windows 2001.1 SP1",
                        "Windows 2006",
                        "Windows 2006 SP1",
                        "Windows 2006.1",
                        "Windows 2009",
                        "Windows 2012",
                        "Windows 2013",
                        "Windows 2015"
                    }
                If (_OSI ("Darwin"))
                {
                    Return ((Match (Local0, MEQ, Arg0, MTR, Zero, Zero) != Ones))
                }
                Else
                {
                    Return (_OSI (Arg0))
                }
            }
        }
        """
    }
    
    private func generateHDEF() -> String {
        return """
        DefinitionBlock ("", "SSDT", 1, "SYSM", "HDEF", 0x00003000)
        {
            External (_SB_, DeviceObj)
            External (_SB_.PC00, DeviceObj)
            External (_SB_.PC00.HDAS, DeviceObj)
            External (DTGP, MethodObj)

            Scope (\\_SB.PC00)
            {
                Device (HDEF)
                {
                    Name (_ADR, 0x001F0003)
                    Method (_DSM, 4, NotSerialized)
                    {
                        If ((Arg2 == Zero))
                        {
                            Return (Buffer (One)
                            {
                                 0x03
                            })
                        }

                        Local0 = Package (0x18)
                            {
                                "layout-id",
                                Buffer (0x04)
                                {
                                     0x07, 0x00, 0x00, 0x00
                                },

                                "alc-layout-id",
                                Buffer (0x04)
                                {
                                     0x0C, 0x00, 0x00, 0x00
                                },

                                "MaximumBootBeepVolume",
                                Buffer (One)
                                {
                                     0xEF
                                },

                                "MaximumBootBeepVolumeAlt",
                                Buffer (One)
                                {
                                     0xF1
                                },

                                "multiEQDevicePresence",
                                Buffer (0x04)
                                {
                                     0x0C, 0x00, 0x01, 0x00
                                },

                                "AAPL,slot-name",
                                Buffer (0x09)
                                {
                                    "Built In"
                                },

                                "model",
                                Buffer (0x39)
                                {
                                    "Intel Union Point PCH - High Definition Audio Controller"
                                },

                                "hda-gfx",
                                Buffer (0x0A)
                                {
                                    "onboard-1"
                                },

                                "built-in",
                                Buffer (One)
                                {
                                     0x01
                                },

                                "device_type",
                                Buffer (0x16)
                                {
                                    "High Definition Audio"
                                },

                                "name",
                                Buffer (0x10)
                                {
                                    "Realtek ALC1220"
                                },

                                "PinConfigurations",
                                Buffer (Zero){}
                            }
                        DTGP (Arg0, Arg1, Arg2, Arg3, RefOf (Local0))
                        Return (Local0)
                    }
                }
            }

            Method (_SB.PC00.HDAS._STA, 0, NotSerialized)
            {
                Return (Zero)
            }
        }
        """
    }
    
    private func generateGenericSSDT(for ssdt: String) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        return """
        /*
         * \(ssdt).dsl
         * Generated by SSDT Generator
         * Date: \(dateFormatter.string(from: Date()))
         * Motherboard: \(motherboardModel)
         * Chipset: \(selectedChipset)
         * Device Type: \(selectedDeviceType)
         */
        
        DefinitionBlock ("", "SSDT", 2, "SYSM", "\(ssdt.replacingOccurrences(of: "SSDT-", with: ""))", 0x00000000)
        {
            // External references
            External (_SB_.PCI0, DeviceObj)
            External (_SB_.PCI0.LPCB, DeviceObj)
            External (_SB_.PCI0.PEG0, DeviceObj)
            External (_SB_.PCI0.SAT0, DeviceObj)
            External (_SB_.PCI0.XHCI, DeviceObj)
            
            Scope (\\)
            {
                // DTGP method - required for _DSM methods
                Method (DTGP, 5, NotSerialized)
                {
                    If (LEqual (Arg0, Buffer (0x10)
                        {
                            /* 0000 */  0xC6, 0xB7, 0xB5, 0xA0, 0x18, 0x13, 0x1C, 0x44,
                            /* 0008 */  0xB0, 0xC9, 0xFE, 0x69, 0x5E, 0xAF, 0x94, 0x9B
                        }))
                    {
                        If (LEqual (Arg1, One))
                        {
                            If (LEqual (Arg2, 0x03))
                            {
                                If (LEqual (Arg3, Buffer (0x04)
                                    {
                                        0x00, 0x00, 0x00, 0x03
                                    }))
                                {
                                    If (LEqual (Arg4, Zero))
                                    {
                                        Return (Buffer (One) { 0x03 })
                                    }
                                }
                            }
                        }
                    }
                    
                    Return (Buffer (One) { 0x00 })
                }
            }
            
            // \(ssdt) implementation
            Scope (_SB.PCI0)
            {
                Device (\(ssdt.replacingOccurrences(of: "SSDT-", with: "")))
                {
                    Name (_HID, "APP0001")
                    Name (_CID, "PNP0C02")
                    
                    Method (_STA, 0, NotSerialized)
                    {
                        If (_OSI ("Darwin"))
                        {
                            Return (0x0F)
                        }
                        Else
                        {
                            Return (0x00)
                        }
                    }
                    
                    Method (_DSM, 4, Serialized)
                    {
                        Store (Package (0x04)
                        {
                            "AAPL,slot-name",
                            Buffer () { "Generated Slot" },
                            "model",
                            Buffer () { "\(ssdt) Device" },
                            "built-in",
                            Buffer (One) { 0x01 }
                        }, Local0)
                        
                        DTGP (Arg0, Arg1, Arg2, Arg3, RefOf (Local0))
                        Return (Local0)
                    }
                }
            }
        }
        """
    }
    
    // MARK: - Utility Functions
    
    private func compileDSLToAML(dslPath: String, amlPath: String) -> (success: Bool, output: String) {
        let checkResult = ShellHelper.runCommand("which iasl")
        if !checkResult.success {
            return (false, "iasl compiler not found. Install with: brew install acpica")
        }
        
        let compileResult = ShellHelper.runCommand("iasl \"\(dslPath)\"")
        
        if compileResult.success {
            let compiledAMLPath = dslPath.replacingOccurrences(of: ".dsl", with: ".aml")
            let moveResult = ShellHelper.runCommand("mv \"\(compiledAMLPath)\" \"\(amlPath)\"")
            
            if moveResult.success {
                return (true, "Compiled successfully")
            } else {
                return (false, "Failed to move compiled file: \(moveResult.output)")
            }
        } else {
            return (false, "Compilation failed: \(compileResult.output)")
        }
    }
    
    private func getOutputDirectory() -> String {
        if !outputPath.isEmpty {
            return outputPath
        }
        
        let desktopPath = NSSearchPathForDirectoriesInDomains(.desktopDirectory, .userDomainMask, true).first ?? NSHomeDirectory()
        
        let ssdtDir = desktopPath + "/Generated_SSDTs"
        let fileManager = FileManager.default
        
        if !fileManager.fileExists(atPath: ssdtDir) {
            do {
                try fileManager.createDirectory(atPath: ssdtDir, withIntermediateDirectories: true)
            } catch {
                print("Failed to create directory: \(error)")
                return NSHomeDirectory() + "/Generated_SSDTs"
            }
        }
        return ssdtDir
    }
    
    private func openGeneratedFolder() {
        let outputDir = getOutputDirectory()
        let url = URL(fileURLWithPath: outputDir)
        
        if FileManager.default.fileExists(atPath: outputDir) {
            NSWorkspace.shared.open(url)
        } else {
            do {
                try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
                NSWorkspace.shared.open(url)
            } catch {
                alertTitle = "Error"
                alertMessage = "Failed to create/open folder: \(error.localizedDescription)"
                showAlert = true
            }
        }
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
        Task {
            var validationMessages: [String] = ["SSDT Validation Report:"]
            
            let iaslCheck = ShellHelper.runCommand("which iasl")
            validationMessages.append(iaslCheck.success ? "✅ iasl compiler found" : "❌ iasl compiler not found")
            
            if iaslCheck.success {
                let outputDir = getOutputDirectory()
                let fileManager = FileManager.default
                
                do {
                    let files = try fileManager.contentsOfDirectory(atPath: outputDir)
                    let dslFiles = files.filter { $0.hasSuffix(".dsl") }
                    
                    if dslFiles.isEmpty {
                        validationMessages.append("⚠️ No DSL files found to validate")
                    } else {
                        validationMessages.append("\nValidating \(dslFiles.count) DSL files:")
                        
                        for dslFile in dslFiles {
                            let filePath = "\(outputDir)/\(dslFile)"
                            let validateResult = ShellHelper.runCommand("iasl -vs \"\(filePath)\"")
                            
                            if validateResult.success {
                                validationMessages.append("✅ \(dslFile): Syntax OK")
                            } else {
                                let lines = validateResult.output.components(separatedBy: "\n")
                                let errors = lines.filter { $0.contains("Error") || $0.contains("error") }
                                validationMessages.append("❌ \(dslFile): \(errors.first ?? "Syntax error")")
                            }
                        }
                    }
                } catch {
                    validationMessages.append("❌ Failed to read output directory: \(error.localizedDescription)")
                }
            }
            
            validationMessages.append("\nCommon Issues to Check:")
            validationMessages.append("• All SSDTs must have valid DefinitionBlock")
            validationMessages.append("• Method names must follow ACPI naming conventions")
            validationMessages.append("• External references must be declared")
            validationMessages.append("• Use proper scope (\\ for root, _SB for devices)")
            
            await MainActor.run {
                alertTitle = "SSDT Validation"
                alertMessage = validationMessages.joined(separator: "\n")
                showAlert = true
            }
        }
    }
    
    private func saveToFile() {
        if generatedSSDTs.isEmpty {
            alertTitle = "No SSDTs Generated"
            alertMessage = "Please generate SSDTs first before saving to file."
            showAlert = true
            return
        }
        
        let panel = NSOpenPanel()
        panel.title = "Select Output Folder"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        
        if panel.runModal() == .OK, let url = panel.url {
            saveSSDTsToFolder(at: url)
        }
    }
    
    private func saveSSDTsToFolder(at url: URL) {
        Task {
            let fileManager = FileManager.default
            let outputDir = getOutputDirectory()
            
            do {
                let files = try fileManager.contentsOfDirectory(atPath: outputDir)
                let generatedFiles = files.filter { generatedSSDTs.contains($0) }
                
                if generatedFiles.isEmpty {
                    await MainActor.run {
                        alertTitle = "No Files to Save"
                        alertMessage = "No generated SSDT files found in the output directory."
                        showAlert = true
                    }
                    return
                }
                
                var successCount = 0
                var failedCount = 0
                var errorMessages: [String] = []
                
                for file in generatedFiles {
                    let sourcePath = "\(outputDir)/\(file)"
                    let destinationPath = url.appendingPathComponent(file).path
                    
                    do {
                        try fileManager.copyItem(atPath: sourcePath, toPath: destinationPath)
                        successCount += 1
                    } catch {
                        failedCount += 1
                        errorMessages.append("Failed to copy \(file): \(error.localizedDescription)")
                    }
                }
                
                let readmeContent = """
                # Generated SSDTs
                
                ## Generation Details
                • Generated on: \(Date())
                • Motherboard: \(motherboardModel)
                • Chipset: \(selectedChipset)
                • Device Type: \(selectedDeviceType)
                • Total Files: \(generatedFiles.count)
                
                ## Files Included:
                \(generatedFiles.map { "• \($0)" }.joined(separator: "\n"))
                
                ## How to Use:
                1. Copy .aml files to EFI/OC/ACPI/
                2. Add SSDT entries to config.plist → ACPI → Add
                3. Set Enabled = True for each SSDT
                4. Rebuild kernel cache and restart
                
                ## Notes:
                • Review each SSDT for your specific hardware
                • Test SSDTs individually before using all at once
                • Keep backups of your original ACPI tables
                """
                
                let readmePath = url.appendingPathComponent("README.txt").path
                try readmeContent.write(toFile: readmePath, atomically: true, encoding: .utf8)
                
                await MainActor.run {
                    if failedCount == 0 {
                        alertTitle = "Save Successful"
                        alertMessage = """
                        Successfully saved \(successCount) SSDT files to:
                        \(url.path)
                        
                        Files saved:
                        • \(generatedFiles.joined(separator: "\n• "))
                        • README.txt (with instructions)
                        
                        ⚠️ Remember to review and test these SSDTs before using them!
                        """
                    } else {
                        alertTitle = "Partial Save"
                        alertMessage = """
                        Saved \(successCount) of \(generatedFiles.count) files to:
                        \(url.path)
                        
                        Errors encountered:
                        \(errorMessages.joined(separator: "\n"))
                        """
                    }
                    showAlert = true
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        NSWorkspace.shared.open(url)
                    }
                }
                
            } catch {
                await MainActor.run {
                    alertTitle = "Save Failed"
                    alertMessage = "Failed to save SSDTs: \(error.localizedDescription)"
                    showAlert = true
                }
            }
        }
    }
    
    private func openSSDTGuide() {
        if let url = URL(string: "https://dortania.github.io/Getting-Started-With-ACPI/") {
            NSWorkspace.shared.open(url)
        }
    }
}