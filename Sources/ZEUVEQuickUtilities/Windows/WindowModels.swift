import Foundation

public struct WindowFrame: Codable, Equatable, Sendable {
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double
    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x; self.y = y; self.width = width; self.height = height
    }
    public var isValid: Bool {
        [x, y, width, height].allSatisfy { $0.isFinite && abs($0) < 100_000 } && width > 0 && height > 0
    }
}

/// Runtime identity and display text never enter the persisted profile model.
public struct WindowSnapshot: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let applicationName: String
    public let bundleIdentifier: String
    public let title: String
    public let processIdentifier: Int32
    public let frame: WindowFrame
    public let minimized: Bool
    public let canRestoreGeometry: Bool
    public let recentOrder: UInt64
    public init(id: UUID, applicationName: String, bundleIdentifier: String, title: String, processIdentifier: Int32, frame: WindowFrame, minimized: Bool, canRestoreGeometry: Bool, recentOrder: UInt64 = 0) {
        self.id = id; self.applicationName = applicationName; self.bundleIdentifier = bundleIdentifier
        self.title = title; self.processIdentifier = processIdentifier; self.frame = frame
        self.minimized = minimized; self.canRestoreGeometry = canRestoreGeometry; self.recentOrder = recentOrder
    }
    public var displayTitle: String { title.isEmpty ? "Ventana sin título" : title }
}

public struct WindowDisplayGeometry: Codable, Equatable, Sendable {
    public var frame: WindowFrame
    public var visibleFrame: WindowFrame
    public init(frame: WindowFrame, visibleFrame: WindowFrame) { self.frame = frame; self.visibleFrame = visibleFrame }
}

public struct WindowLayoutSlot: Codable, Equatable, Sendable, Identifiable {
    public var id: UUID
    public var bundleIdentifier: String
    public var displayIndex: Int
    /// Fractions of the original display's usable area, in AX top-left coordinates.
    public var relativeFrame: WindowFrame
    public init(id: UUID = UUID(), bundleIdentifier: String, displayIndex: Int, relativeFrame: WindowFrame) {
        self.id = id; self.bundleIdentifier = bundleIdentifier; self.displayIndex = displayIndex; self.relativeFrame = relativeFrame
    }
}

public struct WindowLayoutProfile: Codable, Equatable, Sendable, Identifiable {
    public var id: UUID
    public var name: String
    public var displays: [WindowDisplayGeometry]
    public var slots: [WindowLayoutSlot]
    public init(id: UUID = UUID(), name: String, displays: [WindowDisplayGeometry], slots: [WindowLayoutSlot]) {
        self.id = id; self.name = name; self.displays = displays; self.slots = slots
    }
    public func validate() throws {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, name.count <= 80,
              !displays.isEmpty, displays.count <= 16, displays.allSatisfy({ $0.frame.isValid && $0.visibleFrame.isValid }),
              !slots.isEmpty, slots.count <= 100, Set(slots.map(\.id)).count == slots.count,
              slots.allSatisfy({ !$0.bundleIdentifier.isEmpty && $0.bundleIdentifier.count <= 256 && displays.indices.contains($0.displayIndex) && $0.relativeFrame.isValid }) else {
            throw QuickUtilityError.failure("La distribución de ventanas no es válida.")
        }
    }
}

public struct WindowLayoutsPreferences: Codable, Equatable, Sendable {
    public var schemaVersion = 1
    public var profiles: [WindowLayoutProfile] = []
    public var automaticallyRestore = false
    public var automaticProfileID: UUID?
    public init() {}
    public func validate() throws {
        guard schemaVersion == 1, profiles.count <= 50, Set(profiles.map(\.id)).count == profiles.count,
              automaticProfileID == nil || profiles.contains(where: { $0.id == automaticProfileID }) else {
            throw QuickUtilityError.failure("La configuración de distribuciones es incompatible o está dañada.")
        }
        for profile in profiles { try profile.validate() }
        if automaticallyRestore && automaticProfileID == nil { throw QuickUtilityError.failure("Selecciona una distribución para la restauración automática.") }
    }
}

public struct WindowLayoutResult: Equatable, Sendable {
    public var restored = 0
    public var omitted = 0
    public var failed = 0
    public var cancelled = false
    public init() {}
    public var summary: String {
        "\(restored) restauradas · \(omitted) omitidas · \(failed) con error" + (cancelled ? " · Cancelada" : "")
    }
}

public enum WindowGeometryPlanner {
    public static func displayIndex(for frame: WindowFrame, displays: [WindowDisplayGeometry]) -> Int? {
        displays.indices.max { intersectionArea(frame, displays[$0].frame) < intersectionArea(frame, displays[$1].frame) }
    }
    private static func intersectionArea(_ a: WindowFrame, _ b: WindowFrame) -> Double {
        max(0, min(a.x + a.width, b.x + b.width) - max(a.x, b.x)) * max(0, min(a.y + a.height, b.y + b.height) - max(a.y, b.y))
    }
    public static func relative(_ frame: WindowFrame, to display: WindowDisplayGeometry) -> WindowFrame {
        let usable = display.visibleFrame
        return .init(x: (frame.x - usable.x) / usable.width, y: (frame.y - usable.y) / usable.height, width: frame.width / usable.width, height: frame.height / usable.height)
    }
    public static func restored(_ relative: WindowFrame, on display: WindowDisplayGeometry) -> WindowFrame {
        let usable = display.visibleFrame
        let width = min(usable.width, max(min(100, usable.width), relative.width * usable.width))
        let height = min(usable.height, max(min(80, usable.height), relative.height * usable.height))
        return .init(x: max(usable.x, min(usable.x + usable.width - width, usable.x + relative.x * usable.width)),
                     y: max(usable.y, min(usable.y + usable.height - height, usable.y + relative.y * usable.height)), width: width, height: height)
    }
    /// No hardware identifiers are saved. Automatic matching requires the complete
    /// topology; explicit restore can adapt equal-count displays by their roles.
    public static func topologyMatches(_ saved: [WindowDisplayGeometry], _ current: [WindowDisplayGeometry]) -> Bool {
        saved.count == current.count && zip(saved, current).allSatisfy { a, b in
            abs(a.frame.x - b.frame.x) < 1 && abs(a.frame.y - b.frame.y) < 1 && abs(a.frame.width - b.frame.width) < 1 && abs(a.frame.height - b.frame.height) < 1
        }
    }
}
