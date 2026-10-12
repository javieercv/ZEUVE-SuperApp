import XCTest
import ZEUVEStorage
@testable import ZEUVEQuickUtilities

@MainActor final class ProductivityRegressionTests: XCTestCase {
    private func store() throws -> SettingsRepository {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("zeuve-productivity-regression-\(UUID().uuidString)")
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        return try SettingsRepository(database: SQLiteDatabase(url: directory.appendingPathComponent("settings.sqlite")))
    }

    func testResetPreservesTemplatesBeforeFirstActivation() async throws {
        let settings = try store()
        let template = FileTemplate(name: "Notas", fileExtension: "md", content: "# Notas\n")
        var preferences = NewFilePreferences(); preferences.format = .json; preferences.templates = [template]
        try settings.set(preferences, forKey: "quickUtilities.newFile.v1")
        let service = NewFileUtilityService(settings: settings)
        XCTAssertEqual(service.state, .disabled)
        try await service.restoreDefaultSettings()
        let stored = try XCTUnwrap(settings.value(forKey: "quickUtilities.newFile.v1", as: NewFilePreferences.self))
        XCTAssertEqual(stored.format, .text)
        XCTAssertEqual(stored.templates, [template])
    }

    func testResetDoesNotOverwriteUnreadableTemplateConfiguration() async throws {
        let settings = try store()
        let template = FileTemplate(name: "Conservar", fileExtension: "txt", content: "Contenido recuperable\n")
        var preferences = NewFilePreferences(); preferences.schemaVersion = 2; preferences.templates = [template]
        try settings.set(preferences, forKey: "quickUtilities.newFile.v1")
        let service = NewFileUtilityService(settings: settings)
        XCTAssertThrowsError(try service.prepareSettings())
        do { try await service.start(); XCTFail("Se activó una configuración incompatible") } catch {}
        guard case .failed = service.state else { return XCTFail("No se detectó el esquema incompatible al activar") }
        do { try await service.restoreDefaultSettings(); XCTFail("Se restableció una configuración cuyas plantillas no se podían leer") }
        catch {}
        let stored = try XCTUnwrap(settings.value(forKey: "quickUtilities.newFile.v1", as: NewFilePreferences.self))
        XCTAssertEqual(stored.schemaVersion, 2)
        XCTAssertEqual(stored.templates, [template])
    }

    func testStoppingRejectsSubsequentCreateAndDoesNotModifyExistingFiles() async throws {
        let settings = try store()
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("zeuve-stopped-file-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let original = directory.appendingPathComponent("original.txt")
        try Data("Original".utf8).write(to: original)
        let service = NewFileUtilityService(settings: settings)
        try await service.start(); try await service.stop()
        do { _ = try await service.create(directory: directory, name: "nuevo.txt", content: "Nuevo"); XCTFail("Se creó un archivo tras desactivar") }
        catch {}
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.appendingPathComponent("nuevo.txt").path))
        XCTAssertEqual(try String(contentsOf: original, encoding: .utf8), "Original")
    }

    func testTextLineJoiningIncludesUnicodeLineAndParagraphSeparators() {
        XCTAssertEqual(TextAction.joinLines.apply(to: "a\u{2028}b\u{2029}c\r\nd"), "a b c d")
        XCTAssertEqual(TextAction.spaces.apply(to: "a\u{2028}b"), "a\u{2028}b")
    }

    func testLateShelfAdditionAfterStopCannotRepopulateReferences() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("zeuve-stopped-shelf-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("original.txt")
        try Data("Original".utf8).write(to: file)
        let service = FileShelfUtilityService()
        try await service.start(); try service.add([file]); try await service.stop()
        XCTAssertThrowsError(try service.add([file]))
        XCTAssertTrue(service.items.isEmpty)
        XCTAssertEqual(try String(contentsOf: file, encoding: .utf8), "Original")
    }

    func testShelfRejectsMissingDragReferencesAndKeepsRemainingOriginal() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("zeuve-missing-shelf-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let first = directory.appendingPathComponent("first.txt"), second = directory.appendingPathComponent("second.txt")
        try Data("First".utf8).write(to: first); try Data("Second".utf8).write(to: second)
        let service = FileShelfUtilityService(); try await service.start(); try service.add([first, second])
        try FileManager.default.removeItem(at: first)
        XCTAssertEqual(try service.referencesForDrag(), [second])
        XCTAssertEqual(try String(contentsOf: second, encoding: .utf8), "Second")
        try await service.stop()
    }
}
