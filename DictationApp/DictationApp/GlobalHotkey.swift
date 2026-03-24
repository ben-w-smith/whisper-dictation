import Foundation
import KeyboardShortcuts

// MARK: - Keyboard Shortcuts Extension
extension KeyboardShortcuts.Name {
    static let toggleDictation = Self("toggleDictation", default: .init(.space, modifiers: .control))
}

// MARK: - Hotkey Manager
@MainActor
class HotkeyManager: ObservableObject {
    static let shared = HotkeyManager()
    private weak var manager: TranscriptionManager?

    private init() {}

    func configure(with manager: TranscriptionManager) {
        self.manager = manager
        setupListeners()
        setupMouseButtonManager()
    }

    private func setupListeners() {
        KeyboardShortcuts.onKeyDown(for: .toggleDictation) { [weak self] in
            Task { @MainActor in
                self?.manager?.toggleRecording()
            }
        }
    }

    private func setupMouseButtonManager() {
        MouseButtonManager.shared.configure(with: manager!)
    }
}
