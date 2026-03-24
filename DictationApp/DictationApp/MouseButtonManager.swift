import Foundation
import Carbon
import Cocoa

// MARK: - Mouse Button Configuration
struct MouseButtonConfig: Codable, Equatable {
    let buttonNumber: Int

    var displayName: String {
        switch buttonNumber {
        case 1: return "Left Click"
        case 2: return "Right Click"
        case 3: return "Middle Click"
        case 4: return "Button 4 (Back)"
        case 5: return "Button 5 (Forward)"
        case 6: return "Button 6"
        case 7: return "Button 7"
        default: return "Button \(buttonNumber)"
        }
    }

    static let `default` = MouseButtonConfig(buttonNumber: 4)
}

// MARK: - Mouse Button Manager
@MainActor
class MouseButtonManager: ObservableObject {
    static let shared = MouseButtonManager()

    @Published var isEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: "mouseButtonEnabled")
            if isEnabled {
                startMonitoring()
            } else {
                stopMonitoring()
            }
        }
    }

    @Published var mouseButtonConfig: MouseButtonConfig? {
        didSet {
            if let config = mouseButtonConfig {
                if let data = try? JSONEncoder().encode(config) {
                    UserDefaults.standard.set(data, forKey: "mouseButtonConfig")
                }
            } else {
                UserDefaults.standard.removeObject(forKey: "mouseButtonConfig")
            }
        }
    }

    @Published var isRecordingMouseButton: Bool = false
    @Published private(set) var hasAccessibilityPermission: Bool = false

    private weak var manager: TranscriptionManager?
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var isProcessingClick: Bool = false
    private var lastClickTime: Date?
    private var permissionCheckTimer: Timer?

    private init() {
        self.isEnabled = UserDefaults.standard.bool(forKey: "mouseButtonEnabled")

        if let data = UserDefaults.standard.data(forKey: "mouseButtonConfig"),
           let config = try? JSONDecoder().decode(MouseButtonConfig.self, from: data) {
            self.mouseButtonConfig = config
        }

        // Initial permission check
        self.hasAccessibilityPermission = Self.checkAccessibilityPermissionStatus()

        // Start monitoring for permission changes
        startPermissionMonitoring()

        if isEnabled {
            startMonitoring()
        }
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
                // Permission was just granted - try to start monitoring if enabled
                if isEnabled && mouseButtonConfig != nil {
                    startMonitoring()
                }
                // Switch to less frequent checks (every 30 seconds)
                permissionCheckTimer?.invalidate()
                permissionCheckTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
                    Task { @MainActor in
                        self?.refreshPermissionStatus()
                    }
                }
            } else {
                // Permission was revoked - stop monitoring
                stopMonitoring()
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

    func configure(with manager: TranscriptionManager) {
        self.manager = manager
    }

    // MARK: - Recording Mode
    func startRecordingMouseButton() {
        isRecordingMouseButton = true
        startMonitoringForRecording()
    }

    func stopRecordingMouseButton() {
        isRecordingMouseButton = false
        stopRecordingMonitor()

        // Restart normal monitoring if enabled
        if isEnabled {
            startMonitoring()
        }
    }

    private func startMonitoringForRecording() {
        // Stop normal monitoring temporarily
        stopMonitoring()

        // Create event tap for recording
        let mask = (1 << CGEventType.otherMouseDown.rawValue)

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: CGEventMask(mask),
            callback: { proxy, type, event, refcon in
                guard let refcon = refcon else { return Unmanaged.passRetained(event) }
                let manager = Unmanaged<MouseButtonManager>.fromOpaque(refcon).takeUnretainedValue()

                if type == .otherMouseDown {
                    let buttonNumber = Int(event.getIntegerValueField(.mouseEventButtonNumber))

                    Task { @MainActor in
                        manager.handleRecordedButton(buttonNumber: buttonNumber)
                    }
                }

                return Unmanaged.passRetained(event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            print("Failed to create event tap for recording")
            return
        }

        self.eventTap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        self.runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    private func stopRecordingMonitor() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            if let source = runLoopSource {
                CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
            }
            CFMachPortInvalidate(tap)
        }
        eventTap = nil
        runLoopSource = nil
    }

    private func handleRecordedButton(buttonNumber: Int) {
        guard isRecordingMouseButton else { return }

        // Only accept button 4 and higher (side buttons)
        // Buttons 1, 2, 3 are left, right, middle click which would interfere with normal usage
        if buttonNumber >= 4 {
            mouseButtonConfig = MouseButtonConfig(buttonNumber: buttonNumber)
            stopRecordingMouseButton()
        }
    }

    // MARK: - Normal Monitoring
    func startMonitoring() {
        guard isEnabled, mouseButtonConfig != nil else { return }

        // Stop any existing tap
        stopMonitoring()

        // Create event tap for mouse button monitoring
        // We use listenOnly to not intercept the events
        let mask = (1 << CGEventType.otherMouseDown.rawValue)

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: CGEventMask(mask),
            callback: { proxy, type, event, refcon in
                guard let refcon = refcon else { return Unmanaged.passRetained(event) }
                let manager = Unmanaged<MouseButtonManager>.fromOpaque(refcon).takeUnretainedValue()

                if type == .otherMouseDown {
                    let buttonNumber = Int(event.getIntegerValueField(.mouseEventButtonNumber))

                    Task { @MainActor in
                        manager.handleMouseButtonPress(buttonNumber: buttonNumber)
                    }
                }

                return Unmanaged.passRetained(event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            print("Failed to create event tap - check Accessibility permissions")
            // Show alert about accessibility permissions
            Task { @MainActor in
                self.showAccessibilityPermissionAlert()
            }
            return
        }

        self.eventTap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        self.runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        print("Mouse button monitoring started for button \(mouseButtonConfig?.buttonNumber ?? 0)")
    }

    func stopMonitoring() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            if let source = runLoopSource {
                CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
            }
            CFMachPortInvalidate(tap)
        }
        eventTap = nil
        runLoopSource = nil
    }

    private func handleMouseButtonPress(buttonNumber: Int) {
        guard let config = mouseButtonConfig,
              config.buttonNumber == buttonNumber,
              !isProcessingClick else { return }

        // Debounce: ignore clicks within 200ms of each other
        let now = Date()
        if let lastClick = lastClickTime, now.timeIntervalSince(lastClick) < 0.2 {
            return
        }
        lastClickTime = now

        isProcessingClick = true

        // Toggle recording
        manager?.toggleRecording()

        // Reset processing flag after a short delay
        Task {
            try? await Task.sleep(nanoseconds: 300_000_000) // 300ms
            isProcessingClick = false
        }
    }

    private func showAccessibilityPermissionAlert() {
        let alert = NSAlert()
        alert.messageText = "Accessibility Permission Required"
        alert.informativeText = "To use mouse button shortcuts, please grant Dictation accessibility permissions.\n\nGo to System Settings > Privacy & Security > Accessibility and enable Dictation."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Cancel")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            // Open Accessibility settings
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                NSWorkspace.shared.open(url)
            }
        }
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
