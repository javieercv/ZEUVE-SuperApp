#if os(macOS)
import AppKit
import Carbon

/// LaunchServices supplies login/service reasons as the value of keyAEPropData,
/// not as parameter keywords. Ordinary launches retain the main window.
public enum ResidentLaunchPolicy {
    public static func opensMainWindow(for event: NSAppleEventDescriptor?) -> Bool {
        guard let event, event.eventClass == AEEventClass(kCoreEventClass),
              event.eventID == AEEventID(kAEOpenApplication),
              let reason = event.paramDescriptor(forKeyword: AEKeyword(keyAEPropData)) else { return true }
        return reason.enumCodeValue != OSType(keyAELaunchedAsLogInItem)
            && reason.enumCodeValue != OSType(keyAELaunchedAsServiceItem)
    }
}
#endif
