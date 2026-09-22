import Foundation
import ZEUVECore

public struct MediaEditValidator: Sendable {
    private let compatibility: MediaContainerCompatibilityRegistry
    private let metadataCompatibility: MediaMetadataCompatibilityRegistry
    public init(
        compatibility: MediaContainerCompatibilityRegistry = .init(),
        metadataCompatibility: MediaMetadataCompatibilityRegistry = .init()
    ) {
        self.compatibility = compatibility
        self.metadataCompatibility = metadataCompatibility
    }

    public func validateDraft(_ draft: MediaEditDraft) throws {
        guard draft.originalFingerprint.matches(draft.originalURL) else { throw MultimediaInspectorError.originalChanged }
        guard !draft.originalInspection.videoStreams.isEmpty || !draft.originalInspection.audioStreams.isEmpty else { throw MultimediaInspectorError.unsupportedFile }
        try validateExternal(draft.videoTracks + draft.audioTracks + draft.subtitleTracks)
        try validateAttachments(draft.attachments, targetContainer: draft.targetContainer)
        try validateArtworks(draft.artworks, targetContainer: draft.targetContainer)
        try validateChapters(draft.chapters, duration: draft.originalInspection.durationSeconds)
        try validateMetadata(draft.metadata, container: draft.targetContainer)

        for track in draft.videoTracks {
            if compatibility.decision(kind: .video, codec: track.codec, container: draft.targetContainer) != .streamCopy {
                throw MultimediaInspectorError.requiresTranscode("la pista de vídeo \(track.codec) no cabe por copia directa en \(draft.targetContainer.displayName)")
            }
        }
        for track in draft.audioTracks {
            if compatibility.decision(kind: .audio, codec: track.codec, container: draft.targetContainer) != .streamCopy {
                throw MultimediaInspectorError.requiresTranscode("la pista de audio \(track.codec) no cabe por copia directa en \(draft.targetContainer.displayName)")
            }
        }
        for track in draft.subtitleTracks {
            switch compatibility.decision(kind: .subtitle, codec: track.codec, container: draft.targetContainer) {
            case .streamCopy: break
            case .convertSubtitle(let to):
                guard draft.authorizedSubtitleConversions.contains(track.id) else { throw MultimediaInspectorError.subtitleConversionAuthorizationRequired(track.codec, to) }
            case .incompatible:
                throw MultimediaInspectorError.subtitleNotConvertible(track.codec)
            }
        }
        guard compatibility.isCompatible(draft: draft, container: draft.targetContainer, allowAuthorizedSubtitleConversion: true) else {
            throw MultimediaInspectorError.incompatibleContainer("hay streams auxiliares que no pueden preservarse en \(draft.targetContainer.displayName)")
        }
    }

    private func validateExternal(_ tracks: [MediaEditableTrack]) throws {
        for track in tracks {
            guard case .external(let url, let fingerprint, _) = track.source else { continue }
            try validateExternalFile(url: url, fingerprint: fingerprint)
        }
    }

    private func validateArtworks(_ artworks: [MediaEditableArtwork], targetContainer: EditableMediaContainer) throws {
        let policy = MediaArtworkCompatibility()
        guard artworks.count <= 1 else { throw MultimediaInspectorError.incompatibleContainer("solo se admite una carátula attached_pic por salida") }
        for artwork in artworks {
            if case .external(let url, let fingerprint, _) = artwork.source {
                try validateExternalFile(url: url, fingerprint: fingerprint)
                guard policy.canAdd(artwork, to: targetContainer) else {
                    throw MultimediaInspectorError.requiresTranscode("la carátula \(artwork.codec) no puede añadirse por copia directa a \(targetContainer.displayName)")
                }
            }
        }
    }

    private func validateAttachments(_ attachments: [MediaEditableAttachment], targetContainer: EditableMediaContainer) throws {
        if !attachments.isEmpty, !compatibility.supportsAttachments(container: targetContainer) {
            throw MultimediaInspectorError.incompatibleContainer("los adjuntos requieren un contenedor MKV")
        }
        var names = Set<String>()
        for attachment in attachments {
            let name = attachment.filename.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty,
                  URL(fileURLWithPath: name).lastPathComponent == name,
                  !name.contains("/"), !name.contains("\\"), name != ".", name != ".." else {
                throw MultimediaInspectorError.invalidAttachment("el nombre «\(attachment.filename)» no es válido")
            }
            guard names.insert(name.lowercased()).inserted else {
                throw MultimediaInspectorError.invalidAttachment("hay más de un adjunto llamado «\(name)»")
            }
            let mime = attachment.mimeType.trimmingCharacters(in: .whitespacesAndNewlines)
            let pieces = mime.split(separator: "/", omittingEmptySubsequences: false)
            guard pieces.count == 2, pieces.allSatisfy({ !$0.isEmpty }), !mime.contains("\n"), !mime.contains("\r") else {
                throw MultimediaInspectorError.invalidAttachment("el MIME «\(attachment.mimeType)» no es válido")
            }
            if case .external(let url, let fingerprint) = attachment.source {
                try validateExternalFile(url: url, fingerprint: fingerprint)
            }
        }
    }

    private func validateChapters(_ chapters: [MediaEditableChapter], duration: Double?) throws {
        guard !chapters.isEmpty else { return }
        guard let duration, duration.isFinite, duration > 0 else {
            throw MultimediaInspectorError.invalidChapter("no se conoce una duración fiable para construir capítulos")
        }
        let sorted = chapters.sorted { $0.startTime < $1.startTime }
        var previous: Double?
        for chapter in sorted {
            guard chapter.startTime.isFinite, chapter.startTime >= 0, chapter.startTime < duration else {
                throw MultimediaInspectorError.invalidChapter("hay un capítulo fuera de la duración del archivo")
            }
            if let previous, chapter.startTime - previous < 0.001 {
                throw MultimediaInspectorError.invalidChapter("dos capítulos empiezan en el mismo instante")
            }
            previous = chapter.startTime
        }
    }

    private func validateMetadata(_ metadata: MediaMetadataDraft, container: EditableMediaContainer) throws {
        for key in metadata.touchedContainerKeys where !metadataCompatibility.supportsContainerKey(key, container: container) {
            throw MultimediaInspectorError.unsupportedMetadata("el campo \(key) no es editable de forma segura en \(container.displayName)")
        }
        for (_, keys) in metadata.touchedVideoKeysByStream {
            for key in keys where !metadataCompatibility.supportsVideoKey(key, container: container) {
                throw MultimediaInspectorError.unsupportedMetadata("el campo de vídeo \(key) no es editable de forma segura en \(container.displayName)")
            }
        }
    }

    private func validateExternalFile(url: URL, fingerprint: FileFingerprint) throws {
        guard FileManager.default.fileExists(atPath: url.path) else { throw MultimediaInspectorError.inputMissing(url.lastPathComponent) }
        let values = try? url.resourceValues(forKeys: [.isSymbolicLinkKey, .isRegularFileKey])
        guard values?.isSymbolicLink != true, values?.isRegularFile == true else { throw MultimediaInspectorError.inputChanged(url.lastPathComponent) }
        guard fingerprint.matches(url) else { throw MultimediaInspectorError.inputChanged(url.lastPathComponent) }
    }
}
