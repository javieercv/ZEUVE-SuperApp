import Foundation
import ZEUVEEngines

public struct DownloadOutputValidator: Sendable {
    private let runner: ExternalProcessRunner

    public init(runner: ExternalProcessRunner = ExternalProcessRunner()) {
        self.runner = runner
    }

    public func verifyMediaFiles(_ files: [URL], ffprobe: URL, expectedKind: UniversalMediaKind? = nil) async throws {
        guard files.contains(where: Self.isMediaFile) else { throw UniversalDownloaderError.noPublishedFiles }
        for file in files {
            try Task.checkCancellation()
            let ext = file.pathExtension.lowercased()
            if Self.audioVideoExtensions.contains(ext) {
                let output = LockedDataCollector(maximumBytes: 262_144)
                let result = try await runner.run(
                    ExternalProcessRequest(
                        executable: ffprobe,
                        arguments: ["-v", "error", "-show_entries", "format=format_name:stream=codec_type:stream_disposition=attached_pic", "-of", "json", "-i", file.path]
                    ),
                    onStdout: { output.append($0) }
                )
                guard result.succeeded,
                      Self.isCompatibleProbe(output.data, extensionName: ext, expectedKind: expectedKind) else {
                    throw UniversalDownloaderError.noPublishedFiles
                }
            } else if Self.imageExtensions.contains(ext) {
                guard expectedKind?.mediaClass != .audio, expectedKind?.mediaClass != .video,
                      try Self.hasValidImageSignature(file, extensionName: ext) else {
                    throw UniversalDownloaderError.noPublishedFiles
                }
            } else if !Self.auxiliaryExtensions.contains(ext) {
                throw UniversalDownloaderError.noPublishedFiles
            }
        }
    }

    static func isCompatibleProbe(_ data: Data, extensionName: String, expectedKind: UniversalMediaKind?) -> Bool {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let format = root["format"] as? [String: Any], let name = format["format_name"] as? String,
              let streams = root["streams"] as? [[String: Any]] else { return false }
        let containers: [String: Set<String>] = [
            "mp4": ["mov", "mp4"], "mov": ["mov", "mp4"], "m4v": ["mov", "mp4"], "m4a": ["mov", "mp4"],
            "mkv": ["matroska", "webm"], "webm": ["matroska", "webm"],
            "mp3": ["mp3"], "flac": ["flac"], "wav": ["wav"], "ogg": ["ogg"], "opus": ["ogg"], "aac": ["aac"]
        ]
        guard let allowed = containers[extensionName], !allowed.isDisjoint(with: name.split(separator: ",").map(String.init)) else { return false }
        let audio = streams.contains { $0["codec_type"] as? String == "audio" }
        let video = streams.contains {
            $0["codec_type"] as? String == "video" && (($0["disposition"] as? [String: Any])?["attached_pic"] as? Int ?? 0) == 0
        }
        switch expectedKind?.mediaClass {
        case .audio: return audio && !video
        case .video: return video
        case .image: return false
        default: return audio || video
        }
    }

    public static func isMediaFile(_ file: URL) -> Bool {
        audioVideoExtensions.contains(file.pathExtension.lowercased())
            || imageExtensions.contains(file.pathExtension.lowercased())
    }

    static let audioVideoExtensions: Set<String> = ["mp4", "mkv", "webm", "m4a", "mp3", "flac", "wav", "opus", "mov", "m4v", "ogg", "aac"]
    static let imageExtensions: Set<String> = ["jpg", "jpeg", "png", "webp", "gif", "avif", "heic", "heif", "tif", "tiff", "bmp"]
    static let auxiliaryExtensions: Set<String> = ["vtt", "srt", "ass", "ssa", "lrc", "ttml", "srv1", "srv2", "srv3", "json", "description", "txt"]

    static func hasValidImageSignature(_ file: URL, extensionName: String) throws -> Bool {
        let handle = try FileHandle(forReadingFrom: file)
        defer { try? handle.close() }
        let data = try handle.read(upToCount: 32) ?? Data()
        guard data.count >= 4 else { return false }
        let bytes = [UInt8](data)
        switch extensionName {
        case "jpg", "jpeg": return bytes.starts(with: [0xFF, 0xD8, 0xFF])
        case "png": return bytes.starts(with: [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
        case "gif": return data.starts(with: Data("GIF87a".utf8)) || data.starts(with: Data("GIF89a".utf8))
        case "webp": return data.starts(with: Data("RIFF".utf8)) && data.count >= 12 && data[8..<12] == Data("WEBP".utf8)
        case "bmp": return bytes.starts(with: [0x42, 0x4D])
        case "tif", "tiff": return bytes.starts(with: [0x49, 0x49, 0x2A, 0x00]) || bytes.starts(with: [0x4D, 0x4D, 0x00, 0x2A])
        case "avif", "heic", "heif":
            guard data.count >= 12 else { return false }
            return String(decoding: data[4..<12], as: UTF8.self).contains("ftyp")
        default: return true
        }
    }
}
