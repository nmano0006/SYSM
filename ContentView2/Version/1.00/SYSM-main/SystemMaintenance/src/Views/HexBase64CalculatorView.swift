// Views/HexBase64CalculatorView.swift
import SwiftUI

// MARK: - Main Calculator View
struct HexBase64CalculatorView: View {
    @State private var inputText = ""
    @State private var hexResult = ""
    @State private var base64Result = ""
    @State private var decimalResult = ""
    @State private var binaryResult = ""
    @State private var asciiResult = ""
    @State private var selectedInputType = 0 // 0: Text, 1: Hex, 2: Base64, 3: Decimal, 4: Binary
    @State private var selectedOutputType = 0 // 0: Hex, 1: Base64, 2: Decimal, 3: Binary, 4: ASCII
    @State private var isConverting = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var conversionHistory: [ConversionRecord] = []
    @State private var showHistory = false
    @State private var showCheatSheet = false
    
    private let inputTypes = ["Text", "Hex", "Base64", "Decimal", "Binary"]
    private let outputTypes = ["Hex", "Base64", "Decimal", "Binary", "ASCII"]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                headerSection
                
                // Main Conversion Area
                conversionSection
                
                // Information Section
                informationSection
            }
            .padding(.bottom, 20)
        }
        .alert("Conversion Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
        .sheet(isPresented: $showCheatSheet) {
            CheatSheetView()
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 8) {
            Text("Hex/Base64 Calculator")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.blue)
            
            Text("Convert between different encoding formats")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.top, 20)
    }
    
    // MARK: - Conversion Section
    private var conversionSection: some View {
        VStack(spacing: 16) {
            // Input Section
            inputSection
            
            // Conversion Buttons
            conversionButtons
            
            // Results Section
            resultsSection
            
            // Quick Tools
            quickToolsSection
            
            // History Panel
            if showHistory && !conversionHistory.isEmpty {
                historySection
            }
        }
        .padding(.horizontal)
    }
    
    // MARK: - Input Section
    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Input")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Picker("Input Type", selection: $selectedInputType) {
                    ForEach(0..<inputTypes.count, id: \.self) { index in
                        Text(inputTypes[index]).tag(index)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 120)
            }
            
            ZStack(alignment: .topLeading) {
                TextEditor(text: $inputText)
                    .font(.system(.body, design: .monospaced))
                    .frame(height: 120)
                    .padding(4)
                    .background(Color(.textBackgroundColor))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                
                if inputText.isEmpty {
                    Text(getPlaceholderText())
                        .foregroundColor(.gray)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 12)
                }
            }
            
            HStack {
                Text("Length: \(inputText.count) characters")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button("Clear") {
                    inputText = ""
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(12)
    }
    
    private func getPlaceholderText() -> String {
        switch selectedInputType {
        case 0: return "Enter text to convert..."
        case 1: return "Enter hex values (e.g., 48 65 6C 6C 6F)..."
        case 2: return "Enter Base64 string (e.g., SGVsbG8=)..."
        case 3: return "Enter decimal values (e.g., 72 101 108 108 111)..."
        case 4: return "Enter binary values (e.g., 01001000 01100101)..."
        default: return "Enter text to convert..."
        }
    }
    
    // MARK: - Conversion Buttons
    private var conversionButtons: some View {
        HStack(spacing: 12) {
            Button(action: convertAll) {
                HStack {
                    if isConverting {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                    Image(systemName: "arrow.right.arrow.left")
                    Text("Convert All")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(inputText.isEmpty || isConverting)
            
            Button(action: convertSelected) {
                HStack {
                    Image(systemName: "arrow.right")
                    Text("Convert Selected")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(inputText.isEmpty || isConverting)
        }
        .padding(.horizontal)
    }
    
    // MARK: - Results Section
    private var resultsSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Results")
                    .font(.headline)
                Spacer()
                
                Picker("Output Type", selection: $selectedOutputType) {
                    ForEach(0..<outputTypes.count, id: \.self) { index in
                        Text(outputTypes[index]).tag(index)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 120)
                
                Button(action: { showHistory.toggle() }) {
                    Label("History", systemImage: "clock.arrow.circlepath")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            
            ResultCard(title: "Hex", value: hexResult, color: .orange)
            ResultCard(title: "Base64", value: base64Result, color: .blue)
            ResultCard(title: "Decimal", value: decimalResult, color: .green)
            ResultCard(title: "Binary", value: binaryResult, color: .purple)
            ResultCard(title: "ASCII", value: asciiResult, color: .red)
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(12)
    }
    
    // MARK: - Quick Tools Section
    private var quickToolsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Tools")
                .font(.headline)
            
            HStack(spacing: 12) {
                Button("Upper Case") {
                    inputText = inputText.uppercased()
                }
                .buttonStyle(.bordered)
                
                Button("Lower Case") {
                    inputText = inputText.lowercased()
                }
                .buttonStyle(.bordered)
                
                Button("Remove Spaces") {
                    inputText = inputText.replacingOccurrences(of: " ", with: "")
                }
                .buttonStyle(.bordered)
                
                Button("Reverse") {
                    inputText = String(inputText.reversed())
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                Button("Cheat Sheet") {
                    showCheatSheet = true
                }
                .buttonStyle(.bordered)
            }
            
            // Common values
            HStack(spacing: 12) {
                Text("Examples:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Button("Hello World") {
                    inputText = "Hello World"
                }
                .buttonStyle(.borderless)
                .font(.caption)
                
                Button("Test123") {
                    inputText = "Test123"
                }
                .buttonStyle(.borderless)
                .font(.caption)
                
                Button("SYSM") {
                    inputText = "SYSM"
                }
                .buttonStyle(.borderless)
                .font(.caption)
                
                Button("Empty") {
                    inputText = ""
                }
                .buttonStyle(.borderless)
                .font(.caption)
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(12)
    }
    
    // MARK: - History Section
    private var historySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Conversion History")
                    .font(.headline)
                
                Spacer()
                
                Button("Clear All") {
                    conversionHistory.removeAll()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                
                Button("Close") {
                    showHistory = false
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(conversionHistory) { record in
                        HistoryItem(record: record)
                    }
                }
            }
            .frame(maxHeight: 300)
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(12)
        .shadow(radius: 5)
    }
    
    // MARK: - Information Section
    private var informationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Encoding Information")
                .font(.headline)
            
            CalculatorInfoRow(title: "Hex", description: "Base-16 encoding using 0-9 and A-F (case insensitive)")
            CalculatorInfoRow(title: "Base64", description: "64-character encoding using A-Z, a-z, 0-9, +, /, and = padding")
            CalculatorInfoRow(title: "Decimal", description: "Base-10 representation of ASCII values (space separated)")
            CalculatorInfoRow(title: "Binary", description: "Base-2 representation (8 bits per character, space separated)")
            CalculatorInfoRow(title: "ASCII", description: "American Standard Code for Information Interchange (0-127)")
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    // MARK: - Conversion Functions
    private func convertAll() {
        isConverting = true
        
        // Clear previous results
        hexResult = ""
        base64Result = ""
        decimalResult = ""
        binaryResult = ""
        asciiResult = ""
        
        DispatchQueue.global(qos: .userInitiated).async {
            let input = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if input.isEmpty {
                DispatchQueue.main.async {
                    isConverting = false
                    errorMessage = "Input cannot be empty"
                    showError = true
                }
                return
            }
            
            var results: [String] = []
            
            // Convert based on input type
            switch selectedInputType {
            case 0: // Text
                results = convertFromText(input)
            case 1: // Hex
                results = convertFromHex(input)
            case 2: // Base64
                results = convertFromBase64(input)
            case 3: // Decimal
                results = convertFromDecimal(input)
            case 4: // Binary
                results = convertFromBinary(input)
            default:
                results = ["", "", "", "", ""]
            }
            
            DispatchQueue.main.async {
                hexResult = results[0]
                base64Result = results[1]
                decimalResult = results[2]
                binaryResult = results[3]
                asciiResult = results[4]
                
                // Add to history
                let record = ConversionRecord(
                    input: input,
                    inputType: inputTypes[selectedInputType],
                    hex: results[0],
                    base64: results[1],
                    decimal: results[2],
                    binary: results[3],
                    ascii: results[4],
                    timestamp: Date()
                )
                conversionHistory.insert(record, at: 0)
                
                // Keep only last 50 records
                if conversionHistory.count > 50 {
                    conversionHistory = Array(conversionHistory.prefix(50))
                }
                
                isConverting = false
            }
        }
    }
    
    private func convertSelected() {
        isConverting = true
        
        let input = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if input.isEmpty {
            isConverting = false
            errorMessage = "Input cannot be empty"
            showError = true
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            var result = ""
            
            // Convert based on input type and desired output type
            switch selectedInputType {
            case 0: // Text -> Selected output
                result = convertTextToOutput(text: input, outputType: selectedOutputType)
            case 1: // Hex -> Selected output
                result = convertHexToOutput(hex: input, outputType: selectedOutputType)
            case 2: // Base64 -> Selected output
                result = convertBase64ToOutput(base64: input, outputType: selectedOutputType)
            case 3: // Decimal -> Selected output
                result = convertDecimalToOutput(decimal: input, outputType: selectedOutputType)
            case 4: // Binary -> Selected output
                result = convertBinaryToOutput(binary: input, outputType: selectedOutputType)
            default:
                result = ""
            }
            
            DispatchQueue.main.async {
                // Update the appropriate result field
                switch selectedOutputType {
                case 0:
                    hexResult = result
                case 1:
                    base64Result = result
                case 2:
                    decimalResult = result
                case 3:
                    binaryResult = result
                case 4:
                    asciiResult = result
                default:
                    break
                }
                
                // Add to history
                let record = ConversionRecord(
                    input: input,
                    inputType: inputTypes[selectedInputType],
                    hex: selectedOutputType == 0 ? result : "",
                    base64: selectedOutputType == 1 ? result : "",
                    decimal: selectedOutputType == 2 ? result : "",
                    binary: selectedOutputType == 3 ? result : "",
                    ascii: selectedOutputType == 4 ? result : "",
                    timestamp: Date()
                )
                conversionHistory.insert(record, at: 0)
                
                if conversionHistory.count > 50 {
                    conversionHistory = Array(conversionHistory.prefix(50))
                }
                
                isConverting = false
            }
        }
    }
    
    // MARK: - Conversion Helper Functions
    
    private func convertFromText(_ text: String) -> [String] {
        let hex = convertTextToHex(text)
        let base64 = convertTextToBase64(text)
        let decimal = convertTextToDecimal(text)
        let binary = convertTextToBinary(text)
        let ascii = text // ASCII is the text itself
        
        return [hex, base64, decimal, binary, ascii]
    }
    
    private func convertFromHex(_ hex: String) -> [String] {
        // Clean hex string
        let cleanedHex = hex.replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "0x", with: "")
            .replacingOccurrences(of: "\\x", with: "")
        
        // Convert hex to data
        guard let data = hexStringToData(cleanedHex) else {
            return ["Invalid Hex", "", "", "", ""]
        }
        
        // Convert to text
        guard let text = String(data: data, encoding: .utf8) else {
            return ["Invalid Hex encoding", "", "", "", ""]
        }
        
        let base64 = data.base64EncodedString()
        let decimal = convertTextToDecimal(text)
        let binary = convertTextToBinary(text)
        
        return [formatHex(cleanedHex), base64, decimal, binary, text]
    }
    
    private func convertFromBase64(_ base64: String) -> [String] {
        // Clean base64 string
        let cleanedBase64 = base64.replacingOccurrences(of: " ", with: "")
        
        guard let data = Data(base64Encoded: cleanedBase64) else {
            return ["", "Invalid Base64", "", "", ""]
        }
        
        guard let text = String(data: data, encoding: .utf8) else {
            return ["", "Invalid Base64 encoding", "", "", ""]
        }
        
        let hex = data.map { String(format: "%02X", $0) }.joined()
        let decimal = convertTextToDecimal(text)
        let binary = convertTextToBinary(text)
        
        return [formatHex(hex), cleanedBase64, decimal, binary, text]
    }
    
    private func convertFromDecimal(_ decimal: String) -> [String] {
        // Split by spaces or commas
        let cleanedDecimal = decimal.replacingOccurrences(of: ",", with: " ")
        let numbers = cleanedDecimal.split(separator: " ").compactMap { Int($0) }
        
        // Convert to characters
        let characters = numbers.compactMap { UnicodeScalar($0) }.map { Character($0) }
        let text = String(characters)
        
        let hex = convertTextToHex(text)
        let base64 = convertTextToBase64(text)
        let binary = convertTextToBinary(text)
        
        return [hex, base64, cleanedDecimal, binary, text]
    }
    
    private func convertFromBinary(_ binary: String) -> [String] {
        // Clean binary string
        let cleanedBinary = binary.replacingOccurrences(of: " ", with: "")
        
        // Split into 8-bit chunks
        var chars = [Character]()
        for i in stride(from: 0, to: cleanedBinary.count, by: 8) {
            let start = cleanedBinary.index(cleanedBinary.startIndex, offsetBy: i)
            let end = cleanedBinary.index(start, offsetBy: min(8, cleanedBinary.count - i))
            let byteStr = String(cleanedBinary[start..<end])
            
            if let byte = UInt8(byteStr, radix: 2) {
                chars.append(Character(UnicodeScalar(byte)))
            }
        }
        
        let text = String(chars)
        let hex = convertTextToHex(text)
        let base64 = convertTextToBase64(text)
        let decimal = convertTextToDecimal(text)
        
        return [hex, base64, decimal, formatBinary(cleanedBinary), text]
    }
    
    // MARK: - Text to Output Conversions
    
    private func convertTextToOutput(text: String, outputType: Int) -> String {
        switch outputType {
        case 0: return convertTextToHex(text)
        case 1: return convertTextToBase64(text)
        case 2: return convertTextToDecimal(text)
        case 3: return convertTextToBinary(text)
        case 4: return text // ASCII
        default: return ""
        }
    }
    
    private func convertHexToOutput(hex: String, outputType: Int) -> String {
        let cleanedHex = hex.replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "0x", with: "")
            .replacingOccurrences(of: "\\x", with: "")
        
        guard let data = hexStringToData(cleanedHex),
              let text = String(data: data, encoding: .utf8) else {
            return "Invalid Hex"
        }
        
        switch outputType {
        case 0: return formatHex(cleanedHex)
        case 1: return data.base64EncodedString()
        case 2: return convertTextToDecimal(text)
        case 3: return convertTextToBinary(text)
        case 4: return text
        default: return ""
        }
    }
    
    private func convertBase64ToOutput(base64: String, outputType: Int) -> String {
        let cleanedBase64 = base64.replacingOccurrences(of: " ", with: "")
        
        guard let data = Data(base64Encoded: cleanedBase64),
              let text = String(data: data, encoding: .utf8) else {
            return "Invalid Base64"
        }
        
        switch outputType {
        case 0: return formatHex(data.map { String(format: "%02X", $0) }.joined())
        case 1: return cleanedBase64
        case 2: return convertTextToDecimal(text)
        case 3: return convertTextToBinary(text)
        case 4: return text
        default: return ""
        }
    }
    
    private func convertDecimalToOutput(decimal: String, outputType: Int) -> String {
        let cleanedDecimal = decimal.replacingOccurrences(of: ",", with: " ")
        let numbers = cleanedDecimal.split(separator: " ").compactMap { Int($0) }
        let characters = numbers.compactMap { UnicodeScalar($0) }.map { Character($0) }
        let text = String(characters)
        
        switch outputType {
        case 0: return convertTextToHex(text)
        case 1: return convertTextToBase64(text)
        case 2: return cleanedDecimal
        case 3: return convertTextToBinary(text)
        case 4: return text
        default: return ""
        }
    }
    
    private func convertBinaryToOutput(binary: String, outputType: Int) -> String {
        let cleanedBinary = binary.replacingOccurrences(of: " ", with: "")
        
        // Convert binary to text
        var chars = [Character]()
        for i in stride(from: 0, to: cleanedBinary.count, by: 8) {
            let start = cleanedBinary.index(cleanedBinary.startIndex, offsetBy: i)
            let end = cleanedBinary.index(start, offsetBy: min(8, cleanedBinary.count - i))
            let byteStr = String(cleanedBinary[start..<end])
            
            if let byte = UInt8(byteStr, radix: 2) {
                chars.append(Character(UnicodeScalar(byte)))
            }
        }
        
        let text = String(chars)
        
        switch outputType {
        case 0: return convertTextToHex(text)
        case 1: return convertTextToBase64(text)
        case 2: return convertTextToDecimal(text)
        case 3: return formatBinary(cleanedBinary)
        case 4: return text
        default: return ""
        }
    }
    
    // MARK: - Basic Conversion Functions
    
    private func convertTextToHex(_ text: String) -> String {
        let hex = text.utf8.map { String(format: "%02X", $0) }.joined()
        return formatHex(hex)
    }
    
    private func convertTextToBase64(_ text: String) -> String {
        guard let data = text.data(using: .utf8) else { return "" }
        return data.base64EncodedString()
    }
    
    private func convertTextToDecimal(_ text: String) -> String {
        return text.utf8.map { String($0) }.joined(separator: " ")
    }
    
    private func convertTextToBinary(_ text: String) -> String {
        return text.utf8.map { byte -> String in
            let binary = String(byte, radix: 2)
            return String(repeating: "0", count: 8 - binary.count) + binary
        }.joined(separator: " ")
    }
    
    // MARK: - Formatting Functions
    
    private func formatHex(_ hex: String) -> String {
        // Format with spaces every 2 characters
        return stride(from: 0, to: hex.count, by: 2).map {
            let start = hex.index(hex.startIndex, offsetBy: $0)
            let end = hex.index(start, offsetBy: min(2, hex.count - $0))
            return String(hex[start..<end])
        }.joined(separator: " ").uppercased()
    }
    
    private func formatBinary(_ binary: String) -> String {
        // Format with spaces every 8 characters
        return stride(from: 0, to: binary.count, by: 8).map {
            let start = binary.index(binary.startIndex, offsetBy: $0)
            let end = binary.index(start, offsetBy: min(8, binary.count - $0))
            return String(binary[start..<end])
        }.joined(separator: " ")
    }
    
    // MARK: - Utility Functions
    
    private func hexStringToData(_ hex: String) -> Data? {
        var data = Data()
        var hex = hex
        
        // Remove any non-hex characters
        hex = hex.filter { "0123456789ABCDEFabcdef".contains($0) }
        
        // Ensure even length
        if hex.count % 2 != 0 {
            hex = "0" + hex
        }
        
        var index = hex.startIndex
        while index < hex.endIndex {
            let nextIndex = hex.index(index, offsetBy: 2)
            if nextIndex <= hex.endIndex {
                let byteString = hex[index..<nextIndex]
                if let byte = UInt8(byteString, radix: 16) {
                    data.append(byte)
                }
            }
            index = nextIndex
        }
        
        return data.isEmpty ? nil : data
    }
}

// MARK: - Result Card Component
struct ResultCard: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.headline)
                    .foregroundColor(color)
                
                Spacer()
                
                Button(action: copyToClipboard) {
                    Image(systemName: "doc.on.doc")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .disabled(value.isEmpty)
                .help("Copy to clipboard")
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                Text(value.isEmpty ? "No result" : value)
                    .font(.system(.body, design: .monospaced))
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.textBackgroundColor))
                    .cornerRadius(6)
            }
            
            if !value.isEmpty {
                HStack {
                    Text("Length: \(value.count) characters")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    if value.contains(" ") {
                        Text("• Words: \(value.split(separator: " ").count)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private func copyToClipboard() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(value, forType: .string)
        
        // Show a quick feedback (optional - could add a toast notification)
        #if os(macOS)
        NSSound(named: "Glass")?.play()
        #endif
    }
}

// MARK: - Calculator Info Row Component (Renamed to avoid conflict)
struct CalculatorInfoRow: View {
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .frame(width: 80, alignment: .leading)
            
            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Cheat Sheet View
struct CheatSheetView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Encoding Cheat Sheet")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.bottom, 8)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Common Examples")
                            .font(.headline)
                            .foregroundColor(.blue)
                        
                        CheatItem(title: "Text:", value: "Hello")
                        CheatItem(title: "Hex:", value: "48 65 6C 6C 6F")
                        CheatItem(title: "Base64:", value: "SGVsbG8=")
                        CheatItem(title: "Decimal:", value: "72 101 108 108 111")
                        CheatItem(title: "Binary:", value: "01001000 01100101 01101100 01101100 01101111")
                    }
                    
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("ASCII Reference")
                            .font(.headline)
                            .foregroundColor(.green)
                        
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                CheatItem(title: "A:", value: "Hex: 41, Dec: 65")
                                CheatItem(title: "a:", value: "Hex: 61, Dec: 97")
                                CheatItem(title: "0:", value: "Hex: 30, Dec: 48")
                                CheatItem(title: "Space:", value: "Hex: 20, Dec: 32")
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .leading, spacing: 4) {
                                CheatItem(title: "Newline:", value: "Hex: 0A, Dec: 10")
                                CheatItem(title: "Tab:", value: "Hex: 09, Dec: 9")
                                CheatItem(title: "@:", value: "Hex: 40, Dec: 64")
                                CheatItem(title: "?:", value: "Hex: 3F, Dec: 63")
                            }
                        }
                    }
                    
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Format Tips")
                            .font(.headline)
                            .foregroundColor(.orange)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("• Hex: Use spaces or no spaces, case insensitive")
                            Text("• Base64: May end with = or == for padding")
                            Text("• Binary: Must be 8 bits per character")
                            Text("• Decimal: Space or comma separated")
                            Text("• Non-printable characters show as � in ASCII")
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                    
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Common Uses")
                            .font(.headline)
                            .foregroundColor(.purple)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("• Hex: Memory addresses, color codes, MAC addresses")
                            Text("• Base64: Email attachments, data URLs, API tokens")
                            Text("• Binary: Bit masks, permissions, network protocols")
                            Text("• Decimal: ASCII art, simple encoding")
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                }
            }
            
            HStack {
                Spacer()
                Button("Close") {
                    #if os(macOS)
                    NSApp.sendAction(#selector(NSPopover.performClose(_:)), to: nil, from: nil)
                    #endif
                }
                .keyboardShortcut(.escape)
            }
            .padding(.top, 8)
        }
        .padding()
        .frame(width: 500, height: 500)
    }
}

struct CheatItem: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .frame(width: 60, alignment: .leading)
                Text(value)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
            }
        }
    }
}

// MARK: - History Item Component
struct HistoryItem: View {
    let record: ConversionRecord
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("\(record.inputType): \(record.input.truncate(to: 20))")
                    .font(.caption)
                    .fontWeight(.medium)
                
                Spacer()
                
                Text(record.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            if !record.hex.isEmpty {
                Text("Hex: \(record.hex.truncate(to: 30))")
                    .font(.caption2)
                    .foregroundColor(.orange)
            }
            
            if !record.base64.isEmpty {
                Text("Base64: \(record.base64.truncate(to: 30))")
                    .font(.caption2)
                    .foregroundColor(.blue)
            }
            
            if !record.decimal.isEmpty && record.decimal != record.input {
                Text("Decimal: \(record.decimal.truncate(to: 30))")
                    .font(.caption2)
                    .foregroundColor(.green)
            }
        }
        .padding(8)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(6)
        .contextMenu {
            Button("Copy Input") {
                copyToClipboard(record.input)
            }
            
            if !record.hex.isEmpty {
                Button("Copy Hex") {
                    copyToClipboard(record.hex)
                }
            }
            
            if !record.base64.isEmpty {
                Button("Copy Base64") {
                    copyToClipboard(record.base64)
                }
            }
            
            if !record.decimal.isEmpty {
                Button("Copy Decimal") {
                    copyToClipboard(record.decimal)
                }
            }
            
            if !record.binary.isEmpty {
                Button("Copy Binary") {
                    copyToClipboard(record.binary)
                }
            }
            
            Divider()
            
            Button("Delete") {
                // This would need to be connected to parent view to delete
            }
        }
    }
    
    private func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
}

// MARK: - Data Models
struct ConversionRecord: Identifiable {
    let id = UUID()
    let input: String
    let inputType: String
    let hex: String
    let base64: String
    let decimal: String
    let binary: String
    let ascii: String
    let timestamp: Date
}

// MARK: - String Extension for Truncation
extension String {
    func truncate(to length: Int, trailing: String = "...") -> String {
        if self.count > length {
            return String(self.prefix(length)) + trailing
        }
        return self
    }
}

// MARK: - Preview
struct HexBase64CalculatorView_Previews: PreviewProvider {
    static var previews: some View {
        HexBase64CalculatorView()
            .frame(width: 1200, height: 800)
            .preferredColorScheme(.light)
        
        HexBase64CalculatorView()
            .frame(width: 1200, height: 800)
            .preferredColorScheme(.dark)
            .previewDisplayName("Dark Mode")
    }
}