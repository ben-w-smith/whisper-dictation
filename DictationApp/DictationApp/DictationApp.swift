import SwiftUI

@main
struct DictationApp: App {
    @StateObject private var transcriptionManager = TranscriptionManager()
    @StateObject private var setupManager = SetupManager.shared

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

        // Setup wizard window (separate window to avoid popover issues)
        WindowGroup(id: "setup-wizard") {
            SetupWizardView()
                .environmentObject(transcriptionManager)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 700, height: 500)
        .windowResizability(.contentSize)
        .defaultPosition(.center)
        .commandsRemoved()
    }
}
