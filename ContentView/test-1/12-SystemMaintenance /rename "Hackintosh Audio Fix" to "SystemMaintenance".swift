// MARK: - Main Content View
struct ContentView: View {
    @State private var selectedTab = 0
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var alertTitle = "Status"
    @State private var isDownloadingKDK = false
    @State private var isInstallingKext = false
    @State private var isUninstallingKDK = false
    @State private var isMountingPartition = false
    @State private var downloadProgress: Double = 0
    @State private var installedKDKVersion: String? = nil
    @State private var systemProtectStatus: String = "Checking..."
    @State private var appleHDAStatus: String = "Checking..."
    @State private var appleHDAVersion: String? = nil
    @State private var appleALCStatus: String = "Checking..."
    @State private var appleALCVersion: String? = nil
    @State private var liluStatus: String = "Checking..."
    @State private var liluVersion: String? = nil
    @State private var showDonationSheet = false
    @State private var efiPath: String? = nil
    @State private var showEFISelectionView = false
    @State private var allDrives: [DriveInfo] = []
    @State private var kextSourcePath: String = ""
    @State private var systemInfo = SystemInfo()
    @State private var showDiskDetailView = false
    @State private var selectedDrive: DriveInfo?
    @State private var isLoadingDrives = false
    
    var body: some View {
        VStack(spacing: 0) {
            headerView
            
            TabView(selection: $selectedTab) {
                SystemMaintenanceView(
                    isDownloadingKDK: $isDownloadingKDK,
                    isUninstallingKDK: $isUninstallingKDK,
                    isMountingPartition: $isMountingPartition,
                    downloadProgress: $downloadProgress,
                    showAlert: $showAlert,
                    alertTitle: $alertTitle,
                    alertMessage: $alertMessage,
                    installedKDKVersion: $installedKDKVersion,
                    systemProtectStatus: $systemProtectStatus,
                    appleHDAStatus: $appleHDAStatus,
                    appleHDAVersion: $appleHDAVersion,
                    appleALCStatus: $appleALCStatus,
                    appleALCVersion: $appleALCVersion,
                    liluStatus: $liluStatus,
                    liluVersion: $liluVersion,
                    efiPath: $efiPath,
                    showEFISelectionView: $showEFISelectionView,
                    allDrives: $allDrives,
                    isLoadingDrives: $isLoadingDrives,
                    showDiskDetailView: $showDiskDetailView,
                    refreshDrives: refreshAllDrives
                )
                .tabItem {
                    Label("System", systemImage: "gear")
                }
                .tag(0)
                
                KextManagementView(
                    isInstallingKext: $isInstallingKext,
                    showAlert: $showAlert,
                    alertTitle: $alertTitle,
                    alertMessage: $alertMessage,
                    appleHDAStatus: $appleHDAStatus,
                    appleHDAVersion: $appleHDAVersion,
                    appleALCStatus: $appleALCStatus,
                    appleALCVersion: $appleALCVersion,
                    liluStatus: $liluStatus,
                    liluVersion: $liluVersion,
                    efiPath: $efiPath,
                    kextSourcePath: $kextSourcePath
                )
                .tabItem {
                    Label("Kexts", systemImage: "puzzlepiece.extension")
                }
                .tag(1)
                
                SystemInfoView(
                    showAlert: $showAlert,
                    alertTitle: $alertTitle,
                    alertMessage: $alertMessage,
                    appleHDAStatus: $appleHDAStatus,
                    appleALCStatus: $appleALCStatus,
                    liluStatus: $liluStatus,
                    efiPath: $efiPath,
                    systemInfo: $systemInfo,
                    allDrives: $allDrives,
                    refreshSystemInfo: refreshSystemInfo
                )
                .tabItem {
                    Label("Info", systemImage: "info.circle")
                }
                .tag(2)
                
                AudioToolsView(
                    showAlert: $showAlert,
                    alertTitle: $alertTitle,
                    alertMessage: $alertMessage
                )
                .tabItem {
                    Label("Audio Tools", systemImage: "speaker.wave.3")
                }
                .tag(3)
            }
            .tabViewStyle(.automatic)
        }
        .alert(alertTitle, isPresented: $showAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
        .sheet(isPresented: $showDonationSheet) {
            DonationView()
        }
        .sheet(isPresented: $showEFISelectionView) {
            EFISelectionView(
                isPresented: $showEFISelectionView,
                efiPath: $efiPath,
                showAlert: $showAlert,
                alertTitle: $alertTitle,
                alertMessage: $alertMessage,
                allDrives: $allDrives
            )
        }
        .sheet(isPresented: $showDiskDetailView) {
            if let drive = selectedDrive {
                DiskDetailView(
                    isPresented: $showDiskDetailView,
                    drive: drive,
                    allDrives: $allDrives,
                    refreshDrives: refreshAllDrives
                )
            }
        }
        .onAppear {
            checkSystemStatus()
            loadAllDrives()
            checkEFIMount()
            loadSystemInfo()
        }
    }
    
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("SystemMaintenance")  // Changed from "Hackintosh Audio Fix"
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Text("System Maintenance & Kext Management")  // Changed subtitle
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            HStack(spacing: 12) {
                // System Info
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(allDrives.filter { $0.isInternal }.count) Internal • \(allDrives.filter { !$0.isInternal }.count) External")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(allDrives.count) Total Drives")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                // Audio Status
                HStack(spacing: 4) {
                    Circle()
                        .fill(audioStatusColor)
                        .frame(width: 8, height: 8)
                    Text("Audio: \(audioStatus)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(audioStatusColor.opacity(0.1))
                .cornerRadius(20)
            }
        }
        .padding()
        .background(Color(.windowBackgroundColor))
    }
    
    private var audioStatus: String {
        if appleHDAStatus == "Installed" && appleALCStatus == "Installed" && liluStatus == "Installed" {
            return "Working"
        } else {
            return "Setup Required"
        }
    }
    
    private var audioStatusColor: Color {
        audioStatus == "Working" ? .green : .orange
    }
    
    private func checkSystemStatus() {
        let sipDisabled = ShellHelper.isSIPDisabled()
        systemProtectStatus = sipDisabled ? "Disabled" : "Enabled"
        
        DispatchQueue.global(qos: .background).async {
            let liluLoaded = ShellHelper.checkKextLoaded("Lilu")
            let appleALCLoaded = ShellHelper.checkKextLoaded("AppleALC")
            let appleHDALoaded = ShellHelper.checkKextLoaded("AppleHDA")
            
            let liluVer = ShellHelper.getKextVersion("Lilu")
            let appleALCVer = ShellHelper.getKextVersion("AppleALC")
            let appleHDAVer = ShellHelper.getKextVersion("AppleHDA")
            
            DispatchQueue.main.async {
                liluStatus = liluLoaded ? "Installed" : "Not Installed"
                appleALCStatus = appleALCLoaded ? "Installed" : "Not Installed"
                appleHDAStatus = appleHDALoaded ? "Installed" : "Not Installed"
                
                liluVersion = liluVer
                appleALCVersion = appleALCVer
                appleHDAVersion = appleHDAVer
            }
        }
    }
    
    private func loadAllDrives() {
        isLoadingDrives = true
        DispatchQueue.global(qos: .background).async {
            let drives = ShellHelper.getAllDrives()
            DispatchQueue.main.async {
                allDrives = drives
                isLoadingDrives = false
            }
        }
    }
    
    private func refreshAllDrives() {
        loadAllDrives()
    }
    
    private func checkEFIMount() {
        DispatchQueue.global(qos: .background).async {
            if ShellHelper.mountEFIPartition() {
                let path = ShellHelper.getEFIPath()
                DispatchQueue.main.async {
                    efiPath = path
                }
            }
        }
    }
    
    private func loadSystemInfo() {
        DispatchQueue.global(qos: .background).async {
            let info = ShellHelper.getSystemInfo()
            DispatchQueue.main.async {
                systemInfo = info
            }
        }
    }
    
    private func refreshSystemInfo() {
        loadSystemInfo()
    }
}

// MARK: - Preview
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .frame(width: 1200, height: 800)
    }
}