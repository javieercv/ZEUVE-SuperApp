import Foundation
import ZEUVEEngines

public enum MultimediaBatchRuleMatch: String, Codable, Sendable, CaseIterable, Identifiable {
    case equals, notEquals, contains, isEmpty, isNotEmpty
    public var id: String { rawValue }
    public var displayName: String { switch self { case .equals: return "Es igual a"; case .notEquals: return "No es igual a"; case .contains: return "Contiene"; case .isEmpty: return "Está vacío"; case .isNotEmpty: return "No está vacío" } }
}

public enum MultimediaBatchRuleField: String, Codable, Sendable, CaseIterable, Identifiable {
    case codec, language, title, isDefault, isForced
    public var id: String { rawValue }
    public var displayName: String { switch self { case .codec: return "Códec"; case .language: return "Idioma"; case .title: return "Título"; case .isDefault: return "Default"; case .isForced: return "Forced" } }
}

public struct MultimediaBatchRuleCondition: Codable, Sendable, Equatable, Identifiable {
    public let id: UUID
    public var kind: MediaTrackKind
    public var field: MultimediaBatchRuleField
    public var match: MultimediaBatchRuleMatch
    public var value: String

    public init(id: UUID = UUID(), kind: MediaTrackKind, field: MultimediaBatchRuleField, match: MultimediaBatchRuleMatch = .equals, value: String = "") {
        self.id = id; self.kind = kind; self.field = field; self.match = match; self.value = value
    }
}

public enum MultimediaBatchRuleAction: Codable, Sendable, Equatable {
    case remove
    case setLanguage(String)
    case setTitle(String)
    case setDefault(Bool)
    case setForced(Bool)
}

public struct MultimediaBatchStructuralRule: Codable, Sendable, Equatable, Identifiable {
    public let id: UUID
    public var name: String
    public var enabled: Bool
    public var conditions: [MultimediaBatchRuleCondition]
    public var action: MultimediaBatchRuleAction

    public init(id: UUID = UUID(), name: String, enabled: Bool = true, conditions: [MultimediaBatchRuleCondition], action: MultimediaBatchRuleAction) {
        self.id = id; self.name = name; self.enabled = enabled; self.conditions = conditions; self.action = action
    }
}

public struct MultimediaBatchRuleSet: Codable, Sendable, Equatable, Identifiable {
    public let id: UUID
    public var schemaVersion: Int
    public var name: String
    public var rules: [MultimediaBatchStructuralRule]
    public var modifiedAt: Date

    public init(id: UUID = UUID(), schemaVersion: Int = 1, name: String, rules: [MultimediaBatchStructuralRule], modifiedAt: Date = Date()) {
        self.id = id; self.schemaVersion = schemaVersion; self.name = name; self.rules = rules; self.modifiedAt = modifiedAt
    }
}

public struct MultimediaBatchRuleApplication: Sendable, Equatable {
    public let draft: MediaEditDraft
    public let appliedRuleNames: [String]
    public let warnings: [String]
}

public struct MultimediaBatchRuleEngine: Sendable {
    public init() {}

    public func apply(_ ruleSet: MultimediaBatchRuleSet, to inputDraft: MediaEditDraft) -> MultimediaBatchRuleApplication {
        var draft = inputDraft
        var applied: [String] = []
        var warnings: [String] = []
        for rule in ruleSet.rules where rule.enabled {
            var didApply = false
            apply(rule: rule, tracks: &draft.videoTracks, didApply: &didApply, warnings: &warnings)
            apply(rule: rule, tracks: &draft.audioTracks, didApply: &didApply, warnings: &warnings)
            apply(rule: rule, tracks: &draft.subtitleTracks, didApply: &didApply, warnings: &warnings)
            if didApply { applied.append(rule.name) }
        }
        return .init(draft: draft, appliedRuleNames: applied, warnings: warnings)
    }

    private func apply(rule: MultimediaBatchStructuralRule, tracks: inout [MediaEditableTrack], didApply: inout Bool, warnings: inout [String]) {
        guard rule.conditions.allSatisfy({ $0.kind == tracks.first?.kind || tracks.isEmpty }) || rule.conditions.isEmpty else {
            // Las condiciones de otro tipo se evalúan en su colección correspondiente.
            return
        }
        var output: [MediaEditableTrack] = []
        for var track in tracks {
            let relevant = rule.conditions.filter { $0.kind == track.kind }
            guard !relevant.isEmpty, relevant.allSatisfy({ matches($0, track: track) }) else { output.append(track); continue }
            switch rule.action {
            case .remove:
                didApply = true
                continue
            case .setLanguage(let value): track.language = sanitized(value); didApply = true
            case .setTitle(let value): track.title = sanitized(value); didApply = true
            case .setDefault(let value): track.isDefault = value; didApply = true
            case .setForced(let value):
                if track.kind == .subtitle { track.isForced = value; didApply = true }
                else { warnings.append("La regla «\(rule.name)» intentó aplicar forced a una pista que no es subtítulo.") }
            }
            output.append(track)
        }
        tracks = output
    }

    private func matches(_ condition: MultimediaBatchRuleCondition, track: MediaEditableTrack) -> Bool {
        let actual: String
        switch condition.field {
        case .codec: actual = track.codec
        case .language: actual = track.language
        case .title: actual = track.title
        case .isDefault: actual = track.isDefault ? "true" : "false"
        case .isForced: actual = track.isForced ? "true" : "false"
        }
        let lhs = actual.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let rhs = condition.value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch condition.match {
        case .equals: return lhs == rhs
        case .notEquals: return lhs != rhs
        case .contains: return lhs.contains(rhs)
        case .isEmpty: return lhs.isEmpty
        case .isNotEmpty: return !lhs.isEmpty
        }
    }

    private func sanitized(_ value: String) -> String {
        String(value.replacingOccurrences(of: "\u{0000}", with: "").prefix(512)).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
