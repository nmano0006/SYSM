private func mountSelectedPartition() {
    isMounting = true
    
    DispatchQueue.global(qos: .background).async {
        // Use USB boot mount method
        let result = ShellHelper.mountFromUSBBoot(partition: selectedPartition)
        
        DispatchQueue.main.async {
            isMounting = false
            
            if result.success {
                // Get the mount path
                let path: String
                if result.output.contains("/Volumes/") {
                    // Extract path from output
                    let lines = result.output.components(separatedBy: "\n")
                    if let mountLine = lines.first(where: { $0.contains("/Volumes/") }) {
                        path = mountLine
                    } else {
                        path = ShellHelper.getEFIPath() ?? "/Volumes/EFI"
                    }
                } else {
                    path = ShellHelper.getEFIPath() ?? "/Volumes/EFI"
                }
                
                efiPath = path
                
                alertTitle = "✅ Mount Successful"
                alertMessage = """
                Successfully mounted \(selectedPartition)
                
                Mounted at: \(path)
                
                You can now proceed with kext installation.
                """
                isPresented = false
            } else {
                alertTitle = "❌ Mount Failed"
                alertMessage = """
                Failed to mount \(selectedPartition) from USB boot:
                
                \(result.output)
                
                Try:
                1. Open Terminal and run: sudo diskutil mount \(selectedPartition)
                2. Check Disk Utility for the EFI partition
                3. Try a different partition (disk1s1 instead of disk0s1)
                """
            }
            showAlert = true
        }
    }
}