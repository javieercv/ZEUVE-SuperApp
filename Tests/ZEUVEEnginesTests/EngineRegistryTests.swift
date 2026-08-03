import Foundation
import XCTest
@testable import ZEUVEEngines

final class EngineRegistryTests: XCTestCase {
    private var root: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("ZEUVE-EngineTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: root) }

    func testSHA256KnownVectorAndIncrementalFile() throws {
        XCTAssertEqual(SHA256.hexDigest(data: Data("abc".utf8)), "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
        let file = root.appendingPathComponent("sample.bin")
        try Data("abc".utf8).write(to: file)
        XCTAssertEqual(try SHA256.hexDigest(fileAt: file, chunkSize: 1), "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
    }

    func testRegistryRejectsDuplicateAndUnsafePaths() throws {
        let valid = descriptor(name: "ffmpeg", path: "ffmpeg/ffmpeg")
        XCTAssertThrowsError(try EngineRegistry(resourceRoot: root, manifest: .init(engines: [valid, valid])))
        let unsafe = descriptor(name: "bad", path: "/tmp/bad")
        XCTAssertThrowsError(try EngineRegistry(resourceRoot: root, manifest: .init(engines: [unsafe])))
        let traversal = EngineDescriptor(
            name: "traversal", executable: "traversal", relativePath: "tool/traversal", version: "1",
            architecture: .arm64, sha256: String(repeating: "a", count: 64), source: "test",
            licenseFile: "../LICENSE", purpose: "test", diagnosticArguments: ["--version"], size: 1,
            requirement: .required
        )
        XCTAssertThrowsError(try EngineRegistry(resourceRoot: root, manifest: .init(engines: [traversal])))
    }

    func testSharedManifestContainsFFmpegOnlyOnce() throws {
        let project = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let url = project.appendingPathComponent("Sources/ZEUVEEngines/Resources/Engines/engines.json")
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        let manifest = try JSONDecoder().decode(EngineManifest.self, from: Data(contentsOf: url))
        XCTAssertEqual(manifest.engines.filter { $0.name == "ffmpeg" }.count, 1)
        XCTAssertEqual(manifest.engines.filter { $0.name == "ffprobe" }.count, 1)
        let duplicates = try FileManager.default.subpathsOfDirectory(atPath: project.path).filter { $0.hasSuffix("/ffmpeg") && !$0.contains(".build") }
        XCTAssertLessThanOrEqual(duplicates.count, 1)
    }

    func testMissingEngineIsDetectedAndRuntimeHashMismatchDoesNotBlockDiagnostics() async throws {
        let payload = Data("not-a-real-engine".utf8)
        let descriptor = EngineDescriptor(name: "tool", executable: "tool", relativePath: "tool/tool", version: "1.0", architecture: .arm64, sha256: SHA256.hexDigest(data: payload), source: "test", licenseFile: "tool/LICENSE", purpose: "test", diagnosticArguments: ["--version"], size: Int64(payload.count), requirement: .required)
        let registry = try EngineRegistry(resourceRoot: root, manifest: .init(engines: [descriptor]))
        let missing = await EngineDiagnosticService(registry: registry).diagnose(named: "tool")
        XCTAssertEqual(missing?.state, .missing)

        let executable = root.appendingPathComponent("tool/tool")
        try FileManager.default.createDirectory(at: executable.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("license".utf8).write(to: executable.deletingLastPathComponent().appendingPathComponent("LICENSE"))
        try Data("changed".utf8).write(to: executable)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executable.path)
        let modified = await EngineDiagnosticService(registry: registry).diagnose(named: "tool")
        XCTAssertNotEqual(modified?.state, .hashMismatch)
        XCTAssertFalse(modified?.message.localizedCaseInsensitiveContains("SHA-256") == true)
        XCTAssertFalse(modified?.message.localizedCaseInsensitiveContains("tamaño") == true)
    }



    func testDiagnosticCacheIsReusedAndInvalidatedWhenEngineChanges() async throws {
        let manifest = EngineManifest(schemaVersion: 1, engines: [descriptor(name: "tool", path: "tool/tool")])
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("ZEUVE-DiagnosticCache-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        let executable = root.appendingPathComponent("tool/tool")
        try FileManager.default.createDirectory(at: executable.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("license".utf8).write(to: executable.deletingLastPathComponent().appendingPathComponent("LICENSE"))
        try Data("binary".utf8).write(to: executable)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executable.path)
        let registry = try EngineRegistry(resourceRoot: root, manifest: manifest)
        let service = EngineDiagnosticService(registry: registry)

        _ = await service.diagnose(named: "tool")
        let firstCacheCount = await service.cachedDiagnosticCount()
        XCTAssertEqual(firstCacheCount, 1)
        _ = await service.diagnose(named: "tool")
        let secondCacheCount = await service.cachedDiagnosticCount()
        XCTAssertEqual(secondCacheCount, 1)

        try FileManager.default.removeItem(at: executable)
        let missing = await service.diagnose(named: "tool")
        XCTAssertEqual(missing?.state, .missing)
        await service.invalidateDiagnostics()
        let emptyCacheCount = await service.cachedDiagnosticCount()
        XCTAssertEqual(emptyCacheCount, 0)
    }

    func testProcessFailureDetailsIncludeExitSignalAndCapturedOutput() {
        let result = ExternalProcessResult(exitCode: 255, terminationSignal: 9, wasCancelled: false)
        let details = EngineDiagnosticDetailFormatter.processFailureDetails(
            result: result,
            stdout: Data("version parcial".utf8),
            stderr: Data("mensaje real de macOS".utf8)
        )

        XCTAssertTrue(details.contains("Código de salida: 255"))
        XCTAssertTrue(details.contains("Señal de terminación: 9"))
        XCTAssertTrue(details.contains { $0.contains("version parcial") })
        XCTAssertTrue(details.contains { $0.contains("mensaje real de macOS") })
    }

    func testDiagnosticDecodesOlderPayloadWithoutTechnicalDetails() throws {
        let descriptor = descriptor(name: "tool", path: "tool/tool")
        let current = EngineDiagnostic(
            descriptor: descriptor,
            state: .launchFailed,
            message: "Fallo",
            dynamicDependencies: ["/usr/lib/libSystem.B.dylib"]
        )
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(current)) as? [String: Any])
        object.removeValue(forKey: "technicalDetails")

        let decoded = try JSONDecoder().decode(
            EngineDiagnostic.self,
            from: JSONSerialization.data(withJSONObject: object)
        )
        XCTAssertEqual(decoded.technicalDetails, [])
        XCTAssertEqual(decoded.dynamicDependencies, ["/usr/lib/libSystem.B.dylib"])
    }

    func testIncrementalDecoderDoesNotKeepCompleteOutput() throws {
        let decoder = IncrementalLineDecoder(maximumBufferedBytes: 4096)
        for index in 0..<10_000 {
            let lines = try decoder.append(Data("line-\(index)\n".utf8))
            XCTAssertEqual(lines.count, 1)
            XCTAssertLessThan(decoder.bufferedByteCount, 64)
        }
        XCTAssertEqual(decoder.bufferedByteCount, 0)
    }

    private func descriptor(name: String, path: String) -> EngineDescriptor {
        .init(name: name, executable: name, relativePath: path, version: "1", architecture: .arm64, sha256: String(repeating: "a", count: 64), source: "test", licenseFile: "LICENSE", purpose: "test", diagnosticArguments: ["--version"], size: 1, requirement: .required)
    }
}
