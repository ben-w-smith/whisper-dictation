import Foundation
import AppKit
import SwiftUI

/// Manages setup checks and first-run configuration
@MainActor
class SetupManager: ObservableObject {
    static let shared = SetupManager()

    // MARK: - Published State

    @Published var currentStep: SetupStep = .welcome
    @Published var setupCompleted: Bool {
        didSet {
            UserDefaults.standard.set(setupCompleted, forKey: "setupCompleted")
        }
    }

    // System check results
    @Published var pythonVersion: String?
    @Published var hasPython310: CheckStatus = .unchecked
    @Published var hasHomebrew: CheckStatus = .unchecked
    @Published var hasPortAudio: CheckStatus = .unchecked
    @Published var hasVenv: CheckStatus = .unchecked

    // User selections
    @Published var selectedVaultPath: URL?
    @Published var selectedModel: WhisperModel = .baseEn

    // Setup progress
    @Published var isRunningSetup: Bool = false
    @Published var setupProgress: String = ""
    @Published var setupError: String?

    // MARK: - Types

    enum SetupStep: Int, CaseIterable {
        case welcome
        case systemCheck
        case permissions
        case vaultConfig
        case modelSelection
        case complete

        var title: String {
            switch self {
            case .welcome: return "Welcome"
            case .systemCheck: return "System Check"
            case .permissions: return "Permissions"
            case .vaultConfig: return "Vault Configuration"
            case .modelSelection: return "Model Selection"
            case .complete: return "Setup Complete"
            }
        }

        var stepNumber: Int {
            rawValue + 1
        }

        var totalSteps: Int {
            SetupStep.allCases.count
        }
    }

    enum CheckStatus {
        case unchecked
        case checking
        case pass
        case fail(String)
        case warning(String)

        var isPass: Bool {
            if case .pass = self { return true }
            return false
        }

        var isFail: Bool {
            if case .fail = self { return true }
            return false
        }

        var isUnchecked: Bool {
            if case .unchecked = self { return true }
            return false
        }
    }

    // MARK: - Computed Properties

    var canProceed: Bool {
        // All steps have a valid model selection as default, so always proceed
        return true
    }

    var nextStep: SetupStep? {
        guard let nextIndex = SetupStep.RawValue(exactly: currentStep.rawValue + 1) else {
            return nil
        }
        return SetupStep(rawValue: nextIndex)
    }

    var previousStep: SetupStep? {
        guard let prevIndex = SetupStep.RawValue(exactly: currentStep.rawValue - 1) else {
            return nil
        }
        return SetupStep(rawValue: prevIndex)
    }

    // MARK: - Initialization

    private init() {
        self.setupCompleted = UserDefaults.standard.bool(forKey: "setupCompleted")
    }

    // MARK: - Navigation

    func goToNextStep() {
        guard let next = nextStep else { return }
        currentStep = next

        // Auto-trigger checks for system check step
        if currentStep == .systemCheck {
            runSystemChecks()
        }
    }

    func goToPreviousStep() {
        guard let previous = previousStep else { return }
        currentStep = previous
    }

    func skipSetup() {
        markSetupCompleted()
    }

    func markSetupCompleted() {
        setupCompleted = true

        // Save selections to their respective managers
        saveVaultConfiguration()
        saveModelSelection()
    }

    // MARK: - System Checks

    func runSystemChecks() {
        // Reset all to checking
        hasPython310 = .checking
        hasHomebrew = .checking
        hasPortAudio = .checking
        hasVenv = .checking

        Task {
            await checkPython()
            await checkHomebrew()
            await checkPortAudio()
            await checkVenv()
        }
    }

    private func checkPython() async {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
        task.arguments = ["--version"]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe

        do {
            try task.run()
            task.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""

            // Parse version: "Python 3.x.x"
            if let match = output.range(of: #"Python (\d+\.\d+)"#, options: .regularExpression) {
                let versionStr = String(output[match]).replacingOccurrences(of: "Python ", with: "")
                pythonVersion = versionStr

                let parts = versionStr.split(separator: ".").compactMap { Int($0) }
                if parts.count >= 2 {
                    let major = parts[0]
                    let minor = parts[1]

                    await MainActor.run {
                        if major > 3 || (major == 3 && minor >= 10) {
                            hasPython310 = .pass
                        } else {
                            hasPython310 = .fail("Python 3.10+ required, found \(versionStr)")
                        }
                    }
                    return
                }
            }

            await MainActor.run {
                hasPython310 = .fail("Could not parse Python version")
            }
        } catch {
            await MainActor.run {
                hasPython310 = .fail("Python 3 not found")
            }
        }
    }

    private func checkHomebrew() async {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/local/bin/brew")

        // Try alternate location
        if !FileManager.default.fileExists(atPath: task.executableURL!.path) {
            task.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/brew")
        }

        task.arguments = ["--version"]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe

        do {
            try task.run()
            task.waitUntilExit()

            if task.terminationStatus == 0 {
                await MainActor.run {
                    hasHomebrew = .pass
                }
            } else {
                await MainActor.run {
                    hasHomebrew = .fail("Homebrew not found")
                }
            }
        } catch {
            await MainActor.run {
                hasHomebrew = .fail("Homebrew not installed. Install from https://brew.sh")
            }
        }
    }

    private func checkPortAudio() async {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/local/bin/brew")

        // Try alternate location
        if !FileManager.default.fileExists(atPath: task.executableURL!.path) {
            task.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/brew")
        }

        task.arguments = ["list", "portaudio"]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()

        do {
            try task.run()
            task.waitUntilExit()

            if task.terminationStatus == 0 {
                await MainActor.run {
                    hasPortAudio = .pass
                }
            } else {
                await MainActor.run {
                    hasPortAudio = .warning("PortAudio not installed (will be installed by setup)")
                }
            }
        } catch {
            await MainActor.run {
                hasPortAudio = .warning("PortAudio check failed")
            }
        }
    }

    private func checkVenv() async {
        let venvPath = "\(PathManager.scriptsPath)/venv"

        if FileManager.default.fileExists(atPath: venvPath) {
            let pythonPath = "\(venvPath)/bin/python"
            if FileManager.default.fileExists(atPath: pythonPath) {
                await MainActor.run {
                    hasVenv = .pass
                }
            } else {
                await MainActor.run {
                    hasVenv = .fail("Virtual environment exists but appears incomplete")
                }
            }
        } else {
            await MainActor.run {
                hasVenv = .warning("Virtual environment not found (will be created by setup)")
            }
        }
    }

    // MARK: - Setup Execution

    func runSetup() {
        isRunningSetup = true
        setupError = nil
        setupProgress = "Preparing setup..."

        Task {
            do {
                await MainActor.run {
                    setupProgress = "Running setup script..."
                }

                let scriptsPath = PathManager.scriptsPath
                let setupScript = URL(fileURLWithPath: (scriptsPath as NSString).deletingLastPathComponent)
                    .appendingPathComponent("setup.sh")

                // Check if setup.sh exists
                guard FileManager.default.fileExists(atPath: setupScript.path) else {
                    throw SetupError.scriptNotFound
                }

                let process = Process()
                process.executableURL = setupScript
                process.arguments = []

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

                if process.terminationStatus == 0 {
                    // Re-run checks
                    runSystemChecks()

                    await MainActor.run {
                        setupProgress = "Setup completed successfully!"
                        isRunningSetup = false
                    }
                } else {
                    await MainActor.run {
                        setupError = errorOutput.isEmpty ? output : errorOutput
                        setupProgress = "Setup failed"
                        isRunningSetup = false
                    }
                }
            } catch {
                await MainActor.run {
                    setupError = error.localizedDescription
                    setupProgress = "Setup failed"
                    isRunningSetup = false
                }
            }
        }
    }

    // MARK: - Vault Configuration

    func selectVaultFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Select your Obsidian vault folder"
        panel.prompt = "Select Vault"

        // Suggest common locations
        let homeDir = NSHomeDirectory()
        let possiblePaths = [
            "\(homeDir)/Documents/ObsidianVault",
            "\(homeDir)/Obsidian",
            "\(homeDir)/Documents/Obsidian"
        ]

        for path in possiblePaths {
            if FileManager.default.fileExists(atPath: path) {
                panel.directoryURL = URL(fileURLWithPath: path)
                break
            }
        }

        if panel.directoryURL == nil {
            panel.directoryURL = URL(fileURLWithPath: homeDir)
        }

        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else { return }

            Task { @MainActor in
                self?.selectedVaultPath = url
            }
        }
    }

    private func saveVaultConfiguration() {
        guard let vaultPath = selectedVaultPath else { return }

        let obsidianManager = ObsidianManager.shared
        obsidianManager.vaultPath = vaultPath
        obsidianManager.isVaultEnabled = true
        _ = obsidianManager.updatePythonScript()
    }

    // MARK: - Model Selection

    private func saveModelSelection() {
        UserDefaults.standard.set(selectedModel.rawValue, forKey: "selectedModel")
    }

    // MARK: - Models Info

    func modelSize(_ model: WhisperModel) -> String {
        switch model {
        case .tinyEn: return "74 MB"
        case .baseEn: return "141 MB"
        case .distilSmallEn: return "320 MB"
        case .distilMediumEn: return "755 MB"
        case .distilLargeV3: return "1.4 GB"
        }
    }

    func modelDescription(_ model: WhisperModel) -> String {
        switch model {
        case .tinyEn:
            return "Fastest option, good for real-time transcription. Lower accuracy."
        case .baseEn:
            return "Good balance of speed and accuracy. Recommended for most users."
        case .distilSmallEn:
            return "Better accuracy with reasonable speed. Good for note-taking."
        case .distilMediumEn:
            return "High accuracy, slower. Best for important content."
        case .distilLargeV3:
            return "Best quality, slowest. Only for the most demanding use cases."
        }
    }
}

// MARK: - Errors

enum SetupError: LocalizedError {
    case scriptNotFound

    var errorDescription: String? {
        switch self {
        case .scriptNotFound:
            return "setup.sh not found. Please ensure you're running from the correct directory."
        }
    }
}
