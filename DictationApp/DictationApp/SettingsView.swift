import SwiftUI
import KeyboardShortcuts
import ServiceManagement

struct SettingsView: View {
    @EnvironmentObject var manager: TranscriptionManager

    var body: some View {
        TabView {
            GeneralSettingsView()
                .environmentObject(manager)
                .tabItem {
                    Label("General", systemImage: "gear")
                }

            HotkeySettingsView()
                .environmentObject(manager)
                .tabItem {
                    Label("Shortcuts", systemImage: "keyboard")
                }

            RefinementSettingsView()
                .tabItem {
                    Label("Refinement", systemImage: "sparkles")
                }

            SoundSettingsView()
                .tabItem {
                    Label("Sounds", systemImage: "speaker.wave.2")
                }
        }
        .frame(width: 550, height: 580)
    }
}

struct GeneralSettingsView: View {
    @EnvironmentObject var manager: TranscriptionManager
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @StateObject private var obsidianManager = ObsidianManager.shared

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
}

struct HotkeySettingsView: View {
    @EnvironmentObject var manager: TranscriptionManager
    @StateObject private var mouseButtonManager = MouseButtonManager.shared
    @FocusState private var isRecorderFocused: Bool

    var body: some View {
        Form {
            Section("Keyboard Shortcut") {
                HStack {
                    Text("Toggle Dictation:")
                        .font(.headline)
                    Spacer()
                    KeyboardShortcuts.Recorder(for: .toggleDictation) { shortcut in
                        if let shortcut = shortcut {
                            print("Shortcut set: \(shortcut)")
                        }
                    }
                    .focused($isRecorderFocused)
                    .onAppear {
                        // Auto-focus the recorder when view appears
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            isRecorderFocused = true
                        }
                    }
                }
            }

            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Tip: Click the box above and press your desired key combination.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("Default: Control + Space")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            Section("Mouse Button Shortcut") {
                VStack(alignment: .leading, spacing: 12) {
                    // Enable/Disable toggle
                    HStack {
                        Text("Enable Mouse Button Toggle")
                            .font(.headline)
                        Spacer()
                        Toggle("", isOn: $mouseButtonManager.isEnabled)
                            .toggleStyle(.switch)
                    }

                    // Mouse button configuration
                    if mouseButtonManager.isEnabled {
                        Divider()

                        HStack {
                            Text("Mouse Button:")
                                .font(.subheadline)
                            Spacer()

                            if mouseButtonManager.isRecordingMouseButton {
                                HStack(spacing: 8) {
                                    ProgressView()
                                        .scaleEffect(0.7)
                                    Text("Press a mouse button...")
                                        .foregroundStyle(.orange)
                                        .font(.subheadline)
                                }
                            } else if let config = mouseButtonManager.mouseButtonConfig {
                                HStack(spacing: 8) {
                                    Text(config.displayName)
                                        .font(.subheadline)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.accentColor.opacity(0.2))
                                        .cornerRadius(4)

                                    Button("Change") {
                                        mouseButtonManager.startRecordingMouseButton()
                                    }
                                    .buttonStyle(.bordered)

                                    Button("Clear") {
                                        mouseButtonManager.mouseButtonConfig = nil
                                    }
                                    .buttonStyle(.bordered)
                                }
                            } else {
                                Button("Record Mouse Button") {
                                    mouseButtonManager.startRecordingMouseButton()
                                }
                                .buttonStyle(.bordered)
                            }
                        }

                        Divider()

                        // Status and permission info
                        if !MouseButtonManager.checkAccessibilityPermission() {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.orange)
                                Text("Accessibility permission required for mouse button shortcuts")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                Button("Grant Permission") {
                                    MouseButtonManager.requestAccessibilityPermission()
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
                .padding(.vertical, 4)
            }

            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Mouse Button Tips:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("- Buttons 4 and 5 are typically the side buttons on gaming mice")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Text("- The keyboard shortcut and mouse button can be used together")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Text("- Requires Accessibility permission to detect global mouse clicks")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .onChange(of: mouseButtonManager.isRecordingMouseButton) { _, isRecording in
            // If recording was cancelled externally, ensure we're in sync
            if !isRecording {
                // Recording finished
            }
        }
    }
}

// MARK: - Mouse Button Recorder View (Alternative standalone component)
struct MouseButtonRecorder: View {
    @StateObject private var mouseButtonManager = MouseButtonManager.shared
    let onButtonRecorded: ((MouseButtonConfig) -> Void)?

    init(onButtonRecorded: ((MouseButtonConfig) -> Void)? = nil) {
        self.onButtonRecorded = onButtonRecorded
    }

    var body: some View {
        HStack {
            if mouseButtonManager.isRecordingMouseButton {
                ProgressView()
                    .scaleEffect(0.7)
                Text("Press a mouse button...")
                    .foregroundStyle(.orange)
            } else if let config = mouseButtonManager.mouseButtonConfig {
                Text(config.displayName)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.accentColor.opacity(0.2))
                    .cornerRadius(6)
            } else {
                Text("No button set")
                    .foregroundStyle(.secondary)
            }
        }
        .onTapGesture {
            if !mouseButtonManager.isRecordingMouseButton {
                mouseButtonManager.startRecordingMouseButton()
            }
        }
    }
}

// MARK: - Sound Settings View

struct SoundSettingsView: View {
    @StateObject private var soundManager = SoundManager.shared

    var body: some View {
        Form {
            Section {
                // Master enable toggle
                HStack {
                    Text("Enable Sound Effects")
                    Spacer()
                    Toggle("", isOn: $soundManager.soundsEnabled)
                        .toggleStyle(.switch)
                }
            }

            if soundManager.soundsEnabled {
                Section("Recording Sounds") {
                    SoundPickerRow(
                        label: "Recording Started",
                        selection: Binding(
                            get: { soundManager.startRecordingSound },
                            set: { soundManager.startRecordingSound = $0 }
                        ),
                        onPreview: { soundManager.previewSound($0) }
                    )

                    SoundPickerRow(
                        label: "Recording Stopped",
                        selection: Binding(
                            get: { soundManager.stopRecordingSound },
                            set: { soundManager.stopRecordingSound = $0 }
                        ),
                        onPreview: { soundManager.previewSound($0) }
                    )
                }

                Section("Completion Sounds") {
                    SoundPickerRow(
                        label: "Transcription Ready",
                        selection: Binding(
                            get: { soundManager.transcriptionReadySound },
                            set: { soundManager.transcriptionReadySound = $0 }
                        ),
                        onPreview: { soundManager.previewSound($0) }
                    )
                }

                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Volume")
                            .font(.subheadline)

                        HStack(spacing: 12) {
                            Image(systemName: "speaker.fill")
                                .foregroundStyle(.secondary)

                            Slider(value: $soundManager.soundVolume, in: 0...1)
                                .frame(maxWidth: .infinity)

                            Image(systemName: "speaker.wave.3.fill")
                                .foregroundStyle(.secondary)

                            Text("\(Int(soundManager.soundVolume * 100))%")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(width: 40, alignment: .trailing)
                        }

                        Button("Test Volume") {
                            soundManager.previewSound(.hero)
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }

            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Sound Effects Tips:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("- Sounds help you know when dictation has started/stopped")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Text("- \"Glass\" is a pleasant notification sound for starting")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Text("- \"Hero\" works well for completion notifications")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Text("- Select \"None\" to disable a specific sound")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Sound Picker Row

struct SoundPickerRow: View {
    let label: String
    @Binding var selection: SoundEffect
    let onPreview: (SoundEffect) -> Void

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)

            Spacer()

            Picker("", selection: $selection) {
                ForEach(SoundEffect.allCases) { sound in
                    Text(sound.displayName).tag(sound)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 120)

            Button(action: {
                onPreview(selection)
            }) {
                Image(systemName: "play.circle")
                    .font(.title3)
            }
            .buttonStyle(.borderless)
            .disabled(selection == .none)
            .opacity(selection == .none ? 0.3 : 1)
            .help("Preview sound")
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(TranscriptionManager())
}
