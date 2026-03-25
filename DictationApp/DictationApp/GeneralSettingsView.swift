import SwiftUI
import ServiceManagement

struct GeneralSettingsView: View {
    @EnvironmentObject var manager: TranscriptionManager
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @ObservedObject private var obsidianManager = ObsidianManager.shared
    @ObservedObject private var autoPasteManager = AutoPasteManager.shared

    var body: some View {
        Form {
            Section("Transcription") {
                Picker("Default Model:", selection: $manager.selectedModel) {
                    ForEach(WhisperModel.allCases) { model in
                        Text(model.displayName).tag(model)
                    }
                }
                .onChange(of: manager.selectedModel) { _, newValue in
                    manager.setSelectedModel(newValue)
                }
            }

            Section("Auto-Paste") {
                HStack {
                    Text("Auto-paste after transcription")
                    Spacer()
                    Toggle("", isOn: $autoPasteManager.isEnabled)
                        .toggleStyle(.switch)
                }

                if autoPasteManager.isEnabled {
                    HStack {
                        Text("Paste delay:")
                        Slider(value: $autoPasteManager.pasteDelay, in: 0...2, step: 0.1)
                            .frame(maxWidth: 150)
                        Text("\(String(format: "%.1f", autoPasteManager.pasteDelay))s")
                            .foregroundStyle(.secondary)
                            .frame(width: 35, alignment: .trailing)
                    }

                    if !autoPasteManager.hasAccessibilityPermission {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                            Text("Accessibility permission required for auto-paste")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Button("Grant Permission") {
                                autoPasteManager.requestPermissionWithMonitoring()
                            }
                            .buttonStyle(.bordered)
                        }
                    } else {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text("Accessibility permission granted")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Section("Storage") {
                // Enable/Disable toggle
                HStack {
                    Text("Save to Obsidian Vault")
                    Spacer()
                    Toggle("", isOn: $obsidianManager.isVaultEnabled)
                        .toggleStyle(.switch)
                        .onChange(of: obsidianManager.isVaultEnabled) { _, newValue in
                            if newValue {
                                obsidianManager.validateVault()
                                if obsidianManager.validationStatus == .valid {
                                    _ = obsidianManager.updatePythonScript()
                                }
                            }
                        }
                }

                // Vault configuration (shown when enabled)
                if obsidianManager.isVaultEnabled {
                    Divider()

                    // Folder selection and path display
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            if let path = obsidianManager.vaultPath {
                                // Show current path
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Vault Path:")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text(path.path)
                                        .font(.system(.caption, design: .monospaced))
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                }

                                Spacer()

                                Button("Change...") {
                                    obsidianManager.selectVaultFolder()
                                }
                                .buttonStyle(.bordered)
                            } else {
                                Button("Select Vault Folder") {
                                    obsidianManager.selectVaultFolder()
                                }
                                .buttonStyle(.borderedProminent)
                            }
                        }

                        // Status indicator
                        HStack(spacing: 6) {
                            Image(systemName: obsidianManager.validationStatus.iconName)
                                .foregroundStyle(statusColor(for: obsidianManager.validationStatus))

                            Text(obsidianManager.validationStatus.displayText)
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            if obsidianManager.validationStatus == .invalid("") {
                                // Hidden, we use the message from the enum
                            }
                        }

                        // Validation error message
                        if case .invalid(let message) = obsidianManager.validationStatus {
                            Text(message)
                                .font(.caption)
                                .foregroundStyle(.red)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            Section("Application") {
                HStack {
                    Text("Launch at Login")
                    Spacer()
                    Toggle("", isOn: $launchAtLogin)
                        .toggleStyle(.switch)
                        .onChange(of: launchAtLogin) { _, newValue in
                            setLaunchAtLogin(enabled: newValue)
                        }
                }
            }

            Section {
                HStack {
                    Spacer()
                    VStack(spacing: 4) {
                        Text(appVersion)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("Dictation Beta")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    Spacer()
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .onChange(of: obsidianManager.vaultPath) { _, _ in
            // Update Python script when vault path changes
            if obsidianManager.isVaultEnabled && obsidianManager.validationStatus == .valid {
                _ = obsidianManager.updatePythonScript()
            }
        }
    }

    private func statusColor(for status: ObsidianManager.VaultStatus) -> Color {
        switch status {
        case .notConfigured:
            return .secondary
        case .valid:
            return .green
        case .invalid:
            return .red
        case .checking:
            return .orange
        }
    }

    private func setLaunchAtLogin(enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("Failed to set launch at login: \(error)")
        }
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "Version \(version) (\(build))"
    }
}
