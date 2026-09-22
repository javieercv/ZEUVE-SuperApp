import Foundation
import ZEUVEEngines

public actor MultimediaResultValidator {
    private let inspector: MediaInspectionService
    public init(inspector: MediaInspectionService = MediaInspectionService()) { self.inspector = inspector }

    public func validate(url: URL, plan: MediaEditPlan, original: MediaInspectionResult, ffprobe: URL) async throws -> MediaInspectionResult {
        let values = try url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
        guard values.isRegularFile == true, (values.fileSize ?? 0) > 0 else { throw MultimediaInspectorError.invalidOutput("FFmpeg no generó un archivo regular") }
        let result = try await inspector.inspect(url: url, ffprobe: ffprobe, useCache: false)

        guard result.videoStreams.count == plan.videoTracks.count else { throw MultimediaInspectorError.validationFailed("el número de pistas de vídeo no coincide con el plan") }
        guard result.audioStreams.count == plan.audioTracks.count else { throw MultimediaInspectorError.validationFailed("el número de pistas de audio no coincide con el plan") }
        guard result.subtitleStreams.count == plan.subtitleTracks.count else { throw MultimediaInspectorError.validationFailed("el número de subtítulos no coincide con el plan") }

        for (expected, actual) in zip(plan.videoTracks, result.videoStreams) {
            guard sameCodec(expected.outputCodec, actual.codec_name) else { throw MultimediaInspectorError.validationFailed("una pista de vídeo no conserva su códec") }
            try validateTrackMetadata(expected.track, actual: actual)
        }
        for (expected, actual) in zip(plan.audioTracks, result.audioStreams) {
            guard sameCodec(expected.outputCodec, actual.codec_name) else { throw MultimediaInspectorError.validationFailed("una pista de audio no conserva su códec") }
            try validateTrackMetadata(expected.track, actual: actual)
        }
        for (expected, actual) in zip(plan.subtitleTracks, result.subtitleStreams) {
            guard sameCodec(expected.outputCodec, actual.codec_name) else { throw MultimediaInspectorError.validationFailed("un subtítulo no utiliza el códec previsto") }
            try validateTrackMetadata(expected.track, actual: actual)
        }
        let resultAttachedPictures = result.streams.filter { $0.codec_type == "video" && $0.isAttachedPicture }
        guard resultAttachedPictures.count == plan.artworks.count else { throw MultimediaInspectorError.validationFailed("el número de carátulas no coincide con el plan") }
        for (planned, actual) in zip(plan.artworks, resultAttachedPictures) {
            guard sameCodec(planned.artwork.codec, actual.codec_name) else { throw MultimediaInspectorError.validationFailed("una carátula no conserva el códec previsto") }
            if !planned.artwork.title.isEmpty, planned.artwork.title != actual.title { throw MultimediaInspectorError.validationFailed("el título de una carátula no coincide") }
        }

        let originalOther = original.streams.filter { !["video", "audio", "subtitle", "attachment"].contains($0.codec_type ?? "") }
        let resultOther = result.streams.filter { !["video", "audio", "subtitle", "attachment"].contains($0.codec_type ?? "") }
        guard resultOther.count == originalOther.count else { throw MultimediaInspectorError.validationFailed("no se han preservado todos los streams auxiliares") }
        for (before, after) in zip(originalOther, resultOther) {
            guard before.codec_type == after.codec_type, sameCodec(before.codec_name, after.codec_name) else {
                throw MultimediaInspectorError.validationFailed("un stream auxiliar ha cambiado de tipo o códec")
            }
        }

        try validateChapters(plan.chapters, actual: result.chapters ?? [])
        try validateAttachments(plan.attachments, actual: result.attachmentStreams)
        try validateManagedMetadata(plan, actual: result)

        guard (result.programs?.count ?? 0) == (original.programs?.count ?? 0) else { throw MultimediaInspectorError.validationFailed("no se han preservado los programas multimedia") }
        return result
    }

    private func validateTrackMetadata(_ expected: MediaEditableTrack, actual: MediaInspectionStream) throws {
        let expLang = expected.language.trimmingCharacters(in: .whitespacesAndNewlines)
        let expTitle = expected.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !expLang.isEmpty, actual.language != expLang { throw MultimediaInspectorError.validationFailed("el idioma de una pista no coincide") }
        if !expTitle.isEmpty, actual.title != expTitle { throw MultimediaInspectorError.validationFailed("el título de una pista no coincide") }
        guard actual.isDefault == expected.isDefault else { throw MultimediaInspectorError.validationFailed("el flag default no coincide") }
        if expected.kind == .subtitle, actual.isForced != expected.isForced { throw MultimediaInspectorError.validationFailed("el flag forced no coincide") }
    }

    private func validateChapters(_ expected: [PlannedChapter], actual: [MediaInspectionChapter]) throws {
        guard actual.count == expected.count else { throw MultimediaInspectorError.validationFailed("el número de capítulos no coincide con el plan") }
        for (planned, chapter) in zip(expected, actual) {
            guard let start = MultimediaChapterTimeParser.seconds(chapter.start_time), abs(start - planned.startTime) <= 0.01 else {
                throw MultimediaInspectorError.validationFailed("el inicio de un capítulo no coincide")
            }
            if let end = MultimediaChapterTimeParser.seconds(chapter.end_time), abs(end - planned.endTime) > 0.02 {
                throw MultimediaInspectorError.validationFailed("el final de un capítulo no coincide")
            }
            let title = chapter.tags?.firstValue(caseInsensitiveKey: "title") ?? ""
            if title != planned.title { throw MultimediaInspectorError.validationFailed("el título de un capítulo no coincide") }
        }
    }

    private func validateAttachments(_ expected: [PlannedAttachment], actual: [MediaInspectionStream]) throws {
        guard actual.count == expected.count else { throw MultimediaInspectorError.validationFailed("el número de adjuntos no coincide con el plan") }
        for (planned, stream) in zip(expected, actual) {
            let filename = stream.tags?.firstValue(caseInsensitiveKey: "filename") ?? stream.title ?? ""
            let mime = stream.tags?.firstValue(caseInsensitiveKey: "mimetype") ?? stream.tags?.firstValue(caseInsensitiveKey: "mime_type") ?? ""
            if filename != planned.attachment.filename { throw MultimediaInspectorError.validationFailed("el nombre de un adjunto no coincide") }
            if !planned.attachment.mimeType.isEmpty, mime.caseInsensitiveCompare(planned.attachment.mimeType) != .orderedSame {
                throw MultimediaInspectorError.validationFailed("el MIME de un adjunto no coincide")
            }
            if planned.action == .keep, !sameCodec(planned.attachment.codec, stream.codec_name) {
                throw MultimediaInspectorError.validationFailed("un adjunto original ha cambiado de códec")
            }
        }
    }

    private func validateManagedMetadata(_ plan: MediaEditPlan, actual: MediaInspectionResult) throws {
        for key in plan.metadata.touchedContainerKeys {
            let expected = plan.metadata.containerValues[key] ?? ""
            let actualValue = actual.format?.tags?.firstValue(caseInsensitiveKey: key) ?? ""
            if actualValue != expected { throw MultimediaInspectorError.validationFailed("el metadato global \(key) no coincide") }
        }
        for (streamIndex, keys) in plan.metadata.touchedVideoKeysByStream {
            guard let ordinal = plan.originalVideoStreamIndices.firstIndex(of: streamIndex), ordinal < actual.streams.filter({ $0.codec_type == "video" }).count else {
                throw MultimediaInspectorError.validationFailed("no se ha localizado el stream de vídeo para validar metadatos")
            }
            let videoStreams = actual.streams.filter { $0.codec_type == "video" }
            let stream = videoStreams[ordinal]
            let values = plan.metadata.videoValuesByStream[streamIndex] ?? [:]
            for key in keys {
                let expected = values[key] ?? ""
                let actualValue = stream.tags?.firstValue(caseInsensitiveKey: key) ?? ""
                if actualValue != expected { throw MultimediaInspectorError.validationFailed("el metadato de vídeo \(key) no coincide") }
            }
        }
    }

    private func sameCodec(_ lhs: String?, _ rhs: String?) -> Bool {
        func n(_ s: String?) -> String {
            let v = (s ?? "").lowercased()
            return v == "srt" ? "subrip" : (v == "h265" ? "hevc" : v)
        }
        return n(lhs) == n(rhs)
    }
}

private extension Dictionary where Key == String, Value == String {
    func firstValue(caseInsensitiveKey key: String) -> String? {
        first { $0.key.caseInsensitiveCompare(key) == .orderedSame }?.value
    }
}
