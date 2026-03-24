import Foundation
import AppKit

/// Manages Obsidian vault connection and path configuration
@MainActor
class ObsidianManager: ObservableObject {
    static let shared = ObsidianManager()

    // MARK: - Published State

    @Published var isVaultEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isVaultEnabled, forKey: "obsidianVaultEnabled")
        }
    }

    @Published var vaultPath: URL? {
        didSet {
            if let path = vaultPath {
                UserDefaults.standard.set(path.path, forKey: "obsidianVaultPath")
                validateVault()
            } else {
                UserDefaults.standard.removeObject(forKey: "obsidianVaultPath")
                validationStatus = .notConfigured
            }
        }
    }

    @Published var validationStatus: VaultStatus = .notConfigured

    // MARK: - Types

    enum VaultStatus: Equatable {
        case notConfigured
        case valid
        case invalid(String)
        case checking

        var displayText: String {
            switch self {
            case .notConfigured:
                return "Not configured"
            case .valid:
                return "Connected"
            case .invalid(let message):
                return message
            case .checking:
                return "Checking..."
            }
        }

        var iconName: String {
            switch self {
            case .notConfigured:
                return "folder.badge.questionmark"
            case .valid:
                return "checkmark.circle.fill"
            case .invalid:
                return "exclamationmark.triangle.fill"
            case .checking:
                return "arrow.trianglehead.clockwise.rotate 90°"
            }
        }

        var iconColor: String {
            switch self {
            case .notConfigured:
                return "secondary"
            case .valid:
                return "green"
            case .invalid:
                return "red"
            case .checking:
                return "orange"
            }
        }
    }

    // MARK: - Computed Properties

    /// The full path to the transcriptions directory within the vault
    var transcriptionsPath: String? {
        guard isVaultEnabled, let vault = vaultPath else { return nil }
        return vault.appendingPathComponent("transcriptions").path
    }

    /// Whether the vault is properly configured and valid
    var isReady: Bool {
        isVaultEnabled && vaultPath != nil && validationStatus == .valid
    }

    // MARK: - Initialization

    private init() {
        // Load saved settings
        self.isVaultEnabled = UserDefaults.standard.bool(forKey: "obsidianVaultEnabled")

        if let savedPath = UserDefaults.standard.string(forKey: "obsidianVaultPath") {
            self.vaultPath = URL(fileURLWithPath: savedPath)
            validateVault()
        } else {
            self.validationStatus = .notConfigured
        }
    }

    // MARK: - Vault Selection

    /// Opens a folder picker dialog to select the Obsidian vault
    func selectVaultFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Select your Obsidian vault folder"
        panel.prompt = "Select Vault"

        // Start in user's home directory
        panel.directoryURL = URL(fileURLWithPath: NSHomeDirectory())

        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else { return }

            Task { @MainActor in
                self?.vaultPath = url
            }
        }
    }

    /// Clears the current vault configuration
    func clearVault() {
        vaultPath = nil
        validationStatus = .notConfigured
    }

    // MARK: - Validation

    /// Validates that the selected folder is a valid Obsidian vault
    func validateVault() {
        guard let path = vaultPath else {
            validationStatus = .notConfigured
            return
        }

        validationStatus = .checking

        // Check if the path exists
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            validationStatus = .invalid("Folder does not exist")
            return
        }

        // Check for .obsidian folder (indicates a valid Obsidian vault)
        let obsidianFolder = path.appendingPathComponent(".obsidian")
        guard FileManager.default.fileExists(atPath: obsidianFolder.path) else {
            validationStatus = .invalid("Not an Obsidian vault (missing .obsidian folder)")
            return
        }

        // Check if we can create the transcriptions directory
        let transcriptionsDir = path.appendingPathComponent("transcriptions")
        do {
            // Try to create it if it doesn't exist
            if !FileManager.default.fileExists(atPath: transcriptionsDir.path) {
                try FileManager.default.createDirectory(at: transcriptionsDir, withIntermediateDirectories: true)
            }

            // Verify we can write to it
            let testFile = transcriptionsDir.appendingPathComponent(".write-test")
            try "test".write(to: testFile, atomically: true, encoding: .utf8)
            try FileManager.default.removeItem(at: testFile)

            validationStatus = .valid
        } catch {
            validationStatus = .invalid("Cannot write to vault: \(error.localizedDescription)")
        }
    }

    // MARK: - Python Script Updates

    /// Updates the dictate-toggle.py script with the configured vault path
    /// Returns true if successful, false otherwise
    func updatePythonScript() -> Bool {
        guard let vaultPath = vaultPath else { return false }

        let scriptsPath = "/Users/bensmith/whisper-dictation"
        let scriptPath = "\(scriptsPath)/dictate-toggle.py"

        guard var content = try? String(contentsOfFile: scriptPath, encoding: .utf8) else {
            print("Could not read dictate-toggle.py")
            return false
        }

        // Update the OBSIDIAN_VAULT path
        let pattern = #"OBSIDIAN_VAULT = Path\("[^"]+"\)"#
        let replacement = #"OBSIDIAN_VAULT = Path("\#(vaultPath.path)")"#

        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            print("Could not create regex for OBSIDIAN_VAULT")
            return false
        }

        let range = NSRange(content.startIndex..., in: content)
        content = regex.stringByReplacingMatches(in: content, options: [], range: range, withTemplate: replacement)

        do {
            try content.write(toFile: scriptPath, atomically: true, encoding: .utf8)
            print("Updated OBSIDIAN_VAULT to: \(vaultPath.path)")
            return true
        } catch {
            print("Failed to write updated script: \(error)")
            return false
        }
    }
}
