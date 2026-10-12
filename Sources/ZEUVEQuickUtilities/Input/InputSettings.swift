import Foundation
import ZEUVECore

public struct ScrollDirectionOptions: Codable, Equatable, Sendable {
    public var schemaVersion = 1
    public var invertVertical = true
    public var invertHorizontal = false
    public init() {}
    public func validate() throws {
        guard schemaVersion == 1 else { throw QuickUtilityError.failure("La configuración de la rueda pertenece a una versión incompatible.") }
    }
}

/// A physical key and modifiers, never typed content. The display label is local UI metadata.
public struct MouseButtonShortcut: Codable, Equatable, Sendable {
    public var keyCode: UInt16
    public var label: String
    public var command: Bool
    public var option: Bool
    public var control: Bool
    public var shift: Bool
    public init(keyCode: UInt16, label: String, command: Bool = false, option: Bool = false, control: Bool = false, shift: Bool = false) {
        self.keyCode = keyCode; self.label = label; self.command = command
        self.option = option; self.control = control; self.shift = shift
    }
    public var displayName: String {
        (control ? "⌃" : "") + (option ? "⌥" : "") + (shift ? "⇧" : "") + (command ? "⌘" : "") + label
    }
    public func validate() throws {
        let functionKeys: Set<UInt16> = [122, 120, 99, 118, 96, 97, 98, 100, 101, 109, 103, 111, 105, 107, 113, 106, 64, 79, 80, 90]
        guard keyCode < 128, !label.isEmpty, label.count <= 24,
              !label.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }),
              ![54, 55, 56, 57, 58, 59, 60, 61, 62, 63].contains(keyCode),
              command || option || control || functionKeys.contains(keyCode) else {
            throw QuickUtilityError.failure("Selecciona una tecla y modificadores seguros para el atajo.")
        }
        // Destructive/system commands are never mouse-button presets. Other app actions require an explicit assignment.
        let forbiddenCommandKeys: Set<UInt16> = [0, 6, 7, 8, 9, 12, 13, 40, 46, 4, 43]
        if command && forbiddenCommandKeys.contains(keyCode) {
            throw QuickUtilityError.failure("Este atajo corresponde a una función fundamental y no puede asignarse a un botón.")
        }
        if (command && option && keyCode == 53) || keyCode == 127 {
            throw QuickUtilityError.failure("Este atajo del sistema no puede asignarse a un botón.")
        }
    }
    public static let back = Self(keyCode: 123, label: "←", command: true)
    public static let forward = Self(keyCode: 124, label: "→", command: true)
    public static let missionControl = Self(keyCode: 126, label: "↑", control: true)
    public static let showDesktop = Self(keyCode: 103, label: "F11")
}

public struct AdditionalMouseButtonsOptions: Codable, Equatable, Sendable {
    public var schemaVersion = 1
    /// Quartz indices: 0 primary, 1 secondary and 2 middle are deliberately protected.
    public var assignments: [Int: MouseButtonShortcut] = [:]
    public init() {}
    public func validate() throws {
        guard schemaVersion == 1 else { throw QuickUtilityError.failure("La configuración de botones pertenece a una versión incompatible.") }
        for (button, shortcut) in assignments {
            guard (3...31).contains(button) else { throw QuickUtilityError.failure("Los botones primario, secundario y central están protegidos.") }
            try shortcut.validate()
        }
    }
}

public struct DiscreteScrollSample: Equatable, Sendable {
    public var continuous: Bool
    public var verticalLines: Int64
    public var horizontalLines: Int64
    public var verticalPoints: Int64
    public var horizontalPoints: Int64
    public var verticalFixed: Double
    public var horizontalFixed: Double
    public init(continuous: Bool, verticalLines: Int64, horizontalLines: Int64, verticalPoints: Int64, horizontalPoints: Int64, verticalFixed: Double, horizontalFixed: Double) {
        self.continuous = continuous; self.verticalLines = verticalLines; self.horizontalLines = horizontalLines
        self.verticalPoints = verticalPoints; self.horizontalPoints = horizontalPoints
        self.verticalFixed = verticalFixed; self.horizontalFixed = horizontalFixed
    }
    public func transformed(using options: ScrollDirectionOptions) -> Self {
        guard !continuous, (try? options.validate()) != nil else { return self }
        guard verticalFixed.isFinite, horizontalFixed.isFinite,
              !options.invertVertical || (verticalLines != .min && verticalPoints != .min),
              !options.invertHorizontal || (horizontalLines != .min && horizontalPoints != .min) else { return self }
        var result = self
        if options.invertVertical {
            result.verticalLines = -verticalLines; result.verticalPoints = -verticalPoints; result.verticalFixed = -verticalFixed
        }
        if options.invertHorizontal {
            result.horizontalLines = -horizontalLines; result.horizontalPoints = -horizontalPoints; result.horizontalFixed = -horizontalFixed
        }
        return result
    }
}

/// Owns only pairs whose down event was consumed, avoiding orphaned ups during activation.
struct MouseButtonPairTracker {
    private(set) var consumed: Set<Int> = []
    mutating func down(_ index: Int, mapped: Bool) -> Bool {
        guard index >= 3, index <= 31, mapped else { return false }
        return consumed.insert(index).inserted
    }
    mutating func up(_ index: Int) -> Bool { consumed.remove(index) != nil }
    func dragging(_ index: Int) -> Bool { consumed.contains(index) }
}
