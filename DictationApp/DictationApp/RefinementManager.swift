import Foundation
import Security

/// Manages AI refinement settings for post-transcription processing
@MainActor
class RefinementManager: ObservableObject {
    static let shared = RefinementManager()

    // MARK: - Types

    /// API patterns supported for refinement
    enum APIPattern: String, CaseIterable, Identifiable {
        case openAI = "openai"
        case anthropic = "anthropic"
        case gemini = "gemini"

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .openAI: return "OpenAI-compatible"
            case .anthropic: return "Anthropic/Claude"
            case .gemini: return "Google Gemini"
            }
        }

        var description: String {
            switch self {
            case .openAI: return "OpenAI, DeepSeek, Moonshot, Groq, Qwen, OpenRouter, Ollama, LM Studio"
            case .anthropic: return "Anthropic Claude API"
            case .gemini: return "Google Gemini API"
            }
        }

        var defaultBaseURL: String {
            switch self {
            case .openAI: return "https://api.openai.com/v1"
            case .anthropic: return "https://api.anthropic.com/v1"
            case .gemini: return "https://generativelanguage.googleapis.com/v1beta"
            }
        }

        var exampleModels: [String] {
            switch self {
            case .openAI: return ["gpt-4o-mini", "gpt-4o", "o4-mini"]
            case .anthropic: return ["claude-3-5-haiku-20241022", "claude-3-7-sonnet"]
            case .gemini: return ["gemini-2.5-flash", "gemini-2.5-pro"]
            }
        }
    }

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

    @Published var isRefinementEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isRefinementEnabled, forKey: "refinementEnabled")
        }
    }

    @Published var apiPattern: APIPattern {
        didSet {
            UserDefaults.standard.set(apiPattern.rawValue, forKey: "refinementAPIPattern")
            // Update base URL to pattern default if it was empty or matched previous pattern's default
            if baseURL.isEmpty || baseURL == oldValue.defaultBaseURL {
                baseURL = apiPattern.defaultBaseURL
            }
        }
    }

    @Published var baseURL: String {
        didSet {
            UserDefaults.standard.set(baseURL, forKey: "refinementBaseURL")
        }
    }

    @Published var model: String {
        didSet {
            UserDefaults.standard.set(model, forKey: "refinementModel")
        }
    }

    @Published var customPrompt: String {
        didSet {
            UserDefaults.standard.set(customPrompt, forKey: "refinementCustomPrompt")
        }
    }

    @Published var apiKeyStatus: APIKeyStatus = .notSet

    // MARK: - Constants

    private let keychainService = "com.whisper-dictation.refinement"
    private let keychainAccount = "api-key"

    static let defaultPrompt = """
Improve this speech-to-text transcription:
- Fix grammar and punctuation
- Remove filler words (um, uh, like, you know)
- Improve clarity while preserving meaning and tone
- Return ONLY the improved text, no explanations

Transcription:
"""

    // MARK: - Computed Properties

    /// Whether refinement is properly configured and ready to use
    var isReady: Bool {
        let hasValidAPIKey = apiKeyStatus == .set
        return isRefinementEnabled && hasValidAPIKey && !baseURL.isEmpty && !model.isEmpty
    }

    /// The API key from Keychain (returns nil if not set or error)
    var apiKey: String? {
        getAPIKey()
    }

    // MARK: - Initialization

    private init() {
        self.isRefinementEnabled = UserDefaults.standard.bool(forKey: "refinementEnabled")

        // Load API pattern, default to openAI
        if let savedPattern = UserDefaults.standard.string(forKey: "refinementAPIPattern"),
           let pattern = APIPattern(rawValue: savedPattern) {
            self.apiPattern = pattern
        } else {
            self.apiPattern = .openAI
        }

        self.baseURL = UserDefaults.standard.string(forKey: "refinementBaseURL") ?? ""
        self.model = UserDefaults.standard.string(forKey: "refinementModel") ?? ""
        self.customPrompt = UserDefaults.standard.string(forKey: "refinementCustomPrompt") ?? Self.defaultPrompt

        // Set default base URL if empty
        if baseURL.isEmpty {
            baseURL = apiPattern.defaultBaseURL
        }

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
            apiKeyStatus = .set
        } else {
            apiKeyStatus = .notSet
        }
    }

    // MARK: - Configuration Export

    /// Returns a dictionary with all configuration needed by the Python script
    func exportConfig() -> [String: String] {
        var config: [String: String] = [:]

        config["DICTATE_REFINEMENT_ENABLED"] = isRefinementEnabled ? "true" : "false"
        config["DICTATE_REFINEMENT_API_PATTERN"] = apiPattern.rawValue
        config["DICTATE_REFINEMENT_BASE_URL"] = baseURL
        config["DICTATE_REFINEMENT_MODEL"] = model

        if let key = apiKey {
            config["DICTATE_REFINEMENT_API_KEY"] = key
        }

        config["DICTATE_REFINEMENT_PROMPT"] = customPrompt

        return config
    }
}
