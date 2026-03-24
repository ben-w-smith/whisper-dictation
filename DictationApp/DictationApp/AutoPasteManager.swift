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

    @Published private(set) var hasAccessibilityPermission: Bool = false
    private var permissionCheckTimer: Timer?

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

        // Initial permission check
        self.hasAccessibilityPermission = Self.checkAccessibilityPermissionStatus()

        // Start monitoring for permission changes
        startPermissionMonitoring()
    }

    deinit {
        permissionCheckTimer?.invalidate()
    }

    // MARK: - Permission Monitoring

    private func startPermissionMonitoring() {
        // Check permission status every 1 second when permission is not granted
        permissionCheckTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshPermissionStatus()
            }
        }
    }

    private func refreshPermissionStatus() {
        let currentStatus = Self.checkAccessibilityPermissionStatus()
        if currentStatus != hasAccessibilityPermission {
            hasAccessibilityPermission = currentStatus
            if currentStatus {
                // Permission was just granted - stop frequent polling
                permissionCheckTimer?.invalidate()
                permissionCheckTimer = nil
                // Switch to less frequent checks (every 30 seconds) in case permission is revoked
                permissionCheckTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
                    Task { @MainActor in
                        self?.refreshPermissionStatus()
                    }
                }
            }
        }
    }

    func requestPermissionWithMonitoring() {
        // Request permission (shows system dialog if eligible)
        Self.requestAccessibilityPermission()
        // Force an immediate check after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.refreshPermissionStatus()
        }
    }

    // MARK: - Recording State Tracking

    /// Call this when recording starts to capture the currently focused element
    func recordFocusedElement() {
        print("AutoPaste: recordFocusedElement() called, isEnabled = \(isEnabled)")

        // Always save the currently focused application, regardless of isEnabled
        // This allows auto-paste to work if the user enables it during recording
        focusedAppAtRecordingStart = NSWorkspace.shared.frontmostApplication
        print("AutoPaste: Recorded focused app: \(focusedAppAtRecordingStart?.localizedName ?? "nil")")

        // Always save the focused UI element
        let systemWideElement = AXUIElementCreateSystemWide()
        var focusedElement: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(systemWideElement, kAXFocusedUIElementAttribute as CFString, &focusedElement)
        print("AutoPaste: AXUIElementCopyAttributeValue result: \(result.rawValue)")

        if result == .success, let element = focusedElement {
            focusedElementAtRecordingStart = (element as! AXUIElement)
            print("AutoPaste: Recorded focused element at recording start")

            // Debug: Get the role of the focused element
            var roleValue: CFTypeRef?
            let roleResult = AXUIElementCopyAttributeValue(focusedElementAtRecordingStart!, kAXRoleAttribute as CFString, &roleValue)
            if roleResult == .success, let role = roleValue as? String {
                print("AutoPaste: Focused element role: \(role)")
            }
        } else {
            focusedElementAtRecordingStart = nil
            print("AutoPaste: No focused element found at recording start - error code: \(result.rawValue)")
            if result.rawValue == -25200 {
                print("AutoPaste: kAXErrorAPIDisabled - Accessibility API is not enabled!")
            }
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
        print("AutoPaste: autoPaste() called with text length: \(text.count)")
        print("AutoPaste: isEnabled = \(isEnabled)")
        print("AutoPaste: hasAccessibilityPermission = \(hasAccessibilityPermission)")
        print("AutoPaste: focusedElementAtRecordingStart is nil: \(focusedElementAtRecordingStart == nil)")
        print("AutoPaste: focusedAppAtRecordingStart is nil: \(focusedAppAtRecordingStart == nil)")

        guard isEnabled, !text.isEmpty else {
            print("AutoPaste: Early return - isEnabled: \(isEnabled), text.isEmpty: \(text.isEmpty)")
            return
        }

        // Check if user switched apps during recording
        let currentApp = NSWorkspace.shared.frontmostApplication
        print("AutoPaste: Current app: \(currentApp?.localizedName ?? "nil")")
        print("AutoPaste: Recorded app: \(focusedAppAtRecordingStart?.localizedName ?? "nil")")

        if let recordedApp = focusedAppAtRecordingStart,
           let currentApp = currentApp,
           recordedApp.processIdentifier != currentApp.processIdentifier {
            print("AutoPaste: User switched apps during recording, skipping auto-paste")
            showNotification(title: "Auto-paste skipped", message: "You switched apps during recording")
            clearFocusedElement()
            return
        }

        // Always copy text to clipboard first as a fallback mechanism
        copyToClipboard(text: text)

        // Apply configurable delay
        if pasteDelay > 0 {
            try? await Task.sleep(nanoseconds: UInt64(pasteDelay * 1_000_000_000))
        }

        // First, try direct Accessibility API insertion at cursor position
        if let element = focusedElementAtRecordingStart {
            if await insertTextDirectly(element: element, text: text) {
                print("AutoPaste: Successfully inserted text via Accessibility API")
                showNotification(title: "Text inserted", message: "Transcription pasted automatically")
                clearFocusedElement()
                return
            }
        }

        // Fallback: Simulate Cmd+V (text is now in clipboard)
        print("AutoPaste: Direct insertion failed, falling back to Cmd+V")

        // Activate the target app before simulating paste
        if let targetApp = focusedAppAtRecordingStart {
            print("AutoPaste: Activating target app: \(targetApp.localizedName ?? "unknown")")
            targetApp.activate(options: [])
            // Small delay to let the app activate
            try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
        }

        if await simulatePaste(text: text) {
            print("AutoPaste: Successfully simulated Cmd+V")
            showNotification(title: "Text pasted", message: "Transcription pasted from clipboard")
        } else {
            print("AutoPaste: Failed to paste text")
            showNotification(title: "Auto-paste failed", message: "Text is in clipboard - press Cmd+V to paste")
        }

        clearFocusedElement()
    }

    /// Copy text to the system clipboard (public for external use)
    func copyToClipboardPublic(text: String) {
        copyToClipboard(text: text)
    }

    /// Copy text to the system clipboard
    private func copyToClipboard(text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        print("AutoPaste: Text copied to clipboard")
    }

    // MARK: - Direct Text Insertion via Accessibility API

    private func insertTextDirectly(element: AXUIElement, text: String) async -> Bool {
        print("AutoPaste: insertTextDirectly() called")

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
        print("AutoPaste: Element accepts text input")

        // Method 1: Try to insert at cursor position using kAXSelectedTextAttribute
        // This replaces the current selection (if any) with the text, or inserts at cursor
        let selectedTextResult = AXUIElementSetAttributeValue(element, kAXSelectedTextAttribute as CFString, text as CFTypeRef)
        print("AutoPaste: kAXSelectedTextAttribute result: \(selectedTextResult.rawValue)")
        if selectedTextResult == .success {
            print("AutoPaste: Inserted text at cursor via kAXSelectedTextAttribute")
            return true
        }

        // Method 2: Get current value and selected range, then insert text at that position
        print("AutoPaste: Method 1 failed, trying Method 2")
        var currentValue: CFTypeRef?
        let valueResult = AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &currentValue)
        print("AutoPaste: kAXValueAttribute result: \(valueResult.rawValue)")

        var rangeValue: CFTypeRef?
        let rangeResult = AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &rangeValue)
        print("AutoPaste: kAXSelectedTextRangeAttribute result: \(rangeResult.rawValue)")

        if valueResult == .success, let existingText = currentValue as? String,
           rangeResult == .success, let range = rangeValue {
            print("AutoPaste: Method 2 - got existing text and range")
            // Parse the AXValue to get the range (it's a CFRange wrapped in AXValue)
            var cfRange = CFRange()
            if AXValueGetValue(range as! AXValue, AXValueType(rawValue: kAXValueCFRangeType)!, &cfRange) {
                // Insert text at cursor position (start of selection)
                let insertIndex = cfRange.location
                let prefix = String(existingText.prefix(insertIndex))
                let suffix = String(existingText.dropFirst(insertIndex + cfRange.length))
                let newText = prefix + text + suffix

                let setResult = AXUIElementSetAttributeValue(element, kAXValueAttribute as CFString, newText as CFTypeRef)
                print("AutoPaste: Method 2 - set value result: \(setResult.rawValue)")
                if setResult == .success {
                    // Move cursor to end of inserted text
                    let newCursorPos = insertIndex + text.count
                    var newRange = CFRange(location: newCursorPos, length: 0)
                    if let axValue = AXValueCreate(AXValueType(rawValue: kAXValueCFRangeType)!, &newRange) {
                        _ = AXUIElementSetAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, axValue)
                    }
                    print("AutoPaste: Inserted text at cursor position \(insertIndex)")
                    return true
                }
            }
        } else {
            print("AutoPaste: Method 2 - failed to get value/range, valueResult: \(valueResult.rawValue), rangeResult: \(rangeResult.rawValue)")
        }

        // Method 3: For apps that don't support the above, try posting keyboard events
        // This types the text character by character at the cursor position
        print("AutoPaste: Method 2 failed, trying Method 3 (keyboard events)")
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

    private func simulatePaste(text: String) async -> Bool {
        print("AutoPaste: simulatePaste() called")

        // Ensure text is in clipboard before simulating paste
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        let success = pasteboard.setString(text, forType: .string)

        guard success else {
            print("AutoPaste: Failed to set clipboard content")
            return false
        }
        print("AutoPaste: Clipboard set successfully")

        // Small delay to ensure clipboard is updated
        try? await Task.sleep(nanoseconds: 50_000_000) // 50ms

        let source = CGEventSource(stateID: .combinedSessionState)

        // Cmd down
        guard let cmdDown = CGEvent(keyboardEventSource: source, virtualKey: 0x37, keyDown: true) else {
            return false
        }
        // Don't set command flag on the command key itself
        cmdDown.post(tap: .cgSessionEventTap)

        // V down with command modifier
        guard let vDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true) else {
            // Release Cmd
            if let cmdUp = CGEvent(keyboardEventSource: source, virtualKey: 0x37, keyDown: false) {
                cmdUp.post(tap: .cgSessionEventTap)
            }
            return false
        }
        vDown.flags = .maskCommand
        vDown.post(tap: .cgSessionEventTap)

        // V up with command modifier
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

        print("AutoPaste: Keyboard events posted successfully")
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

    /// Internal method to check the actual permission status from the system
    private static func checkAccessibilityPermissionStatus() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    /// Check if accessibility permission is currently granted
    /// - Returns: true if permission is granted, false otherwise
    static func checkAccessibilityPermission() -> Bool {
        return checkAccessibilityPermissionStatus()
    }

    /// Request accessibility permission from the user
    /// This will show the system permission dialog if the app is eligible
    static func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }
}
