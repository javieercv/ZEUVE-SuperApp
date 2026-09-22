import Foundation

public struct FFmpegVideoPreviewPreparedCommand: Sendable, Equatable {
    public let arguments: [String]
    public let outputWidth: Int
    public let outputHeight: Int
    public let outputFPS: Double
    public let startPosition: TimeInterval
}

public struct FFmpegVideoPreviewCommandBuilder: Sendable {
    public init() {}

    public func prepare(
        source: MultimediaVideoPreviewSource,
        from position: TimeInterval,
        limits inputLimits: MultimediaVideoPreviewLimits,
        decoder: MultimediaVideoPreviewDecoder,
        playbackRate: Double = 1
    ) throws -> FFmpegVideoPreviewPreparedCommand {
        guard source.width > 0, source.height > 0 else { throw MultimediaInspectorError.invalidInput }
        var limits = inputLimits
        limits.normalize()
        let start = min(max(position, 0), source.duration ?? max(position, 0))
        let scale = min(1.0, min(Double(limits.maximumWidth) / Double(source.width), Double(limits.maximumHeight) / Double(source.height)))
        let width = even(max(2, Int((Double(source.width) * scale).rounded(.down))))
        let height = even(max(2, Int((Double(source.height) * scale).rounded(.down))))
        let sourceFPS = source.frameRate.flatMap { $0.isFinite && $0 > 0 ? $0 : nil } ?? Double(limits.maximumFPS)
        let fps = max(1, min(sourceFPS, Double(limits.maximumFPS)))
        let rate = min(max(playbackRate.isFinite ? playbackRate : 1, 0.5), 2)

        var args = ["-hide_banner", "-nostdin", "-v", "error"]
        switch decoder {
        case .hardware:
            #if canImport(Darwin)
            args += ["-hwaccel", "videotoolbox"]
            #endif
        case .automatic:
            #if canImport(Darwin)
            args += ["-hwaccel", "auto"]
            #endif
        case .software:
            break
        }
        if start > 0 { args += ["-ss", String(format: "%.6f", start)] }
        args += ["-readrate", String(format: "%.3f", rate)]
        args += [
            "-i", source.url.path,
            "-map", "0:\(source.streamIndex)",
            "-an", "-sn", "-dn",
            "-vf", "scale=\(width):\(height):flags=fast_bilinear,fps=\(String(format: "%.6f", fps))",
            "-pix_fmt", "bgra",
            "-f", "rawvideo",
            "pipe:1",
        ]
        return .init(arguments: args, outputWidth: width, outputHeight: height, outputFPS: fps, startPosition: start)
    }

    private func even(_ value: Int) -> Int { value % 2 == 0 ? value : value - 1 }
}
