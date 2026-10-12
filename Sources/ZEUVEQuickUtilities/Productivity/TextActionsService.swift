import Foundation

public enum TextAction: String, CaseIterable, Sendable {
    case uppercase, lowercase, spaces, joinLines, invisibleCharacters
    public var title: String {
        switch self {
        case .uppercase: "Convertir a mayúsculas"
        case .lowercase: "Convertir a minúsculas"
        case .spaces: "Normalizar espacios"
        case .joinLines: "Unir líneas"
        case .invisibleCharacters: "Limpiar caracteres invisibles"
        }
    }
    public func apply(to text: String) -> String {
        switch self {
        case .uppercase: text.uppercased(with: Locale(identifier: "es_ES"))
        case .lowercase: text.lowercased(with: Locale(identifier: "es_ES"))
        case .spaces: text.replacingOccurrences(of: "[\\t\\p{Zs}]+", with: " ", options: .regularExpression)
        case .joinLines: text.replacingOccurrences(of: "[\\r\\n\u{2028}\u{2029}]+", with: " ", options: .regularExpression)
        case .invisibleCharacters:
            String(String.UnicodeScalarView(text.unicodeScalars.filter { ![0x200B, 0xFEFF, 0x00AD].contains($0.value) }))
        }
    }
}

@MainActor public final class TextActionsUtilityService: QuickUtilityService {
    public let id = QuickUtilityID.selectedText
    public private(set) var state = QuickUtilityState.disabled { didSet { stateDidChange?(state) } }
    public var stateDidChange: (@MainActor (QuickUtilityState) -> Void)?
    public init() {}
    public func start() async throws { try Task.checkCancellation(); state = .active }
    public func stop() async throws { state = .disabled }
    public func restoreDefaultSettings() async throws { try await stop() }
    public func transform(_ text: String, action: TextAction) throws -> String {
        guard state == .active else { throw QuickUtilityError.failure("Activa Acciones de texto en Ajustes > Utilidades rápidas.") }
        return action.apply(to: text)
    }
}
