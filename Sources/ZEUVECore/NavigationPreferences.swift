import Foundation

public struct KeyboardShortcutDescriptor: Codable, Sendable, Hashable, Equatable {
    public var key: String
    public var command: Bool
    public var option: Bool
    public var control: Bool
    public var shift: Bool

    public init(key: String, command: Bool = false, option: Bool = false, control: Bool = false, shift: Bool = false) {
        self.key = key
        self.command = command
        self.option = option
        self.control = control
        self.shift = shift
    }

    public static func command(_ key: String) -> Self { .init(key: key, command: true) }

    public var normalized: Self {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedKey = trimmed.count == 1 ? trimmed.lowercased() : trimmed
        return .init(key: normalizedKey, command: command, option: option, control: control, shift: shift)
    }

    public var displayName: String {
        let value = normalized
        var result = ""
        if value.control { result += "⌃" }
        if value.option { result += "⌥" }
        if value.shift { result += "⇧" }
        if value.command { result += "⌘" }
        return result + value.key.uppercased()
    }
}

public enum KeyboardShortcutOverride: Codable, Sendable, Hashable, Equatable {
    case disabled
    case custom(KeyboardShortcutDescriptor)

    private enum CodingKeys: String, CodingKey { case kind, shortcut }
    private enum Kind: String, Codable { case disabled, custom }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(Kind.self, forKey: .kind) {
        case .disabled: self = .disabled
        case .custom: self = .custom(try container.decode(KeyboardShortcutDescriptor.self, forKey: .shortcut))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .disabled:
            try container.encode(Kind.disabled, forKey: .kind)
        case .custom(let shortcut):
            try container.encode(Kind.custom, forKey: .kind)
            try container.encode(shortcut, forKey: .shortcut)
        }
    }
}

public struct NavigationPreferences: Codable, Sendable, Equatable {
    public var moduleOrder: [String]
    public var shortcutOverrides: [String: KeyboardShortcutOverride]

    public init(moduleOrder: [String] = [], shortcutOverrides: [String: KeyboardShortcutOverride] = [:]) {
        self.moduleOrder = moduleOrder
        self.shortcutOverrides = shortcutOverrides
    }

    public func effectiveShortcut(for targetID: String, defaults: NavigationPreferencesDefaults) -> KeyboardShortcutDescriptor? {
        switch shortcutOverrides[targetID] {
        case .disabled?: return nil
        case .custom(let shortcut)?: return shortcut.normalized
        case nil: return defaults.shortcuts[targetID]?.normalized
        }
    }
}

public struct NavigationPreferencesDefaults: Sendable, Equatable {
    public let moduleOrder: [String]
    public let shortcuts: [String: KeyboardShortcutDescriptor]
    public let historyTargetID: String

    public init(moduleOrder: [String], shortcuts: [String: KeyboardShortcutDescriptor], historyTargetID: String) {
        self.moduleOrder = moduleOrder
        self.shortcuts = shortcuts
        self.historyTargetID = historyTargetID
    }
}

public enum KeyboardShortcutValidationError: LocalizedError, Equatable {
    case invalidKey
    case missingModifier
    case reserved(String)
    case conflict(String)

    public var errorDescription: String? {
        switch self {
        case .invalidKey: return "La tecla seleccionada no es válida para un atajo."
        case .missingModifier: return "Los atajos con teclas de escritura deben incluir ⌘, ⌥ o ⌃."
        case .reserved(let name): return "El atajo \(name) está reservado por una función fundamental de macOS o ZEUVE."
        case .conflict(let name): return "El atajo ya está asignado a \(name)."
        }
    }
}

public enum KeyboardShortcutValidator {
    private static let reserved: Set<KeyboardShortcutDescriptor> = Set([
        KeyboardShortcutDescriptor.command("q"), .command("w"), .command("z"), .command("x"), .command("c"), .command("v"), .command("a"),
        .command("h"), .command("m"), .command(","),
        KeyboardShortcutDescriptor(key: "z", command: true, shift: true),
    ].map { $0.normalized })

    public static func validate(_ shortcut: KeyboardShortcutDescriptor) throws {
        let value = shortcut.normalized
        guard value.key.count == 1,
              let scalar = value.key.unicodeScalars.first,
              !CharacterSet.controlCharacters.contains(scalar),
              !CharacterSet.whitespacesAndNewlines.contains(scalar) else {
            throw KeyboardShortcutValidationError.invalidKey
        }
        guard value.command || value.option || value.control else {
            throw KeyboardShortcutValidationError.missingModifier
        }
        if reserved.contains(value) { throw KeyboardShortcutValidationError.reserved(value.displayName) }
    }

    public static func normalized(
        _ preferences: NavigationPreferences,
        availableModuleIDs: [String],
        defaults: NavigationPreferencesDefaults
    ) -> NavigationPreferences {
        let available = Set(availableModuleIDs)
        var seen: Set<String> = []
        var order = preferences.moduleOrder.filter { available.contains($0) && seen.insert($0).inserted }
        for moduleID in defaults.moduleOrder where available.contains(moduleID) && seen.insert(moduleID).inserted { order.append(moduleID) }
        for moduleID in availableModuleIDs where seen.insert(moduleID).inserted { order.append(moduleID) }

        let validTargets = available.union([defaults.historyTargetID])
        var overrides: [String: KeyboardShortcutOverride] = [:]
        var used: Set<KeyboardShortcutDescriptor> = []

        // Defaults occupy a shortcut unless explicitly disabled/replaced. Walk stable module order + history.
        let targets = order + [defaults.historyTargetID]
        for target in targets where validTargets.contains(target) {
            let override = preferences.shortcutOverrides[target]
            switch override {
            case .disabled?:
                overrides[target] = .disabled
            case .custom(let raw)?:
                let value = raw.normalized
                guard (try? validate(value)) != nil, used.insert(value).inserted else {
                    overrides[target] = .disabled
                    continue
                }
                overrides[target] = .custom(value)
            case nil:
                if let defaultShortcut = defaults.shortcuts[target]?.normalized, (try? validate(defaultShortcut)) != nil {
                    if used.insert(defaultShortcut).inserted {
                        // no override necessary
                    } else {
                        overrides[target] = .disabled
                    }
                }
            }
        }
        return NavigationPreferences(moduleOrder: order, shortcutOverrides: overrides)
    }

    public static func conflictTarget(
        shortcut: KeyboardShortcutDescriptor,
        assigningTo targetID: String,
        preferences: NavigationPreferences,
        defaults: NavigationPreferencesDefaults,
        targetNames: [String: String]
    ) -> String? {
        let value = shortcut.normalized
        for otherID in defaults.moduleOrder + [defaults.historyTargetID] where otherID != targetID {
            if preferences.effectiveShortcut(for: otherID, defaults: defaults)?.normalized == value {
                return targetNames[otherID] ?? otherID
            }
        }
        return nil
    }
}
