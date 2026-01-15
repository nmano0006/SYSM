private func mountSelectedPartition() {
    isMounting = true
    
    DispatchQueue.global(qos: .background).async {
        let result = ShellHelper.runCommand("diskutil mount \(selectedPartition)", needsSudo: true)
        
        DispatchQueue.main.async {
            isMounting = false
            
            if result.success {
                let path = ShellHelper.getEFIPath()
                efiPath = path
                
                alertTitle = "Success"
                alertMessage = """
                Successfully mounted \(selectedPartition)
                
                Mounted at: \(path ?? "Unknown location")
                
                You can now proceed with kext installation.
                """
                isPresented = false
            } else {
                alertTitle = "Mount Failed"
                alertMessage = """
                Failed to mount \(selectedPartition):
                
                \(result.output)
                
                Try another partition or check Disk Utility.
                """
            }
            showAlert = true
        }
    }
}