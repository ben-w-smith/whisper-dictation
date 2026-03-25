import SwiftUI

struct RefinementSettingsView: View {
    @State private var isRefinementEnabled = RefinementManager.shared.isRefinementEnabled
    @State private var baseURL = RefinementManager.shared.baseURL
    @State private var model = RefinementManager.shared.model
    @State private var customPrompt = RefinementManager.shared.customPrompt
    @State private var showAPIKeyField = false
    @State private var tempAPIKey = ""
    @State private var showingClearConfirmation = false
    @State private var apiKeyStatus = RefinementManager.shared.apiKeyStatus

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
                    Toggle("", isOn: $isRefinementEnabled)
                        .toggleStyle(.switch)
                        .onChange(of: isRefinementEnabled) { _, newValue in
                            RefinementManager.shared.isRefinementEnabled = newValue
                        }
                }
            }

            if isRefinementEnabled {
                Section("API Configuration") {
                    // Base URL
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Base URL:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("https://api.openai.com/v1", text: $baseURL)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))
                            .onChange(of: baseURL) { _, newValue in
                                RefinementManager.shared.baseURL = newValue
                            }
                    }

                    // Model
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Model:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("gpt-4o-mini", text: $model)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))
                            .onChange(of: model) { _, newValue in
                                RefinementManager.shared.model = newValue
                            }
                    }
                }

                Section("API Key") {
                    // API Key status and management
                    HStack {
                        Image(systemName: apiKeyStatus.iconName)
                            .foregroundStyle(apiKeyStatusColor)

                        Text(apiKeyStatus.displayText)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Spacer()

                        if apiKeyStatus == .set {
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
                                    _ = RefinementManager.shared.saveAPIKey(tempAPIKey)
                                    apiKeyStatus = RefinementManager.shared.apiKeyStatus
                                    showAPIKeyField = false
                                    tempAPIKey = ""
                                }
                                .buttonStyle(.borderedProminent)
                                .disabled(tempAPIKey.isEmpty && apiKeyStatus != .set)
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

                        TextEditor(text: $customPrompt)
                            .font(.system(.body, design: .monospaced))
                            .frame(minHeight: 100, maxHeight: 150)
                            .border(Color.secondary.opacity(0.2))
                            .onChange(of: customPrompt) { _, newValue in
                                RefinementManager.shared.customPrompt = newValue
                            }

                        Button("Reset to Default") {
                            customPrompt = RefinementManager.defaultPrompt
                            RefinementManager.shared.customPrompt = RefinementManager.defaultPrompt
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
                        Text("- Enter your API base URL (e.g., https://api.openai.com/v1)")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                        Text("- Enter the model name (e.g., gpt-4o-mini)")
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
                RefinementManager.shared.deleteAPIKey()
                apiKeyStatus = RefinementManager.shared.apiKeyStatus
            }
        } message: {
            Text("This will remove the stored API key from your keychain.")
        }
    }

    private var apiKeyStatusColor: Color {
        switch apiKeyStatus {
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
