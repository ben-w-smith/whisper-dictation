import SwiftUI

// MARK: - Sound Settings View

struct SoundSettingsView: View {
    @ObservedObject private var soundManager = SoundManager.shared

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
