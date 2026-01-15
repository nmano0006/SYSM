alertTitle = "SSDTs Generated"
alertMessage = """
Successfully generated \(generatedSSDTs.count) SSDTs for \(motherboardModel):

\(generatedSSDTs.joined(separator: "\n"))

Files saved to: ~/Desktop/Generated_SSDTs/

\(recommendations)

Next steps:
1. Copy SSDTs to EFI/OC/ACPI/
2. Add to config.plist → ACPI → Add
3. Enable Patch → FixMask in config.plist
4. Rebuild kernel cache
5. Restart system

Note: These are template SSDTs. You may need to customize them for your specific hardware.
"""