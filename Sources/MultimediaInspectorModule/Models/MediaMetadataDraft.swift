import Foundation
import ZEUVEEngines

public struct MediaMetadataDraft: Sendable, Equatable, Codable {
    public var containerValues: [String: String]
    public var touchedContainerKeys: Set<String>
    public var videoValuesByStream: [Int: [String: String]]
    public var touchedVideoKeysByStream: [Int: Set<String>]

    public init(
        containerValues: [String: String] = [:],
        touchedContainerKeys: Set<String> = [],
        videoValuesByStream: [Int: [String: String]] = [:],
        touchedVideoKeysByStream: [Int: Set<String>] = [:]
    ) {
        self.containerValues = containerValues
        self.touchedContainerKeys = touchedContainerKeys
        self.videoValuesByStream = videoValuesByStream
        self.touchedVideoKeysByStream = touchedVideoKeysByStream
    }

    public static func from(inspection: MediaInspectionResult, compatibility: MediaMetadataCompatibilityRegistry = .init()) -> MediaMetadataDraft {
        var container: [String: String] = [:]
        for key in compatibility.editableContainerKeys {
            if let value = inspection.format?.tags?.firstValue(caseInsensitiveKey: key) { container[key] = value }
        }
        var video: [Int: [String: String]] = [:]
        for stream in inspection.videoStreams {
            guard let index = stream.index else { continue }
            var values: [String: String] = [:]
            for key in compatibility.editableVideoKeys {
                if let value = stream.tags?.firstValue(caseInsensitiveKey: key) { values[key] = value }
            }
            video[index] = values
        }
        return .init(containerValues: container, videoValuesByStream: video)
    }

    public mutating func setContainerValue(_ value: String, for key: String) {
        containerValues[key] = value
        touchedContainerKeys.insert(key)
    }

    public mutating func setVideoValue(_ value: String, for key: String, streamIndex: Int) {
        var values = videoValuesByStream[streamIndex] ?? [:]
        values[key] = value
        videoValuesByStream[streamIndex] = values
        var touched = touchedVideoKeysByStream[streamIndex] ?? []
        touched.insert(key)
        touchedVideoKeysByStream[streamIndex] = touched
    }
}

private extension Dictionary where Key == String, Value == String {
    func firstValue(caseInsensitiveKey key: String) -> String? {
        first { $0.key.caseInsensitiveCompare(key) == .orderedSame }?.value
    }
}
