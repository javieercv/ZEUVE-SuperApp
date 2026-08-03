import Foundation
import CZEUVEProcess

#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif

public struct ExternalProcessRequest: Sendable, Equatable {
    public let executable: URL
    public let arguments: [String]
    public let environment: [String: String]
    public let workingDirectory: URL?

    public init(
        executable: URL,
        arguments: [String],
        environment: [String: String] = [:],
        workingDirectory: URL? = nil
    ) {
        self.executable = executable.standardizedFileURL
        self.arguments = arguments
        self.environment = environment
        self.workingDirectory = workingDirectory?.standardizedFileURL
    }
}

public struct ExternalProcessResult: Sendable, Equatable {
    public let exitCode: Int32
    public let terminationSignal: Int32
    public let wasCancelled: Bool

    public init(exitCode: Int32, terminationSignal: Int32, wasCancelled: Bool) {
        self.exitCode = exitCode
        self.terminationSignal = terminationSignal
        self.wasCancelled = wasCancelled
    }

    public var succeeded: Bool { exitCode == 0 && terminationSignal == 0 && !wasCancelled }
}

public enum ExternalProcessError: LocalizedError, Equatable {
    case runnerBusy
    case invalidExecutable(String)
    case spawnFailed(Int32)
    case waitFailed(Int32)
    case nonZeroExit(Int32)
    case cancelled
    case descendantsStillRunning(Int32)

    public var errorDescription: String? {
        switch self {
        case .runnerBusy: return "Este ejecutor ya tiene un proceso activo."
        case .invalidExecutable(let path): return "El ejecutable no es válido: \(path)."
        case .spawnFailed(let code): return "No se ha podido iniciar el proceso (error POSIX \(code))."
        case .waitFailed(let code): return "No se ha podido esperar a que termine el proceso (error POSIX \(code))."
        case .nonZeroExit(let code): return "El proceso terminó con el código \(code)."
        case .cancelled: return "La operación se ha cancelado."
        case .descendantsStillRunning(let pid): return "Siguen existiendo procesos descendientes del grupo \(pid)."
        }
    }
}

public actor ExternalProcessRegistry {
    public static let shared = ExternalProcessRegistry()
    private var processGroups: Set<Int32> = []

    public init() {}

    public func register(_ pid: Int32) { processGroups.insert(pid) }
    public func unregister(_ pid: Int32) { processGroups.remove(pid) }
    public func activeProcessGroups() -> [Int32] { processGroups.sorted() }

    @discardableResult
    public func terminateAll(gracePeriod: Duration = .seconds(2)) async -> Bool {
        let groups = processGroups
        guard !groups.isEmpty else { return true }
        for pid in groups { _ = zeuve_signal_process_group(pid_t(pid), SIGTERM) }
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: gracePeriod)
        while clock.now < deadline {
            if groups.allSatisfy({ zeuve_process_group_exists(pid_t($0)) == 0 }) { break }
            try? await Task.sleep(for: .milliseconds(25))
        }
        for pid in groups where zeuve_process_group_exists(pid_t(pid)) != 0 {
            _ = zeuve_signal_process_group(pid_t(pid), SIGKILL)
        }
        let killDeadline = clock.now.advanced(by: .seconds(2))
        while clock.now < killDeadline {
            if groups.allSatisfy({ zeuve_process_group_exists(pid_t($0)) == 0 }) { break }
            try? await Task.sleep(for: .milliseconds(25))
        }
        guard groups.allSatisfy({ zeuve_process_group_exists(pid_t($0)) == 0 }) else { return false }

        // El grupo ya no tiene procesos vivos; espera además a que cada runner haya
        // completado waitpid, cerrado sus tuberías y retirado su registro.
        let reapDeadline = clock.now.advanced(by: .seconds(2))
        while clock.now < reapDeadline {
            if processGroups.isDisjoint(with: groups) { return true }
            try? await Task.sleep(for: .milliseconds(25))
        }
        return processGroups.isDisjoint(with: groups)
    }
}

public actor ExternalProcessRunner {
    public typealias OutputHandler = @Sendable (Data) -> Void

    private let registry: ExternalProcessRegistry
    private var activePID: Int32?
    private var cancellationRequested = false

    public init(registry: ExternalProcessRegistry = .shared) {
        self.registry = registry
    }

    public func run(
        _ request: ExternalProcessRequest,
        onStdout: @escaping OutputHandler = { _ in },
        onStderr: @escaping OutputHandler = { _ in }
    ) async throws -> ExternalProcessResult {
        guard activePID == nil else { throw ExternalProcessError.runnerBusy }
        guard request.executable.isFileURL,
              request.executable.path.hasPrefix("/"),
              FileManager.default.fileExists(atPath: request.executable.path) else {
            throw ExternalProcessError.invalidExecutable(request.executable.path)
        }

        cancellationRequested = false
        var pid: pid_t = 0
        var stdoutFD: Int32 = -1
        var stderrFD: Int32 = -1
        let environment = ProcessInfo.processInfo.environment.merging(request.environment) { _, new in new }
        let argv = [request.executable.path] + request.arguments
        let env = environment.sorted(by: { $0.key < $1.key }).map { "\($0.key)=\($0.value)" }

        let spawnCode: Int32 = withCStringArray(argv) { argvPointer in
            withCStringArray(env) { envPointer in
                if let working = request.workingDirectory?.path {
                    return working.withCString { workPointer in
                        request.executable.path.withCString { executablePointer in
                            Int32(zeuve_spawn_process(
                                executablePointer,
                                argvPointer,
                                envPointer,
                                workPointer,
                                &pid,
                                &stdoutFD,
                                &stderrFD
                            ))
                        }
                    }
                }
                return request.executable.path.withCString { executablePointer in
                    Int32(zeuve_spawn_process(
                        executablePointer,
                        argvPointer,
                        envPointer,
                        nil,
                        &pid,
                        &stdoutFD,
                        &stderrFD
                    ))
                }
            }
        }
        guard spawnCode == 0 else { throw ExternalProcessError.spawnFailed(spawnCode) }

        let processID = Int32(pid)
        activePID = processID
        await registry.register(processID)

        let stdoutTask = Self.readTask(fd: stdoutFD, handler: onStdout)
        let stderrTask = Self.readTask(fd: stderrFD, handler: onStderr)

        let waitResult = await Task.detached(priority: .userInitiated) { () -> (Int32, Int32, Int32) in
            var exitStatus: Int32 = -1
            var signal: Int32 = 0
            let code = Int32(zeuve_wait_process(pid, -1, &exitStatus, &signal))
            return (code, exitStatus, signal)
        }.value

        _ = await stdoutTask.result
        _ = await stderrTask.result
        await registry.unregister(processID)
        let wasCancelled = cancellationRequested
        activePID = nil
        cancellationRequested = false

        guard waitResult.0 == 0 else { throw ExternalProcessError.waitFailed(waitResult.0) }
        let result = ExternalProcessResult(
            exitCode: waitResult.1,
            terminationSignal: waitResult.2,
            wasCancelled: wasCancelled
        )
        if wasCancelled { throw CancellationError() }
        return result
    }

    public func cancel(gracePeriod: Duration = .seconds(2)) async throws {
        guard let pid = activePID else { return }
        cancellationRequested = true
        let term = Int32(zeuve_signal_process_group(pid_t(pid), SIGTERM))
        if term != 0 && term != ESRCH { throw ExternalProcessError.spawnFailed(term) }

        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: gracePeriod)
        while clock.now < deadline {
            if zeuve_process_group_exists(pid_t(pid)) == 0 { break }
            try? await Task.sleep(for: .milliseconds(25))
        }
        if zeuve_process_group_exists(pid_t(pid)) != 0 {
            let killCode = Int32(zeuve_signal_process_group(pid_t(pid), SIGKILL))
            if killCode != 0 && killCode != ESRCH { throw ExternalProcessError.spawnFailed(killCode) }
        }

        let finalDeadline = clock.now.advanced(by: .seconds(2))
        while clock.now < finalDeadline {
            if activePID != pid && zeuve_process_group_exists(pid_t(pid)) == 0 { return }
            try? await Task.sleep(for: .milliseconds(25))
        }
        if zeuve_process_group_exists(pid_t(pid)) != 0 {
            throw ExternalProcessError.descendantsStillRunning(pid)
        }
    }

    public func activeProcessID() -> Int32? { activePID }

    private static func readTask(fd: Int32, handler: @escaping OutputHandler) -> Task<Void, Never> {
        Task.detached(priority: .utility) {
            defer { close(fd) }
            var buffer = [UInt8](repeating: 0, count: 16_384)
            while true {
                let count = read(fd, &buffer, buffer.count)
                if count > 0 {
                    handler(Data(buffer[0..<count]))
                } else if count == 0 {
                    return
                } else if errno != EINTR {
                    return
                }
            }
        }
    }

    private func withCStringArray<T>(
        _ strings: [String],
        _ body: (UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>) throws -> T
    ) rethrows -> T {
        var pointers = strings.map { strdup($0) }
        pointers.append(nil)
        defer { for pointer in pointers where pointer != nil { free(pointer) } }
        return try pointers.withUnsafeMutableBufferPointer { buffer in
            try body(buffer.baseAddress!)
        }
    }
}

public final class IncrementalLineDecoder: @unchecked Sendable {
    private let lock = NSLock()
    private var buffer = Data()
    private let maximumBufferedBytes: Int

    public init(maximumBufferedBytes: Int = 1_048_576) {
        self.maximumBufferedBytes = max(4_096, maximumBufferedBytes)
    }

    public func append(_ data: Data) throws -> [String] {
        lock.lock()
        defer { lock.unlock() }
        buffer.append(data)
        guard buffer.count <= maximumBufferedBytes else {
            buffer.removeAll(keepingCapacity: true)
            throw IncrementalLineDecoderError.lineTooLong
        }
        var lines: [String] = []
        while let newline = buffer.firstIndex(of: 0x0A) {
            var line = buffer[..<newline]
            if line.last == 0x0D { line = line.dropLast() }
            lines.append(String(decoding: line, as: UTF8.self))
            buffer.removeSubrange(...newline)
        }
        return lines
    }

    public func finish() -> String? {
        lock.lock()
        defer { lock.unlock() }
        guard !buffer.isEmpty else { return nil }
        defer { buffer.removeAll(keepingCapacity: true) }
        return String(decoding: buffer, as: UTF8.self)
    }

    public var bufferedByteCount: Int {
        lock.lock(); defer { lock.unlock() }
        return buffer.count
    }
}

public enum IncrementalLineDecoderError: LocalizedError, Equatable {
    case lineTooLong
    public var errorDescription: String? { "La salida del proceso contiene una línea demasiado grande." }
}
