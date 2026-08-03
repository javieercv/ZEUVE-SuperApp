import Foundation
import ZEUVEEngines

/// Gestiona la tabla de tiempos de una extracción de fotogramas.
/// La ruta optimizada consume `showinfo` de la misma ejecución de FFmpeg;
/// `writeCSV` se conserva como alternativa compatible para otros llamadores.
public actor FrameTimingService {
    private let runner: ExternalProcessRunner

    public init(runner: ExternalProcessRunner = ExternalProcessRunner()) {
        self.runner = runner
    }

    public func makeCollector(destination: URL) throws -> FrameTimingCSVCollector {
        try FrameTimingCSVCollector(url: destination)
    }

    public func writeCSV(source: URL, ffprobe: URL, destination: URL) async throws {
        try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        guard FileManager.default.createFile(atPath: destination.path, contents: Data("fotograma,tiempo_segundos,duracion_segundos\n".utf8)) else {
            throw UniversalConverterError.processFailed("No se ha podido crear el CSV de tiempos.")
        }
        let writer = try FrameProbeCSVWriter(url: destination)
        let errors = LimitedOutputCollector(maximumBytes: 512 * 1_024)
        let result = try await runner.run(
            ExternalProcessRequest(executable: ffprobe, arguments: [
                "-v", "error", "-select_streams", "v:0", "-show_frames",
                "-show_entries", "frame=best_effort_timestamp_time,pkt_duration_time",
                "-of", "csv=p=0", source.path,
            ]),
            onStdout: { writer.append($0) },
            onStderr: { errors.append($0) }
        )
        try writer.finish()
        guard result.exitCode == 0 else {
            try? FileManager.default.removeItem(at: destination)
            throw UniversalConverterError.processFailed(errors.string.isEmpty ? "No se han podido leer los tiempos de los fotogramas." : errors.string)
        }
    }

    public func cancel() async { try? await runner.cancel() }
}

/// Escritor incremental para las líneas del filtro `showinfo` de FFmpeg.
/// El archivo puede conservarse parcialmente si la extracción se cancela.
public final class FrameTimingCSVCollector: @unchecked Sendable {
    private let lock = NSLock()
    private let handle: FileHandle
    private let decoder = IncrementalLineDecoder(maximumBufferedBytes: 512 * 1_024)
    private var capturedError: Error?
    private var closed = false
    private var lastFrameIndex = -1

    public init(url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        guard FileManager.default.createFile(
            atPath: url.path,
            contents: Data("fotograma,tiempo_segundos,duracion_segundos\n".utf8)
        ) else {
            throw UniversalConverterError.processFailed("No se ha podido crear el CSV de tiempos.")
        }
        handle = try FileHandle(forWritingTo: url)
        try handle.seekToEnd()
    }

    public func append(_ data: Data) {
        lock.lock()
        defer { lock.unlock() }
        guard !closed, capturedError == nil else { return }
        do {
            try write(lines: decoder.append(data))
        } catch {
            capturedError = error
        }
    }

    public func finish() throws {
        lock.lock()
        defer { lock.unlock() }
        guard !closed else {
            if let capturedError { throw capturedError }
            return
        }
        if let final = decoder.finish(), !final.isEmpty { try write(lines: [final]) }
        try handle.synchronize()
        try handle.close()
        closed = true
        if let capturedError { throw capturedError }
    }

    public var frameCount: Int {
        lock.lock(); defer { lock.unlock() }
        return lastFrameIndex + 1
    }

    private func write(lines: [String]) throws {
        for line in lines where line.contains("showinfo") && line.contains("pts_time:") {
            guard let rawIndex = token(after: "n:", in: line), let index = Int(rawIndex), index > lastFrameIndex else { continue }
            let time = token(after: "pts_time:", in: line) ?? ""
            let duration = token(after: "duration_time:", in: line) ?? ""
            let safeDuration = duration == "N/A" ? "" : duration
            try handle.write(contentsOf: Data("\(index + 1),\(time),\(safeDuration)\n".utf8))
            lastFrameIndex = index
        }
    }

    private func token(after key: String, in line: String) -> String? {
        guard let range = line.range(of: key) else { return nil }
        let tail = line[range.upperBound...].drop(while: { $0 == " " || $0 == "\t" })
        let value = tail.prefix(while: { !$0.isWhitespace })
        return value.isEmpty ? nil : String(value)
    }
}

private final class FrameProbeCSVWriter: @unchecked Sendable {
    private let lock = NSLock()
    private let handle: FileHandle
    private let decoder = IncrementalLineDecoder(maximumBufferedBytes: 256 * 1_024)
    private var index = 0
    private var capturedError: Error?

    init(url: URL) throws { handle = try FileHandle(forWritingTo: url); try handle.seekToEnd() }
    func append(_ data: Data) {
        lock.lock(); defer { lock.unlock() }
        guard capturedError == nil else { return }
        do { try write(lines: decoder.append(data)) } catch { capturedError = error }
    }
    func finish() throws {
        lock.lock(); defer { lock.unlock() }
        if let final = decoder.finish(), !final.isEmpty { try write(lines: [final]) }
        try handle.synchronize(); try handle.close()
        if let capturedError { throw capturedError }
    }
    private func write(lines: [String]) throws {
        for line in lines where !line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            index += 1
            let fields = line.split(separator: ",", omittingEmptySubsequences: false).map(String.init)
            let time = fields.indices.contains(0) ? fields[0] : ""
            let duration = fields.indices.contains(1) ? fields[1] : ""
            try handle.write(contentsOf: Data("\(index),\(time),\(duration)\n".utf8))
        }
    }
}
