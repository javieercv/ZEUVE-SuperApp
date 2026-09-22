import Foundation
import ZEUVECore
import ZEUVEEngines

public enum EditableMediaContainer: String, Codable, CaseIterable, Sendable, Identifiable {
    case mkv, mp4, mov, webm
    public var id: String { rawValue }
    public var fileExtension: String { rawValue }
    public var displayName: String { rawValue.uppercased() }
    public static func detect(from result: MediaInspectionResult, url: URL) -> EditableMediaContainer? {
        let names = (result.format?.format_name ?? "").lowercased().split(separator: ",").map(String.init)
        if names.contains("matroska") || url.pathExtension.lowercased() == "mkv" { return .mkv }
        if url.pathExtension.lowercased() == "mov" { return .mov }
        if names.contains("webm") || url.pathExtension.lowercased() == "webm" { return .webm }
        if names.contains("mov") || names.contains("mp4") || url.pathExtension.lowercased() == "mp4" { return .mp4 }
        return nil
    }
}

public struct MediaEditDraft: Sendable, Equatable {
    public let originalURL: URL
    public let originalFingerprint: FileFingerprint
    public let originalInspection: MediaInspectionResult
    public let originalContainer: EditableMediaContainer
    public var targetContainer: EditableMediaContainer
    public var videoTracks: [MediaEditableTrack]
    public var audioTracks: [MediaEditableTrack]
    public var subtitleTracks: [MediaEditableTrack]
    public var chapters: [MediaEditableChapter]
    public var attachments: [MediaEditableAttachment]
    public var artworks: [MediaEditableArtwork]
    public var metadata: MediaMetadataDraft
    public var authorizedSubtitleConversions: Set<UUID>

    public init(originalURL: URL, originalFingerprint: FileFingerprint, inspection: MediaInspectionResult, container: EditableMediaContainer) throws {
        let sourceValues = try? originalURL.resourceValues(forKeys: [.isSymbolicLinkKey, .isRegularFileKey])
        guard sourceValues?.isSymbolicLink != true, sourceValues?.isRegularFile == true else {
            throw MultimediaInspectorError.notEditable("para proteger la identidad del original, la edición requiere un archivo regular y no un enlace simbólico")
        }
        let video = inspection.videoStreams.compactMap { MediaEditableTrack.from(stream: $0, kind: .video) }
        let audio = inspection.audioStreams.compactMap { MediaEditableTrack.from(stream: $0, kind: .audio) }
        let subtitles = inspection.subtitleStreams.compactMap { MediaEditableTrack.from(stream: $0, kind: .subtitle) }
        guard video.count == inspection.videoStreams.count, audio.count == inspection.audioStreams.count, subtitles.count == inspection.subtitleStreams.count else {
            throw MultimediaInspectorError.notEditable("faltan índices de stream necesarios para construir un plan seguro")
        }
        let sourceChapters = inspection.chapters ?? []
        let chapters = sourceChapters.enumerated().compactMap { MediaEditableChapter.from($0.element, offset: $0.offset) }.sorted { $0.startTime < $1.startTime }
        guard chapters.count == sourceChapters.count else {
            throw MultimediaInspectorError.notEditable("hay capítulos con tiempos que no pueden representarse de forma segura")
        }
        let attachments = inspection.attachmentStreams.enumerated().compactMap { MediaEditableAttachment.from(stream: $0.element, offset: $0.offset) }
        guard attachments.count == inspection.attachmentStreams.count else {
            throw MultimediaInspectorError.notEditable("faltan índices necesarios para preservar los adjuntos")
        }
        self.originalURL = originalURL
        self.originalFingerprint = originalFingerprint
        self.originalInspection = inspection
        self.originalContainer = container
        self.targetContainer = container
        self.videoTracks = video
        self.audioTracks = audio
        self.subtitleTracks = subtitles
        self.chapters = chapters
        self.attachments = attachments
        self.artworks = inspection.streams.compactMap(MediaEditableArtwork.from(stream:))
        self.metadata = MediaMetadataDraft.from(inspection: inspection)
        self.authorizedSubtitleConversions = []
    }
}

public struct MediaEditDraftHistory: Sendable {
    public private(set) var current: MediaEditDraft
    public private(set) var undoStack: [MediaEditDraft] = []
    public private(set) var redoStack: [MediaEditDraft] = []
    public let initial: MediaEditDraft
    public init(_ draft: MediaEditDraft) { current = draft; initial = draft }
    public var canUndo: Bool { !undoStack.isEmpty }
    public var canRedo: Bool { !redoStack.isEmpty }
    public var isDirty: Bool { current != initial }

    public mutating func perform(_ change: (inout MediaEditDraft) -> Void) {
        var next = current; change(&next); guard next != current else { return }
        undoStack.append(current); current = next; redoStack.removeAll(keepingCapacity: true)
    }
    @discardableResult public mutating func undo() -> Bool { guard let previous = undoStack.popLast() else { return false }; redoStack.append(current); current = previous; return true }
    @discardableResult public mutating func redo() -> Bool { guard let next = redoStack.popLast() else { return false }; undoStack.append(current); current = next; return true }
}
