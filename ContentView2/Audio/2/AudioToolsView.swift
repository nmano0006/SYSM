import SwiftUI
import AVFoundation

struct AudioToolsView: View {
    @State private var audioDevices: [AudioDevice] = []
    @State private var selectedInputDevice: AudioDevice?
    @State private var selectedOutputDevice: AudioDevice?
    @State private var currentVolume: Float = 0.5
    @State private var isMuted = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var isTestingSound = false
    @State private var audioPlayer: AVAudioPlayer?
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Text("Audio Tools")
                    .font(.title)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button(action: refreshAudioDevices) {
                    Label("Refresh", systemImage: "arrow.clockwise")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal)
            
            // Audio Control Cards
            AudioControlCards
            
            // Input Devices
            AudioDevicesSection(title: "Input Devices", 
                               devices: audioDevices.filter { $0.type == .input }, 
                               selectedDevice: $selectedInputDevice)
            
            // Output Devices
            AudioDevicesSection(title: "Output Devices", 
                               devices: audioDevices.filter { $0.type == .output }, 
                               selectedDevice: $selectedOutputDevice)
            
            Spacer()
            
            // Audio Testing
            AudioTestingSection
        }
        .padding()
        .onAppear {
            refreshAudioDevices()
        }
        .onDisappear {
            audioPlayer?.stop()
        }
        .alert("Audio Tools", isPresented: $showAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
    }
    
    private var AudioControlCards: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 12) {
            VolumeControlCard
            
            MuteControlCard
            
            DeviceInfoCard
        }
        .padding(.horizontal)
    }
    
    private var VolumeControlCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "speaker.wave.2")
                    .foregroundColor(.blue)
                
                Text("Volume Control")
                    .font(.headline)
            }
            
            HStack {
                Image(systemName: "speaker.fill")
                    .foregroundColor(.secondary)
                
                Slider(value: $currentVolume, in: 0...1, step: 0.05) { _ in
                    updateSystemVolume()
                }
                .disabled(isMuted)
                
                Image(systemName: "speaker.wave.3.fill")
                    .foregroundColor(.secondary)
            }
            
            Text("\(Int(currentVolume * 100))%")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(12)
    }
    
    private var MuteControlCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.fill")
                    .foregroundColor(isMuted ? .red : .orange)
                
                Text("Mute Control")
                    .font(.headline)
            }
            
            Toggle(isOn: $isMuted) {
                Text(isMuted ? "Audio Muted" : "Audio Enabled")
                    .font(.body)
            }
            .toggleStyle(.switch)
            .onChange(of: isMuted) { _ in
                toggleMute()
            }
            
            Text("Toggle system audio output")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(12)
    }
    
    private var DeviceInfoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "headphones")
                    .foregroundColor(.green)
                
                Text("Current Device")
                    .font(.headline)
            }
            
            if let outputDevice = audioDevices.first(where: { $0.isCurrentOutput }) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(outputDevice.name)
                        .font(.body)
                        .fontWeight(.medium)
                    
                    HStack {
                        Text("Output")
                            .font(.caption)
                            .foregroundColor(.green)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(4)
                        
                        if outputDevice.isDefault {
                            Text("Default")
                                .font(.caption)
                                .foregroundColor(.blue)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(4)
                        }
                    }
                    
                    Text("\(outputDevice.sampleRate)Hz • \(outputDevice.channels) channels")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else {
                Text("No output device")
                    .font(.body)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(12)
    }
    
    private var AudioTestingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Audio Testing")
                .font(.headline)
                .padding(.horizontal)
            
            HStack(spacing: 12) {
                Button(action: playTestSound) {
                    HStack {
                        Image(systemName: isTestingSound ? "stop.circle.fill" : "play.circle.fill")
                        Text(isTestingSound ? "Stop Test" : "Play Test Sound")
                    }
                    .frame(minWidth: 150)
                }
                .buttonStyle(.borderedProminent)
                .tint(isTestingSound ? .red : .green)
                .disabled(isMuted)
                
                Button(action: testMicrophone) {
                    HStack {
                        Image(systemName: "mic.fill")
                        Text("Test Microphone")
                    }
                    .frame(minWidth: 150)
                }
                .buttonStyle(.bordered)
                .disabled(selectedInputDevice == nil)
                
                Spacer()
                
                Button("Audio Report") {
                    generateAudioReport()
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal)
        }
    }
    
    private func AudioDevicesSection(title: String, devices: [AudioDevice], selectedDevice: Binding<AudioDevice?>) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text("\(devices.count) devices")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)
            
            if devices.isEmpty {
                Text("No \(title.lowercased()) found")
                    .foregroundColor(.secondary)
                    .padding()
                    .frame(maxWidth: .infinity)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(devices) { device in
                            AudioDeviceCard(device: device, 
                                          isSelected: selectedDevice.wrappedValue?.id == device.id,
                                          action: {
                                selectedDevice.wrappedValue = device
                                if device.type == .output {
                                    setOutputDevice(device)
                                }
                            })
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }
    
    private func AudioDeviceCard(device: AudioDevice, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: device.type == .input ? "mic.fill" : "speaker.wave.2.fill")
                        .foregroundColor(device.type == .input ? .blue : .orange)
                    
                    Text(device.name)
                        .font(.body)
                        .fontWeight(.medium)
                        .lineLimit(2)
                    
                    Spacer()
                    
                    if device.isDefault {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                    }
                    
                    if device.isCurrentInput && device.type == .input {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                    }
                    
                    if device.isCurrentOutput && device.type == .output {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(device.type == .input ? "Input" : "Output")
                            .font(.caption)
                            .foregroundColor(device.type == .input ? .blue : .orange)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(device.type == .input ? Color.blue.opacity(0.1) : Color.orange.opacity(0.1))
                            .cornerRadius(4)
                        
                        if device.isBuiltIn {
                            Text("Built-in")
                                .font(.caption)
                                .foregroundColor(.green)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.green.opacity(0.1))
                                .cornerRadius(4)
                        }
                    }
                    
                    Text("\(device.sampleRate)Hz • \(device.channels) channels")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if !device.uid.isEmpty {
                        Text(device.uid)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            .padding()
            .frame(width: 250, alignment: .leading)
            .background(isSelected ? Color.blue.opacity(0.1) : Color(.controlBackgroundColor))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
    
    private func refreshAudioDevices() {
        let shellHelper = ShellHelper.shared
        var devices: [AudioDevice] = []
        
        // Simplified audio device detection for macOS
        let result = shellHelper.runCommand("""
        system_profiler SPAudioDataType -json 2>/dev/null | \
        python3 -c "
        import json, sys
        try:
            data = json.load(sys.stdin)
            if 'SPAudioDataType' in data:
                for item in data['SPAudioDataType']:
                    if '_items' in item:
                        for device in item['_items']:
                            name = device.get('_name', 'Unknown Device')
                            uid = device.get('coreaudio_device_uid', 'unknown')
                            sample_rate = device.get('coreaudio_default_sample_rate', '44100')
                            transport = device.get('coreaudio_device_transport', 'Unknown')
                            is_output = device.get('coreaudio_output_uid', '') != ''
                            is_input = device.get('coreaudio_input_uid', '') != ''
                            is_default_output = device.get('coreaudio_default_audio_output_device', '') == 'spaudio_yes'
                            is_default_input = device.get('coreaudio_default_audio_input_device', '') == 'spaudio_yes'
                            
                            if is_output or is_input:
                                device_type = 'both' if (is_output and is_input) else ('output' if is_output else 'input')
                                print(f'{name}|{uid}|{sample_rate}|{transport}|{device_type}|{is_default_output}|{is_default_input}')
        except Exception as e:
            # Fallback to text parsing if JSON fails
            pass
        " || system_profiler SPAudioDataType | grep -E '(^        _name:|coreaudio_device_uid:|coreaudio_default_sample_rate:)' | \
        sed 's/^        _name: //;s/^            coreaudio_device_uid: //;s/^            coreaudio_default_sample_rate: //' | \
        tr '\\n' '|' | sed 's/||/\\n/g' | grep -v '^$'
        """)
        
        let lines = result.output.components(separatedBy: "\n").filter { !$0.isEmpty }
        
        if !lines.isEmpty {
            for line in lines {
                let components = line.components(separatedBy: "|")
                if components.count >= 2 {
                    let name = components[0]
                    let uid = components.count > 1 ? components[1] : name
                    let sampleRate = components.count > 2 ? components[2] : "44100"
                    let transport = components.count > 3 ? components[3] : "Unknown"
                    let deviceTypeStr = components.count > 4 ? components[4] : "both"
                    let isDefaultOutput = components.count > 5 ? (components[5] == "true" || components[5] == "1") : false
                    let isDefaultInput = components.count > 6 ? (components[6] == "true" || components[6] == "1") : false
                    
                    let deviceType: AudioDeviceType
                    switch deviceTypeStr {
                    case "input":
                        deviceType = .input
                    case "output":
                        deviceType = .output
                    default:
                        deviceType = .both
                    }
                    
                    let device = AudioDevice(
                        id: uid,
                        name: name,
                        uid: uid,
                        type: deviceType,
                        sampleRate: sampleRate,
                        channels: "2",
                        isDefault: isDefaultOutput || isDefaultInput,
                        isCurrentOutput: isDefaultOutput,
                        isCurrentInput: isDefaultInput,
                        isBuiltIn: transport.contains("Built-in") || name.contains("Built-in") || name.contains("Mac") || name.contains("Internal"),
                        transport: transport
                    )
                    devices.append(device)
                }
            }
        } else {
            // Fallback: Use simple system_profiler output
            let simpleResult = shellHelper.runCommand("system_profiler SPAudioDataType | grep -E '^        _name:' | sed 's/^        _name: //'")
            
            let deviceNames = simpleResult.output.components(separatedBy: "\n").filter { !$0.isEmpty }
            
            for (index, name) in deviceNames.enumerated() {
                let isBuiltIn = name.contains("Built-in") || name.contains("Mac") || name.contains("Internal")
                let isDefault = index == 0 // First device is often default
                
                let device = AudioDevice(
                    id: "device-\(index)",
                    name: name,
                    uid: "device-\(index)",
                    type: .both,
                    sampleRate: "44100",
                    channels: "2",
                    isDefault: isDefault,
                    isCurrentOutput: isDefault,
                    isCurrentInput: isDefault,
                    isBuiltIn: isBuiltIn,
                    transport: "Unknown"
                )
                devices.append(device)
            }
        }
        
        // Add default devices if still empty
        if devices.isEmpty {
            let defaultOutput = AudioDevice(
                id: "default-output",
                name: "Default Output",
                uid: "default-output",
                type: .output,
                sampleRate: "44100",
                channels: "2",
                isDefault: true,
                isCurrentOutput: true,
                isCurrentInput: false,
                isBuiltIn: true,
                transport: "Unknown"
            )
            
            let defaultInput = AudioDevice(
                id: "default-input",
                name: "Default Input",
                uid: "default-input",
                type: .input,
                sampleRate: "44100",
                channels: "1",
                isDefault: true,
                isCurrentOutput: false,
                isCurrentInput: true,
                isBuiltIn: true,
                transport: "Unknown"
            )
            
            devices = [defaultOutput, defaultInput]
        }
        
        audioDevices = devices
        
        // Set selected devices
        selectedOutputDevice = devices.first { $0.isCurrentOutput && $0.type != .input }
        selectedInputDevice = devices.first { $0.isCurrentInput && $0.type != .output }
    }
    
    private func updateSystemVolume() {
        let volumePercent = Int(currentVolume * 100)
        let shellHelper = ShellHelper.shared
        _ = shellHelper.runCommand("osascript -e 'set volume output volume \(volumePercent)'")
    }
    
    private func toggleMute() {
        let shellHelper = ShellHelper.shared
        let muteCommand = isMuted ? "set volume with output muted" : "set volume without output muted"
        _ = shellHelper.runCommand("osascript -e '\(muteCommand)'")
    }
    
    private func setOutputDevice(_ device: AudioDevice) {
        let shellHelper = ShellHelper.shared
        
        // Try to set output device using AppleScript
        let appleScript = """
        tell application "System Preferences"
            reveal pane id "com.apple.preference.sound"
            activate
        end tell
        
        tell application "System Events"
            tell application process "System Preferences"
                repeat until window "Sound" exists
                    delay 0.1
                end repeat
                tell tab group 1 of window "Sound"
                    click radio button "Output"
                    select (row 1 of table 1 of scroll area 1 where value of text field 1 is "\(device.name)")
                end tell
            end tell
        end tell
        
        delay 1
        if application "System Preferences" is running then
            tell application "System Preferences" to quit
        end if
        """
        
        let result = shellHelper.runCommand("osascript -e '\(appleScript)' 2>/dev/null || echo 'Could not set audio device'")
        
        if result.success {
            alertMessage = "Output device set to \(device.name)"
        } else {
            alertMessage = "Failed to set output device: \(result.error.isEmpty ? "Unknown error" : result.error)"
        }
        showAlert = true
        refreshAudioDevices()
    }
    
    private func playTestSound() {
        if isTestingSound {
            audioPlayer?.stop()
            isTestingSound = false
            return
        }
        
        isTestingSound = true
        
        // Use system beep on macOS
        NSSound.beep()
        
        // Also try to play a sound file if available
        if let sound = NSSound(named: "Glass") {
            sound.play()
        }
        
        // Stop after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.isTestingSound = false
        }
    }
    
    private func testMicrophone() {
        guard let inputDevice = selectedInputDevice else { return }
        
        alertMessage = """
        Microphone Test for: \(inputDevice.name)
        
        Device Information:
        • UID: \(inputDevice.uid)
        • Type: \(inputDevice.type.rawValue)
        • Sample Rate: \(inputDevice.sampleRate)Hz
        • Channels: \(inputDevice.channels)
        • Transport: \(inputDevice.transport)
        • Built-in: \(inputDevice.isBuiltIn ? "Yes" : "No")
        • Default: \(inputDevice.isDefault ? "Yes" : "No")
        
        Note: Microphone testing requires additional permissions on macOS.
        To test your microphone, use the Voice Memos app or System Preferences → Sound → Input.
        """
        showAlert = true
    }
    
    private func generateAudioReport() {
        var report = "=== Audio System Report ===\n\n"
        report += "Generated: \(Date())\n"
        report += "Total Audio Devices: \(audioDevices.count)\n"
        report += "Input Devices: \(audioDevices.filter { $0.type == .input || $0.type == .both }.count)\n"
        report += "Output Devices: \(audioDevices.filter { $0.type == .output || $0.type == .both }.count)\n"
        report += "System Volume: \(Int(currentVolume * 100))%\n"
        report += "Muted: \(isMuted ? "Yes" : "No")\n\n"
        
        report += "=== Audio Devices ===\n"
        for device in audioDevices {
            report += "\n• \(device.name)\n"
            report += "  UID: \(device.uid)\n"
            report += "  Type: \(device.type.rawValue)\n"
            report += "  Sample Rate: \(device.sampleRate)Hz\n"
            report += "  Channels: \(device.channels)\n"
            report += "  Transport: \(device.transport)\n"
            report += "  Default: \(device.isDefault ? "Yes" : "No")\n"
            report += "  Current Output: \(device.isCurrentOutput ? "Yes" : "No")\n"
            report += "  Current Input: \(device.isCurrentInput ? "Yes" : "No")\n"
            report += "  Built-in: \(device.isBuiltIn ? "Yes" : "No")\n"
        }
        
        // Add system audio info
        report += "\n\n=== System Audio Information ===\n"
        let shellHelper = ShellHelper.shared
        
        let volumeInfo = shellHelper.runCommand("osascript -e 'output volume of (get volume settings)'").output
        report += "Current Volume: \(volumeInfo)%\n"
        
        let muteInfo = shellHelper.runCommand("osascript -e 'output muted of (get volume settings)'").output
        report += "Muted: \(muteInfo.contains("true") ? "Yes" : "No")\n"
        
        // Save to file
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("audio_report_\(Int(Date().timeIntervalSince1970)).txt")
        
        do {
            try report.write(to: fileURL, atomically: true, encoding: .utf8)
            NSWorkspace.shared.open(fileURL)
        } catch {
            alertMessage = "Failed to save report: \(error.localizedDescription)"
            showAlert = true
        }
    }
}

enum AudioDeviceType: String {
    case input = "Input"
    case output = "Output"
    case both = "Input/Output"
}

struct AudioDevice: Identifiable {
    let id: String
    let name: String
    let uid: String
    let type: AudioDeviceType
    let sampleRate: String
    let channels: String
    let isDefault: Bool
    let isCurrentOutput: Bool
    let isCurrentInput: Bool
    let isBuiltIn: Bool
    let transport: String
}