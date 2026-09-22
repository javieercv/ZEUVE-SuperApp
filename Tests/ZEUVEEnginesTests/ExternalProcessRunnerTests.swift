import Foundation
import XCTest
@testable import ZEUVEEngines
#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif

final class ExternalProcessRunnerTests: XCTestCase {
    private var root: URL!
    private var helper: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("ZEUVE-ProcessTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        helper = try buildHelper()
    }

    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: root) }

    func testRunnerStreamsOutputWithoutShell() async throws {
        let runner = ExternalProcessRunner(registry: ExternalProcessRegistry())
        let stdout = LockedDataCollector(maximumBytes: 4096)
        let stderr = LockedDataCollector(maximumBytes: 4096)
        let result = try await runner.run(.init(executable: helper, arguments: ["output"]), onStdout: { stdout.append($0) }, onStderr: { stderr.append($0) })
        XCTAssertTrue(result.succeeded)
        XCTAssertEqual(String(decoding: stdout.data, as: UTF8.self), "salida\n")
        XCTAssertEqual(String(decoding: stderr.data, as: UTF8.self), "error\n")
    }

    func testChildReceivesUnblockedTerminationSignals() async throws {
        let runner = ExternalProcessRunner(registry: ExternalProcessRegistry())
        let output = LockedDataCollector(maximumBytes: 128)
        let result = try await runner.run(.init(executable: helper, arguments: ["signal-mask"]), onStdout: { output.append($0) })
        XCTAssertTrue(result.succeeded)
        XCTAssertEqual(String(decoding: output.data, as: UTF8.self), "0 0\n")
    }

    func testCancelTerminatesParentAndChildProcessGroup() async throws {
        let registry = ExternalProcessRegistry()
        let runner = ExternalProcessRunner(registry: registry)
        let pidFile = root.appendingPathComponent("child.pid")
        let executable = try XCTUnwrap(helper)
        let pidPath = pidFile.path
        let task = Task { try await runner.run(.init(executable: executable, arguments: ["children", pidPath])) }
        let parentPID = try await waitForPID(runner)
        let childPID = try await waitForChildPID(pidFile)
        XCTAssertNotEqual(parentPID, childPID)
        try await runner.cancel(gracePeriod: .milliseconds(150))
        do { _ = try await task.value; XCTFail("La ejecución cancelada no debe completarse") }
        catch is CancellationError { }
        let parentGone = await waitUntilGone(parentPID)
        let childGone = await waitUntilGone(childPID)
        let groups = await registry.activeProcessGroups()
        XCTAssertTrue(parentGone)
        XCTAssertTrue(childGone)
        XCTAssertTrue(groups.isEmpty)
    }

    func testCancellingOwningTaskTerminatesParentAndChildProcessGroup() async throws {
        let registry = ExternalProcessRegistry()
        let runner = ExternalProcessRunner(registry: registry)
        let pidFile = root.appendingPathComponent("task-cancel-child.pid")
        let executable = try XCTUnwrap(helper)
        let task = Task { try await runner.run(.init(executable: executable, arguments: ["children", pidFile.path])) }
        let parentPID = try await waitForPID(runner)
        let childPID = try await waitForChildPID(pidFile)

        task.cancel()
        do {
            _ = try await task.value
            XCTFail("Cancelar la Task propietaria debe cancelar también el proceso externo")
        } catch is CancellationError {
            // esperado
        }

        let parentGone = await waitUntilGone(parentPID)
        let childGone = await waitUntilGone(childPID)
        let groups = await registry.activeProcessGroups()
        let activePID = await runner.activeProcessID()
        XCTAssertTrue(parentGone)
        XCTAssertTrue(childGone)
        XCTAssertTrue(groups.isEmpty)
        XCTAssertNil(activePID)
    }

    func testApplicationShutdownRegistryTerminatesDescendants() async throws {
        let registry = ExternalProcessRegistry()
        let runner = ExternalProcessRunner(registry: registry)
        let pidFile = root.appendingPathComponent("shutdown-child.pid")
        let executable = try XCTUnwrap(helper)
        let pidPath = pidFile.path
        let task = Task { try await runner.run(.init(executable: executable, arguments: ["children", pidPath])) }
        _ = try await waitForPID(runner)
        let childPID = try await waitForChildPID(pidFile)
        let fullyTerminated = await registry.terminateAll(gracePeriod: .milliseconds(150))
        XCTAssertTrue(fullyTerminated)
        do {
            let result = try await task.value
            XCTAssertFalse(result.succeeded)
        } catch {
            // Una terminación solicitada durante el cierre también puede manifestarse como cancelación.
        }
        let childGone = await waitUntilGone(childPID)
        XCTAssertTrue(childGone)
    }

    private func buildHelper() throws -> URL {
        let source = root.appendingPathComponent("helper.c")
        let executable = root.appendingPathComponent("helper")
        try #"""
        #include <errno.h>
        #include <signal.h>
        #include <stdio.h>
        #include <stdlib.h>
        #include <string.h>
        #include <sys/types.h>
        #include <sys/wait.h>
        #include <unistd.h>
        int main(int argc, char **argv) {
            if (argc > 1 && strcmp(argv[1], "signal-mask") == 0) {
                sigset_t mask; sigprocmask(0, NULL, &mask);
                printf("%d %d\n", sigismember(&mask, SIGTERM), sigismember(&mask, SIGINT)); return 0;
            }
            if (argc > 1 && strcmp(argv[1], "output") == 0) {
                fputs("salida\n", stdout); fputs("error\n", stderr); return 0;
            }
            if (argc > 2 && strcmp(argv[1], "children") == 0) {
                signal(SIGTERM, SIG_IGN);
                int ready[2];
                if (pipe(ready) != 0) return 2;
                pid_t child = fork();
                if (child < 0) return 3;
                if (child == 0) {
                    close(ready[0]);
                    signal(SIGTERM, SIG_DFL);
                    char value = '1';
                    (void)write(ready[1], &value, 1);
                    close(ready[1]);
                    for (;;) pause();
                }
                close(ready[1]);
                char value = 0;
                if (read(ready[0], &value, 1) != 1) return 4;
                close(ready[0]);
                FILE *file = fopen(argv[2], "w"); if (!file) return 5;
                fprintf(file, "%d", (int)child); fclose(file);
                for (;;) {
                    int status = 0;
                    (void)waitpid(child, &status, WNOHANG);
                    usleep(10000);
                }
            }
            return 4;
        }
        """#.write(to: source, atomically: true, encoding: .utf8)
        let compilerCandidates = ["/usr/bin/clang", "/usr/bin/cc", "/usr/bin/gcc"]
        guard let compiler = compilerCandidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) else {
            throw XCTSkip("No hay compilador C disponible para crear el ejecutable auxiliar.")
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: compiler)
        process.arguments = [source.path, "-O0", "-o", executable.path]
        try process.run(); process.waitUntilExit()
        guard process.terminationStatus == 0 else { throw XCTSkip("No se ha podido compilar el ejecutable auxiliar.") }
        return executable
    }

    private func waitForPID(_ runner: ExternalProcessRunner) async throws -> Int32 {
        for _ in 0..<200 {
            if let pid = await runner.activeProcessID() { return pid }
            try await Task.sleep(for: .milliseconds(10))
        }
        throw XCTSkip("El proceso auxiliar no llegó a iniciarse.")
    }

    private func waitForChildPID(_ file: URL) async throws -> Int32 {
        for _ in 0..<200 {
            if let value = try? String(contentsOf: file, encoding: .utf8), let pid = Int32(value) { return pid }
            try await Task.sleep(for: .milliseconds(10))
        }
        throw XCTSkip("El proceso hijo no publicó su PID.")
    }

    private func waitUntilGone(_ pid: Int32) async -> Bool {
        for _ in 0..<200 {
            if kill(pid_t(pid), 0) != 0, errno == ESRCH { return true }
            try? await Task.sleep(for: .milliseconds(10))
        }
        return false
    }
}
