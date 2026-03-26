import SwiftUI

struct TranscriptionSettingsView: View {
    @State private var selectedProvider = GeminiTranscriptionManager.shared.selectedProvider
    @State private var autoFallback = GeminiTranscriptionManager.shared.autoFallback
    @State private var showLatency = GeminiTranscriptionManager.shared.showLatency
    @State private var showAPIKeyField = false
    @State private var tempAPIKey = ""
    @State private var showingClearConfirmation = false
    @State private var apiKeyStatus = GeminiTranscriptionManager.shared.apiKeyStatus

    var body: some View {
        Form {
            Section {
                // Provider selection
                Picker("Transcription Provider", selection: $selectedProvider) {
                    ForEach(TranscriptionProvider.allCases) { provider in
                        HStack {
                            Image(systemName: provider.iconName)
                            VStack(alignment: .leading) {
                                Text(provider.displayName)
                                Text(provider.description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .tag(provider)
                    }
                }
                .pickerStyle(.radioGroup)
                .onChange(of: selectedProvider) { _, newValue in
                    GeminiTranscriptionManager.shared.selectedProvider = newValue
                }
            } header: {
                Text("Transcription Provider")
            } footer: {
                Text("Local Whisper works offline. Gemini requires internet but may provide better accuracy.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if selectedProvider.isRemote {
                Section("Gemini Configuration") {
                    // API Key management
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
                                    if GeminiTranscriptionManager.shared.saveAPIKey(tempAPIKey) {
                                        apiKeyStatus = GeminiTranscriptionManager.shared.apiKeyStatus
                                        showAPIKeyField = false
                                        tempAPIKey = ""
                                    } else {
                                        apiKeyStatus = GeminiTranscriptionManager.shared.apiKeyStatus
                                    }
                                }
                                .buttonStyle(.borderedProminent)
                                .disabled(tempAPIKey.isEmpty && apiKeyStatus != .set)
                            }
                        }
                        .padding(.top, 4)
                    }

                    // Get API key link
                    Link("Get API Key from Google AI Studio", destination: URL(string: "https://aistudio.google.com/apikey")!)
                        .font(.subheadline)

                    // Rate limit info
                    Label("Free tier: 1,500 requests/day, 15 requests/minute", systemImage: "info.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Privacy Notice") {
                    VStack(alignment: .leading, spacing: 8) {
                        Label {
                            Text("Audio is sent to Google servers for transcription")
                        } icon: {
                            Image(systemName: "network")
                        }

                        Label {
                            Text("Your API key is stored securely in macOS Keychain")
                        } icon: {
                            Image(systemName: "lock.shield")
                        }

                        Link("Google AI Privacy Policy", destination: URL(string: "https://ai.google.dev/privacy")!)
                            .font(.caption)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Section {
                    Toggle("Auto-fallback to local if remote fails", isOn: $autoFallback)
                        .onChange(of: autoFallback) { _, newValue in
                            GeminiTranscriptionManager.shared.autoFallback = newValue
                        }

                    Toggle("Show transcription latency", isOn: $showLatency)
                        .onChange(of: showLatency) { _, newValue in
                            GeminiTranscriptionManager.shared.showLatency = newValue
                        }
                } header: {
                    Text("Options")
                } footer: {
                    Text("When auto-fallback is enabled, the app will automatically use local Whisper if Gemini is unavailable.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Tips:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("• Local Whisper is fastest for short recordings")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Text("• Gemini Flash Lite is cost-efficient for high volume")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Text("• Gemini Flash provides best accuracy for complex audio")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Text("• Auto-fallback ensures you always get a transcription")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .alert("Clear API Key?", isPresented: $showingClearConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Clear", role: .destructive) {
                GeminiTranscriptionManager.shared.deleteAPIKey()
                apiKeyStatus = GeminiTranscriptionManager.shared.apiKeyStatus
            }
        } message: {
            Text("This will remove the stored Gemini API key from your keychain.")
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
    TranscriptionSettingsView()
        .frame(width: 550, height: 600)
}
