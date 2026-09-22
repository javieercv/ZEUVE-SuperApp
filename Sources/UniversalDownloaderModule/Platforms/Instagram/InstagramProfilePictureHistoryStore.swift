import Foundation
import ZEUVECore
import ZEUVEEngines

public struct InstagramProfilePictureHistoryRecord: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let username: String
    public let capturedAt: Date
    public let filename: String
    public let sha256: String
    public let sourcePage: String?
}

/// Historial local opcional. Solo se alimenta como consecuencia de una descarga expresa
/// de la foto de perfil y nunca consulta perfiles en segundo plano.
public struct InstagramProfilePictureHistoryStore: Sendable {
    private let fileManagerBox: SendableFileManager
    private var fileManager: FileManager { fileManagerBox.fileManager }
    private let rootOverride: URL?

    public init(fileManager: FileManager = .default, root: URL? = nil) {
        fileManagerBox = SendableFileManager(fileManager)
        rootOverride = root
    }

    @discardableResult
    public func preserve(
        file: URL,
        username: String,
        sourcePage: String? = nil,
        capturedAt: Date = Date()
    ) throws -> InstagramProfilePictureHistoryRecord {
        let safeUsername = try DownloadFilenamePolicy().sanitize(username)
        let root = try historyRoot().appendingPathComponent(safeUsername, isDirectory: true)
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        let hash = try SHA256.hexDigest(fileAt: file)
        var records = try load(username: safeUsername)
        if let existing = records.first(where: { $0.sha256 == hash }) { return existing }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let ext = file.pathExtension.isEmpty ? "jpg" : file.pathExtension.lowercased()
        let filename = "\(formatter.string(from: capturedAt))_\(hash.prefix(12)).\(ext)"
        let destination = root.appendingPathComponent(filename, isDirectory: false)
        try fileManager.copyItem(at: file, to: destination)
        let copiedHash = try SHA256.hexDigest(fileAt: destination)
        guard copiedHash == hash else {
            try? fileManager.removeItem(at: destination)
            throw UniversalDownloaderError.noPublishedFiles
        }
        let record = InstagramProfilePictureHistoryRecord(
            id: hash,
            username: username,
            capturedAt: capturedAt,
            filename: filename,
            sha256: hash,
            sourcePage: sourcePage
        )
        records.append(record)
        records.sort { $0.capturedAt > $1.capturedAt }
        try save(records, username: safeUsername)
        return record
    }

    public func load(username: String) throws -> [InstagramProfilePictureHistoryRecord] {
        let safeUsername = try DownloadFilenamePolicy().sanitize(username)
        let index = try historyRoot()
            .appendingPathComponent(safeUsername, isDirectory: true)
            .appendingPathComponent("history.json", isDirectory: false)
        guard fileManager.fileExists(atPath: index.path) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([InstagramProfilePictureHistoryRecord].self, from: Data(contentsOf: index))
    }

    public func historyRoot() throws -> URL {
        let root = try rootOverride ?? AppPaths.applicationSupport(fileManager: fileManager)
            .appendingPathComponent("ProfilePictureHistory", isDirectory: true)
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        return root.standardizedFileURL
    }

    private func save(_ records: [InstagramProfilePictureHistoryRecord], username: String) throws {
        let folder = try historyRoot().appendingPathComponent(username, isDirectory: true)
        try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        let destination = folder.appendingPathComponent("history.json", isDirectory: false)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(records).write(to: destination, options: .atomic)
    }
}

private final class SendableFileManager: @unchecked Sendable {
    let fileManager: FileManager

    init(_ fileManager: FileManager) {
        self.fileManager = fileManager
    }
}
