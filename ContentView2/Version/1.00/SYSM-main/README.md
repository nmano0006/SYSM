# SYSM - macOS System Maintenance Tool

[![Latest Release](https://img.shields.io/github/v/release/nmano0006/SYSM)](https://github.com/nmano0006/SYSM/releases/latest)

A comprehensive macOS application for system maintenance, drive management, kext management, and troubleshooting.

## 📥 Download

**[Download Latest Version](https://github.com/nmano0006/SYSM/releases/latest/download/SYSM.dmg)**

## ☕ Support Development

SYSM is free and open-source. If you find it useful, please consider supporting its development:

**[Donate via PayPal](https://www.paypal.com/donate/?business=H3PV9HX92AVMJ&no_recurring=0&item_name=Support+SYSM+development.+Donations+fund+testing+devices+%26+server+costs+for+this+open-source+tool.&currency_code=CAD)**

### Why Support?
- Funds continued development and updates
- Helps add new features and tools
- Covers testing devices and server costs
- Supports free, open-source software development

### Support Tiers:
- ☕ **$5** - Coffee supporter
- 💻 **$15** - Developer supporter
- 🚀 **$30** - Premium supporter
- 🏆 **$50+** - Gold supporter

*Every donation helps keep SYSM updated and improves the tool for everyone!*

## 📸 Screenshots

| Drive Management | System Information | Kexts Manager |
|:---:|:---:|:---:|
| ![Drive Management](https://raw.githubusercontent.com/nmano0006/SYSM/main/screenshots/1-Drives.png) | ![System Information](https://raw.githubusercontent.com/nmano0006/SYSM/main/screenshots/2-System.png) | ![Kexts Manager](https://raw.githubusercontent.com/nmano0006/SYSM/main/screenshots/3-Kexts.png) |

| Audio Tools | Calculator | SSDT Generator |
|:---:|:---:|:---:|
| ![Audio Tools](https://raw.githubusercontent.com/nmano0006/SYSM/main/screenshots/4-Audio.png) | ![Calculator](https://raw.githubusercontent.com/nmano0006/SYSM/main/screenshots/5-Calculator.png) | ![SSDT Generator](https://raw.githubusercontent.com/nmano0006/SYSM/main/screenshots/6-SSDT%20Generator.png) |

| Info/About | Troubleshooter |
|:---:|:---:|
| ![Info/About](https://raw.githubusercontent.com/nmano0006/SYSM/main/screenshots/7-Info.png) | ![Troubleshooter](https://raw.githubusercontent.com/nmano0006/SYSM/main/screenshots/8-Troubleshoot.png) |

## 🛠️ Building from Source

### Requirements:
- Xcode 14.0 or later
- macOS 11.0 (Big Sur) or later
- Swift 5.7+

### Steps:
\`\`\`bash
# Clone repository
git clone https://github.com/nmano0006/SYSM.git
cd SYSM

# Open in Xcode
open SystemMaintenance.xcodeproj
\`\`\`

1. In Xcode: Press **⌘+B** to Build
2. Press **⌘+R** to Run
3. Or use **Product → Archive** for distribution

### Project Structure:
- \`SystemMaintenance/src/ContentView.swift\` - Main application interface
- \`SystemMaintenance/src/ShellHelper.swift\` - System command utilities
- \`SystemMaintenance/src/Views/\` - 15+ feature views
- \`SystemMaintenance/src/Models/\` - Data models
- \`SystemMaintenance/src/Helpers/\` - Helper classes
- \`SystemMaintenance/docs/assets/\` - App icons and images

### Contributing:
1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a Pull Request

All contributions are welcome under MIT License!

## ⚙️ Installation

1. Download the DMG from the link above
2. Open the DMG file
3. Drag SYSM.app to your Applications folder
4. Open from Applications (right-click → Open if you get security warning)

## 📋 Requirements

- macOS 11.0 (Big Sur) or later
- Full Disk Access permissions (for full functionality)

## 👨‍💻 Author

Nmano0006 (nmano0006@gmail.com)

## 📄 License

MIT License
