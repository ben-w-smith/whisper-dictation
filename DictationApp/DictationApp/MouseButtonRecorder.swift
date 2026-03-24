import SwiftUI

// MARK: - Mouse Button Recorder View (Alternative standalone component)
struct MouseButtonRecorder: View {
    @ObservedObject private var mouseButtonManager = MouseButtonManager.shared
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
