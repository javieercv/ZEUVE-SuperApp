import Foundation

public enum YTDLPDynamicRange: String, Codable, Sendable, Equatable {
    case sdr
    case hdr
    case unknown
}

public struct YTDLPFormat: Codable, Sendable, Equatable, Identifiable {
    public let formatID: String
    public let extensionName: String?
    public let protocolName: String?
    public let width: Int?
    public let height: Int?
    public let fps: Double?
    public let videoCodec: String?
    public let audioCodec: String?
    public let videoBitrateKbps: Double?
    public let audioBitrateKbps: Double?
    public let totalBitrateKbps: Double?
    public let fileSize: Int64?
    public let approximateFileSize: Int64?
    public let language: String?
    public let dynamicRange: YTDLPDynamicRange
    public let formatNote: String?

    public var id: String { formatID }
    public var hasVideo: Bool { videoCodec.map { $0 != "none" } ?? false }
    public var hasAudio: Bool { audioCodec.map { $0 != "none" } ?? false }
    public var isProgressive: Bool { hasVideo && hasAudio }
    public var bestKnownSize: Int64? { fileSize ?? approximateFileSize }

    public init(
        formatID: String,
        extensionName: String? = nil,
        protocolName: String? = nil,
        width: Int? = nil,
        height: Int? = nil,
        fps: Double? = nil,
        videoCodec: String? = nil,
        audioCodec: String? = nil,
        videoBitrateKbps: Double? = nil,
        audioBitrateKbps: Double? = nil,
        totalBitrateKbps: Double? = nil,
        fileSize: Int64? = nil,
        approximateFileSize: Int64? = nil,
        language: String? = nil,
        dynamicRange: YTDLPDynamicRange = .unknown,
        formatNote: String? = nil
    ) {
        self.formatID = formatID
        self.extensionName = extensionName
        self.protocolName = protocolName
        self.width = width
        self.height = height
        self.fps = fps
        self.videoCodec = videoCodec
        self.audioCodec = audioCodec
        self.videoBitrateKbps = videoBitrateKbps
        self.audioBitrateKbps = audioBitrateKbps
        self.totalBitrateKbps = totalBitrateKbps
        self.fileSize = fileSize
        self.approximateFileSize = approximateFileSize
        self.language = language
        self.dynamicRange = dynamicRange
        self.formatNote = formatNote
    }
}

public enum YTDLPSubtitleKind: String, Codable, Sendable, Equatable {
    case manual
    case automatic
}

public struct YTDLPSubtitleTrack: Codable, Sendable, Equatable, Identifiable {
    public let languageCode: String
    public let name: String?
    public let kind: YTDLPSubtitleKind
    public let extensions: [String]

    public var id: String { "\(kind.rawValue):\(languageCode)" }

    public init(languageCode: String, name: String? = nil, kind: YTDLPSubtitleKind, extensions: [String]) {
        self.languageCode = languageCode
        self.name = name
        self.kind = kind
        self.extensions = extensions
    }
}
