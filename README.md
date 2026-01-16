# SYSM - macOS System Maintenance Tool

[![Latest Release](https://img.shields.io/github/v/release/nmano0006/SYSM)](https://github.com/nmano0006/SYSM/releases/latest)

A comprehensive macOS application for system maintenance, drive management, kext management, and troubleshooting. Built specifically for macOS/Hackintosh systems.

## ✨ Features

### **Core Modules:**
- **Drive Manager**: Full EFI partition management, drive mounting/unmounting, storage analysis
- **System Information**: Comprehensive hardware/software diagnostics with Hackintosh support
- **Kexts Manager**: AppleHDA installer with OpenCore integration
- **Audio Tools**: Complete audio system control and device management
- **SSDT Generator**: Advanced SSDT creation for Hackintosh optimization
- **OpenCore Config Editor**: Complete configuration management for OpenCore bootloader
- **Troubleshooting**: Automated system diagnostics and issue resolution
- **Utilities**: Hex calculator, encoding tools, and system maintenance tasks

### **Specialized Tools:**
- **Hackintosh Support**: OpenCore detection, SSDT generation, kext management
- **Security Tools**: SIP status monitoring, permission verification
- **Network Tools**: Interface management and diagnostics
- **Power Management**: CPU monitoring, temperature tracking
- **Boot Management**: NVRAM utilities, boot argument configuration

## 📥 Download

**[Download Latest Version (v1.0.1)](https://github.com/nmano0006/SYSM/releases/download/v1.0.1/SYSM_v1.0.1.dmg)**

**[View on InsanelyMac Forum](https://www.insanelymac.com/forum/topic/362188-sysm-macos-system-maintenance-tool/)**

## 🛠 System Requirements

- **macOS Version:** macOS 11.0 (Big Sur) or later
- **Processor:** Intel or Apple Silicon (with Rosetta 2)
- **Memory:** 4GB minimum, 8GB recommended
- **Storage:** 100MB available space
- **Bootloader:** OpenCore (recommended for full functionality)
- **Permissions:** Administrator access for system-level features

## 🔧 Installation

1. Download the latest DMG file from the releases page
2. Open the DMG and drag SYSM to your Applications folder
3. Launch SYSM (right-click → Open if Gatekeeper blocks it)
4. Grant necessary permissions when prompted

**Note:** Some features require administrator privileges and may need to be run with `sudo` for full functionality.

## 🚀 What's New in v1.0.1

### **Major Features:**
- **Complete OpenCore Integration**: Full configuration editor with real-time monitoring
- **Enhanced Kexts Manager**: Now includes AppleHDA Installer and KDK Manager
- **Advanced SSDT Generator**: Comprehensive template library for Hackintosh optimization
- **Expanded Device Support**: Modern hardware database with Intel 13th Gen support
- **System Troubleshooting**: Automated issue detection and resolution

### **Improvements:**
- **Better EFI Management**: Enhanced partition detection with permission handling
- **Improved Diagnostics**: Detailed error messages and system analysis
- **Enhanced UI**: Developer attribution and improved navigation
- **Comprehensive Monitoring**: Real-time system status tracking
- **Security Enhancements**: SIP monitoring and permission verification

### **Bug Fixes:**
- Fixed EFI mounting permissions on newer macOS versions
- Improved compatibility with macOS Sonoma and later
- Resolved audio configuration issues
- Fixed memory leak in drive management module

## ☕ Support Development

SYSM is free and open-source software developed by **Navaratnam Manoranjana**. If you find it useful, please consider supporting its development:

**[Donate via PayPal](https://www.paypal.com/donate/?business=H3PV9HX92AVMJ&no_recurring=0&item_name=Support+SYSM+development.+Donations+fund+testing+devices+%26+server+costs+for+this+open-source+tool.&currency_code=CAD)**

### **Why Support?**
- 📱 Funds continued development and feature updates
- 🧪 Helps acquire testing devices for compatibility
- 🌐 Covers server costs for update distribution
- 💡 Supports free, open-source software development
- 🔧 Enables faster bug fixes and improvements

### **Support Tiers:**
- ☕ **$5** - Coffee supporter (helps with server costs)
- 💻 **$15** - Developer supporter (helps fund new features)
- 🚀 **$30** - Premium supporter (supports device testing)
- 🏆 **$50+** - Gold supporter (major feature sponsorship)

*Every donation helps keep SYSM updated and improves the tool for the entire Hackintosh community!*

## 🛠️ Building from Source

### **Requirements:**
- Xcode 14.0 or later
- macOS 11.0 (Big Sur) or later
- Swift 5.7+
- Git for version control

### **Build Steps:**
```bash
# Clone repository
git clone https://github.com/nmano0006/SYSM.git
cd SYSM

# Open in Xcode
open SystemMaintenance.xcodeproj

# Build and run
# Product → Run (⌘R)
