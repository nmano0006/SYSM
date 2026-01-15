if needsSudo {
    // For USB boot, try direct sudo first, then fallback to osascript
    // Method 1: Direct sudo (works on some USB boot configurations)
    let sudoCommand = "sudo -S \(command)"
    task.arguments = ["-c", sudoCommand]
    
    // Note: We'll handle password prompting differently for USB boot
    print("Running sudo command: \(sudoCommand)")
} else {
    task.arguments = ["-c", command]
}