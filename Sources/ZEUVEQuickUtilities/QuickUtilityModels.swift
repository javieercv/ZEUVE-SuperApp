import Foundation

public enum QuickUtilityID: String, Codable, CaseIterable, Sendable, Identifiable {
    case audioProtection, audioMixer, scroll, mouseButtons, windowSwitcher, windowLayouts, newFile, fileShelf, selectedText
    public var id: String { "com.zeuve.quick.\(rawValue)" }
}

public enum QuickUtilityPermission: String, Codable, Sendable {
    case accessibility, inputMonitoring, audioCapture
    public var title: String {
        switch self {
        case .accessibility: "Accesibilidad"
        case .inputMonitoring: "Monitorización de entrada"
        case .audioCapture: "Captura de audio del sistema"
        }
    }
}

public enum QuickUtilityState: Equatable, Sendable {
    case disabled, activating, active, deactivating
    case requiresPermission(QuickUtilityPermission)
    case unavailable(String)
    case failed(String)
    public var isTransitioning: Bool { self == .activating || self == .deactivating }
    public var title: String {
        switch self {
        case .disabled: "Desactivada"
        case .activating: "Activando…"
        case .active: "Activa"
        case .deactivating: "Desactivando…"
        case .requiresPermission(let permission): "Requiere \(permission.title)"
        case .unavailable(let reason): "No disponible: \(reason)"
        case .failed(let reason): "Error: \(reason)"
        }
    }
}

public struct QuickUtilityDescriptor: Sendable, Identifiable {
    public let id: QuickUtilityID
    public let name: String
    public let summary: String
    public let icon: String
    public let permissions: [QuickUtilityPermission]
    public init(id: QuickUtilityID, name: String, summary: String, icon: String, permissions: [QuickUtilityPermission] = []) {
        self.id = id; self.name = name; self.summary = summary; self.icon = icon; self.permissions = permissions
    }
}

public enum QuickUtilitiesCatalog {
    public static let all: [QuickUtilityDescriptor] = [
        .init(id: .audioProtection, name: "Protección de audio en llamadas", summary: "Protege fuentes compatibles durante llamadas, cuando la ruta ha sido validada.", icon: "waveform.badge.shield", permissions: [.audioCapture]),
        .init(id: .audioMixer, name: "Volumen por aplicación", summary: "Ajusta el volumen de fuentes compatibles sin cambiar el volumen maestro.", icon: "slider.horizontal.3", permissions: [.audioCapture]),
        .init(id: .scroll, name: "Dirección de la rueda", summary: "Invierte ruedas discretas compatibles y conserva eventos continuos y gestos.", icon: "computermouse", permissions: [.accessibility]),
        .init(id: .mouseButtons, name: "Botones adicionales", summary: "Asigna atajos a botones adicionales por su número; se aplica a ratones compatibles.", icon: "computermouse.fill", permissions: [.accessibility]),
        .init(id: .windowSwitcher, name: "Selector de ventanas", summary: "Elige una ventana individual mediante una lista textual y el teclado.", icon: "macwindow.on.rectangle", permissions: [.accessibility]),
        .init(id: .windowLayouts, name: "Distribuciones de ventanas", summary: "Guarda posiciones y restaura únicamente asociaciones verificadas.", icon: "rectangle.3.group", permissions: [.accessibility]),
        .init(id: .newFile, name: "Crear archivos", summary: "Crea archivos nuevos en una carpeta elegida, sin sobrescribir originales.", icon: "doc.badge.plus"),
        .init(id: .fileShelf, name: "Bandeja temporal", summary: "Mantiene referencias de archivos para arrastrarlos después; se vacía al salir.", icon: "tray"),
        .init(id: .selectedText, name: "Acciones de texto", summary: "Transforma selecciones entregadas explícitamente mediante Servicios de macOS.", icon: "textformat")
    ]
    public static func descriptor(for id: QuickUtilityID) -> QuickUtilityDescriptor {
        all.first { $0.id == id }!
    }
}

public enum QuickUtilityError: LocalizedError, Equatable, Sendable {
    case requiresPermission(QuickUtilityPermission)
    case unavailable(String)
    case failure(String)
    public var errorDescription: String? {
        switch self {
        case .requiresPermission(let permission): "Autoriza \(permission.title) en Ajustes del Sistema y vuelve a intentarlo."
        case .unavailable(let reason), .failure(let reason): reason
        }
    }
    public var state: QuickUtilityState {
        switch self {
        case .requiresPermission(let permission): .requiresPermission(permission)
        case .unavailable(let reason): .unavailable(reason)
        case .failure(let reason): .failed(reason)
        }
    }
}

/// A service owns its native resources. Returning from stop must mean its resources
/// have been released, or throw an error that remains visible in the coordinator.
@MainActor public protocol QuickUtilityService: AnyObject {
    var id: QuickUtilityID { get }
    var state: QuickUtilityState { get }
    var stateDidChange: (@MainActor (QuickUtilityState) -> Void)? { get set }
    func start() async throws
    func stop() async throws
    func restoreDefaultSettings() async throws
}

public struct QuickUtilitySnapshot: Identifiable, Equatable, Sendable {
    public let id: QuickUtilityID
    public let requested: Bool
    public let state: QuickUtilityState
}

public struct QuickUtilitiesPreferences: Codable, Equatable, Sendable {
    public var schemaVersion: Int = 1
    public var enabled: Set<QuickUtilityID> = []
    public init() {}
    public func validate() throws {
        guard schemaVersion == 1 else { throw QuickUtilityError.failure("La configuración de utilidades pertenece a una versión incompatible.") }
    }
}
