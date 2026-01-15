import SwiftUI

struct KextsManagerView: View {
    @StateObject private var kextsManager = KextsManager()
    @State private var selectedKexts = Set<String>()
    @State private var searchText = ""
    @State private var showDeveloperInfo = false
    @State private var isLoading = false
    
    var filteredKexts: [KextInfo] {
        if searchText.isEmpty {
            return kextsManager.allKexts
        } else {
            return kextsManager.allKexts.filter { 
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.bundleID.localizedCaseInsensitiveContains(searchText) ||
                $0.version.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        NavigationView {
            List(selection: $selectedKexts) {
                ForEach(filteredKexts) { kext in
                    KextRow(kext: kext)
                        .contextMenu {
                            Button("Load Kext") {
                                kextsManager.loadKext(kext)
                            }
                            
                            Button("Unload Kext") {
                                kextsManager.unloadKext(kext)
                            }
                            
                            Divider()
                            
                            Button("Reveal in Finder") {
                                kextsManager.revealInFinder(kext)
                            }
                            
                            Button("Get Info") {
                                // Show detailed info
                            }
                        }
                }
            }
            .listStyle(SidebarListStyle())
            .frame(minWidth: 250)
            
            // Main content area
            VStack {
                if let selectedKext = kextsManager.allKexts.first(where: { $0.id == selectedKexts.first }) {
                    KextDetailView(kext: selectedKext)
                } else {
                    VStack(spacing: 20) {
                        Image(systemName: "gearshape.2.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        
                        Text("No Kext Selected")
                            .font(.title2)
                            .foregroundColor(.secondary)
                        
                        Text("Select a kext from the sidebar to view its details")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Developer Info Sidebar
            VStack(alignment: .leading, spacing: 20) {
                // Developer Information Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Developer Information")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    AuthorInfoView(
                        name: "Navaratnam Manoranjan",
                        email: "nmano0006@gmail.com",
                        title: "Kexts Manager",
                        showIcon: true
                    )
                    
                    Divider()
                    
                    // App Information
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "app.badge")
                                .foregroundColor(.blue)
                            Text("App Version")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("2.7.8.1.0")
                                .font(.caption)
                                .foregroundColor(.blue)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(4)
                        }
                        
                        HStack {
                            Image(systemName: "calendar")
                                .foregroundColor(.green)
                            Text("Last Updated")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("2024")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding()
                .background(Color.blue.opacity(0.03))
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.blue.opacity(0.1), lineWidth: 1)
                )
                
                // Kext Statistics
                VStack(alignment: .leading, spacing: 12) {
                    Text("Kext Statistics")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    VStack(spacing: 8) {
                        StatRow(
                            icon: "gearshape.fill",
                            label: "Total Kexts",
                            value: "\(kextsManager.allKexts.count)",
                            color: .blue
                        )
                        
                        StatRow(
                            icon: "checkmark.circle.fill",
                            label: "Loaded",
                            value: "\(kextsManager.allKexts.filter { $0.isLoaded }.count)",
                            color: .green
                        )
                        
                        StatRow(
                            icon: "xmark.circle.fill",
                            label: "Unloaded",
                            value: "\(kextsManager.allKexts.filter { !$0.isLoaded }.count)",
                            color: .orange
                        )
                        
                        StatRow(
                            icon: "exclamationmark.triangle.fill",
                            label: "System Kexts",
                            value: "\(kextsManager.allKexts.filter { $0.isSystem }.count)",
                            color: .red
                        )
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.03))
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.gray.opacity(0.1), lineWidth: 1)
                )
                
                Spacer()
                
                // Quick Actions
                VStack(alignment: .leading, spacing: 12) {
                    Text("Quick Actions")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    VStack(spacing: 8) {
                        Button(action: {
                            kextsManager.refreshKexts()
                        }) {
                            Label("Refresh Kexts", systemImage: "arrow.clockwise")
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.blue.opacity(0.05))
                        .cornerRadius(8)
                        
                        Button(action: {
                            // Show kext installation guide
                        }) {
                            Label("Install Kext Guide", systemImage: "doc.text.fill")
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.green.opacity(0.05))
                        .cornerRadius(8)
                        
                        Button(action: {
                            showDeveloperInfo.toggle()
                        }) {
                            Label("Developer Contact", systemImage: "person.crop.circle")
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.orange.opacity(0.05))
                        .cornerRadius(8)
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.03))
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.gray.opacity(0.1), lineWidth: 1)
                )
            }
            .frame(minWidth: 280, maxWidth: 320)
            .padding()
        }
        .navigationTitle("Kexts Manager")
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button(action: toggleSidebar) {
                    Image(systemName: "sidebar.left")
                }
            }
            
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button("Load All Kexts") {
                        kextsManager.loadAllKexts()
                    }
                    
                    Button("Unload All Kexts") {
                        kextsManager.unloadAllKexts()
                    }
                    
                    Divider()
                    
                    Button("Refresh") {
                        kextsManager.refreshKexts()
                    }
                    
                    Button("Export List") {
                        kextsManager.exportKextList()
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
            
            // Developer badge in toolbar
            ToolbarItem(placement: .status) {
                CompactAuthorView(
                    name: "N. Manoranjan",
                    email: "nmano0006@gmail.com"
                )
                .onTapGesture {
                    showDeveloperInfo.toggle()
                }
            }
        }
        .searchable(text: $searchText, placement: .toolbar)
        .onAppear {
            kextsManager.refreshKexts()
        }
        .sheet(isPresented: $showDeveloperInfo) {
            DeveloperContactSheet()
        }
    }
    
    private func toggleSidebar() {
        NSApp.keyWindow?.firstResponder?.tryToPerform(#selector(NSSplitViewController.toggleSidebar(_:)), with: nil)
    }
}

// MARK: - Supporting Views

struct KextRow: View {
    let kext: KextInfo
    
    var body: some View {
        HStack {
            Image(systemName: kextIcon)
                .foregroundColor(kextColor)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(kext.name)
                    .font(.headline)
                    .lineLimit(1)
                
                Text(kext.bundleID)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            if kext.isLoaded {
                Badge(text: "Loaded", color: .green)
            } else {
                Badge(text: "Unloaded", color: .orange)
            }
            
            if kext.isSystem {
                Badge(text: "System", color: .red)
            }
        }
        .padding(.vertical, 4)
    }
    
    private var kextIcon: String {
        if kext.isSystem {
            return "shield.fill"
        } else if kext.isLoaded {
            return "checkmark.circle.fill"
        } else {
            return "circle"
        }
    }
    
    private var kextColor: Color {
        if kext.isSystem {
            return .red
        } else if kext.isLoaded {
            return .green
        } else {
            return .gray
        }
    }
}

struct KextDetailView: View {
    let kext: KextInfo
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack {
                    Image(systemName: kext.isSystem ? "shield.fill" : "gearshape.fill")
                        .font(.system(size: 40))
                        .foregroundColor(kext.isSystem ? .red : .blue)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(kext.name)
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text(kext.bundleID)
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 8) {
                        Badge(text: kext.isLoaded ? "LOADED" : "UNLOADED", 
                              color: kext.isLoaded ? .green : .orange)
                        
                        if kext.isSystem {
                            Badge(text: "SYSTEM KEXT", color: .red)
                        }
                    }
                }
                .padding(.bottom)
                
                Divider()
                
                // Information Grid
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    InfoCard(
                        title: "Version",
                        value: kext.version,
                        icon: "number",
                        color: .blue
                    )
                    
                    InfoCard(
                        title: "Size",
                        value: kext.size,
                        icon: "externaldrive.fill",
                        color: .green
                    )
                    
                    InfoCard(
                        title: "Path",
                        value: kext.path,
                        icon: "folder.fill",
                        color: .orange
                    )
                    
                    InfoCard(
                        title: "Last Modified",
                        value: kext.lastModified,
                        icon: "calendar",
                        color: .purple
                    )
                }
                
                // Description
                if !kext.description.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Description")
                            .font(.headline)
                        
                        Text(kext.description)
                            .font(.body)
                            .foregroundColor(.secondary)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.gray.opacity(0.05))
                            .cornerRadius(8)
                    }
                }
                
                // Dependencies
                if !kext.dependencies.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Dependencies")
                            .font(.headline)
                        
                        ForEach(kext.dependencies, id: \.self) { dependency in
                            HStack {
                                Image(systemName: "link")
                                    .foregroundColor(.blue)
                                Text(dependency)
                                    .font(.caption)
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.05))
                            .cornerRadius(4)
                        }
                    }
                }
                
                Spacer()
            }
            .padding()
        }
    }
}

struct Badge: View {
    let text: String
    let color: Color
    
    var body: some View {
        Text(text)
            .font(.caption)
            .fontWeight(.semibold)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.1))
            .foregroundColor(color)
            .cornerRadius(4)
    }
}

struct InfoCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text(value)
                .font(.body)
                .fontWeight(.medium)
                .lineLimit(2)
                .truncationMode(.middle)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.05))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(color.opacity(0.1), lineWidth: 1)
        )
    }
}

struct StatRow: View {
    let icon: String
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 20)
            
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.headline)
                .foregroundColor(color)
        }
    }
}

// MARK: - Developer Contact Sheet

struct DeveloperContactSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Developer Contact")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.gray)
                }
                .buttonStyle(.plain)
            }
            .padding()
            
            Divider()
            
            ScrollView {
                VStack(spacing: 24) {
                    // Developer Profile
                    VStack(spacing: 16) {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 80))
                            .foregroundColor(.blue)
                        
                        VStack(spacing: 4) {
                            Text("Navaratnam Manoranjan")
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            Text("OpenCore Configurator Developer")
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.top)
                    
                    // Contact Information
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Contact Information")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        ContactItem(
                            icon: "envelope.fill",
                            title: "Email",
                            value: "nmano0006@gmail.com",
                            actionType: .email
                        )
                        
                        ContactItem(
                            icon: "globe",
                            title: "Support",
                            value: "OpenCore Community",
                            actionType: .link("https://dortania.github.io/OpenCore-Install-Guide/")
                        )
                        
                        ContactItem(
                            icon: "book.fill",
                            title: "Documentation",
                            value: "OpenCore Docs",
                            actionType: .link("https://dortania.github.io/OpenCore-Install-Guide/")
                        )
                    }
                    .padding()
                    .background(Color.blue.opacity(0.03))
                    .cornerRadius(12)
                    
                    // App Information
                    VStack(alignment: .leading, spacing: 16) {
                        Text("App Information")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        InfoRow(label: "Version", value: "2.7.8.1.0")
                        InfoRow(label: "Build Date", value: "2024")
                        InfoRow(label: "Compatibility", value: "macOS 10.15+")
                        InfoRow(label: "License", value: "Open Source")
                    }
                    .padding()
                    .background(Color.gray.opacity(0.03))
                    .cornerRadius(12)
                    
                    // Quick Links
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Quick Links")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        LinkButton(
                            icon: "doc.text.fill",
                            title: "OpenCore Documentation",
                            url: "https://dortania.github.io/OpenCore-Install-Guide/"
                        )
                        
                        LinkButton(
                            icon: "person.2.fill",
                            title: "Hackintosh Community",
                            url: "https://www.reddit.com/r/hackintosh/"
                        )
                        
                        LinkButton(
                            icon: "wrench.and.screwdriver.fill",
                            title: "Kext Repository",
                            url: "https://github.com/acidanthera"
                        )
                    }
                    .padding()
                    .background(Color.orange.opacity(0.03))
                    .cornerRadius(12)
                }
                .padding()
            }
        }
        .frame(width: 500, height: 600)
    }
}

struct ContactItem: View {
    let icon: String
    let title: String
    let value: String
    let actionType: ActionType
    
    enum ActionType {
        case email
        case link(String)
        case none
    }
    
    var body: some View {
        Button(action: performAction) {
            HStack {
                Image(systemName: icon)
                    .frame(width: 24)
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text(value)
                        .font(.body)
                        .foregroundColor(.blue)
                }
                
                Spacer()
                
                Image(systemName: "arrow.up.right")
                    .font(.caption)
                    .foregroundColor(.blue.opacity(0.5))
            }
            .padding()
            .background(Color.blue.opacity(0.05))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
    
    private func performAction() {
        switch actionType {
        case .email:
            if let url = URL(string: "mailto:\(value)") {
                NSWorkspace.shared.open(url)
            }
        case .link(let urlString):
            if let url = URL(string: urlString) {
                NSWorkspace.shared.open(url)
            }
        case .none:
            break
        }
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.body)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.body)
                .fontWeight(.medium)
                .foregroundColor(.primary)
        }
    }
}

struct LinkButton: View {
    let icon: String
    let title: String
    let url: String
    
    var body: some View {
        Button(action: {
            if let url = URL(string: self.url) {
                NSWorkspace.shared.open(url)
            }
        }) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.orange)
                
                Text(title)
                    .font(.body)
                    .foregroundColor(.orange)
                
                Spacer()
                
                Image(systemName: "arrow.up.right")
                    .font(.caption)
                    .foregroundColor(.orange.opacity(0.5))
            }
            .padding()
            .background(Color.orange.opacity(0.05))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Kexts Manager Model

class KextsManager: ObservableObject {
    @Published var allKexts: [KextInfo] = []
    
    func refreshKexts() {
        // Load kexts from system
        DispatchQueue.global(qos: .userInitiated).async {
            let kexts = self.loadSystemKexts()
            
            DispatchQueue.main.async {
                self.allKexts = kexts
            }
        }
    }
    
    func loadKext(_ kext: KextInfo) {
        // Implementation to load kext
        print("Loading kext: \(kext.name)")
    }
    
    func unloadKext(_ kext: KextInfo) {
        // Implementation to unload kext
        print("Unloading kext: \(kext.name)")
    }
    
    func loadAllKexts() {
        // Implementation to load all kexts
    }
    
    func unloadAllKexts() {
        // Implementation to unload all kexts
    }
    
    func revealInFinder(_ kext: KextInfo) {
        // Implementation to reveal kext in Finder
    }
    
    func exportKextList() {
        // Implementation to export kext list
    }
    
    private func loadSystemKexts() -> [KextInfo] {
        // Load kexts from /System/Library/Extensions and /Library/Extensions
        return [
            KextInfo(
                name: "AppleACPIPlatform",
                bundleID: "com.apple.driver.AppleACPIPlatform",
                version: "1.4",
                size: "2.1 MB",
                path: "/System/Library/Extensions/AppleACPIPlatform.kext",
                isLoaded: true,
                isSystem: true,
                description: "ACPI platform driver",
                dependencies: ["com.apple.iokit.IOACPIFamily"],
                lastModified: "2024-01-15"
            ),
            KextInfo(
                name: "Lilu",
                bundleID: "as.vit9696.Lilu",
                version: "1.6.5",
                size: "1.8 MB",
                path: "/Library/Extensions/Lilu.kext",
                isLoaded: true,
                isSystem: false,
                description: "An open source kernel extension bringing a platform for arbitrary kext, library, and program patching",
                dependencies: [],
                lastModified: "2024-01-10"
            ),
            KextInfo(
                name: "WhateverGreen",
                bundleID: "as.vit9696.WhateverGreen",
                version: "1.6.3",
                size: "2.3 MB",
                path: "/Library/Extensions/WhateverGreen.kext",
                isLoaded: true,
                isSystem: false,
                description: "Various patches necessary for certain ATI/AMD/Intel/Nvidia GPUs",
                dependencies: ["as.vit9696.Lilu"],
                lastModified: "2024-01-10"
            )
        ]
    }
}

struct KextInfo: Identifiable {
    let id = UUID()
    let name: String
    let bundleID: String
    let version: String
    let size: String
    let path: String
    let isLoaded: Bool
    let isSystem: Bool
    let description: String
    let dependencies: [String]
    let lastModified: String
}

// MARK: - Preview

struct KextsManagerView_Previews: PreviewProvider {
    static var previews: some View {
        KextsManagerView()
    }
}

struct DeveloperContactSheet_Previews: PreviewProvider {
    static var previews: some View {
        DeveloperContactSheet()
    }
}