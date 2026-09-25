import Foundation
import Testing
import ZEUVECore
import ZEUVEEngines
import ZEUVEOperations
@testable import MultimediaInspectorModule

private func makePreflightFFprobe() throws -> (executable: URL, directory: URL) {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("zeuve-preflight-tests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let source = root.appendingPathComponent("fake_ffprobe.c")
    let executable = root.appendingPathComponent("fake_ffprobe")
    let program = #"""
#include <stdio.h>
#include <string.h>
#include <unistd.h>

int main(int argc, char **argv) {
    const char *input = argc > 1 ? argv[argc - 1] : "";
    if (strstr(input, "slow") != NULL) { sleep(30); }
    fputs("{\"streams\":[{\"index\":0,\"codec_type\":\"audio\",\"codec_name\":\"flac\",\"sample_rate\":\"48000\",\"channels\":2}],\"format\":{\"format_name\":\"matroska,webm\",\"duration\":\"1.0\"}}", stdout);
    fflush(stdout);
    return 0;
}
"""#
    try program.write(to: source, atomically: true, encoding: .utf8)
    let compiler = Process()
    compiler.executableURL = URL(fileURLWithPath: "/usr/bin/cc")
    compiler.arguments = [source.path, "-O2", "-o", executable.path]
    try compiler.run()
    compiler.waitUntilExit()
    guard compiler.terminationStatus == 0 else {
        throw NSError(domain: "MultimediaBatchPreflightTests", code: Int(compiler.terminationStatus))
    }
    return (executable, root)
}

private func preflightFile(in directory: URL, name: String = "input.mkv") throws -> MultimediaBatchDiscoveredFile {
    let url = directory.appendingPathComponent(name)
    try Data("fixture".utf8).write(to: url)
    return .init(url: url, fingerprint: try FileFingerprint.read(from: url))
}

private func waitForPreflightOperation(_ coordinator: OperationCoordinator) async throws -> OperationSnapshot {
    for _ in 0..<100 {
        if let current = await coordinator.current() { return current }
        try await Task.sleep(for: .milliseconds(20))
    }
    throw NSError(domain: "MultimediaBatchPreflightTests", code: 1)
}

@Test func multimediaBatchPreflightPropagatesBusyWithoutDisturbingActiveOperation() async throws {
    let coordinator = OperationCoordinator()
    let activeID = try await coordinator.begin(moduleID: "com.zeuve.qa", name: "Operación existente")
    let service = MultimediaBatchPreflightService(coordinator: coordinator)

    do {
        _ = try await service.prepare(files: [], ruleSet: .init(name: "Vacío", rules: []), ffprobe: URL(fileURLWithPath: "/unused"), preferences: .defaults)
        Issue.record("El preflight no debe continuar cuando el coordinador está ocupado")
    } catch let error as OperationCoordinatorError {
        guard case .busy(let snapshot) = error else {
            Issue.record("Se esperaba OperationCoordinatorError.busy")
            return
        }
        #expect(snapshot.id == activeID)
    }

    #expect(await coordinator.current()?.id == activeID)
    try await coordinator.finish(id: activeID)
}

@Test func multimediaBatchPreflightFinishesCoordinatorBeforeReturning() async throws {
    let coordinator = OperationCoordinator()
    let service = MultimediaBatchPreflightService(coordinator: coordinator)
    let result = try await service.prepare(files: [], ruleSet: .init(name: "Vacío", rules: []), ffprobe: URL(fileURLWithPath: "/unused"), preferences: .defaults)
    #expect(result.isEmpty)
    #expect(await coordinator.current() == nil)
}

@Test func multimediaBatchPreflightPreservesNormalNoChangesResult() async throws {
    let helper = try makePreflightFFprobe()
    defer { try? FileManager.default.removeItem(at: helper.directory) }
    let file = try preflightFile(in: helper.directory)
    let coordinator = OperationCoordinator()
    let service = MultimediaBatchPreflightService(coordinator: coordinator)

    let result = try await service.prepare(files: [file], ruleSet: .init(name: "Sin cambios", rules: []), ffprobe: helper.executable, preferences: .defaults)

    #expect(result.count == 1)
    #expect(result.first?.url == file.url)
    #expect(result.first?.classification == .noChanges)
    #expect(result.first?.plan == nil)
    #expect(await coordinator.current() == nil)
}

@Test func multimediaBatchPreflightRespondsToCoordinatorCancellationAndReleasesOperation() async throws {
    let helper = try makePreflightFFprobe()
    defer { try? FileManager.default.removeItem(at: helper.directory) }
    let file = try preflightFile(in: helper.directory, name: "slow.mkv")
    let coordinator = OperationCoordinator()
    let service = MultimediaBatchPreflightService(coordinator: coordinator)
    let task = Task {
        try await service.prepare(files: [file], ruleSet: .init(name: "Cancelación", rules: []), ffprobe: helper.executable, preferences: .defaults)
    }
    let operation = try await waitForPreflightOperation(coordinator)
    try await coordinator.requestCancellation(id: operation.id)

    do {
        _ = try await task.value
        Issue.record("La cancelación global debe interrumpir el preflight")
    } catch {
        #expect(error is CancellationError)
    }
    #expect(await coordinator.current() == nil)
}

@Test func multimediaBatchPreflightRespondsToTaskCancellationAndReleasesOperation() async throws {
    let helper = try makePreflightFFprobe()
    defer { try? FileManager.default.removeItem(at: helper.directory) }
    let file = try preflightFile(in: helper.directory, name: "slow-local.mkv")
    let coordinator = OperationCoordinator()
    let service = MultimediaBatchPreflightService(coordinator: coordinator)
    let task = Task {
        try await service.prepare(files: [file], ruleSet: .init(name: "Cancelación local", rules: []), ffprobe: helper.executable, preferences: .defaults)
    }
    _ = try await waitForPreflightOperation(coordinator)
    task.cancel()

    do {
        _ = try await task.value
        Issue.record("La cancelación de la tarea debe interrumpir el preflight")
    } catch {
        #expect(error is CancellationError)
    }
    #expect(await coordinator.current() == nil)
}
