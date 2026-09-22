import Foundation
import ZEUVEStorage

public enum MultimediaInspectorFavoriteKind: String, Codable, Sendable, CaseIterable {
    case batchPreset, structuralRuleSet
}

public struct MultimediaInspectorFavorite: Codable, Sendable, Equatable, Identifiable {
    public let id: UUID
    public let kind: MultimediaInspectorFavoriteKind
    public let referencedID: UUID
    public var displayName: String
    public var modifiedAt: Date

    public init(id: UUID = UUID(), kind: MultimediaInspectorFavoriteKind, referencedID: UUID, displayName: String, modifiedAt: Date = Date()) {
        self.id = id; self.kind = kind; self.referencedID = referencedID; self.displayName = displayName; self.modifiedAt = modifiedAt
    }
}

public final class MultimediaInspectorFavoritesStore: @unchecked Sendable {
    public static let currentSchemaVersion = 1
    private struct Payload: Codable { var schemaVersion: Int; var items: [MultimediaInspectorFavorite] }
    private let repository: SettingsRepository?
    public init(repository: SettingsRepository?) { self.repository = repository }

    public func load() -> [MultimediaInspectorFavorite] {
        guard let repository else { return [] }
        do {
            guard let payload = try repository.value(forKey: MultimediaInspectorStorageKeys.favorites, as: Payload.self) else { return [] }
            guard payload.schemaVersion <= Self.currentSchemaVersion else { return [] }
            return payload.items.compactMap(Self.normalize)
        } catch {
            return []
        }
    }

    public func save(_ items: [MultimediaInspectorFavorite]) throws {
        let normalized = items.compactMap(Self.normalize)
        guard normalized.count == items.count else { throw MultimediaInspectorError.invalidInput }
        try repository?.set(Payload(schemaVersion: Self.currentSchemaVersion, items: normalized), forKey: MultimediaInspectorStorageKeys.favorites)
    }

    public func setFavorite(kind: MultimediaInspectorFavoriteKind, referencedID: UUID, displayName: String, favorite: Bool) throws -> [MultimediaInspectorFavorite] {
        var items = load()
        items.removeAll { $0.kind == kind && $0.referencedID == referencedID }
        if favorite {
            guard let item = Self.normalize(.init(kind: kind, referencedID: referencedID, displayName: displayName)) else { throw MultimediaInspectorError.invalidInput }
            items.append(item)
        }
        try save(items)
        return items
    }

    private static func normalize(_ value: MultimediaInspectorFavorite) -> MultimediaInspectorFavorite? {
        let name = value.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, !name.contains("/"), !name.contains("\\"), name.count <= 160 else { return nil }
        return .init(id: value.id, kind: value.kind, referencedID: value.referencedID, displayName: name, modifiedAt: value.modifiedAt)
    }
}
