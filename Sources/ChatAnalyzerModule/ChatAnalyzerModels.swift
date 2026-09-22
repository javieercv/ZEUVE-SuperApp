import Foundation

public let chatAnalyzerModuleIdentifier = "com.zeuve.chat-analyzer"

public enum ChatPlatform: String, Codable, CaseIterable, Sendable, Identifiable {
    case whatsapp
    case instagram
    public var id: String { rawValue }
    public var displayName: String { self == .whatsapp ? "WhatsApp" : "Instagram" }
}

public enum ChatCategory: String, Codable, CaseIterable, Sendable, Identifiable {
    case chat
    case messageRequest
    case broadcast
    case secret
    case unknown
    public var id: String { rawValue }
    public var displayName: String {
        switch self {
        case .chat: return "Chats"
        case .messageRequest: return "Solicitudes de mensajes"
        case .broadcast: return "Chats de difusión"
        case .secret: return "Conversaciones secretas"
        case .unknown: return "Sin categoría"
        }
    }
}

public enum ChatContentType: String, Codable, CaseIterable, Sendable, Identifiable {
    case text, image, video, audio, sticker, link, document, location, contact, call
    case sharedPost, story, reel, deleted, system, other
    public var id: String { rawValue }
    public var displayName: String {
        switch self {
        case .text: return "Texto"
        case .image: return "Imagen"
        case .video: return "Vídeo"
        case .audio: return "Audio"
        case .sticker: return "Sticker"
        case .link: return "Enlace"
        case .document: return "Documento"
        case .location: return "Ubicación"
        case .contact: return "Contacto"
        case .call: return "Llamada"
        case .sharedPost: return "Publicación compartida"
        case .story: return "Historia"
        case .reel: return "Reel"
        case .deleted: return "Contenido eliminado"
        case .system: return "Mensaje del sistema"
        case .other: return "Otro"
        }
    }
}

public enum InstagramTimeZoneStrategy: String, Codable, CaseIterable, Sendable, Identifiable {
    case californiaToSpain
    case utcToSpain
    case alreadySpain
    case noConversion
    public var id: String { rawValue }
    public var displayName: String {
        switch self {
        case .californiaToSpain: return "California → España"
        case .utcToSpain: return "UTC → España"
        case .alreadySpain: return "Ya está en horario de España"
        case .noConversion: return "No convertir la hora"
        }
    }
    public var sourceTimeZone: TimeZone {
        switch self {
        case .californiaToSpain: return TimeZone(identifier: "America/Los_Angeles") ?? .gmt
        case .utcToSpain: return .gmt
        case .alreadySpain, .noConversion: return TimeZone(identifier: "Europe/Madrid") ?? .current
        }
    }
}

public enum AmbiguousNumericDateOrder: String, Codable, CaseIterable, Sendable, Identifiable {
    case dayMonthYear
    case monthDayYear
    public var id: String { rawValue }
    public var displayName: String { self == .dayMonthYear ? "Día / mes / año" : "Mes / día / año" }
}

public enum MultimediaDefinition: String, Codable, CaseIterable, Sendable, Identifiable {
    case classic
    case nonText
    case configurable
    public var id: String { rawValue }
    public var displayName: String {
        switch self {
        case .classic: return "Imagen, vídeo, audio y sticker"
        case .nonText: return "Todo contenido que no sea texto"
        case .configurable: return "Categorías configurables"
        }
    }
}

public enum ConversationFilterStrategy: String, Codable, CaseIterable, Sendable, Identifiable {
    case fullTimelineThenFilter
    case afterFiltering
    public var id: String { rawValue }
    public var displayName: String {
        self == .fullTimelineThenFilter ? "Cronología completa y después filtros" : "Después de aplicar filtros"
    }
}

public struct ChatArchiveLimits: Codable, Sendable, Equatable {
    public var compressedWarningBytes: Int64 = 4 * 1_024 * 1_024 * 1_024
    public var compressedMaximumBytes: Int64 = 16 * 1_024 * 1_024 * 1_024
    public var entryWarningCount: Int = 100_000
    public var entryMaximumCount: Int = 500_000
    public var individualRelevantWarningBytes: Int64 = 256 * 1_024 * 1_024
    public var individualRelevantMaximumBytes: Int64 = 1_024 * 1_024 * 1_024
    public var totalDeclaredWarningBytes: Int64 = 100 * 1_024 * 1_024 * 1_024
    public var totalDeclaredMaximumBytes: Int64 = 500 * 1_024 * 1_024 * 1_024
    public var compressionRatioWarning: Double = 200
    public var compressionRatioMaximum: Double = 1_000
    public var htmlPageWarningCount: Int = 10_000
    public var htmlPageMaximumCount: Int = 50_000
    public var messageWarningCount: Int = 5_000_000
    public var messageMaximumCount: Int = 20_000_000
    public init() {}
}

public struct ChatAnalyzerSettings: Codable, Sendable, Equatable {
    public var instagramTimeZone: InstagramTimeZoneStrategy = .californiaToSpain
    public var numericDateOrder: AmbiguousNumericDateOrder = .dayMonthYear
    public var conversationThresholdMinutes: Int = 180
    /// Zero means no additional limit inside a temporal conversation.
    public var responseWindowMinutes: Int = 1_440
    public var includeStopWords: Bool = false
    public var multimediaDefinition: MultimediaDefinition = .classic
    public var configurableMultimediaTypes: Set<ChatContentType> = [.image, .video, .audio, .sticker]
    public var conversationFilterStrategy: ConversationFilterStrategy = .fullTimelineThenFilter
    public var listLimit: Int = 25
    public var granularity: TimeGranularity = .month
    /// Nil means that conversation files are not limited by size.
    public var conversationFileMaximumBytes: Int64? = nil
    public var archiveLimits = ChatArchiveLimits()
    public init() {}
}

public enum ChatInputKind: String, Codable, Sendable {
    case zip
    case whatsappText
    case instagramHTML
    case instagramFolder
}

public struct ChatInput: Sendable, Equatable, Identifiable {
    public let id: UUID
    public let url: URL
    public let kind: ChatInputKind
    public let estimatedPlatform: ChatPlatform?
    public let fingerprint: FileFingerprintSnapshot
    public init(id: UUID = UUID(), url: URL, kind: ChatInputKind, estimatedPlatform: ChatPlatform?, fingerprint: FileFingerprintSnapshot) {
        self.id = id
        self.url = url
        self.kind = kind
        self.estimatedPlatform = estimatedPlatform
        self.fingerprint = fingerprint
    }
}

public struct FileFingerprintSnapshot: Codable, Sendable, Equatable {
    public let size: Int64
    public let modifiedAt: Date
    public init(size: Int64, modifiedAt: Date) { self.size = size; self.modifiedAt = modifiedAt }
    public static func read(_ url: URL, fileManager: FileManager = .default) throws -> Self {
        let values = try url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey, .isDirectoryKey])
        guard let date = values.contentModificationDate else {
            throw ChatAnalyzerError.unreadableFile(url.lastPathComponent)
        }
        if let size = values.fileSize { return .init(size: Int64(size), modifiedAt: date) }
        if values.isDirectory == true {
            let attributes = try fileManager.attributesOfItem(atPath: url.path)
            let size = (attributes[.size] as? NSNumber)?.int64Value ?? 0
            return .init(size: size, modifiedAt: date)
        }
        throw ChatAnalyzerError.unreadableFile(url.lastPathComponent)
    }
    public func matches(_ url: URL) -> Bool { (try? Self.read(url)) == self }
}

public struct ChatAttachmentReference: Codable, Sendable, Equatable, Hashable {
    public let path: String
    public let exists: Bool
    public let inferredType: ChatContentType
    public init(path: String, exists: Bool, inferredType: ChatContentType) {
        self.path = path; self.exists = exists; self.inferredType = inferredType
    }
}

public struct NormalizedMessage: Codable, Sendable, Equatable, Identifiable, Hashable {
    public let id: String
    public let conversationID: String
    public let timestamp: Date
    public let originalDateText: String
    public let timeZoneStrategy: String
    public let author: String
    public let originalAuthor: String
    public let text: String
    public let platform: ChatPlatform
    public let contentType: ChatContentType
    public let sourceFile: String
    public let sourcePage: Int?
    public let sourcePosition: Int
    public let category: ChatCategory
    public let isSystem: Bool
    public let hasUncertainDate: Bool
    public let attachment: ChatAttachmentReference?

    public init(
        id: String,
        conversationID: String,
        timestamp: Date,
        originalDateText: String,
        timeZoneStrategy: String,
        author: String,
        originalAuthor: String? = nil,
        text: String,
        platform: ChatPlatform,
        contentType: ChatContentType,
        sourceFile: String,
        sourcePage: Int? = nil,
        sourcePosition: Int,
        category: ChatCategory = .chat,
        isSystem: Bool = false,
        hasUncertainDate: Bool = false,
        attachment: ChatAttachmentReference? = nil
    ) {
        self.id = id; self.conversationID = conversationID; self.timestamp = timestamp
        self.originalDateText = originalDateText; self.timeZoneStrategy = timeZoneStrategy
        self.author = author; self.originalAuthor = originalAuthor ?? author; self.text = text
        self.platform = platform; self.contentType = contentType; self.sourceFile = sourceFile
        self.sourcePage = sourcePage; self.sourcePosition = sourcePosition; self.category = category
        self.isSystem = isSystem; self.hasUncertainDate = hasUncertainDate; self.attachment = attachment
    }
}

public struct ChatImportWarning: Codable, Sendable, Equatable, Identifiable {
    public let id: UUID
    public let code: String
    public let message: String
    public init(id: UUID = UUID(), code: String, message: String) { self.id = id; self.code = code; self.message = message }
}

public struct InstagramConversationDescriptor: Codable, Sendable, Equatable, Identifiable, Hashable {
    public let id: String
    public let displayName: String
    public let category: ChatCategory
    public let normalizedPath: String
    public let pages: [String]
    public let duplicateDisplayName: Bool
    public init(id: String, displayName: String, category: ChatCategory, normalizedPath: String, pages: [String], duplicateDisplayName: Bool = false) {
        self.id = id; self.displayName = displayName; self.category = category
        self.normalizedPath = normalizedPath; self.pages = pages; self.duplicateDisplayName = duplicateDisplayName
    }
}

public struct ChatImportSummary: Codable, Sendable, Equatable {
    public var sourceCount = 0
    public var processedFiles = 0
    public var processedHTMLPages = 0
    public var recognizedMessages = 0
    public var discardedMessages = 0
    public var referencedAttachments = 0
    public var missingAttachments = 0
    /// Adjuntos mencionados cuando solo se ha proporcionado el archivo de conversación y no pueden verificarse.
    public var unverifiedAttachments: Int? = nil
    public var unreferencedAttachments = 0
    public var warnings: [ChatImportWarning] = []
    public init() {}
}

public struct ChatAnalysisResult: Sendable, Equatable, Identifiable {
    public let id: UUID
    public let startedAt: Date
    public let finishedAt: Date
    public let messageCount: Int
    public let participantCount: Int
    public let platforms: Set<ChatPlatform>
    public let summary: ChatImportSummary
    public let settings: ChatAnalyzerSettings

    public init(
        id: UUID,
        startedAt: Date,
        finishedAt: Date,
        messageCount: Int,
        participantCount: Int,
        platforms: Set<ChatPlatform>,
        summary: ChatImportSummary,
        settings: ChatAnalyzerSettings
    ) {
        self.id = id
        self.startedAt = startedAt
        self.finishedAt = finishedAt
        self.messageCount = messageCount
        self.participantCount = participantCount
        self.platforms = platforms
        self.summary = summary
        self.settings = settings
    }

    /// Inicializador de compatibilidad para pruebas y consumidores pequeños. Las sesiones reales
    /// no conservan esta colección: calculan los metadatos y mantienen los mensajes en SQLite.
    public init(id: UUID, startedAt: Date, finishedAt: Date, messages: [NormalizedMessage], summary: ChatImportSummary, settings: ChatAnalyzerSettings) {
        self.init(
            id: id,
            startedAt: startedAt,
            finishedAt: finishedAt,
            messageCount: messages.count,
            participantCount: Set(messages.lazy.filter { !$0.isSystem }.map(\.author)).count,
            platforms: Set(messages.map(\.platform)),
            summary: summary,
            settings: settings
        )
    }
}

public enum ChatAnalyzerError: LocalizedError, Equatable {
    case noInput
    case unreadableFile(String)
    case unsupportedInput(String)
    case archiveDamaged
    case archiveEncrypted
    case archiveUnsafe(String)
    case archiveLimit(String)
    case conversationFileLimit(name: String, size: Int64, maximum: Int64)
    case chatNotFound
    case multipleWhatsAppTexts([String])
    case whatsappTextNotFound
    case whatsappNoMessages
    case instagramConversationRequired
    case instagramConversationNotFound
    case instagramNoMessages
    case unknownInstagramStructure
    case cancelled
    case sourceChanged(String)
    case invalidDate(String)
    case invalidManifest
    case storageUnavailable(String)

    public var errorDescription: String? {
        switch self {
        case .noInput: return "Añade al menos un archivo compatible."
        case .unreadableFile(let name): return "No se puede leer «\(name)». Comprueba sus permisos."
        case .unsupportedInput(let name): return "«\(name)» no es una entrada compatible."
        case .archiveDamaged: return "El ZIP está dañado o no tiene una estructura válida."
        case .archiveEncrypted: return "El ZIP está cifrado y no puede analizarse."
        case .archiveUnsafe(let detail): return "El ZIP contiene una ruta o entrada insegura: \(detail)."
        case .archiveLimit(let detail): return "El ZIP supera un límite de seguridad: \(detail)."
        case .conversationFileLimit(let name, let size, let maximum):
            let actual = ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
            let configured = ByteCountFormatter.string(fromByteCount: maximum, countStyle: .file)
            return "El archivo de conversación «\(name)» ocupa \(actual) y supera el límite configurado de \(configured). Puedes cambiarlo en Ajustes > Analizador de chats."
        case .chatNotFound: return "No se ha encontrado una conversación compatible."
        case .multipleWhatsAppTexts: return "El ZIP contiene varios TXT de WhatsApp válidos. Selecciona uno."
        case .whatsappTextNotFound: return "No se ha encontrado un TXT de WhatsApp válido."
        case .whatsappNoMessages: return "El TXT no contiene mensajes de WhatsApp reconocibles."
        case .instagramConversationRequired: return "Selecciona una conversación de Instagram."
        case .instagramConversationNotFound: return "La conversación de Instagram ya no está disponible en el ZIP."
        case .instagramNoMessages: return "No se han reconocido mensajes en la conversación de Instagram."
        case .unknownInstagramStructure: return "La estructura de los HTML de Instagram no es compatible o ha cambiado."
        case .cancelled: return "El análisis se ha cancelado."
        case .sourceChanged(let name): return "«\(name)» ha cambiado después de seleccionarlo. Vuelve a añadirlo."
        case .invalidDate(let text): return "No se ha podido interpretar la fecha «\(text)»."
        case .invalidManifest: return "No se ha podido cargar el manifiesto del Analizador de chats."
        case .storageUnavailable(let detail): return "No se ha podido preparar el almacenamiento temporal: \(detail)."
        }
    }
}
