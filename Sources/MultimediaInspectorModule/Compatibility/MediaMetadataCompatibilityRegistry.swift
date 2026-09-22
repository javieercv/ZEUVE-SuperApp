import Foundation

public struct MediaMetadataCompatibilityRegistry: Sendable {
    public let editableContainerKeys: [String] = [
        "title", "artist", "album", "album_artist", "composer", "genre", "date", "comment", "copyright"
    ]
    public let editableVideoKeys: [String] = ["title"]

    public init() {}

    public func supportsContainerKey(_ key: String, container: EditableMediaContainer) -> Bool {
        let normalized = key.lowercased()
        guard editableContainerKeys.contains(normalized) else { return false }
        switch container {
        case .mkv: return true
        case .mp4, .mov:
            return ["title", "artist", "album", "album_artist", "composer", "genre", "date", "comment", "copyright"].contains(normalized)
        case .webm:
            return ["title", "artist", "album", "composer", "genre", "date", "comment", "copyright"].contains(normalized)
        }
    }

    public func supportsVideoKey(_ key: String, container: EditableMediaContainer) -> Bool {
        editableVideoKeys.contains(key.lowercased()) && container != .webm
    }
}
