import Foundation
import ZEUVECore

public enum MultimediaVideoPreviewDecoder: String, Codable, CaseIterable, Sendable, Identifiable {
    case automatic, hardware, software
    public var id: String { rawValue }
    public var displayName: String {
        switch self {
        case .automatic: return "Automático"
        case .hardware: return "Preferir hardware"
        case .software: return "Software"
        }
    }
}

public enum MultimediaVideoPreviewScaleMode: String, Codable, CaseIterable, Sendable, Identifiable {
    case fit, fill
    public var id: String { rawValue }
    public var displayName: String { self == .fit ? "Ajustar" : "Rellenar" }
}

public struct MultimediaVideoPreviewLimits: Codable, Sendable, Equatable {
    public var maximumWidth: Int
    public var maximumHeight: Int
    public var maximumFPS: Int
    public var maximumBufferedFrames: Int

    public init(maximumWidth: Int = 1920, maximumHeight: Int = 1080, maximumFPS: Int = 30, maximumBufferedFrames: Int = 3) {
        self.maximumWidth = maximumWidth
        self.maximumHeight = maximumHeight
        self.maximumFPS = maximumFPS
        self.maximumBufferedFrames = maximumBufferedFrames
        normalize()
    }

    public mutating func normalize() {
        maximumWidth = min(max(maximumWidth, 320), 3840)
        maximumHeight = min(max(maximumHeight, 180), 2160)
        maximumFPS = min(max(maximumFPS, 5), 60)
        maximumBufferedFrames = min(max(maximumBufferedFrames, 1), 8)
    }

    public static let `default` = MultimediaVideoPreviewLimits()
}

public struct MultimediaVideoPreviewSource: Sendable, Equatable, Identifiable {
    public let url: URL
    public let fingerprint: FileFingerprint
    public let streamIndex: Int
    public let codec: String
    public let width: Int
    public let height: Int
    public let frameRate: Double?
    public let duration: TimeInterval?
    public let title: String

    public var id: String { MultimediaAudioPreviewSource.identity(url: url, fingerprint: fingerprint, streamIndex: streamIndex) }

    public init(url: URL, fingerprint: FileFingerprint, streamIndex: Int, codec: String, width: Int, height: Int, frameRate: Double?, duration: TimeInterval?, title: String) {
        self.url = url.standardizedFileURL
        self.fingerprint = fingerprint
        self.streamIndex = streamIndex
        self.codec = codec
        self.width = width
        self.height = height
        self.frameRate = frameRate
        self.duration = duration
        self.title = title
    }
}

public struct MultimediaVideoPreviewFrame: Sendable, Equatable {
    public let pixelsBGRA: Data
    public let width: Int
    public let height: Int
    public let timestamp: TimeInterval

    public init(pixelsBGRA: Data, width: Int, height: Int, timestamp: TimeInterval) {
        self.pixelsBGRA = pixelsBGRA
        self.width = width
        self.height = height
        self.timestamp = timestamp
    }
}

public struct MultimediaVideoPreviewSnapshot: Sendable, Equatable {
    public let state: MultimediaPreviewPlaybackState
    public let sourceID: String?
    public let position: TimeInterval
    public let duration: TimeInterval?
    public let frame: MultimediaVideoPreviewFrame?
    public let errorMessage: String?

    public static let idle = MultimediaVideoPreviewSnapshot(state: .idle, sourceID: nil, position: 0, duration: nil, frame: nil, errorMessage: nil)
}
