#if os(macOS)
import AppKit
import ApplicationServices
import IOKit.hid

@MainActor public enum QuickUtilityPermissions {
    public static func request(_ permission: QuickUtilityPermission) {
        switch permission {
        case .accessibility:
            // The public option is an immutable string; its C declaration is imported as var.
            let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
            _ = AXIsProcessTrustedWithOptions(options)
        case .inputMonitoring:
            _ = IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
        case .audioCapture:
            // Core Audio presents its own authorization when a tap is requested.
            openSettings(permission)
        }
    }
    public static func openSettings(_ permission: QuickUtilityPermission) {
        let pane: String
        switch permission {
        case .accessibility: pane = "Privacy_Accessibility"
        case .inputMonitoring: pane = "Privacy_ListenEvent"
        case .audioCapture: pane = ""
        }
        let address = "x-apple.systempreferences:com.apple.preference.security" + (pane.isEmpty ? "" : "?\(pane)")
        if let url = URL(string: address) { NSWorkspace.shared.open(url) }
    }
}
#endif
