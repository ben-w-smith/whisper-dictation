import SwiftUI

struct RefinementSettingsView: View {
    @ObservedObject private var refinementManager = RefinementManager.shared
    @State private var showAPIKeyField = false
    @State private var tempAPIKey = ""
    @State private var showingClearConfirmation = false
    @State private var showProviderExamples = false

    // Provider examples loaded from providers.json
    @State private var providers: [ProviderInfo] = ProviderInfo.loadProviders()

    var body: some View {
        Form {
            Section {
                // Master enable toggle
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Enable AI Refinement")
                            .font(.headline)
                        Text("Post-process transcriptions with AI")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: $refinementManager.isRefinementEnabled)
                        .toggleStyle(.switch)
                }
            }

            if refinementManager.isRefinementEnabled {
                Section("API Pattern") {
                    Picker("Pattern", selection: $refinementManager.apiPattern) {
                        ForEach(RefinementManager.APIPattern.allCases) { pattern in
                            VStack(alignment: .leading) {
                                Text(pattern.displayName)
                                Text(pattern.description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .tag(pattern)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section("API Configuration") {
                    // Base URL
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Base URL:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField(refinementManager.apiPattern.defaultBaseURL, text: $refinementManager.baseURL)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))
                    }

                    // Model
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Model:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField(
                            "e.g., \(refinementManager.apiPattern.exampleModels.first ?? "model-name")",
                            text: $refinementManager.model
                        )
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                    }
                }

                // Popular Providers (collapsible)
                Section {
                    DisclosureGroup("Popular Providers", isExpanded: $showProviderExamples) {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(providersForCurrentPattern) { provider in
                                ProviderRowView(provider: provider) { selectedProvider in
                                    // Auto-fill base URL when clicked
                                    refinementManager.baseURL = selectedProvider.baseURL
                                    if let firstModel = selectedProvider.models.first {
                                        refinementManager.model = firstModel
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section("API Key") {
                    // API Key status and management
                    HStack {
                        Image(systemName: refinementManager.apiKeyStatus.iconName)
                            .foregroundStyle(apiKeyStatusColor)

                        Text(refinementManager.apiKeyStatus.displayText)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Spacer()

                        if refinementManager.apiKeyStatus == .set {
                            Button("Change") {
                                tempAPIKey = ""
                                showAPIKeyField = true
                            }
                            .buttonStyle(.bordered)

                            Button("Clear") {
                                showingClearConfirmation = true
                            }
                            .buttonStyle(.bordered)
                        } else {
                            Button("Set API Key") {
                                tempAPIKey = ""
                                showAPIKeyField = true
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }

                    // API Key input field (shown when editing)
                    if showAPIKeyField {
                        VStack(alignment: .leading, spacing: 8) {
                            SecureField("API Key", text: $tempAPIKey)
                                .textFieldStyle(.roundedBorder)

                            HStack {
                                Button("Cancel") {
                                    showAPIKeyField = false
                                    tempAPIKey = ""
                                }
                                .buttonStyle(.bordered)

                                Spacer()

                                Button("Save") {
                                    _ = refinementManager.saveAPIKey(tempAPIKey)
                                    showAPIKeyField = false
                                    tempAPIKey = ""
                                }
                                .buttonStyle(.borderedProminent)
                                .disabled(tempAPIKey.isEmpty && refinementManager.apiKeyStatus != .set)
                            }
                        }
                        .padding(.top, 4)
                    }
                }

                Section("Custom Prompt") {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("System Prompt:")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        TextEditor(text: $refinementManager.customPrompt)
                            .font(.system(.body, design: .monospaced))
                            .frame(minHeight: 100, maxHeight: 150)
                            .border(Color.secondary.opacity(0.2))

                        Button("Reset to Default") {
                            refinementManager.customPrompt = RefinementManager.defaultPrompt
                        }
                        .buttonStyle(.bordered)
                        .font(.caption)
                    }
                }

                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Setup Tips:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("- Select your API pattern above")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                        Text("- Click a provider in 'Popular Providers' to auto-fill URL")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                        Text("- Falls back to raw transcription if API fails")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .alert("Clear API Key?", isPresented: $showingClearConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Clear", role: .destructive) {
                refinementManager.deleteAPIKey()
            }
        } message: {
            Text("This will remove the stored API key from your keychain.")
        }
    }

    private var apiKeyStatusColor: Color {
        switch refinementManager.apiKeyStatus {
        case .notSet:
            return .secondary
        case .set:
            return .green
        case .error:
            return .red
        }
    }

    private var providersForCurrentPattern: [ProviderInfo] {
        providers.filter { $0.pattern == refinementManager.apiPattern.rawValue }
    }
}

// MARK: - Provider Info Model

struct ProviderInfo: Identifiable, Codable {
    let id = UUID()
    let name: String
    let pattern: String
    let baseURL: String
    let models: [String]
    let docsURL: String?
    let apiKeyURL: String?
    let local: Bool?
    let note: String?

    enum CodingKeys: String, CodingKey {
        case name, pattern, baseURL, models, docsURL, apiKeyURL, local, note
    }

    // Load providers from JSON file
    static func loadProviders() -> [ProviderInfo] {
        guard let url = Bundle.main.url(forResource: "providers", withExtension: "json") else {
            print("providers.json not found in bundle")
            return []
        }

        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            // Decode the top-level object and extract the providers array
            struct ProvidersFile: Codable {
                let providers: [ProviderInfo]
            }
            let file = try decoder.decode(ProvidersFile.self, from: data)
            return file.providers
        } catch {
            print("Error loading providers.json: \(error)")
            return []
        }
    }
}

// MARK: - Provider Row View

struct ProviderRowView: View {
    let provider: ProviderInfo
    let onSelect: (ProviderInfo) -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(provider.name)
                        .font(.subheadline)
                        .fontWeight(.medium)

                    if provider.local == true {
                        Text("(Local)")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                }

                Text(provider.baseURL)
                    .font(.caption)
                    .fontDesign(.monospaced)
                    .foregroundStyle(.secondary)

                if let note = provider.note {
                    Text(note)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            Button("Use") {
                onSelect(provider)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    RefinementSettingsView()
        .frame(width: 550, height: 700)
}
