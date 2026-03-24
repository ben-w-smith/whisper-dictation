import SwiftUI

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

            StatsSettingsView()
                .tabItem {
                    Label("Stats", systemImage: "chart.bar")
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

#Preview {
    SettingsView()
        .environmentObject(TranscriptionManager())
}
