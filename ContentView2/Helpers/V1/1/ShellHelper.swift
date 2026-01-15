import Foundation
import AppKit

struct ShellHelper {
    static func runCommand(_ command: String) -> (output: String, success: Bool) {
        let task = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        
        task.standardOutput = outputPipe
        task.standardError = errorPipe
        task.arguments = ["-c", command]
        task.launchPath = "/bin/zsh"
        
        do {
            try task.run()
        } catch {
            print("Process execution error: \(error)")
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let errorOutput = String(data: errorData, encoding: .utf8) ?? ""
            return ("Error: \(error.localizedDescription)\nStderr: \(errorOutput)", false)
        }
        
        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        
        let output = String(data: outputData, encoding: .utf8) ?? ""
        let errorOutput = String(data: errorData, encoding: .utf8) ?? ""
        
        task.waitUntilExit()
        let success = task.terminationStatus == 0
        
        if !errorOutput.isEmpty && !errorOutput.contains("doesn't exist") {
            print("Command stderr: \(errorOutput)")
        }
        
        let combinedOutput = output + (errorOutput.isEmpty ? "" : "\n\(errorOutput)")
        return (combinedOutput, success)
    }
    
    static func isSIPDisabled() -> Bool {
        let result = runCommand("csrutil status 2>/dev/null || echo 'Unknown'")
        let output = result.output.lowercased()
        return output.contains("disabled")
    }
}