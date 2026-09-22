import Foundation
import ZEUVEStorage

public final class MultimediaInspectorRuleSetStore: @unchecked Sendable {
    public static let currentSchemaVersion = 1
    private let repository: SettingsRepository?
    public init(repository: SettingsRepository?) { self.repository = repository }

    public func load() -> [MultimediaBatchRuleSet] {
        guard let stored = try? repository?.value(forKey: MultimediaInspectorStorageKeys.ruleSets, as: [MultimediaBatchRuleSet].self) else { return [] }
        return (stored ?? []).compactMap(Self.normalize)
    }

    public func save(_ ruleSets: [MultimediaBatchRuleSet]) throws {
        let normalized = ruleSets.compactMap(Self.normalize)
        guard normalized.count == ruleSets.count else { throw MultimediaInspectorError.invalidInput }
        try repository?.set(normalized, forKey: MultimediaInspectorStorageKeys.ruleSets)
    }

    private static func normalize(_ value: MultimediaBatchRuleSet) -> MultimediaBatchRuleSet? {
        guard value.schemaVersion <= currentSchemaVersion else { return nil }
        var copy = value
        copy.schemaVersion = currentSchemaVersion
        copy.name = copy.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !copy.name.isEmpty else { return nil }
        for index in copy.rules.indices {
            copy.rules[index].name = copy.rules[index].name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !copy.rules[index].name.isEmpty else { return nil }
        }
        return copy
    }
}
