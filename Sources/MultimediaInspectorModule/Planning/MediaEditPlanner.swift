import Foundation

public struct MediaEditPlanner: Sendable {
    private let compatibility: MediaContainerCompatibilityRegistry
    private let validator: MediaEditValidator
    private let preferences: MultimediaInspectorPreferences
    public init(
        compatibility: MediaContainerCompatibilityRegistry = .init(),
        preferences: MultimediaInspectorPreferences = .defaults
    ) {
        self.compatibility = compatibility
        self.validator = MediaEditValidator(compatibility: compatibility)
        self.preferences = preferences
    }

    public func plan(from inputDraft: MediaEditDraft) throws -> MediaEditPlan {
        var draft = inputDraft
        if let preferred = preferences.preferredContainer,
           compatibility.isCompatible(draft: draft, container: preferred, allowAuthorizedSubtitleConversion: true) {
            draft.targetContainer = preferred
        }
        if !compatibility.isCompatible(draft: draft, container: draft.targetContainer, allowAuthorizedSubtitleConversion: true),
           let alternative = compatibility.suggestedContainer(for: draft) {
            draft.targetContainer = alternative
        }
        try validator.validateDraft(draft)

        let originalVideo = Set(draft.originalInspection.videoStreams.compactMap(\.index))
        let originalAudio = Set(draft.originalInspection.audioStreams.compactMap(\.index))
        let originalSubs = Set(draft.originalInspection.subtitleStreams.compactMap(\.index))
        let keptVideo = Set(draft.videoTracks.compactMap { if case .original(let i) = $0.source { i } else { nil } })
        let keptAudio = Set(draft.audioTracks.compactMap { if case .original(let i) = $0.source { i } else { nil } })
        let keptSubs = Set(draft.subtitleTracks.compactMap { if case .original(let i) = $0.source { i } else { nil } })
        let removed = Array(originalVideo.subtracting(keptVideo).union(originalAudio.subtracting(keptAudio)).union(originalSubs.subtracting(keptSubs))).sorted()
        let removedSet = Set(removed)
        let removedTracks = draft.originalInspection.streams.compactMap { stream -> PlannedTrack? in
            guard let index = stream.index, removedSet.contains(index) else { return nil }
            let kind: MediaTrackKind
            if stream.codec_type == "video" { kind = .video }
            else if stream.codec_type == "audio" { kind = .audio }
            else if stream.codec_type == "subtitle" { kind = .subtitle }
            else { return nil }
            guard let track = MediaEditableTrack.from(stream: stream, kind: kind) else { return nil }
            return PlannedTrack(track: track, action: .remove, outputCodec: track.codec)
        }

        let video = draft.videoTracks.map { track -> PlannedTrack in
            let action: PlannedTrackAction = { if case .external = track.source { return .add }; return .keep }()
            return PlannedTrack(track: track, action: action, outputCodec: track.codec)
        }
        let audio = draft.audioTracks.map { track -> PlannedTrack in
            let action: PlannedTrackAction = { if case .external = track.source { return .add }; return .keep }()
            return PlannedTrack(track: track, action: action, outputCodec: track.codec)
        }
        let subtitles = draft.subtitleTracks.map { track -> PlannedTrack in
            let base: PlannedTrackAction = { if case .external = track.source { return .add }; return .keep }()
            switch compatibility.decision(kind: .subtitle, codec: track.codec, container: draft.targetContainer) {
            case .convertSubtitle(let to): return PlannedTrack(track: track, action: .convertSubtitle, outputCodec: to)
            case .streamCopy: return PlannedTrack(track: track, action: base, outputCodec: track.codec)
            case .incompatible: return PlannedTrack(track: track, action: base, outputCodec: track.codec)
            }
        }

        let chapters = try plannedChapters(from: draft)
        let attachments = draft.attachments.map { attachment in
            PlannedAttachment(attachment: attachment, action: {
                if case .external = attachment.source { return .add }
                return .keep
            }())
        }
        let artworks = draft.artworks.map { artwork in
            PlannedArtwork(artwork: artwork, action: { if case .external = artwork.source { return .add }; return .keep }())
        }
        let keptOriginalArtworks = Set(draft.artworks.compactMap { $0.source.originalStreamIndex })
        let removedArtworks = draft.originalInspection.streams.filter { $0.codec_type == "video" && $0.isAttachedPicture }.compactMap { stream -> PlannedArtwork? in
            guard let index = stream.index, !keptOriginalArtworks.contains(index), let artwork = MediaEditableArtwork.from(stream: stream) else { return nil }
            return PlannedArtwork(artwork: artwork, action: .remove)
        }

        let keptOriginalAttachments = Set(draft.attachments.compactMap { $0.source.originalStreamIndex })
        let removedAttachments = draft.originalInspection.attachmentStreams.compactMap { stream -> PlannedAttachment? in
            guard let index = stream.index, !keptOriginalAttachments.contains(index),
                  let attachment = MediaEditableAttachment.from(stream: stream, offset: index) else { return nil }
            return PlannedAttachment(attachment: attachment, action: .remove)
        }

        var warnings: [String] = []
        if draft.targetContainer != draft.originalContainer {
            warnings.append("El contenedor cambiará de \(draft.originalContainer.displayName) a \(draft.targetContainer.displayName) para mantener vídeo y audio mediante stream copy.")
            let hasMetadata = !(draft.originalInspection.format?.tags?.isEmpty ?? true) || draft.originalInspection.streams.contains { !($0.tags?.isEmpty ?? true) }
            if hasMetadata || !chapters.isEmpty {
                warnings.append("ZEUVE mapeará los datos compatibles, pero un cambio de contenedor puede no representar todos los tags exactamente igual. El resultado se validará antes de publicarse.")
            }
        }
        if attachments.contains(where: { $0.action == .add }) {
            warnings.append("Los adjuntos se incorporarán sin recodificar vídeo ni audio y solo en un contenedor compatible.")
        }
        if subtitles.contains(where: { $0.action == .convertSubtitle }) {
            warnings.append("Solo los subtítulos autorizados se convertirán; pueden perderse estilos no representables en el formato de destino.")
        }

        return MediaEditPlan(
            originalURL: draft.originalURL,
            originalFingerprint: draft.originalFingerprint,
            targetContainer: draft.targetContainer,
            videoTracks: video,
            audioTracks: audio,
            subtitleTracks: subtitles,
            originalVideoStreamIndices: draft.originalInspection.streams.filter { $0.codec_type == "video" }.compactMap(\.index),
            chapters: chapters,
            attachments: attachments,
            artworks: artworks,
            removedArtworks: removedArtworks,
            removedAttachments: removedAttachments,
            metadata: draft.metadata,
            preserveMetadata: preferences.preserveMetadata,
            removedOriginalStreamIndices: removed,
            removedTracks: removedTracks,
            warnings: warnings
        )
    }

    private func plannedChapters(from draft: MediaEditDraft) throws -> [PlannedChapter] {
        guard !draft.chapters.isEmpty else { return [] }
        guard let duration = draft.originalInspection.durationSeconds, duration.isFinite, duration > 0 else {
            throw MultimediaInspectorError.invalidChapter("no se conoce la duración del archivo")
        }
        let sorted = draft.chapters.sorted { $0.startTime < $1.startTime }
        return sorted.enumerated().map { index, chapter in
            let end = index + 1 < sorted.count ? sorted[index + 1].startTime : duration
            return PlannedChapter(chapter: chapter, endTime: end)
        }
    }
}
