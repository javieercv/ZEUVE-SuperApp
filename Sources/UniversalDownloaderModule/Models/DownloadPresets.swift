import Foundation

public struct UniversalDownloadPreset: Codable, Sendable, Equatable, Identifiable {
    public let id: UUID
    public var schemaVersion: Int
    public var name: String
    public var settings: UniversalDownloadSettings
    public var isFavorite: Bool
    public var modifiedAt: Date

    public init(id: UUID = UUID(), schemaVersion: Int = 2, name: String, settings: UniversalDownloadSettings, isFavorite: Bool = false, modifiedAt: Date = Date()) {
        self.id = id
        self.schemaVersion = schemaVersion
        self.name = name
        self.settings = settings
        self.isFavorite = isFavorite
        self.modifiedAt = modifiedAt
    }
}
