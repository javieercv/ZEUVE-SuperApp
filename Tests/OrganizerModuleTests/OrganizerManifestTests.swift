import XCTest
@testable import OrganizerModule

final class OrganizerManifestTests: XCTestCase {
    func testBundledManifestIsValid() throws {
        let manifest = try OrganizerModuleDefinition.manifest()
        XCTAssertEqual(manifest.identifier, organizerModuleIdentifier)
        XCTAssertEqual(manifest.moduleAPI, "1.0")
        XCTAssertTrue(manifest.capabilities.contains(.undo))
        XCTAssertTrue(manifest.permissions.contains(.openExternalApplications), "El Organizador abre Finder y debe declarar ese permiso.")
        XCTAssertEqual(Set(manifest.permissions.map(\.rawValue)), Set(["readUserSelectedFiles", "writeUserSelectedFolder", "openExternalApplications"]))
    }
}
