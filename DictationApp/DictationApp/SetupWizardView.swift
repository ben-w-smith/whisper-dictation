import SwiftUI

struct SetupWizardView: View {
    @StateObject private var setupManager = SetupManager.shared
    @ObservedObject private var obsidianManager = ObsidianManager.shared
    @Environment(\.dismiss) var dismiss
    @Environment(\.dismissWindow) var dismissWindow

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header

            Divider()

            // Content based on current step
            ScrollView {
                contentView
                    .frame(maxWidth: 600)
            }

            Divider()

            // Footer with navigation
            footer
        }
        .frame(width: 700, height: 500)
        .onAppear {
            // Initialize selections from existing config
            if obsidianManager.vaultPath != nil {
                setupManager.selectedVaultPath = obsidianManager.vaultPath
            }
            if let savedModel = UserDefaults.standard.string(forKey: "selectedModel"),
               let model = WhisperModel(rawValue: savedModel) {
                setupManager.selectedModel = model
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("DictationApp Setup")
                    .font(.headline)

                Text("Step \(setupManager.currentStep.stepNumber) of \(setupManager.currentStep.totalSteps): \(setupManager.currentStep.title)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Step indicator
            HStack(spacing: 6) {
                ForEach(SetupManager.SetupStep.allCases, id: \.self) { step in
                    Circle()
                        .fill(stepColor(for: step))
                        .frame(width: 8, height: 8)
                }
            }
        }
        .padding()
    }

    // MARK: - Content

    @ViewBuilder
    private var contentView: some View {
        switch setupManager.currentStep {
        case .welcome:
            welcomeStep
        case .systemCheck:
            systemCheckStep
        case .permissions:
            permissionsStep
        case .vaultConfig:
            vaultConfigStep
        case .modelSelection:
            modelSelectionStep
        case .complete:
            completeStep
        }
    }

    // MARK: - Welcome Step

    private var welcomeStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Welcome to DictationApp")
                .font(.title)
                .fontWeight(.semibold)

            Text("DictationApp is a macOS menu bar app that uses local AI to transcribe your voice into text. All processing happens on your computer—your audio never leaves your device.")
                .font(.body)

            VStack(alignment: .leading, spacing: 12) {
                featureRow(icon: "waveform", title: "Voice Transcription", description: "Press a hotkey to start/stop recording")
                featureRow(icon: "cpu", title: "Local AI", description: "Uses Whisper models for accurate transcription")
                featureRow(icon: "folder", title: "Obsidian Integration", description: "Save transcriptions to your vault")
                featureRow(icon: "checkmark.circle", title: "Privacy First", description: "No cloud services, no data collection")
            }

            Text("This wizard will guide you through the initial setup.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func featureRow(icon: String, title: String, description: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.blue)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - System Check Step

    private var systemCheckStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("System Check")
                .font(.title)
                .fontWeight(.semibold)

            Text("We'll verify your system has the required dependencies. If anything is missing, we'll help you install it.")
                .font(.body)

            VStack(spacing: 12) {
                checkRow(
                    title: "Python 3.10+",
                    status: setupManager.hasPython310,
                    detail: setupManager.pythonVersion.map { "Found Python \($0)" }
                )

                checkRow(
                    title: "Homebrew",
                    status: setupManager.hasHomebrew,
                    detail: nil
                )

                checkRow(
                    title: "PortAudio",
                    status: setupManager.hasPortAudio,
                    detail: "Required for audio recording"
                )

                checkRow(
                    title: "Virtual Environment",
                    status: setupManager.hasVenv,
                    detail: "Python dependencies"
                )
            }

            if setupManager.isRunningSetup {
                VStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.8)

                    Text(setupManager.setupProgress)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
            }

            if let error = setupManager.setupError {
                Text("Setup Error: \(error)")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
            }

            // Setup button if checks failed
            if setupManager.hasVenv.isFail || setupManager.hasPortAudio.isFail || setupManager.hasPython310.isFail {
                Button(action: {
                    setupManager.runSetup()
                }) {
                    HStack {
                        Image(systemName: "terminal")
                        Text("Run Setup Script")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(setupManager.isRunningSetup)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear {
            if setupManager.hasPython310.isUnchecked {
                setupManager.runSystemChecks()
            }
        }
    }

    private func checkRow(title: String, status: SetupManager.CheckStatus, detail: String?) -> some View {
        HStack {
            Image(systemName: statusIcon(for: status))
                .foregroundStyle(statusColor(for: status))
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)

                if let detail = detail {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if case .fail(let message) = status {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                if case .warning(let message) = status {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }

            Spacer()

            if case .checking = status {
                ProgressView()
                    .scaleEffect(0.7)
            }
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
    }

    private func statusIcon(for status: SetupManager.CheckStatus) -> String {
        switch status {
        case .unchecked:
            return "circle"
        case .checking:
            return "circle.dashed"
        case .pass:
            return "checkmark.circle.fill"
        case .fail:
            return "xmark.circle.fill"
        case .warning:
            return "exclamationmark.triangle.fill"
        }
    }

    private func statusColor(for status: SetupManager.CheckStatus) -> Color {
        switch status {
        case .unchecked:
            return .secondary
        case .checking:
            return .blue
        case .pass:
            return .green
        case .fail:
            return .red
        case .warning:
            return .orange
        }
    }

    // MARK: - Permissions Step

    private var permissionsStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Permissions")
                .font(.title)
                .fontWeight(.semibold)

            Text("DictationApp needs certain permissions to function properly. Click the buttons below to open System Settings and grant access.")
                .font(.body)

            // System Permissions Group
            VStack(alignment: .leading, spacing: 12) {
                Text("System Permissions")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)

                permissionRowWithButton(
                    icon: "mic.fill",
                    title: "Microphone Access",
                    description: "Required to record your voice. macOS will prompt you on first recording.",
                    isRequired: true,
                    action: { openPrivacySettings("Privacy_Microphone") }
                )

                permissionRowWithButton(
                    icon: "folder.fill",
                    title: "File System Access",
                    description: "Needed to save transcriptions to your Obsidian vault and manage local history.",
                    isRequired: true,
                    action: { openPrivacySettings("Privacy_AllFiles") }
                )
            }

            Divider()

            // Optional Permissions Group
            VStack(alignment: .leading, spacing: 12) {
                Text("Optional Features")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)

                permissionRowWithButton(
                    icon: "hand.tap.fill",
                    title: "Accessibility",
                    description: "Required for auto-paste feature. Allows the app to paste transcriptions directly into text fields. You can set this up later in Settings.",
                    isRequired: false,
                    action: { openPrivacySettings("Privacy_Accessibility") }
                )
            }

            Text("Note: You can always change these permissions later in System Settings > Privacy & Security.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 8)
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Open System Settings to a specific privacy pane
    private func openPrivacySettings(_ anchor: String) {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(anchor)") {
            NSWorkspace.shared.open(url)
        }
    }

    /// Permission row with icon, description, and action button
    private func permissionRowWithButton(
        icon: String,
        title: String,
        description: String,
        isRequired: Bool,
        action: @escaping () -> Void
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.blue)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)

                    if isRequired {
                        Text("Required")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.red.opacity(0.2))
                            .foregroundStyle(.red)
                            .cornerRadius(4)
                    } else {
                        Text("Optional")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.2))
                            .foregroundStyle(.blue)
                            .cornerRadius(4)
                    }
                }

                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Grant Permission", action: action)
                .buttonStyle(.bordered)
                .controlSize(.small)
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
    }

    // MARK: - Vault Configuration Step

    private var vaultConfigStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Obsidian Vault (Optional)")
                .font(.title)
                .fontWeight(.semibold)

            Text("DictationApp can save your transcriptions to an Obsidian vault. This is optional—you can also use the app without it (transcriptions will be stored locally).")
                .font(.body)

            VStack(spacing: 16) {
                if let vaultPath = setupManager.selectedVaultPath {
                    // Show selected vault
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text("Vault Selected")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }

                        Text(vaultPath.path)
                            .font(.system(.caption, design: .monospaced))
                            .padding(8)
                            .background(Color(nsColor: .controlBackgroundColor))
                            .cornerRadius(6)

                        Button("Change Vault") {
                            setupManager.selectVaultFolder()
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(16)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(12)
                } else {
                    // No vault selected
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 8) {
                            Image(systemName: "folder.badge.questionmark")
                                .foregroundStyle(.secondary)
                            Text("No Vault Selected")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }

                        Text("Your transcriptions will be saved to local storage only. You can configure a vault later in Settings.")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Button("Select Obsidian Vault") {
                            setupManager.selectVaultFolder()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding(16)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(12)
                }
            }

            Text("Skip this step if you don't use Obsidian or want to configure it later.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Model Selection Step

    private var modelSelectionStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Select a Whisper Model")
                .font(.title)
                .fontWeight(.semibold)

            Text("Choose a Whisper model for transcription. Larger models are more accurate but slower. Downloaded models are cached in ~/.cache/huggingface/.")
                .font(.body)

            VStack(spacing: 12) {
                ForEach(WhisperModel.allCases) { model in
                    modelCard(model: model)
                }
            }

            Text("You can change models later in Settings.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear {
            setupManager.checkCachedModels()
        }
    }

    private func modelCard(model: WhisperModel) -> some View {
        let isDownloaded = setupManager.isModelDownloaded(model)

        return Button {
            setupManager.selectedModel = model
        } label: {
            HStack(spacing: 12) {
                // Selection indicator
                Image(systemName: setupManager.selectedModel == model ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(setupManager.selectedModel == model ? .blue : .secondary)
                    .font(.title2)

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(model.displayName)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.primary)

                        Spacer()

                        // Show size or downloaded status
                        if isDownloaded {
                            Text("Downloaded")
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.green.opacity(0.2))
                                .foregroundStyle(.green)
                                .cornerRadius(4)
                        } else {
                            Text(setupManager.modelSize(model))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Text(setupManager.modelDescription(model))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)

                    HStack {
                        HStack(spacing: 8) {
                            Image(systemName: "speedometer")
                                .font(.caption2)
                            Text(model.speed)
                                .font(.caption2)
                        }
                        .foregroundStyle(.secondary)

                        Spacer()

                        // Download button
                        downloadButton(for: model)
                    }
                }
            }
            .padding(12)
            .background(setupManager.selectedModel == model ? Color.blue.opacity(0.1) : Color(nsColor: .controlBackgroundColor))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(setupManager.selectedModel == model ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }

    /// Download button for a model card with status states
    @ViewBuilder
    private func downloadButton(for model: WhisperModel) -> some View {
        let isDownloading = setupManager.downloadingModel == model
        let isDownloaded = setupManager.isModelDownloaded(model)
        let isOtherDownloading = setupManager.downloadingModel != nil && setupManager.downloadingModel != model

        if isDownloaded {
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                Text("Ready")
            }
            .font(.caption)
            .foregroundStyle(.green)
        } else if isDownloading {
            HStack(spacing: 4) {
                ProgressView()
                    .scaleEffect(0.6)
                Text("Downloading...")
            }
            .font(.caption)
            .foregroundStyle(.blue)
        } else {
            Button {
                setupManager.downloadModel(model)
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.down.circle")
                    Text("Download")
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(isOtherDownloading)
        }
    }

    // MARK: - Complete Step

    private var completeStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.green)

                Text("Setup Complete!")
                    .font(.title)
                    .fontWeight(.semibold)
            }

            Text("You're ready to start using DictationApp. Here's what will happen next:")
                .font(.body)

            VStack(alignment: .leading, spacing: 12) {
                nextStepRow(number: 1, text: "The app will appear in your menu bar")
                nextStepRow(number: 2, text: "Press the default hotkey (Control+Space) to start dictating")
                nextStepRow(number: 3, text: "The Whisper model will download on first use")
                nextStepRow(number: 4, text: "Grant microphone permission when prompted")
            }

            Divider()

            Text("You can always change these settings later by opening Settings from the menu bar.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func nextStepRow(number: Int, text: String) -> some View {
        HStack(spacing: 12) {
            Text("\(number)")
                .font(.caption)
                .fontWeight(.semibold)
                .frame(width: 24, height: 24)
                .background(Circle().fill(Color(nsColor: .controlBackgroundColor)))
                .foregroundStyle(.secondary)

            Text(text)
                .font(.subheadline)
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            // Skip button (only on early steps)
            if setupManager.currentStep != .complete {
                Button("Skip Setup") {
                    setupManager.skipSetup()
                    dismiss()
                }
                .buttonStyle(.bordered)
                .font(.caption)
            }

            Spacer()

            // Back button
            if setupManager.previousStep != nil {
                Button("Back") {
                    setupManager.goToPreviousStep()
                }
                .buttonStyle(.bordered)
                .disabled(setupManager.isRunningSetup)
            }

            // Next/Finish button
            Button(action: nextButtonAction) {
                Text(nextButtonTitle)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!setupManager.canProceed || setupManager.isRunningSetup)
        }
        .padding()
    }

    private var nextButtonTitle: String {
        if setupManager.currentStep == .complete {
            return "Start Using DictationApp"
        }
        return "Next"
    }

    private func nextButtonAction() {
        if setupManager.currentStep == .complete {
            setupManager.markSetupCompleted()
            dismiss()
        } else {
            setupManager.goToNextStep()
        }
    }

    // MARK: - Helpers

    private func stepColor(for step: SetupManager.SetupStep) -> Color {
        let current = setupManager.currentStep
        if step.rawValue < current.rawValue {
            return .green
        } else if step == current {
            return .blue
        } else {
            return Color.secondary.opacity(0.3)
        }
    }
}

#Preview {
    SetupWizardView()
}
