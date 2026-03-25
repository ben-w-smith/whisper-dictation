import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var manager: TranscriptionManager

    var body: some View {
        VStack(spacing: 0) {
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

            Divider()

            HStack {
                Text("DictationApp v\(appVersion) (dev)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .frame(width: 550, height: 600)
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
}

#Preview {
    SettingsView()
        .environmentObject(TranscriptionManager())
}
