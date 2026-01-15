// Try to mount
let mountResult = runCommand("diskutil mount \(s1Partition)", needsSudo: true)
if mountResult.success {
    print("✅ Successfully mounted: \(s1Partition)")
    print("Mount output: \(mountResult.output)")
    return true
} else {
    print("❌ Failed to mount \(s1Partition): \(mountResult.output)")
}