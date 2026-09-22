import Foundation

public struct AudioChannelDescriptor: Sendable, Equatable, Identifiable {
    public let index: Int
    public let shortName: String
    public let displayName: String

    public var id: Int { index }

    public init(index: Int, shortName: String, displayName: String) {
        self.index = index
        self.shortName = shortName
        self.displayName = displayName
    }

    public var label: String { "\(displayName) (\(shortName))" }
}

/// Interpreta únicamente layouts de FFmpeg cuyo orden de canales es conocido.
/// Ante cualquier layout desconocido conserva el fallback genérico Canal N.
public enum AudioChannelLayoutResolver {
    public static func channels(layout: String?, count: Int) -> [AudioChannelDescriptor] {
        guard count > 0 else { return [] }
        let names = knownOrder(for: layout?.lowercased())
        guard let names, names.count == count else {
            return (0..<count).map { index in
                AudioChannelDescriptor(index: index, shortName: "C\(index + 1)", displayName: "Canal \(index + 1)")
            }
        }
        return names.enumerated().map { index, item in
            AudioChannelDescriptor(index: index, shortName: item.0, displayName: item.1)
        }
    }

    private static func knownOrder(for layout: String?) -> [(String, String)]? {
        switch layout {
        case "mono":
            return [("FC", "Central")]
        case "stereo":
            return [("L", "Izquierdo"), ("R", "Derecho")]
        case "2.1":
            return [("L", "Izquierdo"), ("R", "Derecho"), ("LFE", "LFE")]
        case "3.0":
            return [("L", "Izquierdo"), ("R", "Derecho"), ("C", "Central")]
        case "3.0(back)":
            return [("L", "Izquierdo"), ("R", "Derecho"), ("BC", "Trasero central")]
        case "quad":
            return [("L", "Izquierdo"), ("R", "Derecho"), ("BL", "Trasero izquierdo"), ("BR", "Trasero derecho")]
        case "quad(side)":
            return [("L", "Izquierdo"), ("R", "Derecho"), ("SL", "Surround izquierdo"), ("SR", "Surround derecho")]
        case "4.0":
            return [("L", "Izquierdo"), ("R", "Derecho"), ("C", "Central"), ("BC", "Trasero central")]
        case "4.1":
            return [("L", "Izquierdo"), ("R", "Derecho"), ("C", "Central"), ("LFE", "LFE"), ("BC", "Trasero central")]
        case "5.0":
            return [("L", "Izquierdo"), ("R", "Derecho"), ("C", "Central"), ("BL", "Trasero izquierdo"), ("BR", "Trasero derecho")]
        case "5.0(side)":
            return [("L", "Izquierdo"), ("R", "Derecho"), ("C", "Central"), ("SL", "Surround izquierdo"), ("SR", "Surround derecho")]
        case "5.1":
            return [("L", "Izquierdo"), ("R", "Derecho"), ("C", "Central"), ("LFE", "LFE"), ("BL", "Trasero izquierdo"), ("BR", "Trasero derecho")]
        case "5.1(side)":
            return [("L", "Izquierdo"), ("R", "Derecho"), ("C", "Central"), ("LFE", "LFE"), ("SL", "Surround izquierdo"), ("SR", "Surround derecho")]
        case "7.1":
            return [("L", "Izquierdo"), ("R", "Derecho"), ("C", "Central"), ("LFE", "LFE"), ("BL", "Trasero izquierdo"), ("BR", "Trasero derecho"), ("SL", "Surround izquierdo"), ("SR", "Surround derecho")]
        case "7.1(wide)":
            return [("L", "Izquierdo"), ("R", "Derecho"), ("C", "Central"), ("LFE", "LFE"), ("BL", "Trasero izquierdo"), ("BR", "Trasero derecho"), ("FLC", "Frontal izquierdo central"), ("FRC", "Frontal derecho central")]
        default:
            return nil
        }
    }
}
