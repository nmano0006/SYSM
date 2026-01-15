// Try to mount
let mountResult = mountFromUSBBoot(partition: s1Partition)
if mountResult.success {
    print("✅ Successfully mounted from USB boot: \(s1Partition)")
    print("Mount output: \(mountResult.output)")
    return true
} else {
    print("❌ Failed to mount \(s1Partition) from USB boot: \(mountResult.output)")
}