import SwiftUI

struct RefinementSettingsView: View {
    @StateObject private var refinementManager = RefinementManager.shared
    @State private var showAPIKeyField = false
    @State private var tempAPIKey = ""
    @State private var showingClearConfirmation = false

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
                Section("Provider") {
                    // Provider selection grouped by category
                    Picker("Provider:", selection: $refinementManager.selectedProvider) {
                        ForEach(RefinementManager.AIProvider.allCases, id: \.self) { provider in
                            Text(provider.displayName).tag(provider)
                        }
                    }
                    .pickerStyle(.menu)

                    // Provider info
                    HStack(spacing: 6) {
                        Image(systemName: "info.circle")
                            .foregroundStyle(.blue)
                        Text(refinementManager.selectedProvider.isOpenAICompatible
                             ? "OpenAI-compatible API format"
                             : "Special API format - requires specific handling")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("API Configuration") {
                    // Base URL
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Base URL:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("Base URL", text: $refinementManager.baseURL)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))
                    }

                    // Model selection
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Model:")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        if let preset = refinementManager.providerPreset(for: refinementManager.selectedProvider),
                           !preset.popularModels.isEmpty {
                            Picker("", selection: $refinementManager.model) {
                                ForEach(preset.popularModels, id: \.self) { model in
                                    Text(model).tag(model)
                                }
                            }
                            .pickerStyle(.menu)
                        } else {
                            TextField("Model name", text: $refinementManager.model)
                                .textFieldStyle(.roundedBorder)
                        }
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
                            SecureField(refinementManager.selectedProvider.apiKeyPlaceholder, text: $tempAPIKey)
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

                    // Local provider note
                    if refinementManager.selectedProvider == .ollama || refinementManager.selectedProvider == .lmStudio {
                        HStack(spacing: 6) {
                            Image(systemName: "info.circle")
                                .foregroundStyle(.blue)
                            Text("Local providers typically don't require an API key")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
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
                        Text("Refinement Tips:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("- AI will clean up grammar and remove filler words")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                        Text("- Falls back to raw transcription if API fails")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                        Text("- gpt-4o-mini and deepseek-chat are fast and affordable")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                        Text("- Local models (Ollama/LM Studio) work offline but may be slower")
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
}

#Preview {
    RefinementSettingsView()
        .frame(width: 550, height: 650)
}
