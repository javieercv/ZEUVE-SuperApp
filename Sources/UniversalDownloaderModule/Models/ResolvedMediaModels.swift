import Foundation

public enum ResolvedMediaKind: String, Codable, Sendable, Equatable {
    case directFile
    case hls
    case dash
    case unknown

    public var isSegmented: Bool { self == .hls || self == .dash }
}

/// Referencia efímera obtenida durante el análisis. Las cabeceras pueden contener
/// datos de sesión y por eso se mantienen solo en memoria: no se codifican.
public struct ResolvedMediaReference: Codable, Sendable, Equatable {
    public let mediaURL: URL?
    public let kind: ResolvedMediaKind
    public let protocolName: String?
    public let extensionName: String?
    public let expiresAt: Date?
    public let resolvedAt: Date
    public let httpHeaders: [String: String]

    public init(
        mediaURL: URL,
        kind: ResolvedMediaKind = .unknown,
        protocolName: String? = nil,
        extensionName: String? = nil,
        expiresAt: Date? = nil,
        resolvedAt: Date = Date(),
        httpHeaders: [String: String] = [:]
    ) {
        self.mediaURL = mediaURL
        self.kind = kind
        self.protocolName = protocolName
        self.extensionName = extensionName
        self.expiresAt = expiresAt
        self.resolvedAt = resolvedAt
        self.httpHeaders = httpHeaders
    }

    public var isSegmented: Bool { kind.isSegmented }

    public func isExpired(at date: Date = Date(), safetyMargin: TimeInterval = 30) -> Bool {
        guard let expiresAt else { return false }
        return expiresAt.timeIntervalSince(date) <= safetyMargin
    }

    private enum CodingKeys: String, CodingKey {
        case kind, protocolName, extensionName, expiresAt, resolvedAt
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        mediaURL = nil
        kind = try values.decodeIfPresent(ResolvedMediaKind.self, forKey: .kind) ?? .unknown
        protocolName = try values.decodeIfPresent(String.self, forKey: .protocolName)
        extensionName = try values.decodeIfPresent(String.self, forKey: .extensionName)
        expiresAt = try values.decodeIfPresent(Date.self, forKey: .expiresAt)
        resolvedAt = try values.decodeIfPresent(Date.self, forKey: .resolvedAt) ?? Date.distantPast
        httpHeaders = [:]
    }

    public func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(kind, forKey: .kind)
        try values.encodeIfPresent(protocolName, forKey: .protocolName)
        try values.encodeIfPresent(extensionName, forKey: .extensionName)
        try values.encodeIfPresent(expiresAt, forKey: .expiresAt)
        try values.encode(resolvedAt, forKey: .resolvedAt)
    }
}
