import SwiftUI
import KeyboardShortcuts

struct HotkeySettingsView: View {
    @EnvironmentObject var manager: TranscriptionManager
    @ObservedObject private var mouseButtonManager = MouseButtonManager.shared
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
                        if !mouseButtonManager.hasAccessibilityPermission {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.orange)
                                Text("Accessibility permission required for mouse button shortcuts")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                Button("Grant Permission") {
                                    mouseButtonManager.requestPermissionWithMonitoring()
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
