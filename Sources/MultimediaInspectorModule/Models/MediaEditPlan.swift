import Foundation
import ZEUVECore

public enum PlannedTrackAction: String, Codable, Sendable { case keep, add, remove, convertSubtitle }
public struct PlannedTrack: Identifiable, Sendable, Equatable {
    public let id: UUID
    public let kind: MediaTrackKind
    public let track: MediaEditableTrack
    public let action: PlannedTrackAction
    public let outputCodec: String
    public init(track: MediaEditableTrack, action: PlannedTrackAction, outputCodec: String) { id = track.id; kind = track.kind; self.track = track; self.action = action; self.outputCodec = outputCodec }
}

public struct PlannedChapter: Identifiable, Sendable, Equatable {
    public let id: UUID
    public let startTime: Double
    public let endTime: Double
    public let title: String
    public let preservedTags: [String: String]
    public init(chapter: MediaEditableChapter, endTime: Double) {
        id = chapter.id
        startTime = chapter.startTime
        self.endTime = endTime
        title = chapter.title
        preservedTags = chapter.preservedTags
    }
}

public enum PlannedAttachmentAction: String, Codable, Sendable { case keep, add, remove }
public struct PlannedAttachment: Identifiable, Sendable, Equatable {
    public let id: UUID
    public let attachment: MediaEditableAttachment
    public let action: PlannedAttachmentAction
    public init(attachment: MediaEditableAttachment, action: PlannedAttachmentAction) {
        id = attachment.id
        self.attachment = attachment
        self.action = action
    }
}


public enum PlannedArtworkAction: String, Codable, Sendable { case keep, add, remove }
public struct PlannedArtwork: Identifiable, Sendable, Equatable {
    public let id: UUID
    public let artwork: MediaEditableArtwork
    public let action: PlannedArtworkAction
    public init(artwork: MediaEditableArtwork, action: PlannedArtworkAction) { id = artwork.id; self.artwork = artwork; self.action = action }
}

public struct MediaEditPlan: Sendable, Equatable {
    public let id: UUID
    public let originalURL: URL
    public let originalFingerprint: FileFingerprint
    public let targetContainer: EditableMediaContainer
    public let videoTracks: [PlannedTrack]
    public let audioTracks: [PlannedTrack]
    public let subtitleTracks: [PlannedTrack]
    public let originalVideoStreamIndices: [Int]
    public let chapters: [PlannedChapter]
    public let attachments: [PlannedAttachment]
    public let artworks: [PlannedArtwork]
    public let removedArtworks: [PlannedArtwork]
    public let removedAttachments: [PlannedAttachment]
    public let metadata: MediaMetadataDraft
    public let preserveMetadata: Bool
    public let removedOriginalStreamIndices: [Int]
    public let removedTracks: [PlannedTrack]
    public let warnings: [String]

    public init(
        id: UUID = UUID(),
        originalURL: URL,
        originalFingerprint: FileFingerprint,
        targetContainer: EditableMediaContainer,
        videoTracks: [PlannedTrack] = [],
        audioTracks: [PlannedTrack],
        subtitleTracks: [PlannedTrack],
        originalVideoStreamIndices: [Int] = [],
        chapters: [PlannedChapter] = [],
        attachments: [PlannedAttachment] = [],
        artworks: [PlannedArtwork] = [],
        removedArtworks: [PlannedArtwork] = [],
        removedAttachments: [PlannedAttachment] = [],
        metadata: MediaMetadataDraft = .init(),
        preserveMetadata: Bool = true,
        removedOriginalStreamIndices: [Int],
        removedTracks: [PlannedTrack] = [],
        warnings: [String]
    ) {
        self.id = id
        self.originalURL = originalURL
        self.originalFingerprint = originalFingerprint
        self.targetContainer = targetContainer
        self.videoTracks = videoTracks
        self.audioTracks = audioTracks
        self.subtitleTracks = subtitleTracks
        self.originalVideoStreamIndices = originalVideoStreamIndices
        self.chapters = chapters
        self.attachments = attachments
        self.artworks = artworks
        self.removedArtworks = removedArtworks
        self.removedAttachments = removedAttachments
        self.metadata = metadata
        self.preserveMetadata = preserveMetadata
        self.removedOriginalStreamIndices = removedOriginalStreamIndices
        self.removedTracks = removedTracks
        self.warnings = warnings
    }
}
