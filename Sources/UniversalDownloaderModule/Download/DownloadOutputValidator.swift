import Foundation
import ZEUVEEngines

public struct DownloadOutputValidator: Sendable {
    private let runner: ExternalProcessRunner

    public init(runner: ExternalProcessRunner = ExternalProcessRunner()) {
        self.runner = runner
    }

    public func verifyMediaFiles(_ files: [URL], ffprobe: URL) async throws {
        for file in files {
            let ext = file.pathExtension.lowercased()
            if Self.audioVideoExtensions.contains(ext) {
                let result = try await runner.run(
                    ExternalProcessRequest(
                        executable: ffprobe,
                        arguments: ["-v", "error", "-show_entries", "format=duration", "-of", "json", "-i", file.path]
                    )
                )
                guard result.exitCode == 0 else { throw UniversalDownloaderError.noPublishedFiles }
            } else if Self.imageExtensions.contains(ext) {
                guard try Self.hasValidImageSignature(file, extensionName: ext) else {
                    throw UniversalDownloaderError.noPublishedFiles
                }
            }
        }
    }

    public static func isMediaFile(_ file: URL) -> Bool {
        audioVideoExtensions.contains(file.pathExtension.lowercased())
            || imageExtensions.contains(file.pathExtension.lowercased())
    }

    static let audioVideoExtensions: Set<String> = ["mp4", "mkv", "webm", "m4a", "mp3", "flac", "wav", "opus", "mov", "m4v", "ogg", "aac"]
    static let imageExtensions: Set<String> = ["jpg", "jpeg", "png", "webp", "gif", "avif", "heic", "heif", "tif", "tiff", "bmp"]

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
