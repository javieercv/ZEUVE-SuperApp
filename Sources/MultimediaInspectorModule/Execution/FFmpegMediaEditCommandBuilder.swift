import Foundation
import ZEUVEEngines

public struct FFmpegMediaEditPreparedCommand: Sendable, Equatable {
    public let request: ExternalProcessRequest
    public let outputURL: URL
}

public struct FFmpegMediaEditCommandBuilder: Sendable {
    public init() {}

    public func command(
        ffmpeg: URL,
        plan: MediaEditPlan,
        outputURL: URL,
        chapterMetadataURL: URL? = nil
    ) throws -> FFmpegMediaEditPreparedCommand {
        var arguments = ["-hide_banner", "-nostdin", "-y", "-i", plan.originalURL.path]
        var externalInputs: [String: Int] = [:]
        var nextInput = 1
        for track in plan.videoTracks + plan.audioTracks + plan.subtitleTracks {
            if case .external(let url, _, _) = track.track.source {
                let key = canonical(url)
                if externalInputs[key] == nil {
                    externalInputs[key] = nextInput
                    nextInput += 1
                    arguments += ["-i", url.path]
                }
            }
        }
        for item in plan.artworks {
            if case .external(let url, _, _) = item.artwork.source {
                let key = canonical(url)
                if externalInputs[key] == nil { externalInputs[key] = nextInput; nextInput += 1; arguments += ["-i", url.path] }
            }
        }
        var chapterInput: Int?
        if let chapterMetadataURL, !plan.chapters.isEmpty {
            chapterInput = nextInput
            nextInput += 1
            arguments += ["-f", "ffmetadata", "-i", chapterMetadataURL.path]
        }

        let managedOriginalTracks = Set(
            plan.videoTracks.compactMap { if case .original(let i) = $0.track.source { i } else { nil } }
            + plan.audioTracks.compactMap { if case .original(let i) = $0.track.source { i } else { nil } }
            + plan.subtitleTracks.compactMap { if case .original(let i) = $0.track.source { i } else { nil } }
            + plan.removedOriginalStreamIndices
            + plan.removedAttachments.compactMap { $0.attachment.source.originalStreamIndex }
            + plan.artworks.compactMap { $0.artwork.source.originalStreamIndex }
            + plan.removedArtworks.compactMap { $0.artwork.source.originalStreamIndex }
        )
        arguments += ["-map", "0"]
        for index in managedOriginalTracks.sorted() { arguments += ["-map", "-0:\(index)"] }
        for item in plan.videoTracks { arguments += ["-map", mapSpecifier(item.track.source, externalInputs: externalInputs)] }
        for item in plan.audioTracks { arguments += ["-map", mapSpecifier(item.track.source, externalInputs: externalInputs)] }
        for item in plan.subtitleTracks { arguments += ["-map", mapSpecifier(item.track.source, externalInputs: externalInputs)] }
        for item in plan.artworks { arguments += ["-map", artworkMapSpecifier(item.artwork.source, externalInputs: externalInputs)] }

        if plan.preserveMetadata { arguments += ["-map_metadata", "0"] }
        else { arguments += ["-map_metadata", "-1"] }

        if let chapterInput { arguments += ["-map_chapters", "\(chapterInput)"] }
        else { arguments += ["-map_chapters", "-1"] }

        arguments += ["-c", "copy"]

        for (i, item) in plan.videoTracks.enumerated() {
            arguments += ["-metadata:s:v:\(i)", "language=\(item.track.language)", "-metadata:s:v:\(i)", "title=\(item.track.title)", "-disposition:v:\(i)", dispositionValue(item.track, includeForced: false)]
        }
        for (i, item) in plan.audioTracks.enumerated() {
            arguments += ["-metadata:s:a:\(i)", "language=\(item.track.language)", "-metadata:s:a:\(i)", "title=\(item.track.title)", "-disposition:a:\(i)", dispositionValue(item.track, includeForced: false)]
        }
        for (i, item) in plan.subtitleTracks.enumerated() {
            if item.action == .convertSubtitle { arguments += ["-c:s:\(i)", item.outputCodec] }
            arguments += ["-metadata:s:s:\(i)", "language=\(item.track.language)", "-metadata:s:s:\(i)", "title=\(item.track.title)", "-disposition:s:\(i)", dispositionValue(item.track, includeForced: true)]
        }

        for (i, item) in plan.artworks.enumerated() {
            let ordinal = plan.videoTracks.count + i
            arguments += ["-disposition:v:\(ordinal)", "attached_pic"]
            if !item.artwork.title.isEmpty { arguments += ["-metadata:s:v:\(ordinal)", "title=\(item.artwork.title)"] }
        }

        let existingAttachments = plan.attachments.filter { $0.action == .keep }
        let addedAttachments = plan.attachments.filter { $0.action == .add }
        for item in addedAttachments {
            guard case .external(let url, _) = item.attachment.source else { continue }
            arguments += ["-attach", url.path]
        }
        for (ordinal, item) in (existingAttachments + addedAttachments).enumerated() {
            arguments += ["-metadata:s:t:\(ordinal)", "filename=\(item.attachment.filename)"]
            arguments += ["-metadata:s:t:\(ordinal)", "mimetype=\(item.attachment.mimeType)"]
        }

        appendManagedMetadata(plan.metadata, plan: plan, arguments: &arguments)
        arguments.append(outputURL.path)
        return .init(request: ExternalProcessRequest(executable: ffmpeg, arguments: arguments), outputURL: outputURL)
    }

    private func appendManagedMetadata(_ metadata: MediaMetadataDraft, plan: MediaEditPlan, arguments: inout [String]) {
        for key in metadata.touchedContainerKeys.sorted() {
            let value = metadata.containerValues[key] ?? ""
            arguments += ["-metadata", "\(key)=\(value)"]
        }
        for (streamIndex, keys) in metadata.touchedVideoKeysByStream.sorted(by: { $0.key < $1.key }) {
            guard let ordinal = plan.originalVideoStreamIndices.firstIndex(of: streamIndex) else { continue }
            let values = metadata.videoValuesByStream[streamIndex] ?? [:]
            for key in keys.sorted() {
                arguments += ["-metadata:s:v:\(ordinal)", "\(key)=\(values[key] ?? "")"]
            }
        }
    }

    private func dispositionValue(_ track: MediaEditableTrack, includeForced: Bool) -> String {
        var values = track.preservedDispositions
        if track.isDefault { values.append("default") }
        if includeForced && track.isForced { values.append("forced") }
        let unique = Array(Set(values)).sorted()
        return unique.isEmpty ? "0" : unique.joined(separator: "+")
    }

    private func artworkMapSpecifier(_ source: MediaArtworkSource, externalInputs: [String: Int]) -> String {
        switch source {
        case .original(let streamIndex): return "0:\(streamIndex)"
        case .external(let url, _, let streamIndex): return "\(externalInputs[canonical(url)] ?? 1):\(streamIndex)"
        }
    }

    private func mapSpecifier(_ source: MediaTrackSource, externalInputs: [String: Int]) -> String {
        switch source {
        case .original(let streamIndex): return "0:\(streamIndex)"
        case .external(let url, _, let streamIndex):
            let input = externalInputs[canonical(url)] ?? 1
            return "\(input):\(streamIndex)"
        }
    }

    private func canonical(_ url: URL) -> String {
        url.standardizedFileURL.resolvingSymlinksInPath().path
    }
}
