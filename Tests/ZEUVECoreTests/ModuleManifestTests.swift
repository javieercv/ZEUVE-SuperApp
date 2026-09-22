import XCTest
@testable import ZEUVECore

final class ModuleManifestTests: XCTestCase {
    func testValidManifestRegistersAndSorts() async throws {
        let registry = ModuleRegistry()
        let second = makeManifest(id: "com.zeuve.second", order: 20)
        let first = makeManifest(id: "com.zeuve.first", order: 10)
        try await registry.register(second)
        try await registry.register(first)
        let modules = await registry.all()
        XCTAssertEqual(modules.map(\.identifier), ["com.zeuve.first", "com.zeuve.second"])
    }

    func testDuplicateIdentifierIsRejected() async throws {
        let registry = ModuleRegistry()
        let manifest = makeManifest(id: "com.zeuve.duplicate", order: 1)
        try await registry.register(manifest)
        do {
            try await registry.register(manifest)
            XCTFail("Se esperaba un error por identificador duplicado")
        } catch let error as ModuleManifestError {
            XCTAssertEqual(error, .duplicateIdentifier("com.zeuve.duplicate"))
        }
    }

    func testProtocolRoundTrip() throws {
        let request = ModuleRequest(
            moduleID: "com.zeuve.organizer",
            action: "plan",
            payload: ["recursive": .bool(true), "count": .number(12)]
        )
        let data = try JSONEncoder().encode(request)
        XCTAssertEqual(try JSONDecoder().decode(ModuleRequest.self, from: data), request)
    }

    private func makeManifest(id: String, order: Int) -> ModuleManifest {
        ModuleManifest(
            identifier: id,
            name: id,
            summary: "Módulo de prueba",
            version: "1.0.0",
            minimumZEUVEVersion: "0.1.0",
            technology: .swift,
            executionMode: .builtIn,
            permissions: [.readUserSelectedFiles],
            capabilities: [.preview],
            presentation: .init(systemImage: "folder", category: "Pruebas", order: order)
        )
    }
}


extension ModuleManifestTests {
    func testLocalLoggerWritesJSONLine() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("zeuve-logger-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let logger = try LocalLogger(directory: directory)
        let date = Date(timeIntervalSince1970: 1_788_000_000)
        let file = try await logger.write(
            .info,
            category: "pruebas",
            message: "Operación completada",
            metadata: ["elementos": "3"],
            timestamp: date
        )

        let lines = try String(contentsOf: file, encoding: .utf8)
            .split(separator: "\n")
        XCTAssertEqual(lines.count, 1)
        let entry = try JSONDecoder.zeuveISO8601.decode(LocalLogEntry.self, from: Data(lines[0].utf8))
        XCTAssertEqual(entry.level, .info)
        XCTAssertEqual(entry.category, "pruebas")
        XCTAssertEqual(entry.message, "Operación completada")
        XCTAssertEqual(entry.metadata["elementos"], "3")
    }

    func testLocalLoggerPrunesOnlyOwnedOldLogsAndKeepsForeignFiles() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("zeuve-logger-retention-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let oldOwned = directory.appendingPathComponent("zeuve-2026-01-01.jsonl")
        let foreign = directory.appendingPathComponent("not-zeuve-2026-01-01.jsonl")
        try Data("old\n".utf8).write(to: oldOwned)
        try Data("keep\n".utf8).write(to: foreign)
        let oldDate = Date().addingTimeInterval(-Double(LocalLogger.retentionDays + 5) * 86_400)
        try FileManager.default.setAttributes([.modificationDate: oldDate], ofItemAtPath: oldOwned.path)
        try FileManager.default.setAttributes([.modificationDate: oldDate], ofItemAtPath: foreign.path)

        _ = try LocalLogger(directory: directory)

        XCTAssertFalse(FileManager.default.fileExists(atPath: oldOwned.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: foreign.path))
    }

    func testLocalLoggerEnforcesSizeCapAndRestrictivePermissions() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("zeuve-logger-size-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let oldest = directory.appendingPathComponent("zeuve-2026-09-05.jsonl")
        let newest = directory.appendingPathComponent("zeuve-2026-09-06.jsonl")
        for (file, age) in [(oldest, 2.0), (newest, 1.0)] {
            _ = FileManager.default.createFile(atPath: file.path, contents: nil)
            let handle = try FileHandle(forWritingTo: file)
            try handle.truncate(atOffset: UInt64(LocalLogger.maximumTotalBytes / 2 + 1_048_576))
            try handle.close()
            try FileManager.default.setAttributes([.modificationDate: Date().addingTimeInterval(-age * 3_600)], ofItemAtPath: file.path)
        }

        let logger = try LocalLogger(directory: directory)
        XCTAssertFalse(FileManager.default.fileExists(atPath: oldest.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: newest.path))

        let written = try await logger.write(.info, category: "pruebas", message: "ok")
        #if !os(Windows)
        let directoryMode = (try FileManager.default.attributesOfItem(atPath: directory.path)[.posixPermissions] as? NSNumber)?.intValue
        let fileMode = (try FileManager.default.attributesOfItem(atPath: written.path)[.posixPermissions] as? NSNumber)?.intValue
        XCTAssertEqual(directoryMode.map { $0 & 0o777 }, 0o700)
        XCTAssertEqual(fileMode.map { $0 & 0o777 }, 0o600)
        #endif
    }
}

private extension JSONDecoder {
    static var zeuveISO8601: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
