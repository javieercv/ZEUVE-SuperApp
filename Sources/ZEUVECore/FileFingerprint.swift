import Foundation

public struct FileFingerprint: Codable, Sendable, Equatable {
    public let size: Int64
    public let modificationTimeNanoseconds: Int64

    public init(size: Int64, modificationTimeNanoseconds: Int64) {
        self.size = size
        self.modificationTimeNanoseconds = modificationTimeNanoseconds
    }

    public static func read(from url: URL, fileManager: FileManager = .default) throws -> FileFingerprint {
        let attributes = try fileManager.attributesOfItem(atPath: url.path)
        guard let size = attributes[.size] as? NSNumber else {
            throw FileFingerprintError.missingSize(url)
        }
        guard let date = attributes[.modificationDate] as? Date else {
            throw FileFingerprintError.missingModificationDate(url)
        }
        return FileFingerprint(
            size: size.int64Value,
            modificationTimeNanoseconds: Int64((date.timeIntervalSince1970 * 1_000_000_000).rounded())
        )
    }

    public func matches(_ url: URL, fileManager: FileManager = .default) -> Bool {
        guard let current = try? Self.read(from: url, fileManager: fileManager) else { return false }
        return current == self
    }
}

public enum FileFingerprintError: LocalizedError {
    case missingSize(URL)
    case missingModificationDate(URL)

    public var errorDescription: String? {
        switch self {
        case .missingSize(let url): return "No se ha podido obtener el tamaño de \(url.lastPathComponent)."
        case .missingModificationDate(let url): return "No se ha podido obtener la fecha de modificación de \(url.lastPathComponent)."
        }
    }
}
