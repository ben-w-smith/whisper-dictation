import Foundation
import Combine
import SwiftUI
import CoreAudio

@MainActor
class TranscriptionManager: ObservableObject {
    // MARK: - Published State
    @Published var isRecording = false
    @Published var selectedModel: WhisperModel = .tinyEn
    @Published var transcriptions: [Transcription] = []
    @Published var isProcessing = false
    @Published var lastError: String?
    @Published var modelStatus: ModelStatus = .notLoaded
    @Published var inputDevices: [AudioDevice] = []
    @Published var selectedInputDevice: AudioDevice = .systemDefault

    // MARK: - Configuration
    private let venvPython: String

    // Reference to HistoryManager for local storage
    private var historyManager: HistoryManager {
        HistoryManager.shared
    }

    // Reference to ObsidianManager for vault path (optional)
    private var obsidianManager: ObsidianManager {
        ObsidianManager.shared
    }

    // Reference to StatisticsManager
    private var statisticsManager: StatisticsManager {
        StatisticsManager.shared
    }

    // MARK: - Initialization
    init() {
        self.venvPython = PathManager.venvPython
        loadSelectedModel()
        loadSelectedInputDevice()
        loadTranscriptions()
        enumerateInputDevices()
        warmupModel()

        // Set up notification for device changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAudioDeviceChange),
            name: NSNotification.Name("com.apple.audio.CoreAudioDeviceListChanged"),
            object: nil
        )
    }

    @objc private func handleAudioDeviceChange() {
        enumerateInputDevices()
    }

    // MARK: - Model Status
    enum ModelStatus: Equatable {
        case notLoaded
        case loading
        case ready
        case error(String)

        var displayText: String {
            switch self {
            case .notLoaded: return "Model not loaded"
            case .loading: return "Loading model..."
            case .ready: return "Ready"
            case .error(let msg): return "Error: \(msg)"
            }
        }

        var iconName: String {
            switch self {
            case .notLoaded: return "circle.dashed"
            case .loading: return "arrow.trianglehead.clockwise.rotate 90°"
            case .ready: return "checkmark.circle.fill"
            case .error: return "exclamationmark.triangle.fill"
            }
        }

        var iconColor: Color {
            switch self {
            case .notLoaded: return .secondary
            case .loading: return .orange
            case .ready: return .green
            case .error: return .red
            }
        }
    }

    // MARK: - Model Warmup
    private func warmupModel() {
        modelStatus = .loading

        Task {
            do {
                // Update warmup script with selected model
                updateWarmupScriptModel()

                let result = try await runPythonScript(name: "warmup-model.py")
                print("Warmup result: \(result)")
                modelStatus = .ready
            } catch {
                print("Warmup error: \(error)")
                modelStatus = .error(error.localizedDescription)
            }
        }
    }

    private func updateWarmupScriptModel() {
        let scriptPath = "\(PathManager.scriptsPath)/warmup-model.py"
        guard var content = try? String(contentsOfFile: scriptPath, encoding: .utf8) else { return }

        let pattern = #"WhisperModel\("[^"]+""#
        let replacement = #"WhisperModel("\#(selectedModel.rawValue)""#

        if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
            let range = NSRange(content.startIndex..., in: content)
            content = regex.stringByReplacingMatches(in: content, options: [], range: range, withTemplate: replacement)
            try? content.write(toFile: scriptPath, atomically: true, encoding: .utf8)
        }
    }

    // MARK: - Model Selection
    private func loadSelectedModel() {
        if let saved = UserDefaults.standard.string(forKey: "selectedModel"),
           let model = WhisperModel(rawValue: saved) {
            selectedModel = model
        }
    }

    private func saveSelectedModel() {
        UserDefaults.standard.set(selectedModel.rawValue, forKey: "selectedModel")
    }

    func setSelectedModel(_ model: WhisperModel) {
        selectedModel = model
        saveSelectedModel()
        // Rewarm with new model
        warmupModel()
    }

    // MARK: - Audio Device Enumeration
    func enumerateInputDevices() {
        var devices: [AudioDevice] = [.systemDefault]

        // Get the default input device ID first
        var defaultDeviceID: AudioDeviceID = 0
        var propertySize = UInt32(MemoryLayout<AudioDeviceID>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        let defaultStatus = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &propertySize,
            &defaultDeviceID
        )

        // Get all audio devices
        address.mSelector = kAudioHardwarePropertyDevices
        address.mScope = kAudioObjectPropertyScopeGlobal
        address.mElement = kAudioObjectPropertyElementMain

        // First get the size needed
        var status = AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &propertySize
        )

        guard status == noErr else {
            print("Failed to get audio devices size: \(status)")
            self.inputDevices = devices
            return
        }

        let deviceCount = Int(propertySize) / MemoryLayout<AudioDeviceID>.size
        var deviceIDs = [AudioDeviceID](repeating: 0, count: deviceCount)

        status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &propertySize,
            &deviceIDs
        )

        guard status == noErr else {
            print("Failed to get audio devices: \(status)")
            self.inputDevices = devices
            return
        }

        // Filter for input devices and get their names
        for (index, deviceID) in deviceIDs.enumerated() {
            // Check if this device has input channels
            var inputAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyStreamConfiguration,
                mScope: kAudioDevicePropertyScopeInput,
                mElement: kAudioObjectPropertyElementMain
            )

            var configSize = UInt32(0)
            let configStatus = AudioObjectGetPropertyDataSize(deviceID, &inputAddress, 0, nil, &configSize)

            guard configStatus == noErr && configSize > 0 else {
                continue
            }

            // Get the buffer list to check number of input channels
            guard let bufferList = malloc(Int(configSize))?.assumingMemoryBound(to: AudioBufferList.self) else {
                continue
            }
            defer { free(bufferList) }

            guard AudioObjectGetPropertyData(deviceID, &inputAddress, 0, nil, &configSize, bufferList) == noErr else {
                continue
            }

            // Check if there are any input channels
            let inputChannels = bufferList.pointee.mBuffers.mNumberChannels
            guard inputChannels > 0 else {
                continue
            }

            // Get device name
            var name: CFString = "" as CFString
            var nameSize = UInt32(MemoryLayout<CFString>.size)
            var nameAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyDeviceNameCFString,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )

            if AudioObjectGetPropertyData(deviceID, &nameAddress, 0, nil, &nameSize, &name) == noErr {
                let deviceName = name as String
                let isDefault = (defaultStatus == noErr && deviceID == defaultDeviceID)

                // Use the enumeration index as the PyAudio index
                // PyAudio indices correspond to the order devices are returned
                let device = AudioDevice(
                    id: index,
                    name: deviceName,
                    isDefault: isDefault
                )
                devices.append(device)
                print("Found input device [\(index)]: \(deviceName) (default: \(isDefault))")
            }
        }

        self.inputDevices = devices

        // Check if selected device still exists
        if !devices.contains(where: { $0.id == selectedInputDevice.id }) {
            selectedInputDevice = .systemDefault
            saveSelectedInputDevice()
        }
    }

    // MARK: - Input Device Selection
    private func loadSelectedInputDevice() {
        if let savedData = UserDefaults.standard.data(forKey: "selectedInputDevice"),
           let saved = try? JSONDecoder().decode(AudioDevice.self, from: savedData) {
            selectedInputDevice = saved
        }
    }

    private func saveSelectedInputDevice() {
        if let data = try? JSONEncoder().encode(selectedInputDevice) {
            UserDefaults.standard.set(data, forKey: "selectedInputDevice")
        }
    }

    func setSelectedInputDevice(_ device: AudioDevice) {
        selectedInputDevice = device
        saveSelectedInputDevice()
        print("Selected input device: \(device.displayName) (index: \(device.id))")
    }

    // MARK: - Transcription History
    func loadTranscriptions() {
        // Always load from local history (works regardless of Obsidian vault)
        historyManager.reloadHistory()
        transcriptions = historyManager.transcriptions

        print("Loaded \(transcriptions.count) transcriptions from local history")

        // Update statistics from loaded transcriptions
        statisticsManager.updateFromTranscriptions(transcriptions)
    }

    // MARK: - Recording Control
    func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }

    private func startRecording() {
        isRecording = true
        lastError = nil
        updateScriptModel()

        // Record the focused element for auto-paste
        AutoPasteManager.shared.recordFocusedElement()

        // Play start recording sound
        SoundManager.shared.playStartRecording()

        Task {
            do {
                let result = try await runPythonScript(name: "dictate-toggle.py")
                print("Recording started: \(result)")
            } catch {
                lastError = "Failed to start recording: \(error)"
                isRecording = false
                AutoPasteManager.shared.clearFocusedElement()
            }
        }
    }

    private func stopRecording() {
        // Play stop recording sound
        SoundManager.shared.playStopRecording()

        isRecording = false

        Task {
            isProcessing = true
            defer { isProcessing = false }

            do {
                let result = try await runPythonScript(name: "dictate-toggle.py")
                print("Recording stopped: \(result)")

                // Parse the transcription from Python output
                guard let parsed = parseTranscriptionFromOutput(result) else {
                    print("No transcription text, clearing focused element")
                    AutoPasteManager.shared.clearFocusedElement()
                    return
                }

                let (text, model, timestamp) = parsed

                // Create transcription and save to local history
                let transcription = Transcription(
                    text: text,
                    timestamp: timestamp,
                    model: model
                )
                historyManager.addTranscription(transcription)

                // Update our published array from history manager
                transcriptions = historyManager.transcriptions

                // Record the new transcription in statistics
                statisticsManager.recordTranscription(transcription)

                // Play transcription ready sound after processing completes
                SoundManager.shared.playTranscriptionReady()

                print("TranscriptionManager: Transcription text ready, length: \(text.count)")
                print("TranscriptionManager: AutoPasteManager.shared.isEnabled = \(AutoPasteManager.shared.isEnabled)")
                print("TranscriptionManager: AutoPasteManager.shared.hasAccessibilityPermission = \(AutoPasteManager.shared.hasAccessibilityPermission)")

                // Always copy to clipboard as fallback
                AutoPasteManager.shared.copyToClipboardPublic(text: text)

                // Auto-paste if enabled
                if AutoPasteManager.shared.isEnabled {
                    print("TranscriptionManager: Calling autoPaste()")
                    await AutoPasteManager.shared.autoPaste(text: text)
                    print("TranscriptionManager: autoPaste() completed")
                } else {
                    print("TranscriptionManager: Auto-paste is disabled, skipping")
                }
            } catch {
                lastError = "Failed to stop recording: \(error)"
                AutoPasteManager.shared.clearFocusedElement()
            }
        }
    }

    /// Parse transcription text from Python script output
    private func parseTranscriptionFromOutput(_ output: String) -> (text: String, model: WhisperModel, timestamp: Date)? {
        // Look for TRANSCRIPTION_START and TRANSCRIPTION_END markers
        guard let startIndex = output.range(of: "TRANSCRIPTION_START")?.upperBound,
              let endIndex = output.range(of: "TRANSCRIPTION_END")?.lowerBound else {
            print("Could not find transcription markers in output")
            return nil
        }

        let text = String(output[startIndex..<endIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
        print("Parsed transcription: \(text)")

        guard !text.isEmpty else { return nil }

        // Parse model
        let model: WhisperModel
        if let modelRange = output.range(of: "TRANSCRIPTION_MODEL:"),
           let modelEnd = output[modelRange.upperBound...].firstIndex(of: "\n") {
            let modelString = String(output[modelRange.upperBound..<modelEnd]).trimmingCharacters(in: .whitespaces)
            model = WhisperModel(rawValue: modelString) ?? .tinyEn
        } else {
            model = selectedModel
        }

        // Parse timestamp
        let timestamp: Date
        if let tsRange = output.range(of: "TRANSCRIPTION_TIMESTAMP:"),
           let tsEnd = output[tsRange.upperBound...].firstIndex(of: "\n") {
            let tsString = String(output[tsRange.upperBound..<tsEnd]).trimmingCharacters(in: .whitespaces)
            timestamp = ISO8601DateFormatter().date(from: tsString) ?? Date()
        } else {
            timestamp = Date()
        }

        return (text, model, timestamp)
    }

    // MARK: - Python Script Execution
    private func runPythonScript(name: String) async throws -> String {
        let scriptPath = "\(PathManager.scriptsPath)/\(name)"

        let process = Process()
        process.executableURL = URL(fileURLWithPath: venvPython)
        process.arguments = [scriptPath]

        // Pass refinement configuration as environment variables
        var environment = ProcessInfo.processInfo.environment
        let refinementConfig = RefinementManager.shared.exportConfig()
        for (key, value) in refinementConfig {
            environment[key] = value
        }

        // Pass Obsidian vault path if configured
        if obsidianManager.isReady, let vaultPath = obsidianManager.vaultPath {
            environment["DICTATE_OBSIDIAN_VAULT"] = vaultPath.path
        }

        process.environment = environment

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

        let output = String(data: outputData, encoding: .utf8) ?? ""
        let errorOutput = String(data: errorData, encoding: .utf8) ?? ""

        if process.terminationStatus != 0 {
            throw DictationError.scriptError(errorOutput.isEmpty ? output : errorOutput)
        }

        return output
    }

    private func updateScriptModel() {
        let scriptPath = "\(PathManager.scriptsPath)/dictate-toggle.py"
        guard var content = try? String(contentsOfFile: scriptPath, encoding: .utf8) else {
            print("Could not read script file")
            return
        }

        // Update model size
        let modelPattern = #"MODEL_SIZE = "[^"]+""#
        let modelReplacement = #"MODEL_SIZE = "\#(selectedModel.rawValue)""#

        if let regex = try? NSRegularExpression(pattern: modelPattern, options: []) {
            let range = NSRange(content.startIndex..., in: content)
            content = regex.stringByReplacingMatches(in: content, options: [], range: range, withTemplate: modelReplacement)
            print("Updated model to: \(selectedModel.rawValue)")
        }

        // Update input device index
        // Use "None" for system default (index -1), otherwise use the device index
        let deviceValue = selectedInputDevice.id == -1 ? "None" : "\(selectedInputDevice.id)"
        let devicePattern = #"INPUT_DEVICE_INDEX = [^\n]+"#
        let deviceReplacement = #"INPUT_DEVICE_INDEX = \#(deviceValue)  # \#(selectedInputDevice.displayName)""#

        if let regex = try? NSRegularExpression(pattern: devicePattern, options: []) {
            let range = NSRange(content.startIndex..., in: content)
            content = regex.stringByReplacingMatches(in: content, options: [], range: range, withTemplate: deviceReplacement)
            print("Updated input device to: \(selectedInputDevice.displayName) (\(deviceValue))")
        }

        // Update Obsidian vault path
        if obsidianManager.isReady, let vaultPath = obsidianManager.vaultPath {
            let vaultPattern = #"OBSIDIAN_VAULT = Path\("[^"]+"\)"#
            let vaultReplacement = #"OBSIDIAN_VAULT = Path("\#(vaultPath.path)")"#

            if let regex = try? NSRegularExpression(pattern: vaultPattern, options: []) {
                let range = NSRange(content.startIndex..., in: content)
                content = regex.stringByReplacingMatches(in: content, options: [], range: range, withTemplate: vaultReplacement)
                print("Updated OBSIDIAN_VAULT to: \(vaultPath.path)")
            }
        }

        try? content.write(toFile: scriptPath, atomically: true, encoding: .utf8)
    }
}

// MARK: - Errors
enum DictationError: LocalizedError {
    case scriptError(String)
    case transcriptionFailed

    var errorDescription: String? {
        switch self {
        case .scriptError(let message):
            return "Script error: \(message)"
        case .transcriptionFailed:
            return "Transcription failed"
        }
    }
}
