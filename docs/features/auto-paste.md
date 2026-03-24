# Auto-Paste

Automatic text insertion via macOS Accessibility API.

## Overview

Auto-paste automatically inserts transcribed text into the application that was focused when recording started. This uses macOS Accessibility APIs to detect and interact with text fields.

## Requirements

- **Accessibility Permission**: Must be granted in System Preferences > Privacy & Security > Accessibility
- **Text Field Focus**: A text input field must be focused when recording starts

## How It Works

### 1. Record Focused Element

When recording starts, the app captures the focused UI element:

```swift
func recordFocusedElement() {
    // Save the currently focused application
    focusedAppAtRecordingStart = NSWorkspace.shared.frontmostApplication

    // Save the focused UI element via Accessibility API
    let systemWideElement = AXUIElementCreateSystemWide()
    var focusedElement: CFTypeRef?
    AXUIElementCopyAttributeValue(systemWideElement,
        kAXFocusedUIElementAttribute as CFString, &focusedElement)

    focusedElementAtRecordingStart = focusedElement as? AXUIElement
}
```

### 2. Insert Text

After transcription, text is inserted using multiple fallback methods:

#### Method 1: Direct Accessibility Insertion

```swift
// Insert at cursor position using kAXSelectedTextAttribute
AXUIElementSetAttributeValue(element,
    kAXSelectedTextAttribute as CFString, text as CFTypeRef)
```

#### Method 2: Value Modification

```swift
// Get current value and selection range
// Insert text at cursor position
// Update the value attribute
AXUIElementSetAttributeValue(element,
    kAXValueAttribute as CFString, newText as CFTypeRef)
```

#### Method 3: Keyboard Events

```swift
// Type text character by character
typeTextWithCGEvent(text: text)
```

#### Method 4: Cmd+V Simulation (Final Fallback)

```swift
// Copy text to clipboard
// Simulate Cmd+V keystroke
```

## Security Considerations

### Secure Text Fields

The app detects and skips secure text fields (password fields):

```swift
private func isSecureTextField(_ element: AXUIElement) -> Bool {
    var roleValue: CFTypeRef?
    AXUIElementCopyAttributeValue(element,
        kAXRoleAttribute as CFString, &roleValue)

    if role as? String == "AXSecureTextField" {
        return true
    }

    // Check if secure input is enabled globally
    if IsSecureEventInputEnabled() {
        return true
    }

    return false
}
```

### App Switching Detection

If the user switches apps during recording, auto-paste is cancelled:

```swift
if recordedApp.processIdentifier != currentApp.processIdentifier {
    print("User switched apps during recording, skipping auto-paste")
    return
}
```

## Configuration

```swift
@Published var isEnabled: Bool  // Toggle auto-paste on/off
@Published var pasteDelay: Double  // Delay before pasting (default: 0.3s)
```

## Permission Monitoring

The manager monitors accessibility permission status:

```swift
private func startPermissionMonitoring() {
    permissionCheckTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
        self?.refreshPermissionStatus()
    }
}
```

## Notifications

User notifications are shown for paste results:

- "Text inserted" - Successful insertion via Accessibility API
- "Text pasted" - Successful Cmd+V paste
- "Auto-paste skipped" - App switching detected
- "Auto-paste failed" - Text is in clipboard for manual paste

## Cross-References

- [Recording](recording.md) - When focused element is recorded
- [Swift Guide](../swift-guide.md) - AutoPasteManager class details
- [Troubleshooting](../troubleshooting.md) - Permission issues

---

*Last updated: 2026-03-24*
