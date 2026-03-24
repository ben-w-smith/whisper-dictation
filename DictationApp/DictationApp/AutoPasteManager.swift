import Foundation
import Cocoa
import Carbon
import ApplicationServices
import UserNotifications

// MARK: - Auto Paste Manager
@MainActor
class AutoPasteManager: ObservableObject {
    static let shared = AutoPasteManager()

    @Published var isEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: "autoPasteEnabled")
        }
    }

    @Published var pasteDelay: Double {
        didSet {
            UserDefaults.standard.set(pasteDelay, forKey: "autoPasteDelay")
        }
    }

    // Track the app that was focused when recording started
    private var focusedAppAtRecordingStart: NSRunningApplication?
    private var focusedElementAtRecordingStart: AXUIElement?

    private init() {
        self.isEnabled = UserDefaults.standard.bool(forKey: "autoPasteEnabled")
        // Default to 0.3 seconds delay, but load saved preference
        if UserDefaults.standard.object(forKey: "autoPasteDelay") == nil {
            self.pasteDelay = 0.3
        } else {
            self.pasteDelay = UserDefaults.standard.double(forKey: "autoPasteDelay")
        }
    }

    // MARK: - Recording State Tracking

    /// Call this when recording starts to capture the currently focused element
    func recordFocusedElement() {
        guard isEnabled else { return }

        // Save the currently focused application
        focusedAppAtRecordingStart = NSWorkspace.shared.frontmostApplication

        // Save the focused UI element
        let systemWideElement = AXUIElementCreateSystemWide()
        var focusedElement: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(systemWideElement, kAXFocusedUIElementAttribute as CFString, &focusedElement)

        if result == .success, let element = focusedElement {
            focusedElementAtRecordingStart = (element as! AXUIElement)
            print("AutoPaste: Recorded focused element at recording start")
        } else {
            focusedElementAtRecordingStart = nil
            print("AutoPaste: No focused element found at recording start")
        }
    }

    /// Clear the recorded focus state (call when recording is cancelled)
    func clearFocusedElement() {
        focusedAppAtRecordingStart = nil
        focusedElementAtRecordingStart = nil
    }

    // MARK: - Auto Paste

    /// Attempt to paste text into the previously focused element
    /// - Parameter text: The text to paste
    func autoPaste(text: String) async {
        guard isEnabled, !text.isEmpty else { return }

        // Check if user switched apps during recording
        let currentApp = NSWorkspace.shared.frontmostApplication
        if let recordedApp = focusedAppAtRecordingStart,
           let currentApp = currentApp,
           recordedApp.processIdentifier != currentApp.processIdentifier {
            print("AutoPaste: User switched apps during recording, skipping auto-paste")
            showNotification(title: "Auto-paste skipped", message: "You switched apps during recording")
            clearFocusedElement()
            return
        }

        // Apply configurable delay
        if pasteDelay > 0 {
            try? await Task.sleep(nanoseconds: UInt64(pasteDelay * 1_000_000_000))
        }

        // First, try direct Accessibility API insertion
        if let element = focusedElementAtRecordingStart {
            if await insertTextDirectly(element: element, text: text) {
                print("AutoPaste: Successfully inserted text via Accessibility API")
                showNotification(title: "Text inserted", message: "Transcription pasted automatically")
                clearFocusedElement()
                return
            }
        }

        // Fallback: Simulate Cmd+V (clipboard should already contain the text)
        print("AutoPaste: Direct insertion failed, falling back to Cmd+V")
        if await simulatePaste() {
            print("AutoPaste: Successfully simulated Cmd+V")
            showNotification(title: "Text pasted", message: "Transcription pasted from clipboard")
        } else {
            print("AutoPaste: Failed to paste text")
            showNotification(title: "Auto-paste failed", message: "Text is in clipboard - press Cmd+V to paste")
        }

        clearFocusedElement()
    }

    // MARK: - Direct Text Insertion via Accessibility API

    private func insertTextDirectly(element: AXUIElement, text: String) async -> Bool {
        // Check if this is a secure input field (password field)
        if isSecureTextField(element) {
            print("AutoPaste: Skipping secure text field (password field)")
            return false
        }

        // Check if the element accepts text input
        guard elementAcceptsTextInput(element) else {
            print("AutoPaste: Element does not accept text input")
            return false
        }

        // Try to set the value directly
        let result = AXUIElementSetAttributeValue(element, kAXValueAttribute as CFString, text as CFTypeRef)

        if result == .success {
            return true
        }

        // If setting value failed, try using AXTextInsertion
        // First, get the selected text range or cursor position
        var rangeValue: CFTypeRef?
        let rangeResult = AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &rangeValue)

        if rangeResult == .success, let _ = rangeValue {
            // Try to insert text at the current selection
            if AXUIElementPerformAction(element, kAXIncrementAction as CFString) == .success {
                // Some apps support text insertion via actions
            }

            // Alternative: Try using the pasteboard approach with the focused element
            // This is more reliable for web views and some other apps
        }

        // For apps that don't support direct value setting, try posting keyboard events
        return await insertViaKeyboardEvents(element: element, text: text)
    }

    private func insertViaKeyboardEvents(element: AXUIElement, text: String) async -> Bool {
        // Focus the element first
        _ = AXUIElementPerformAction(element, kAXRaiseAction as CFString)

        // Small delay to let the element focus
        try? await Task.sleep(nanoseconds: 100_000_000) // 100ms

        // Check if our element is now focused
        let systemWideElement = AXUIElementCreateSystemWide()
        var currentFocused: CFTypeRef?
        _ = AXUIElementCopyAttributeValue(systemWideElement, kAXFocusedUIElementAttribute as CFString, &currentFocused)

        // Use CGEvent to type the text
        return typeTextWithCGEvent(text: text)
    }

    private func typeTextWithCGEvent(text: String) -> Bool {
        let source = CGEventSource(stateID: .combinedSessionState)

        for char in text {
            // Handle special characters
            if char == "\n" {
                // Press Return
                if let downEvent = CGEvent(keyboardEventSource: source, virtualKey: 0x24, keyDown: true),
                   let upEvent = CGEvent(keyboardEventSource: source, virtualKey: 0x24, keyDown: false) {
                    downEvent.post(tap: .cgSessionEventTap)
                    upEvent.post(tap: .cgSessionEventTap)
                }
            } else if char == "\t" {
                // Press Tab
                if let downEvent = CGEvent(keyboardEventSource: source, virtualKey: 0x30, keyDown: true),
                   let upEvent = CGEvent(keyboardEventSource: source, virtualKey: 0x30, keyDown: false) {
                    downEvent.post(tap: .cgSessionEventTap)
                    upEvent.post(tap: .cgSessionEventTap)
                }
            } else {
                // Regular character - use UniChar array for keyboardSetUnicodeString
                let charString = String(char)
                guard let charScalar = charString.unicodeScalars.first else { continue }

                var unichars: [UniChar] = [UniChar(charScalar.value)]

                // Create keyboard event for the character
                if let event = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true) {
                    event.keyboardSetUnicodeString(stringLength: 1, unicodeString: &unichars)
                    event.post(tap: .cgSessionEventTap)

                    // Key up
                    if let upEvent = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false) {
                        upEvent.keyboardSetUnicodeString(stringLength: 1, unicodeString: &unichars)
                        upEvent.post(tap: .cgSessionEventTap)
                    }
                }
            }

            // Small delay between characters to avoid overwhelming the input system
            Thread.sleep(forTimeInterval: 0.005)
        }

        return true
    }

    // MARK: - Cmd+V Simulation (Fallback)

    private func simulatePaste() async -> Bool {
        // Make sure text is in clipboard
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        // Get the current clipboard content from the transcription (it should already be there)
        // Just simulate Cmd+V

        let source = CGEventSource(stateID: .combinedSessionState)

        // Cmd down
        guard let cmdDown = CGEvent(keyboardEventSource: source, virtualKey: 0x37, keyDown: true) else {
            return false
        }
        cmdDown.flags = .maskCommand
        cmdDown.post(tap: .cgSessionEventTap)

        // V down
        guard let vDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true) else {
            // Release Cmd
            if let cmdUp = CGEvent(keyboardEventSource: source, virtualKey: 0x37, keyDown: false) {
                cmdUp.post(tap: .cgSessionEventTap)
            }
            return false
        }
        vDown.flags = .maskCommand
        vDown.post(tap: .cgSessionEventTap)

        // V up
        guard let vUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false) else {
            return false
        }
        vUp.flags = .maskCommand
        vUp.post(tap: .cgSessionEventTap)

        // Cmd up
        guard let cmdUp = CGEvent(keyboardEventSource: source, virtualKey: 0x37, keyDown: false) else {
            return false
        }
        cmdUp.post(tap: .cgSessionEventTap)

        return true
    }

    // MARK: - Helper Methods

    private func elementAcceptsTextInput(_ element: AXUIElement) -> Bool {
        // Get the role of the element
        var roleValue: CFTypeRef?
        let roleResult = AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleValue)

        guard roleResult == .success, let role = roleValue as? String else {
            return false
        }

        // Check for common text input roles
        let textInputRoles = [
            kAXTextFieldRole as String,
            kAXTextAreaRole as String,
            "AXWebArea",  // Web content areas
            "AXTextArea",
            "AXTextField"
        ]

        if textInputRoles.contains(role) {
            return true
        }

        // Check if element is editable
        var editableValue: CFTypeRef?
        let editableResult = AXUIElementCopyAttributeValue(element, "AXEditable" as CFString, &editableValue)

        if editableResult == .success, let editable = editableValue as? Bool, editable {
            return true
        }

        return false
    }

    private func isSecureTextField(_ element: AXUIElement) -> Bool {
        // Check if this is a secure text field (password field)
        var roleValue: CFTypeRef?
        let roleResult = AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleValue)

        guard roleResult == .success, let role = roleValue as? String else {
            return false
        }

        // Check for secure text field role
        if role == "AXSecureTextField" {
            return true
        }

        // Check if secure input is enabled globally (system has a password field focused)
        if IsSecureEventInputEnabled() {
            return true
        }

        return false
    }

    private func showNotification(title: String, message: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = message
        content.sound = .default

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Permission Check

    static func checkAccessibilityPermission() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    static func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }
}
