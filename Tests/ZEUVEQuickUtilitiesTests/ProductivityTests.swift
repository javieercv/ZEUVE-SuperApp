import XCTest
@testable import ZEUVEQuickUtilities
#if os(macOS)
import Darwin
#endif

final class ProductivityTests: XCTestCase {
    func testNamesAndExtensionsRejectTraversalHiddenAndExecutableResults() throws {
        for name in ["", ".", "..", ".oculto", "../archivo.txt", "a/b.txt", "a:b", " a.txt", "a\u{0}.txt", "a.app", "a.command"] {
            XCTAssertThrowsError(try SafeNewFilePublisher.validate(name: name), name)
        }
        for name in ["Información.txt", "datos.json", "archivo", "código.swift"] { XCTAssertNoThrow(try SafeNewFilePublisher.validate(name: name)) }
    }
    func testPublisherPreservesExistingFileAndRejectsSymlinkDestination() async throws {
        #if os(macOS)
        // Foundation intentionally abbreviates /private/var to /var even after
        // resolvingSymlinksInPath. Use the POSIX canonical directory for this
        // success case; the publisher separately rejects symbolic components.
        let raw = realpath(FileManager.default.temporaryDirectory.path, nil)!
        let canonical = String(cString: raw); free(raw)
        let directory = URL(fileURLWithPath: canonical).appendingPathComponent("zeuve-new-qa-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let publisher = SafeNewFilePublisher()
        let result = try await publisher.create(directory: directory, name: "datos.json", content: "{}\n")
        XCTAssertEqual(try String(contentsOf: result, encoding: .utf8), "{}\n")
        do { _ = try await publisher.create(directory: directory, name: "datos.json", content: "otro"); XCTFail("Overwrote original") } catch {}
        XCTAssertEqual(try String(contentsOf: result, encoding: .utf8), "{}\n")
        let link = directory.appendingPathComponent("enlace")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: directory)
        do { _ = try await publisher.create(directory: link, name: "nuevo.txt", content: ""); XCTFail("Followed link") } catch {}
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.appendingPathComponent("nuevo.txt").path))
        XCTAssertFalse(try FileManager.default.contentsOfDirectory(atPath: directory.path).contains { $0.hasPrefix(".zeuve-new-") })
        #endif
    }
    func testTextActionsPreserveUnicodeAndDoNotRemoveEmojiJoiners() {
        XCTAssertEqual(TextAction.uppercase.apply(to: "áéñ ß"), "ÁÉÑ SS")
        XCTAssertEqual(TextAction.lowercase.apply(to: "ÁÉÑ"), "áéñ")
        XCTAssertEqual(TextAction.spaces.apply(to: "a\t \u{00A0}b\nc"), "a b\nc")
        XCTAssertEqual(TextAction.joinLines.apply(to: "a\r\nb\nc"), "a b c")
        XCTAssertEqual(TextAction.invisibleCharacters.apply(to: "👩‍💻a\u{200B}b\u{FEFF}"), "👩‍💻ab")
        for action in TextAction.allCases { XCTAssertEqual(action.apply(to: ""), "") }
    }
    func testPublisherUsesOwnedDescriptorWhenTemporaryNameIsReplaced() async throws {
        #if os(macOS)
        let raw = realpath(FileManager.default.temporaryDirectory.path, nil)!
        let canonical = String(cString: raw); free(raw)
        let directory = URL(fileURLWithPath: canonical).appendingPathComponent("zeuve-publish-race-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let original = directory.appendingPathComponent("original.txt")
        try Data("original protegido".utf8).write(to: original)
        let probe = PublicationReplacementProbe(directory: directory, original: original)
        let result = try await SafeNewFilePublisher().create(directory: directory, name: "nuevo.txt", content: "contenido propio", cancellationCheck: {
            await probe.replaceTemporaryBeforePublication()
        })
        XCTAssertEqual(try String(contentsOf: result, encoding: .utf8), "contenido propio")
        XCTAssertEqual(try String(contentsOf: original, encoding: .utf8), "original protegido")
        let replacedName = await probe.replacedName
        XCTAssertNotNil(replacedName)
        // Cleanup must preserve the foreign object that replaced our temp name.
        XCTAssertEqual(try FileManager.default.destinationOfSymbolicLink(atPath: directory.appendingPathComponent(replacedName!).path), original.path)
        #endif
    }
    func testPublisherCancellationLeavesNoResultOrTemporary() async throws {
        #if os(macOS)
        let raw = realpath(FileManager.default.temporaryDirectory.path, nil)!
        let canonical = String(cString: raw); free(raw)
        let directory = URL(fileURLWithPath: canonical).appendingPathComponent("zeuve-publish-cancel-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let probe = PublicationCancellationProbe()
        do {
            _ = try await SafeNewFilePublisher().create(directory: directory, name: "nuevo.txt", content: String(repeating: "x", count: 150_000), cancellationCheck: { await probe.shouldCancel() })
            XCTFail("Publicó un resultado tras cancelar")
        } catch is CancellationError {} catch { XCTFail("Error inesperado: \(error)") }
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: directory.path), [])
        #endif
    }
    @MainActor func testShelfKeepsReferencesDoesNotMoveAndClearsOnStop() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("zeuve-shelf-qa-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("original.txt")
        try Data("original".utf8).write(to: file)
        let shelf = FileShelfUtilityService()
        XCTAssertThrowsError(try shelf.add([file]))
        try await shelf.start(); try shelf.add([file, file])
        XCTAssertEqual(shelf.items.count, 1)
        XCTAssertEqual(try Data(contentsOf: file), Data("original".utf8))
        XCTAssertEqual(try shelf.referencesForDrag(), [file])
        try FileManager.default.removeItem(at: file)
        XCTAssertEqual(shelf.removeMissing(), 1)
        try await shelf.stop(); XCTAssertTrue(shelf.items.isEmpty)
    }
}

private actor PublicationReplacementProbe {
    let directory: URL
    let original: URL
    var checks = 0
    var replacedName: String?
    init(directory: URL, original: URL) { self.directory = directory; self.original = original }
    func replaceTemporaryBeforePublication() -> Bool {
        checks += 1
        guard checks == 3 else { return false }
        do {
            guard let name = try FileManager.default.contentsOfDirectory(atPath: directory.path).first(where: { $0.hasPrefix(".zeuve-new-") }) else { return true }
            let temporary = directory.appendingPathComponent(name)
            try FileManager.default.moveItem(at: temporary, to: directory.appendingPathComponent("own-temp.txt"))
            try FileManager.default.createSymbolicLink(at: temporary, withDestinationURL: original)
            replacedName = name
            return false
        } catch { return true }
    }
}
private actor PublicationCancellationProbe {
    var checks = 0
    func shouldCancel() -> Bool { checks += 1; return checks == 3 }
}
