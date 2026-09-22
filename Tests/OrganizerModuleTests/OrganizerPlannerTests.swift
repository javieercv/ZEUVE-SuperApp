import Foundation
import XCTest
@testable import OrganizerModule

final class OrganizerPlannerTests: OrganizerTestCase {
    func testDetailedClassification() throws {
        try write("foto.png")
        try write("retrato.jpg")
        try write("clip.mp4")
        try write("manual.pdf")
        let destinations = relativeDestinations(try OrganizerPlanner().buildPlan(folder: root))
        XCTAssertTrue(destinations.contains("Imágenes/PNG/foto.png"))
        XCTAssertTrue(destinations.contains("Imágenes/JPG-JPEG/retrato.jpg"))
        XCTAssertTrue(destinations.contains("Vídeos/MP4/clip.mp4"))
        XCTAssertTrue(destinations.contains("Documentos/PDF/manual.pdf"))
    }

    func testSimpleModeUsesGeneralCategories() throws {
        try write("foto.png")
        try write("manual.pdf")
        let plan = try OrganizerPlanner().buildPlan(
            folder: root,
            options: OrganizerOptions(organizationLevel: .simple)
        )
        XCTAssertEqual(relativeDestinations(plan), ["Imágenes/foto.png", "Documentos/manual.pdf"])
    }

    func testSameStemInOneCategoryIsGrouped() throws {
        try write("proyecto.final.pdf")
        try write("proyecto.final.docx")
        let values = relativeDestinations(try OrganizerPlanner().buildPlan(folder: root))
        XCTAssertEqual(values, [
            "Documentos/proyecto.final/proyecto.final.pdf",
            "Documentos/proyecto.final/proyecto.final.docx",
        ])
    }

    func testSameStemAcrossCategoriesIsRelated() throws {
        try write("portada.pdf")
        try write("portada.png")
        let values = relativeDestinations(try OrganizerPlanner().buildPlan(folder: root))
        XCTAssertEqual(values, ["Relacionados/portada/portada.pdf", "Relacionados/portada/portada.png"])
    }

    func testRelatedGroupingCanBeDisabled() throws {
        try write("portada.pdf")
        try write("portada.png")
        let values = relativeDestinations(try OrganizerPlanner().buildPlan(
            folder: root,
            options: OrganizerOptions(keepRelated: false)
        ))
        XCTAssertEqual(values, ["Documentos/PDF/portada.pdf", "Imágenes/PNG/portada.png"])
    }

    func testEquivalentExtensionsShareFolder() throws {
        try write("uno.heic")
        try write("dos.HEIF")
        let values = relativeDestinations(try OrganizerPlanner().buildPlan(folder: root))
        XCTAssertEqual(values, ["Imágenes/HEIC-HEIF/uno.heic", "Imágenes/HEIC-HEIF/dos.HEIF"])
    }

    func testConflictsAreRenamedWithoutOverwriting() throws {
        try write("foto.jpg", contents: "new")
        try write("Imágenes/JPG-JPEG/foto.jpg", contents: "old")
        let plan = try OrganizerPlanner().buildPlan(folder: root)
        XCTAssertEqual(plan.operations.first?.destination.lastPathComponent, "foto_2.jpg")
        XCTAssertEqual(plan.operations.first?.conflict, true)
    }

    func testConflictSkipOmitsFile() throws {
        try write("foto.jpg", contents: "new")
        try write("Imágenes/JPG-JPEG/foto.jpg", contents: "old")
        let plan = try OrganizerPlanner().buildPlan(
            folder: root,
            options: OrganizerOptions(conflictPolicy: .skip)
        )
        XCTAssertTrue(plan.operations.isEmpty)
        XCTAssertTrue(plan.ignored.contains { $0.reason.contains("Conflicto") })
    }

    func testRecursiveModeIgnoresManagedFoldersAndPackages() throws {
        try write("nuevo.pdf")
        try write("Documentos/PDF/existente.pdf")
        try write("Pendiente/otro.pdf")
        try write("Demo.app/Contents/interno.pdf")
        let plan = try OrganizerPlanner().buildPlan(
            folder: root,
            options: OrganizerOptions(recursive: true)
        )
        XCTAssertEqual(Set(plan.operations.map { $0.source.lastPathComponent }), ["nuevo.pdf", "otro.pdf"])
        XCTAssertTrue(plan.ignored.contains { $0.reason == "Categoría ya organizada" })
        XCTAssertTrue(plan.ignored.contains { $0.reason == "Paquete de macOS" })
    }

    func testHiddenAndTemporaryFilesAreIgnored() throws {
        try write(".secreto.txt")
        try write("descarga.part")
        let plan = try OrganizerPlanner().buildPlan(folder: root)
        XCTAssertTrue(plan.operations.isEmpty)
        XCTAssertEqual(Set(plan.ignored.map(\.reason)), ["Archivo oculto", "Archivo temporal"])
    }

    func testHiddenFilesCanBeIncluded() throws {
        try write(".secreto.txt")
        let plan = try OrganizerPlanner().buildPlan(
            folder: root,
            options: OrganizerOptions(includeHidden: true)
        )
        XCTAssertEqual(plan.operations.count, 1)
    }

    func testSymlinksAreNeverFollowed() throws {
        let target = try write("real.pdf")
        let link = root.appendingPathComponent("link.pdf")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: target)
        let plan = try OrganizerPlanner().buildPlan(folder: root)
        XCTAssertEqual(Set(plan.operations.map { $0.source.lastPathComponent }), ["real.pdf"])
        XCTAssertTrue(plan.ignored.contains { $0.reason == "Enlace simbólico" })
    }

    func testCustomRuleAndLargeFolder() throws {
        try write("modelo.xyz")
        for index in 0..<1200 { try write("archivo_\(index).txt") }
        let options = OrganizerOptions(customRules: ["xyz": .init(category: "Modelos 3D", formatFolder: "XYZ")])
        let plan = try OrganizerPlanner().buildPlan(folder: root, options: options)
        XCTAssertEqual(plan.operations.count, 1201)
        XCTAssertTrue(relativeDestinations(plan).contains("Modelos 3D/XYZ/modelo.xyz"))
        XCTAssertEqual(plan.summary().files, 1201)
    }
}
