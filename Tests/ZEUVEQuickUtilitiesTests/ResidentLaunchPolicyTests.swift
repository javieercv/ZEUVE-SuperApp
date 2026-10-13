#if os(macOS)
import AppKit
import Carbon
import XCTest
@testable import ZEUVEQuickUtilities

final class ResidentLaunchPolicyTests: XCTestCase {
    private func event(id: AEEventID = AEEventID(kAEOpenApplication), reason: OSType? = nil) -> NSAppleEventDescriptor {
        let event = NSAppleEventDescriptor(eventClass: AEEventClass(kCoreEventClass), eventID: id,
                                          targetDescriptor: nil, returnID: AEReturnID(kAutoGenerateReturnID),
                                          transactionID: AETransactionID(kAnyTransactionID))
        if let reason { event.setParam(NSAppleEventDescriptor(enumCode: reason), forKeyword: AEKeyword(keyAEPropData)) }
        return event
    }

    func testNormalUnknownAndMissingLaunchReasonOpenMainWindow() {
        XCTAssertTrue(ResidentLaunchPolicy.opensMainWindow(for: nil))
        XCTAssertTrue(ResidentLaunchPolicy.opensMainWindow(for: event()))
        XCTAssertTrue(ResidentLaunchPolicy.opensMainWindow(for: event(reason: 0)))
        XCTAssertTrue(ResidentLaunchPolicy.opensMainWindow(for: event(reason: 0x7A657576)))
    }

    func testLoginAndServiceLaunchesRemainResidentWithoutMainWindow() {
        XCTAssertFalse(ResidentLaunchPolicy.opensMainWindow(for: event(reason: OSType(keyAELaunchedAsLogInItem))))
        XCTAssertFalse(ResidentLaunchPolicy.opensMainWindow(for: event(reason: OSType(keyAELaunchedAsServiceItem))))
    }

    func testUnrelatedEventOrParameterDoesNotHideMainWindow() {
        XCTAssertTrue(ResidentLaunchPolicy.opensMainWindow(for: event(id: AEEventID(kAEReopenApplication), reason: OSType(keyAELaunchedAsLogInItem))))
        let ordinary = event()
        ordinary.setParam(NSAppleEventDescriptor(boolean: true), forKeyword: AEKeyword(keyAELaunchedAsLogInItem))
        XCTAssertTrue(ResidentLaunchPolicy.opensMainWindow(for: ordinary))
        ordinary.setParam(NSAppleEventDescriptor(string: "invalid"), forKeyword: AEKeyword(keyAEPropData))
        XCTAssertTrue(ResidentLaunchPolicy.opensMainWindow(for: ordinary))
    }
}
#endif
