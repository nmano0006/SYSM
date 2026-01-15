# Go to your repo
cd ~/Desktop/temp-sysm

# Update README
cat > README.md << 'EOF'
# SYSM - macOS System Maintenance Tool

[![Latest Release](https://img.shields.io/github/v/release/nmano0006/SYSM)](https://github.com/nmano0006/SYSM/releases/latest)

A comprehensive macOS application for system maintenance, drive management, kext management, and troubleshooting.

## 📥 Download

**[Download Latest Version](https://github.com/nmano0006/SYSM/releases/latest/download/SYSM.dmg)**

## 🚀 Features

- **Drive Management**: Mount/unmount drives, view disk information
- **System Information**: Detailed system specs and status
- **Kexts Manager**: Manage kernel extensions
- **Audio Tools**: Audio configuration and troubleshooting
- **Hex/Base64 Calculator**: Encoding/decoding utilities
- **SSDT Generator**: ACPI table generation
- **Troubleshooter**: System diagnostics and issue resolution

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
EOF

# Push updated README
git add README.md
git commit -m "Update README with download link and instructions"
git push