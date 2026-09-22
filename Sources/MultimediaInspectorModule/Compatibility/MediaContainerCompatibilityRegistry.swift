import Foundation

public enum MediaCompatibilityDecision: Sendable, Equatable {
    case streamCopy
    case convertSubtitle(to: String)
    case incompatible
}

public struct MediaContainerCompatibilityRegistry: Sendable {
    public init() {}

    public func decision(kind: MediaTrackKind, codec rawCodec: String, container: EditableMediaContainer) -> MediaCompatibilityDecision {
        let codec = normalize(rawCodec)
        switch kind {
        case .video:
            return videoCodecs(for: container).contains(codec) ? .streamCopy : .incompatible
        case .audio:
            return audioCodecs(for: container).contains(codec) ? .streamCopy : .incompatible
        case .subtitle:
            if subtitleCodecs(for: container).contains(codec) { return .streamCopy }
            if (container == .mp4 || container == .mov), ["subrip", "srt", "text"].contains(codec) { return .convertSubtitle(to: "mov_text") }
            return .incompatible
        }
    }

    public func supportsVideo(codec rawCodec: String, container: EditableMediaContainer) -> Bool {
        videoCodecs(for: container).contains(normalize(rawCodec))
    }

    public func supportsAttachments(container: EditableMediaContainer) -> Bool { container == .mkv }

    public func supportsNonEditableStream(codecType: String?, codec: String?, container: EditableMediaContainer) -> Bool {
        switch container {
        case .mkv: return true
        case .mp4, .mov:
            if codecType == "video" { return supportsVideo(codec: codec ?? "", container: container) }
            return codecType == "audio" || codecType == "subtitle" || codecType == "data"
        case .webm:
            if codecType == "video" { return supportsVideo(codec: codec ?? "", container: container) }
            return codecType == "audio" || codecType == "subtitle"
        }
    }

    public func compatibleContainers(for draft: MediaEditDraft, allowAuthorizedSubtitleConversion: Bool = true) -> [EditableMediaContainer] {
        EditableMediaContainer.allCases.filter { container in
            isCompatible(draft: draft, container: container, allowAuthorizedSubtitleConversion: allowAuthorizedSubtitleConversion)
        }
    }

    public func isCompatible(draft: MediaEditDraft, container: EditableMediaContainer, allowAuthorizedSubtitleConversion: Bool) -> Bool {
        let metadataCompatibility = MediaMetadataCompatibilityRegistry()
        for key in draft.metadata.touchedContainerKeys where !metadataCompatibility.supportsContainerKey(key, container: container) { return false }
        for keys in draft.metadata.touchedVideoKeysByStream.values {
            for key in keys where !metadataCompatibility.supportsVideoKey(key, container: container) { return false }
        }
        for video in draft.videoTracks where decision(kind: .video, codec: video.codec, container: container) != .streamCopy { return false }
        for artwork in draft.originalInspection.streams where artwork.codec_type == "video" && artwork.isAttachedPicture {
            if container != .mkv && !supportsVideo(codec: artwork.codec_name ?? "", container: container) { return false }
        }
        for audio in draft.audioTracks where decision(kind: .audio, codec: audio.codec, container: container) != .streamCopy { return false }
        if !draft.attachments.isEmpty, !supportsAttachments(container: container) { return false }
        for subtitle in draft.subtitleTracks {
            switch decision(kind: .subtitle, codec: subtitle.codec, container: container) {
            case .streamCopy: break
            case .convertSubtitle:
                if !allowAuthorizedSubtitleConversion || !draft.authorizedSubtitleConversions.contains(subtitle.id) { return false }
            case .incompatible: return false
            }
        }
        let editedIndices = Set(draft.videoTracks.compactMap { if case .original(let i) = $0.source { i } else { nil } } + draft.audioTracks.compactMap { if case .original(let i) = $0.source { i } else { nil } } + draft.subtitleTracks.compactMap { if case .original(let i) = $0.source { i } else { nil } })
        for stream in draft.originalInspection.streams where !editedIndices.contains(stream.index ?? -999) && stream.codec_type != "video" && stream.codec_type != "audio" && stream.codec_type != "subtitle" && stream.codec_type != "attachment" {
            if !supportsNonEditableStream(codecType: stream.codec_type, codec: stream.codec_name, container: container) { return false }
        }
        return true
    }

    public func suggestedContainer(for draft: MediaEditDraft) -> EditableMediaContainer? {
        if isCompatible(draft: draft, container: draft.originalContainer, allowAuthorizedSubtitleConversion: true) { return draft.originalContainer }
        let priority: [EditableMediaContainer] = [.mkv, .mp4, .mov, .webm]
        return priority.first { isCompatible(draft: draft, container: $0, allowAuthorizedSubtitleConversion: true) }
    }

    private func normalize(_ codec: String) -> String {
        let value = codec.lowercased()
        if value == "h265" { return "hevc" }
        if value == "srt" { return "subrip" }
        return value
    }
    private func videoCodecs(for c: EditableMediaContainer) -> Set<String> {
        switch c {
        case .mkv: return ["h264","hevc","av1","vp8","vp9","mpeg4","mpeg2video","theora","prores","ffv1"]
        case .mp4: return ["h264","hevc","av1","mpeg4","mjpeg"]
        case .mov: return ["h264","hevc","av1","mpeg4","mjpeg","prores"]
        case .webm: return ["vp8","vp9","av1"]
        }
    }
    private func audioCodecs(for c: EditableMediaContainer) -> Set<String> {
        switch c {
        case .mkv: return ["aac","ac3","eac3","dts","truehd","flac","alac","mp3","opus","vorbis","pcm_s16le","pcm_s24le","pcm_s32le"]
        case .mp4: return ["aac","ac3","eac3","mp3","alac","opus"]
        case .mov: return ["aac","ac3","eac3","mp3","alac","pcm_s16le","pcm_s24le","pcm_s32le"]
        case .webm: return ["opus","vorbis"]
        }
    }
    private func subtitleCodecs(for c: EditableMediaContainer) -> Set<String> {
        switch c {
        case .mkv: return ["subrip","ass","ssa","webvtt","hdmv_pgs_subtitle","dvd_subtitle","dvb_subtitle"]
        case .mp4, .mov: return ["mov_text"]
        case .webm: return ["webvtt"]
        }
    }
}
