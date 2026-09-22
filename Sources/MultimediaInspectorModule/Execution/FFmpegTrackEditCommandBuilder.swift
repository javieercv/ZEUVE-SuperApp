import Foundation
import ZEUVEEngines

@available(*, deprecated, renamed: "FFmpegMediaEditPreparedCommand")
public typealias FFmpegTrackEditPreparedCommand = FFmpegMediaEditPreparedCommand

@available(*, deprecated, message: "Usa FFmpegMediaEditCommandBuilder. Se conserva como adaptador de compatibilidad interna.")
public struct FFmpegTrackEditCommandBuilder: Sendable {
    private let preserveMetadata: Bool
    public init(preserveMetadata: Bool = true) { self.preserveMetadata = preserveMetadata }

    public func command(ffmpeg: URL, plan: MediaEditPlan, outputURL: URL) throws -> FFmpegTrackEditPreparedCommand {
        let compatiblePlan = MediaEditPlan(
            id: plan.id,
            originalURL: plan.originalURL,
            originalFingerprint: plan.originalFingerprint,
            targetContainer: plan.targetContainer,
            audioTracks: plan.audioTracks,
            subtitleTracks: plan.subtitleTracks,
            originalVideoStreamIndices: plan.originalVideoStreamIndices,
            chapters: plan.chapters,
            attachments: plan.attachments,
            removedAttachments: plan.removedAttachments,
            metadata: plan.metadata,
            preserveMetadata: preserveMetadata,
            removedOriginalStreamIndices: plan.removedOriginalStreamIndices,
            removedTracks: plan.removedTracks,
            warnings: plan.warnings
        )
        return try FFmpegMediaEditCommandBuilder().command(ffmpeg: ffmpeg, plan: compatiblePlan, outputURL: outputURL)
    }
}
