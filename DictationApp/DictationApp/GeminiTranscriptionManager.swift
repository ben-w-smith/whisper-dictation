import Foundation
import Security

/// Manages remote transcription settings for Gemini API
@MainActor
class GeminiTranscriptionManager: ObservableObject {
    static let shared = GeminiTranscriptionManager()

    // MARK: - Types

    enum APIKeyStatus: Equatable {
        case notSet
        case set
        case error(String)

        var displayText: String {
            switch self {
            case .notSet:
                return "No API key set"
            case .set:
                return "API key configured"
            case .error(let message):
                return message
            }
        }

        var iconName: String {
            switch self {
            case .notSet:
                return "key"
            case .set:
                return "checkmark.circle.fill"
            case .error:
                return "exclamationmark.triangle.fill"
            }
        }
    }

    // MARK: - Published State

    @Published var selectedProvider: TranscriptionProvider {
        didSet {
            UserDefaults.standard.set(selectedProvider.rawValue, forKey: "transcriptionProvider")
        }
    }

    @Published var apiKeyStatus: APIKeyStatus = .notSet

    @Published var autoFallback: Bool {
        didSet {
            UserDefaults.standard.set(autoFallback, forKey: "transcriptionAutoFallback")
        }
    }

    @Published var showLatency: Bool {
        didSet {
            UserDefaults.standard.set(showLatency, forKey: "transcriptionShowLatency")
        }
    }

    // MARK: - Constants

    private let keychainService = "com.whisper-dictation.gemini-transcription"
    private let keychainAccount = "api-key"

    // MARK: - Computed Properties

    /// Whether remote transcription is properly configured and ready to use
    var isReady: Bool {
        guard selectedProvider.isRemote else { return true }  // Local is always ready
        return apiKeyStatus == .set
    }

    /// The API key from Keychain (returns nil if not set or error)
    var apiKey: String? {
        getAPIKey()
    }

    // MARK: - Initialization

    private init() {
        // Load selected provider, default to local
        if let savedProvider = UserDefaults.standard.string(forKey: "transcriptionProvider"),
           let provider = TranscriptionProvider(rawValue: savedProvider) {
            self.selectedProvider = provider
        } else {
            self.selectedProvider = .local
        }

        // Load auto-fallback setting
        self.autoFallback = UserDefaults.standard.object(forKey: "transcriptionAutoFallback") as? Bool ?? true

        // Load show latency setting
        self.showLatency = UserDefaults.standard.object(forKey: "transcriptionShowLatency") as? Bool ?? true

        refreshAPIKeyStatus()
    }

    // MARK: - API Key Management (Keychain)

    private func getAPIKey() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let key = String(data: data, encoding: .utf8) else {
            return nil
        }

        return key
    }

    func saveAPIKey(_ key: String) -> Bool {
        // First, try to delete any existing key
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        // If key is empty, we're just clearing it
        guard !key.isEmpty else {
            refreshAPIKeyStatus()
            return true
        }

        // Validate key format (Gemini keys start with "AIza" and are ~39 chars)
        if !key.hasPrefix("AIza") || key.count < 35 {
            apiKeyStatus = .error("Invalid API key format. Gemini keys start with 'AIza'")
            return false
        }

        // Add the new key
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecValueData as String: key.data(using: .utf8)!,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]

        let status = SecItemAdd(addQuery as CFDictionary, nil)
        let success = status == errSecSuccess

        refreshAPIKeyStatus()
        return success
    }

    func deleteAPIKey() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount
        ]
        SecItemDelete(query as CFDictionary)
        refreshAPIKeyStatus()
    }

    func refreshAPIKeyStatus() {
        if let key = getAPIKey(), !key.isEmpty {
            // Validate key format
            if key.hasPrefix("AIza") && key.count >= 35 {
                apiKeyStatus = .set
            } else {
                apiKeyStatus = .error("Invalid API key format")
            }
        } else {
            apiKeyStatus = .notSet
        }
    }

    // MARK: - Configuration Export

    /// Returns a dictionary with all configuration needed by the Python script
    func exportConfig() -> [String: String] {
        var config: [String: String] = [:]

        config["DICTATE_TRANSCRIPTION_PROVIDER"] = selectedProvider.rawValue
        config["DICTATE_TRANSCRIPTION_AUTO_FALLBACK"] = autoFallback ? "true" : "false"

        if selectedProvider.isRemote, let key = apiKey {
            config["DICTATE_TRANSCRIPTION_API_KEY"] = key
        }

        return config
    }
}
