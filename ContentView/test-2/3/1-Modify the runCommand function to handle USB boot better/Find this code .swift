if needsSudo {
    // Enhanced sudo command for USB boot with better error handling
    let escapedCommand = command.replacingOccurrences(of: "\"", with: "\\\"")
    let appleScript = """
    do shell script "\(escapedCommand)" ¬
    with administrator privileges ¬
    with prompt "SystemMaintenance needs administrator access" ¬
    without altering line endings
    """
    
    task.arguments = ["-c", "osascript -e '\(appleScript)'"]
} else {
    task.arguments = ["-c", command]
}