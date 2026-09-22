import Foundation

public struct FFmpegAudioPreviewCommandBuilder: Sendable {
    public init() {}

    public func arguments(
        source: MultimediaAudioPreviewSource,
        from position: TimeInterval,
        channelSelection: SpectrogramChannelSelection
    ) throws -> [String] {
        guard source.sampleRate > 0, source.channels > 0 else {
            throw MultimediaInspectorError.invalidInput
        }
        if case .channel(let channel) = channelSelection,
           !(0..<source.channels).contains(channel) {
            throw MultimediaInspectorError.invalidInput
        }

        let clampedPosition = min(max(position, 0), source.duration ?? max(position, 0))
        let outputChannels: Int
        switch channelSelection {
        case .mix:
            outputChannels = source.channels == 1 ? 1 : 2
        case .channel:
            outputChannels = 1
        }

        var arguments = ["-hide_banner", "-nostdin", "-v", "error"]
        if clampedPosition > 0 {
            arguments += ["-ss", String(format: "%.6f", clampedPosition)]
        }
        arguments += [
            "-i", source.url.path,
            "-map", "0:\(source.streamIndex)",
            "-vn", "-sn", "-dn",
        ]
        if case .channel(let channel) = channelSelection {
            arguments += ["-af", "pan=mono|c0=c\(channel)", "-ac", "1"]
        } else {
            arguments += ["-ac", String(outputChannels)]
        }
        arguments += [
            "-ar", String(Int(source.sampleRate.rounded())),
            "-f", "f32le",
            "-acodec", "pcm_f32le",
            "pipe:1",
        ]
        return arguments
    }

    public func outputChannelCount(
        source: MultimediaAudioPreviewSource,
        channelSelection: SpectrogramChannelSelection
    ) -> Int {
        switch channelSelection {
        case .mix: return source.channels == 1 ? 1 : 2
        case .channel: return 1
        }
    }
}
