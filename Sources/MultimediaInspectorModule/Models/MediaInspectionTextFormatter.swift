import Foundation
import ZEUVEEngines

public struct MediaInspectionTextFormatter: Sendable {
    public init() {}

    public func stream(_ stream: MediaInspectionStream) -> String {
        var lines: [String] = ["Stream \(stream.index ?? -1) · \(stream.codec_type ?? "desconocido")"]
        append("Códec", [stream.codec_long_name, stream.codec_name].compactMap { clean($0) }.joined(separator: " · "), to: &lines)
        append("Perfil", clean(stream.profile), to: &lines)
        if let width = stream.width, let height = stream.height { append("Resolución", "\(width) × \(height)", to: &lines) }
        if let fps = stream.frameRate { append("FPS", String(format: "%.3f", fps), to: &lines) }
        append("Pixel format", clean(stream.pix_fmt), to: &lines)
        if let sampleRate = stream.sampleRateValue { append("Sample rate", String(format: "%.0f Hz", sampleRate), to: &lines) }
        if let channels = stream.channels { append("Canales", String(channels), to: &lines) }
        append("Layout", clean(stream.channel_layout), to: &lines)
        append("Idioma", clean(stream.language), to: &lines)
        append("Título", clean(stream.title), to: &lines)
        if stream.isDefault { append("Default", "Sí", to: &lines) }
        if stream.isForced { append("Forced", "Sí", to: &lines) }
        append("HDR", clean(stream.inferredHDRDescription), to: &lines)
        return lines.joined(separator: "\n")
    }

    public func summary(_ result: MediaInspectionResult) -> String {
        var lines: [String] = []
        append("Contenedor", clean(result.format?.format_long_name ?? result.format?.format_name), to: &lines)
        if let duration = result.durationSeconds { append("Duración", formatDuration(duration), to: &lines) }
        if let size = result.format?.sizeBytes { append("Tamaño", ByteCountFormatter.string(fromByteCount: size, countStyle: .file), to: &lines) }
        lines.append("Vídeo: \(result.videoStreams.count) stream(s)")
        lines.append("Audio: \(result.audioStreams.count) pista(s)")
        lines.append("Subtítulos: \(result.subtitleStreams.count) pista(s)")
        if let chapters = result.chapters, !chapters.isEmpty { lines.append("Capítulos: \(chapters.count)") }
        if !result.attachmentStreams.isEmpty { lines.append("Adjuntos: \(result.attachmentStreams.count)") }
        return lines.joined(separator: "\n")
    }

    public func tags(_ tags: [String: String]) -> String {
        tags.keys.sorted().map { "\($0): \(tags[$0] ?? "")" }.joined(separator: "\n")
    }

    private func append(_ key: String, _ value: String?, to lines: inout [String]) {
        guard let value = clean(value) else { return }
        lines.append("\(key): \(value)")
    }

    private func clean(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.uppercased() != "N/A" else { return nil }
        return trimmed
    }

    private func formatDuration(_ value: Double) -> String {
        let total = max(Int(value.rounded()), 0)
        return String(format: "%02d:%02d:%02d", total / 3600, (total % 3600) / 60, total % 60)
    }
}
