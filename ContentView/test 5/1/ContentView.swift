//
//  ContentView.swift
//  SystemMaintenance
//
//  Created by Z790 on 2025-12-29.
//

import SwiftUI
import Foundation

struct ContentView: View {
    @State private var availableDisks: [DiskInfo] = []
    @State private var isMounting = false
    @State private var mountedDisks: Set<String> = []
    @State private var errorMessage: String?
    @State private var showSuccess = false
    @State private var refreshTrigger = false
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Image(systemName: "externaldrive")
                    .font(.largeTitle)
                    .foregroundColor(.blue)
                Text("Disk Maintenance")
                    .font(.largeTitle)
                    .fontWeight(.bold)
            }
            .padding(.top, 30)
            
            // Description
            Text("Mount all available drives and volumes")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.bottom, 20)
            
            // Available disks list
            if !availableDisks.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Available Drives (\(availableDisks.count))")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    List(availableDisks, id: \.deviceIdentifier) { disk in
                        DiskRowView(disk: disk, isMounted: mountedDisks.contains(disk.deviceIdentifier))
                    }
                    .frame(height: 300)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            } else {
                ProgressView("Scanning for available drives...")
                    .padding()
            }
            
            // Error message
            if let error = errorMessage {
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.red)
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                }
                .padding()
                .background(Color.red.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .transition(.opacity)
            }
            
            // Success message
            if showSuccess {
                HStack {
                    Image(systemName: "checkmark.circle")
                        .foregroundColor(.green)
                    Text("All drives mounted successfully!")
                        .foregroundColor(.green)
                        .font(.caption)
                }
                .padding()
                .background(Color.green.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .transition(.opacity)
            }
            
            Spacer()
            
            // Action buttons
            VStack(spacing: 15) {
                Button(action: {
                    scanAvailableDisks()
                }) {
                    Label("Refresh Drives", systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(isMounting)
                
                Button(action: {
                    mountAllDrives()
                }) {
                    if isMounting {
                        ProgressView()
                            .scaleEffect(0.8)
                            .frame(maxWidth: .infinity)
                    } else {
                        Label("Mount All Drives", systemImage: "externaldrive.fill.badge.plus")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isMounting || availableDisks.isEmpty)
                
                if !mountedDisks.isEmpty {
                    Button(action: {
                        unmountAllDrives()
                    }) {
                        Label("Unmount All", systemImage: "eject.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.orange)
                    .disabled(isMounting)
                }
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 30)
        }
        .padding()
        .frame(minWidth: 600, minHeight: 700)
        .onAppear {
            scanAvailableDisks()
        }
        .animation(.easeInOut(duration: 0.3), value: availableDisks.count)
        .animation(.easeInOut(duration: 0.3), value: mountedDisks.count)
        .animation(.easeInOut(duration: 0.3), value: errorMessage)
        .animation(.easeInOut(duration: 0.3), value: showSuccess)
        .animation(.easeInOut(duration: 0.3), value: refreshTrigger)
    }
    
    // MARK: - Disk Functions
    
    private func scanAvailableDisks() {
        errorMessage = nil
        showSuccess = false
        
        let task = Process()
        task.launchPath = "/usr/sbin/diskutil"
        task.arguments = ["list", "-plist"]
        
        let outputPipe = Pipe()
        task.standardOutput = outputPipe
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            if let plist = try PropertyListSerialization.propertyList(from: outputData, options: [], format: nil) as? [String: Any],
               let allDisks = plist["AllDisksAndPartitions"] as? [[String: Any]] {
                
                var disks: [DiskInfo] = []
                for disk in allDisks {
                    if let deviceIdentifier = disk["DeviceIdentifier"] as? String,
                       let volumeName = disk["VolumeName"] as? String,
                       let volumeSize = disk["Size"] as? Int64 {
                        
                        let isMounted = (disk["MountPoint"] as? String) != nil
                        let mountPoint = disk["MountPoint"] as? String
                        
                        disks.append(DiskInfo(
                            deviceIdentifier: deviceIdentifier,
                            volumeName: volumeName,
                            volumeSize: volumeSize,
                            isMounted: isMounted,
                            mountPoint: mountPoint
                        ))
                        
                        if isMounted, let mountPoint = mountPoint, !mountPoint.isEmpty {
                            mountedDisks.insert(deviceIdentifier)
                        }
                    }
                }
                
                availableDisks = disks.sorted { $0.deviceIdentifier < $1.deviceIdentifier }
                refreshTrigger.toggle()
            }
        } catch {
            errorMessage = "Failed to scan disks: \(error.localizedDescription)"
        }
    }
    
    private func mountAllDrives() {
        isMounting = true
        errorMessage = nil
        showSuccess = false
        
        let unmountedDisks = availableDisks.filter { !$0.isMounted }
        var mountedCount = 0
        var errors: [String] = []
        
        for disk in unmountedDisks {
            let task = Process()
            task.launchPath = "/usr/sbin/diskutil"
            task.arguments = ["mount", disk.deviceIdentifier]
            
            do {
                try task.run()
                task.waitUntilExit()
                
                if task.terminationStatus == 0 {
                    mountedCount += 1
                    mountedDisks.insert(disk.deviceIdentifier)
                    
                    // Update the disk status
                    if let index = availableDisks.firstIndex(where: { $0.deviceIdentifier == disk.deviceIdentifier }) {
                        availableDisks[index].isMounted = true
                        availableDisks[index].mountPoint = getMountPoint(for: disk.deviceIdentifier)
                    }
                } else {
                    errors.append("Failed to mount \(disk.volumeName)")
                }
            } catch {
                errors.append("Error mounting \(disk.volumeName): \(error.localizedDescription)")
            }
        }
        
        isMounting = false
        refreshTrigger.toggle()
        
        if !errors.isEmpty {
            errorMessage = errors.joined(separator: "\n")
        } else if mountedCount > 0 {
            showSuccess = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                showSuccess = false
            }
        }
    }
    
    private func getMountPoint(for deviceIdentifier: String) -> String? {
        let task = Process()
        task.launchPath = "/usr/sbin/diskutil"
        task.arguments = ["info", "-plist", deviceIdentifier]
        
        let outputPipe = Pipe()
        task.standardOutput = outputPipe
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            if let plist = try PropertyListSerialization.propertyList(from: outputData, options: [], format: nil) as? [String: Any],
               let mountPoint = plist["MountPoint"] as? String {
                return mountPoint
            }
        } catch {
            return nil
        }
        return nil
    }
    
    private func unmountAllDrives() {
        isMounting = true
        errorMessage = nil
        showSuccess = false
        
        let mountedToUnmount = availableDisks.filter { $0.isMounted && $0.deviceIdentifier != "disk0" } // Don't unmount main system disk
        
        for disk in mountedToUnmount {
            let task = Process()
            task.launchPath = "/usr/sbin/diskutil"
            task.arguments = ["unmount", disk.deviceIdentifier]
            
            do {
                try task.run()
                task.waitUntilExit()
                
                if task.terminationStatus == 0 {
                    mountedDisks.remove(disk.deviceIdentifier)
                    
                    // Update the disk status
                    if let index = availableDisks.firstIndex(where: { $0.deviceIdentifier == disk.deviceIdentifier }) {
                        availableDisks[index].isMounted = false
                        availableDisks[index].mountPoint = nil
                    }
                }
            } catch {
                // Continue with other disks even if one fails
            }
        }
        
        isMounting = false
        refreshTrigger.toggle()
    }
}

// MARK: - Disk Info Model

struct DiskInfo: Equatable {
    let deviceIdentifier: String
    let volumeName: String
    let volumeSize: Int64
    var isMounted: Bool
    var mountPoint: String?
    
    var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: volumeSize)
    }
    
    static func == (lhs: DiskInfo, rhs: DiskInfo) -> Bool {
        return lhs.deviceIdentifier == rhs.deviceIdentifier &&
               lhs.volumeName == rhs.volumeName &&
               lhs.volumeSize == rhs.volumeSize &&
               lhs.isMounted == rhs.isMounted &&
               lhs.mountPoint == rhs.mountPoint
    }
}

// MARK: - Disk Row View

struct DiskRowView: View {
    let disk: DiskInfo
    let isMounted: Bool
    
    var body: some View {
        HStack {
            Image(systemName: diskIconName)
                .font(.title2)
                .foregroundColor(diskColor)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(disk.volumeName)
                    .font(.headline)
                Text(disk.deviceIdentifier)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(disk.formattedSize)
                    .font(.subheadline)
                if let mountPoint = disk.mountPoint {
                    Text(mountPoint)
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
            
            Image(systemName: isMounted ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isMounted ? .green : .gray)
                .font(.title3)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
    }
    
    private var diskIconName: String {
        if disk.deviceIdentifier.starts(with: "disk0") {
            return "internaldrive"
        } else if disk.volumeName.lowercased().contains("time machine") {
            return "clock.arrow.circlepath"
        } else {
            return isMounted ? "externaldrive.fill" : "externaldrive"
        }
    }
    
    private var diskColor: Color {
        if isMounted {
            return .green
        } else if disk.deviceIdentifier.starts(with: "disk0") {
            return .blue
        } else {
            return .orange
        }
    }
}

// MARK: - Preview

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}