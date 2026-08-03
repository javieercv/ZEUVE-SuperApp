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
}

private extension JSONDecoder {
    static var zeuveISO8601: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
