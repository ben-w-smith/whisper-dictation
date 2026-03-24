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
    private let scriptsPath = "/Users/bensmith/whisper-dictation"
    private let venvPython: String

    // Reference to ObsidianManager for vault path
    private var obsidianManager: ObsidianManager {
        ObsidianManager.shared
    }

    // Reference to StatisticsManager
    private var statisticsManager: StatisticsManager {
        StatisticsManager.shared
    }

    // MARK: - Initialization
    init() {
        self.venvPython = "\(scriptsPath)/venv/bin/python"
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
        let scriptPath = "\(scriptsPath)/warmup-model.py"
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
        // Check if Obsidian vault is configured and enabled
        guard obsidianManager.isReady,
              let transcriptionsPath = obsidianManager.transcriptionsPath else {
            print("Obsidian vault not configured - skipping transcription history load")
            transcriptions = []
            statisticsManager.updateFromTranscriptions(transcriptions)
            return
        }

        let url = URL(fileURLWithPath: transcriptionsPath)
        guard FileManager.default.fileExists(atPath: transcriptionsPath) else {
            print("Obsidian transcriptions folder not found: \(transcriptionsPath)")
            transcriptions = []
            statisticsManager.updateFromTranscriptions(transcriptions)
            return
        }

        do {
            let files = try FileManager.default.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: [.contentModificationDateKey],
                options: [.skipsHiddenFiles]
            )

            let markdownFiles = files
                .filter { $0.pathExtension == "md" }
                .sorted { file1, file2 in
                    let date1 = (try? file1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? Date.distantPast
                    let date2 = (try? file2.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? Date.distantPast
                    return date1 > date2
                }

            transcriptions = markdownFiles.compactMap { Transcription.fromObsidianFile(url: $0) }
            print("Loaded \(transcriptions.count) transcriptions from Obsidian")

            // Update statistics from loaded transcriptions
            statisticsManager.updateFromTranscriptions(transcriptions)
        } catch {
            print("Error loading transcriptions: \(error)")
        }
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

                try await Task.sleep(nanoseconds: 2_000_000_000)
                loadTranscriptions()

                // Record the new transcription in statistics
                if let latestTranscription = transcriptions.first {
                    statisticsManager.recordTranscription(latestTranscription)
                }

                // Play transcription ready sound after processing completes
                SoundManager.shared.playTranscriptionReady()

                // Auto-paste if enabled
                if AutoPasteManager.shared.isEnabled {
                    // Get the transcribed text from the most recent transcription
                    if let latestTranscription = transcriptions.first {
                        await AutoPasteManager.shared.autoPaste(text: latestTranscription.text)
                    }
                }
            } catch {
                lastError = "Failed to stop recording: \(error)"
                AutoPasteManager.shared.clearFocusedElement()
            }
        }
    }

    // MARK: - Python Script Execution
    private func runPythonScript(name: String) async throws -> String {
        let scriptPath = "\(scriptsPath)/\(name)"

        let process = Process()
        process.executableURL = URL(fileURLWithPath: venvPython)
        process.arguments = [scriptPath]

        // Pass refinement configuration as environment variables
        var environment = ProcessInfo.processInfo.environment
        let refinementConfig = RefinementManager.shared.exportConfig()
        for (key, value) in refinementConfig {
            environment[key] = value
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
        let scriptPath = "\(scriptsPath)/dictate-toggle.py"
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
