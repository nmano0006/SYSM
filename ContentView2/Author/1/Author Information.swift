import SwiftUI

// MARK: - Author Information View Component
struct AuthorInfoView: View {
    let name: String
    let email: String
    let title: String
    let showIcon: Bool
    
    init(name: String = "Navaratnam Manoranjan", 
         email: String = "nmano0006@gmail.com", 
         title: String = "OpenCore Configurator",
         showIcon: Bool = true) {
        self.name = name
        self.email = email
        self.title = title
        self.showIcon = showIcon
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Title section
            HStack {
                if showIcon {
                    Image(systemName: "person.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.blue)
                }
                
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)
                
                Spacer()
            }
            
            // Name section
            HStack {
                Text("Developer:")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                
                Text(name)
                    .font(.system(size: 12, design: .rounded))
                    .foregroundColor(.blue)
                    .lineLimit(1)
                
                Spacer()
            }
            .padding(.leading, showIcon ? 20 : 0)
            
            // Email section
            HStack {
                Image(systemName: "envelope.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.gray)
                
                Text(email)
                    .font(.system(size: 11))
                    .foregroundColor(.blue)
                    .lineLimit(1)
                    .truncationMode(.middle)
                
                Spacer()
                
                // Optional copy button
                Button(action: {
                    copyToClipboard(email)
                }) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 10))
                        .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
                .help("Copy email")
            }
            .padding(.leading, showIcon ? 20 : 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.blue.opacity(0.05))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.blue.opacity(0.2), lineWidth: 1)
        )
    }
    
    private func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        
        // You could add feedback here (like a toast notification)
        #if os(macOS)
        NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
        #endif
    }
}

// MARK: - Compact Author View (for toolbars)
struct CompactAuthorView: View {
    let name: String
    let email: String
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "person.circle.fill")
                .font(.system(size: 14))
                .foregroundColor(.blue)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Text(email)
                    .font(.system(size: 9))
                    .foregroundColor(.blue)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.blue.opacity(0.08))
        .cornerRadius(6)
    }
}

// MARK: - Author Badge View (small badge for corners)
struct AuthorBadgeView: View {
    let name: String
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "person.fill")
                .font(.system(size: 10))
            
            Text("By: \(name)")
                .font(.system(size: 10, weight: .medium))
        }
        .foregroundColor(.blue)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(
            Capsule()
                .fill(Color.blue.opacity(0.1))
        )
        .overlay(
            Capsule()
                .stroke(Color.blue.opacity(0.3), lineWidth: 0.5)
        )
    }
}

// MARK: - Preview Provider
struct AuthorInfoView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            AuthorInfoView()
                .frame(width: 300)
            
            CompactAuthorView(
                name: "Navaratnam Manoranjan",
                email: "nmano0006@gmail.com"
            )
            
            AuthorBadgeView(name: "N. Manoranjan")
            
            // Alternative styling
            AuthorInfoView(
                name: "John Developer",
                email: "john@example.com",
                title: "App Developer",
                showIcon: false
            )
            .frame(width: 300)
        }
        .padding()
    }
}

// MARK: - Usage Examples in Your Views
/*
Example 1: In a sidebar or info panel
struct SidebarView: View {
    var body: some View {
        VStack {
            // ... other content
            
            AuthorInfoView()
                .padding()
        }
    }
}

Example 2: In a toolbar
struct ContentView: View {
    var body: some View {
        VStack {
            // ... main content
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                CompactAuthorView(
                    name: "Navaratnam Manoranjan",
                    email: "nmano0006@gmail.com"
                )
            }
        }
    }
}

Example 3: As a corner badge
struct DetailView: View {
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            // ... main content
            
            AuthorBadgeView(name: "N. Manoranjan")
                .padding()
        }
    }
}
*/

// MARK: - Author Information Model (for more complex scenarios)
struct AuthorInfo {
    let name: String
    let email: String
    let website: String?
    let github: String?
    let role: String
    let version: String
    
    static let defaultAuthor = AuthorInfo(
        name: "Navaratnam Manoranjan",
        email: "nmano0006@gmail.com",
        website: nil,
        github: nil,
        role: "Lead Developer",
        version: "2.7.8.1.0"
    )
}

// MARK: - Enhanced Author View with Model
struct EnhancedAuthorView: View {
    let author: AuthorInfo
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(author.name)
                        .font(.title3.weight(.bold))
                    
                    Text(author.role)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Version badge
                Text("v\(author.version)")
                    .font(.caption.weight(.medium))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(4)
            }
            
            Divider()
            
            // Contact info
            VStack(alignment: .leading, spacing: 8) {
                ContactRow(icon: "envelope.fill", text: author.email, isEmail: true)
                
                if let website = author.website {
                    ContactRow(icon: "globe", text: website, isLink: true)
                }
                
                if let github = author.github {
                    ContactRow(icon: "chevron.left.forwardslash.chevron.right", text: github, isLink: true)
                }
            }
            
            // Copyright notice
            Text("© \(Calendar.current.component(.year, from: Date())) \(author.name)")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 8)
        }
        .padding()
        .background(Color.blue.opacity(0.03))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.blue.opacity(0.1), lineWidth: 1)
        )
    }
}

struct ContactRow: View {
    let icon: String
    let text: String
    var isEmail: Bool = false
    var isLink: Bool = false
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 12))
                .frame(width: 20)
                .foregroundColor(.blue)
            
            Text(text)
                .font(.system(size: 13))
                .foregroundColor(isEmail || isLink ? .blue : .primary)
                .lineLimit(1)
                .truncationMode(.middle)
            
            Spacer()
            
            if isEmail || isLink {
                Button(action: {
                    if isEmail {
                        // Open email client
                        if let url = URL(string: "mailto:\(text)") {
                            #if os(macOS)
                            NSWorkspace.shared.open(url)
                            #else
                            UIApplication.shared.open(url)
                            #endif
                        }
                    } else if isLink {
                        // Open website
                        let urlString = text.hasPrefix("http") ? text : "https://\(text)"
                        if let url = URL(string: urlString) {
                            #if os(macOS)
                            NSWorkspace.shared.open(url)
                            #else
                            UIApplication.shared.open(url)
                            #endif
                        }
                    }
                }) {
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 10))
                        .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Preview for Enhanced View
struct EnhancedAuthorView_Previews: PreviewProvider {
    static var previews: some View {
        EnhancedAuthorView(author: AuthorInfo(
            name: "Navaratnam Manoranjan",
            email: "nmano0006@gmail.com",
            website: "github.com/nmano",
            github: "github.com/nmano",
            role: "OpenCore Configurator Developer",
            version: "2.7.8.1.0"
        ))
        .frame(width: 350)
        .padding()
    }
}