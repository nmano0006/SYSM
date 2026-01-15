import Foundation

// Simple EFI Mounter
func mountEFI(partitionId: String = "disk1s1") {
    let commands = [
        "sudo diskutil mount /dev/\(partitionId)",
        "sudo mount -t msdos /dev/\(partitionId) /Volumes/EFI",
        "sudo mount -t msdos -o rw,noowners /dev/\(partitionId) /Volumes/EFI"
    ]
    
    print("🔧 Mounting EFI partition: \(partitionId)")
    
    for (index, command) in commands.enumerated() {
        print("\n[Method \(index + 1)] Trying: \(command)")
        
        let process = Process()
        let pipe = Pipe()
        
        process.standardOutput = pipe
        process.standardError = pipe
        process.arguments = ["-c", command]
        process.launchPath = "/bin/bash"
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            
            print("Output: \(output)")
            
            if process.terminationStatus == 0 {
                print("✅ Successfully mounted \(partitionId)")
                return
            }
        } catch {
            print("❌ Error: \(error)")
        }
    }
    
    print("❌ All mount attempts failed")
}

// Usage
mountEFI(partitionId: "disk1s1")