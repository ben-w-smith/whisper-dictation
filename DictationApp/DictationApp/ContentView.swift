import SwiftUI

struct ContentView: View {
    @EnvironmentObject var manager: TranscriptionManager
    @Environment(\.openSettings) var openSettings

    var body: some View {
        VStack(spacing: 0) {
            // Header with status
            HStack {
                Image(systemName: manager.isRecording ? "waveform.badge.mic" : "waveform")
                    .foregroundStyle(manager.isRecording ? .red : .secondary)
                Text(manager.isRecording ? "Recording..." : "Dictation")
                    .font(.headline)
                Spacer()

                // Model status indicator
                if manager.modelStatus != .ready {
                    HStack(spacing: 4) {
                        Image(systemName: manager.modelStatus.iconName)
                            .foregroundStyle(manager.modelStatus.iconColor)
                            .font(.caption)
                        Text(manager.modelStatus.displayText)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                Button(action: { NSApp.terminate(nil) }) {
                    Image(systemName: "power")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.ultraThickMaterial)

            // Compact stats row
            CompactStatsRow()
                .background(.ultraThickMaterial)

            Divider()

            // Recording controls
            VStack(spacing: 12) {
                // Main toggle button
                Button(action: { manager.toggleRecording() }) {
                    HStack {
                        if manager.modelStatus == .loading {
                            ProgressView()
                                .scaleEffect(0.8)
                                .padding(.trailing, 4)
                        } else {
                            Image(systemName: manager.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                                .font(.title2)
                        }
                        Text(buttonText)
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(buttonBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.space, modifiers: .command)
                .disabled(manager.modelStatus == .loading)

                // Model selector
                HStack {
                    Text("Model:")
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                    Spacer()
                    Picker("", selection: $manager.selectedModel) {
                        ForEach(WhisperModel.allCases) { model in
                            Text(model.displayName).tag(model)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 160)
                    .disabled(manager.modelStatus == .loading)
                }
                .padding(.horizontal, 4)

                // Microphone selector
                HStack {
                    Text("Microphone:")
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                    Spacer()
                    Picker("", selection: $manager.selectedInputDevice) {
                        ForEach(manager.inputDevices) { device in
                            Text(device.displayName).tag(device)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 160)
                    .disabled(manager.modelStatus == .loading || manager.isRecording)
                    .onChange(of: manager.selectedInputDevice) { _, newDevice in
                        manager.setSelectedInputDevice(newDevice)
                    }
                }
                .padding(.horizontal, 4)
            }
            .padding(12)
            .background(.ultraThickMaterial)

            Divider()

            // Transcription history
            if manager.transcriptions.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "text.bubble")
                        .font(.largeTitle)
                        .foregroundStyle(.tertiary)
                    Text("No transcriptions yet")
                        .foregroundStyle(.secondary)
                    Text("Press your hotkey to start")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .frame(height: 150)
            } else {
                List {
                    ForEach(manager.transcriptions) { transcription in
                        TranscriptionRow(transcription: transcription) {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(transcription.text, forType: .string)
                        }
                    }
                }
                .listStyle(.plain)
                .frame(height: 200)
            }

            Divider()

            // Footer
            HStack {
                Button("Settings") {
                    openSettingsAndBringToFront()
                }

                Spacer()

                if manager.modelStatus == .ready {
                    Text("Ready to record")
                        .font(.caption)
                        .foregroundStyle(.green)
                } else {
                    Text(manager.modelStatus.displayText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(12)
            .background(.ultraThickMaterial)
        }
        .frame(width: 320)
    }

    private var buttonText: String {
        if manager.modelStatus == .loading {
            return "Loading model..."
        } else if manager.isRecording {
            return "Stop Recording"
        } else {
            return "Start Recording"
        }
    }

    private var buttonBackground: some ShapeStyle {
        if manager.modelStatus == .loading {
            return AnyShapeStyle(Color.secondary.opacity(0.1))
        } else if manager.isRecording {
            return AnyShapeStyle(Color.red.opacity(0.1))
        } else {
            return AnyShapeStyle(Color.accentColor.opacity(0.1))
        }
    }

    private func openSettingsAndBringToFront() {
        // Activate the app to ensure windows can be brought to front
        NSApplication.shared.activate(ignoringOtherApps: true)

        // Call openSettings first - this will either open a new window or
        // do nothing if one already exists
        openSettings()

        // Find the Settings window and bring it to front
        // We need to look for the window after openSettings() has a chance to run
        DispatchQueue.main.async {
            // SwiftUI Settings scene windows have these characteristics:
            // - They have titled style mask
            // - They have closable style mask
            // - They are NOT the menu bar extra window (which is untitled and non-closable)
            // - The title may be "Settings" or the app name
            for window in NSApplication.shared.windows {
                // Skip windows that don't look like regular windows
                guard window.styleMask.contains(.titled) &&
                      window.styleMask.contains(.closable) &&
                      !window.styleMask.contains(.hudWindow) else {
                    continue
                }

                // Check if this could be the settings window
                // Settings windows typically have "Settings" in the title or use the app name
                let title = window.title
                if title.contains("Settings") || title == "DictationApp" || title.isEmpty {
                    window.makeKeyAndOrderFront(nil)
                    return
                }
            }

            // Fallback: just bring any titled window to front (besides menu bar)
            for window in NSApplication.shared.windows {
                if window.styleMask.contains(.closable) && window.canBecomeKey {
                    window.makeKeyAndOrderFront(nil)
                    return
                }
            }
        }
    }
}

struct TranscriptionRow: View {
    let transcription: Transcription
    let onCopy: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(transcription.text)
                    .lineLimit(2)
                    .font(.body)
                Spacer()
                Button(action: onCopy) {
                    Image(systemName: "doc.on.doc")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .help("Copy to clipboard")
            }

            HStack {
                Text(transcription.timestamp, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Text("•")
                    .foregroundStyle(.tertiary)
                Text(transcription.model.displayName)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    ContentView()
        .environmentObject(TranscriptionManager())
}
