# Create README.md
cat > README.md << EOF
# SYSM - macOS System Maintenance Tool

A comprehensive macOS application for system maintenance, drive management, kext management, and troubleshooting.

## Features

- **Drive Management**: Mount/unmount drives, view disk information
- **System Information**: Detailed system specs and status
- **Kexts Manager**: Manage kernel extensions
- **Audio Tools**: Audio configuration and troubleshooting
- **Hex/Base64 Calculator**: Encoding/decoding utilities
- **SSDT Generator**: ACPI table generation
- **Troubleshooter**: System diagnostics and issue resolution

## Requirements

- macOS 11.0 (Big Sur) or later
- Xcode 13.0 or later
- Full Disk Access permissions (for full functionality)

## Installation

### From Source

1. Clone the repository:
   \`\`\`bash
   git clone https://github.com/nmano0006/SYSM.git
   \`\`\`

2. Open in Xcode:
   \`\`\`bash
   cd SYSM
   open SYSM.xcodeproj
   \`\`\`

3. Build and run (⌘+R)

## Screenshots

*(Add screenshots here)*

## Permissions

The app requires Full Disk Access for:
- Reading disk information
- Mounting/unmounting drives
- System diagnostics

Grant permissions in: System Settings → Privacy & Security → Full Disk Access

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

MIT License - see LICENSE file for details

## Author

Nmano0006 (nmano0006@gmail.com)
EOF

# Add and commit README
git add README.md
git commit -m "Add README documentation"
git push