import SwiftUI

struct RefinementSettingsView: View {
    @ObservedObject private var refinementManager = RefinementManager.shared
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
                Section("API Configuration") {
                    // Base URL
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Base URL:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("https://api.openai.com/v1", text: $refinementManager.baseURL)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))
                    }

                    // Model
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Model:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("gpt-4o-mini", text: $refinementManager.model)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))
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
