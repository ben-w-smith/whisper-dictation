import Foundation
import Security

/// Manages AI refinement settings for post-transcription processing
@MainActor
class RefinementManager: ObservableObject {
    static let shared = RefinementManager()

    // MARK: - Published State

    @Published var isRefinementEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isRefinementEnabled, forKey: "refinementEnabled")
        }
    }

    @Published var selectedProvider: AIProvider {
        didSet {
            UserDefaults.standard.set(selectedProvider.rawValue, forKey: "refinementProvider")
            // Auto-fill base URL and default model when provider changes
            if let preset = providerPreset(for: selectedProvider) {
                baseURL = preset.baseURL
                model = preset.defaultModel
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

        var iconColor: String {
            switch self {
            case .notSet:
                return "secondary"
            case .set:
                return "green"
            case .error:
                return "red"
            }
        }
    }

    // MARK: - AI Provider Types

    enum AIProvider: String, CaseIterable, Identifiable {
        // OpenAI-Compatible APIs
        case openAI = "openai"
        case deepSeek = "deepseek"
        case moonshot = "moonshot"
        case zhipu = "zhipu"
        case qwen = "qwen"
        case groq = "groq"
        case together = "together"

        // Local/Self-hosted (OpenAI-compatible)
        case ollama = "ollama"
        case lmStudio = "lmstudio"

        // Non-OpenAI APIs (require special handling)
        case anthropic = "anthropic"
        case googleGemini = "google_gemini"

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .openAI: return "OpenAI"
            case .deepSeek: return "DeepSeek"
            case .moonshot: return "Moonshot AI (Kimi)"
            case .zhipu: return "Zhipu AI (GLM)"
            case .qwen: return "Qwen (Alibaba)"
            case .groq: return "Groq"
            case .together: return "Together AI"
            case .ollama: return "Ollama (Local)"
            case .lmStudio: return "LM Studio (Local)"
            case .anthropic: return "Anthropic (Claude)"
            case .googleGemini: return "Google Gemini"
            }
        }

        var category: String {
            switch self {
            case .openAI, .deepSeek, .moonshot, .zhipu, .qwen, .groq, .together:
                return "OpenAI-Compatible"
            case .ollama, .lmStudio:
                return "Local/Self-hosted"
            case .anthropic, .googleGemini:
                return "Special API"
            }
        }

        /// Whether this provider uses OpenAI-compatible API format
        var isOpenAICompatible: Bool {
            switch self {
            case .openAI, .deepSeek, .moonshot, .zhipu, .qwen, .groq, .together, .ollama, .lmStudio:
                return true
            case .anthropic, .googleGemini:
                return false
            }
        }

        var apiKeyPlaceholder: String {
            switch self {
            case .openAI: return "sk-..."
            case .deepSeek: return "sk-..."
            case .moonshot: return "sk-..."
            case .zhipu: return "..."
            case .qwen: return "sk-..."
            case .groq: return "gsk_..."
            case .together: return "..."
            case .ollama, .lmStudio: return "Optional for local"
            case .anthropic: return "sk-ant-..."
            case .googleGemini: return "AIza..."
            }
        }
    }

    // MARK: - Provider Presets

    struct ProviderPreset {
        let name: String
        let baseURL: String
        let defaultModel: String
        let popularModels: [String]
    }

    static let providerPresets: [AIProvider: ProviderPreset] = [
        .openAI: ProviderPreset(
            name: "OpenAI",
            baseURL: "https://api.openai.com/v1",
            defaultModel: "gpt-4o-mini",
            popularModels: ["gpt-4o-mini", "gpt-4o", "gpt-4-turbo", "gpt-3.5-turbo"]
        ),
        .deepSeek: ProviderPreset(
            name: "DeepSeek",
            baseURL: "https://api.deepseek.com/v1",
            defaultModel: "deepseek-chat",
            popularModels: ["deepseek-chat", "deepseek-coder"]
        ),
        .moonshot: ProviderPreset(
            name: "Moonshot AI (Kimi)",
            baseURL: "https://api.moonshot.cn/v1",
            defaultModel: "moonshot-v1-8k",
            popularModels: ["moonshot-v1-8k", "moonshot-v1-32k", "moonshot-v1-128k"]
        ),
        .zhipu: ProviderPreset(
            name: "Zhipu AI (GLM)",
            baseURL: "https://open.bigmodel.cn/api/paas/v4",
            defaultModel: "glm-4-flash",
            popularModels: ["glm-4-flash", "glm-4", "glm-4-plus", "glm-4-air"]
        ),
        .qwen: ProviderPreset(
            name: "Qwen (Alibaba)",
            baseURL: "https://dashscope.aliyuncs.com/compatible-mode/v1",
            defaultModel: "qwen-turbo",
            popularModels: ["qwen-turbo", "qwen-plus", "qwen-max", "qwen-long"]
        ),
        .groq: ProviderPreset(
            name: "Groq",
            baseURL: "https://api.groq.com/openai/v1",
            defaultModel: "llama-3.3-70b-versatile",
            popularModels: ["llama-3.3-70b-versatile", "llama-3.1-8b-instant", "mixtral-8x7b-32768"]
        ),
        .together: ProviderPreset(
            name: "Together AI",
            baseURL: "https://api.together.xyz/v1",
            defaultModel: "meta-llama/Llama-3.3-70B-Instruct-Turbo",
            popularModels: ["meta-llama/Llama-3.3-70B-Instruct-Turbo", "mistralai/Mixtral-8x7B-Instruct-v0.1"]
        ),
        .ollama: ProviderPreset(
            name: "Ollama (Local)",
            baseURL: "http://localhost:11434/v1",
            defaultModel: "llama3.2",
            popularModels: ["llama3.2", "llama3.1", "mistral", "qwen2.5", "gemma2"]
        ),
        .lmStudio: ProviderPreset(
            name: "LM Studio (Local)",
            baseURL: "http://localhost:1234/v1",
            defaultModel: "local-model",
            popularModels: ["local-model"]
        ),
        .anthropic: ProviderPreset(
            name: "Anthropic (Claude)",
            baseURL: "https://api.anthropic.com/v1",
            defaultModel: "claude-3-5-haiku-latest",
            popularModels: ["claude-3-5-haiku-latest", "claude-3-5-sonnet-latest", "claude-3-opus-latest"]
        ),
        .googleGemini: ProviderPreset(
            name: "Google Gemini",
            baseURL: "https://generativelanguage.googleapis.com/v1beta",
            defaultModel: "gemini-2.0-flash-lite",
            popularModels: ["gemini-2.0-flash-lite", "gemini-2.0-flash", "gemini-1.5-flash", "gemini-1.5-pro"]
        )
    ]

    func providerPreset(for provider: AIProvider) -> ProviderPreset? {
        Self.providerPresets[provider]
    }

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
        // Local providers don't need API key
        let needsAPIKey = selectedProvider != .ollama && selectedProvider != .lmStudio
        let hasValidAPIKey = apiKeyStatus == .set || !needsAPIKey
        return isRefinementEnabled && hasValidAPIKey && !baseURL.isEmpty && !model.isEmpty
    }

    /// The API key from Keychain (returns nil if not set or error)
    var apiKey: String? {
        getAPIKey()
    }

    // MARK: - Initialization

    private init() {
        // Load saved settings - initialize all stored properties before using self
        self.isRefinementEnabled = UserDefaults.standard.bool(forKey: "refinementEnabled")

        // Determine provider first
        let provider: AIProvider
        if let savedProvider = UserDefaults.standard.string(forKey: "refinementProvider"),
           let loadedProvider = AIProvider(rawValue: savedProvider) {
            provider = loadedProvider
        } else {
            provider = .openAI
        }
        self.selectedProvider = provider

        // Get preset for the provider (use static dictionary to avoid self issues)
        let preset = Self.providerPresets[provider]

        // Load base URL - if not set, use preset default
        if let savedBaseURL = UserDefaults.standard.string(forKey: "refinementBaseURL"), !savedBaseURL.isEmpty {
            self.baseURL = savedBaseURL
        } else if let preset = preset {
            self.baseURL = preset.baseURL
        } else {
            self.baseURL = "https://api.openai.com/v1"
        }

        // Load model - if not set, use preset default
        if let savedModel = UserDefaults.standard.string(forKey: "refinementModel"), !savedModel.isEmpty {
            self.model = savedModel
        } else if let preset = preset {
            self.model = preset.defaultModel
        } else {
            self.model = "gpt-4o-mini"
        }

        self.customPrompt = UserDefaults.standard.string(forKey: "refinementCustomPrompt") ?? Self.defaultPrompt

        // Check API key status (now all stored properties are initialized)
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
        config["DICTATE_REFINEMENT_PROVIDER"] = selectedProvider.rawValue
        config["DICTATE_REFINEMENT_BASE_URL"] = baseURL
        config["DICTATE_REFINEMENT_MODEL"] = model
        config["DICTATE_REFINEMENT_IS_OPENAI_COMPATIBLE"] = selectedProvider.isOpenAICompatible ? "true" : "false"

        if let key = apiKey {
            config["DICTATE_REFINEMENT_API_KEY"] = key
        }

        config["DICTATE_REFINEMENT_PROMPT"] = customPrompt

        return config
    }

    // MARK: - Apply Preset

    func applyPreset(_ provider: AIProvider) {
        selectedProvider = provider
        if let preset = providerPreset(for: provider) {
            baseURL = preset.baseURL
            model = preset.defaultModel
        }
    }
}
