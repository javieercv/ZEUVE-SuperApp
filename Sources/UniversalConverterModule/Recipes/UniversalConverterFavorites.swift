import Foundation

public struct UniversalConverterFavorite: Codable, Sendable, Equatable, Identifiable {
    public var id: UUID
    public var name: String
    public var sourceCategories: [ConverterCategory]
    public var sourceFormats: [ConverterFormat]
    public var targetFormat: ConverterFormat?
    public var engine: ConverterExecutionKind?
    public var presetID: UUID?
    public var presetName: String?
    public var options: ConverterOperationOptions
    public var outputFolder: URL?
    public var isPinned: Bool
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        name: String,
        sourceCategories: [ConverterCategory],
        sourceFormats: [ConverterFormat],
        targetFormat: ConverterFormat?,
        engine: ConverterExecutionKind?,
        presetID: UUID? = nil,
        presetName: String? = nil,
        options: ConverterOperationOptions,
        outputFolder: URL? = nil,
        isPinned: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Conversión favorita" : name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.sourceCategories = Array(Set(sourceCategories)).sorted { $0.rawValue < $1.rawValue }
        self.sourceFormats = Array(Set(sourceFormats)).sorted { $0.rawValue < $1.rawValue }
        self.targetFormat = targetFormat
        self.engine = engine
        self.presetID = presetID
        self.presetName = presetName
        var sanitized = options
        sanitized.audioVideoImageURL = nil
        if sanitized.audioVideoBackground == .image { sanitized.audioVideoBackground = .black }
        sanitized.normalize()
        self.options = sanitized
        self.outputFolder = outputFolder?.standardizedFileURL
        self.isPinned = isPinned
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public mutating func rename(_ value: String) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        name = trimmed.isEmpty ? "Conversión favorita" : trimmed
        updatedAt = Date()
    }

    public mutating func update(options newOptions: ConverterOperationOptions, outputFolder: URL?, saveOutputFolder: Bool) {
        var sanitized = newOptions
        sanitized.audioVideoImageURL = nil
        if sanitized.audioVideoBackground == .image { sanitized.audioVideoBackground = .black }
        sanitized.normalize()
        options = sanitized
        targetFormat = sanitized.targetFormat
        self.outputFolder = saveOutputFolder ? outputFolder?.standardizedFileURL : nil
        updatedAt = Date()
    }
}

public enum ConverterPortableCollectionKind: String, Codable, Sendable {
    case presets
    case favorites
    case settings
}

public struct ConverterPortableCollection<Item: Codable & Sendable>: Codable, Sendable {
    public let schemaVersion: Int
    public let kind: ConverterPortableCollectionKind
    public let exportedAt: Date
    public let items: [Item]

    public init(kind: ConverterPortableCollectionKind, items: [Item], schemaVersion: Int = 1, exportedAt: Date = Date()) {
        self.schemaVersion = schemaVersion
        self.kind = kind
        self.exportedAt = exportedAt
        self.items = items
    }
}

public enum ConverterRecipeFileService {
    public static func encodePresets(_ presets: [UniversalConverterPreset]) throws -> Data {
        try encoder.encode(ConverterPortableCollection(kind: .presets, items: presets))
    }

    public static func decodePresets(_ data: Data) throws -> [UniversalConverterPreset] {
        let value = try decoder.decode(ConverterPortableCollection<UniversalConverterPreset>.self, from: data)
        guard value.kind == .presets, value.schemaVersion == 1 else { throw UniversalConverterError.incompatibleSettings("El archivo no contiene preajustes compatibles.") }
        return value.items
    }

    public static func encodeFavorites(_ favorites: [UniversalConverterFavorite]) throws -> Data {
        try encoder.encode(ConverterPortableCollection(kind: .favorites, items: favorites))
    }

    public static func decodeFavorites(_ data: Data) throws -> [UniversalConverterFavorite] {
        let value = try decoder.decode(ConverterPortableCollection<UniversalConverterFavorite>.self, from: data)
        guard value.kind == .favorites, value.schemaVersion == 1 else { throw UniversalConverterError.incompatibleSettings("El archivo no contiene favoritas compatibles.") }
        return value.items
    }

    public static func encodeSettings(_ settings: UniversalConverterSettings) throws -> Data {
        try encoder.encode(ConverterPortableCollection(kind: .settings, items: [settings]))
    }

    public static func decodeSettings(_ data: Data) throws -> UniversalConverterSettings {
        let value = try decoder.decode(ConverterPortableCollection<UniversalConverterSettings>.self, from: data)
        guard value.kind == .settings, value.schemaVersion == 1, var settings = value.items.first else {
            throw UniversalConverterError.incompatibleSettings("El archivo no contiene ajustes compatibles.")
        }
        settings.normalize()
        return settings
    }

    private static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    private static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
