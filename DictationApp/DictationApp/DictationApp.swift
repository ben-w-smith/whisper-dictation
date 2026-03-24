import SwiftUI

@main
struct DictationApp: App {
    @StateObject private var transcriptionManager = TranscriptionManager()

    var body: some Scene {
        MenuBarExtra("Dictation", systemImage: transcriptionManager.isRecording ? "waveform.badge.mic" : "waveform") {
            ContentView()
                .environmentObject(transcriptionManager)
                .onAppear {
                    // Configure hotkey manager when UI appears
                    HotkeyManager.shared.configure(with: transcriptionManager)
                }
        }
        .menuBarExtraStyle(.window)

        // Settings window for hotkey configuration
        Settings {
            SettingsView()
                .environmentObject(transcriptionManager)
        }
        .defaultSize(width: 450, height: 300)
        .commandsRemoved()
    }
}
