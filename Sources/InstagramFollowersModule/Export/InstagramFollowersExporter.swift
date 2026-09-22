import Foundation
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

public enum InstagramFollowersExportFormat: String, Sendable, CaseIterable, Identifiable {
    case txt
    case csv
    public var id: String { rawValue }
}

public struct InstagramFollowersExporter: Sendable {
    public init() {}

    public func export(
        accounts: [InstagramAccount],
        category: InstagramFollowersCategory,
        format: InstagramFollowersExportFormat,
        destination: URL,
        overwrite: Bool
    ) throws {
        let fileManager = FileManager.default
        let parent = destination.deletingLastPathComponent()
        guard fileManager.fileExists(atPath: parent.path) else {
            throw InstagramFollowersError.exportFailed("la carpeta de destino no existe")
        }
        if fileManager.fileExists(atPath: destination.path), !overwrite {
            throw InstagramFollowersError.destinationExists(destination.path)
        }

        let data: Data
        switch format {
        case .txt:
            let text = accounts.map(\.username).joined(separator: "\n") + (accounts.isEmpty ? "" : "\n")
            guard let encoded = text.data(using: .utf8) else { throw InstagramFollowersError.exportFailed("no se ha podido codificar el TXT") }
            data = encoded
        case .csv:
            var lines = ["username,category,url"]
            lines.reserveCapacity(accounts.count + 1)
            for account in accounts {
                lines.append([account.username, category.exportValue, account.profileURL.absoluteString].map(csvField).joined(separator: ","))
            }
            guard let encoded = (lines.joined(separator: "\n") + "\n").data(using: .utf8) else {
                throw InstagramFollowersError.exportFailed("no se ha podido codificar el CSV")
            }
            data = encoded
        }

        let staging = parent.appendingPathComponent(".zeuve-instagram-export-\(UUID().uuidString).tmp")
        do {
            try data.write(to: staging, options: [.atomic])
            if fileManager.fileExists(atPath: destination.path) {
                try replaceAtomically(staging: staging, destination: destination)
            } else {
                try fileManager.moveItem(at: staging, to: destination)
            }
        } catch {
            try? fileManager.removeItem(at: staging)
            throw InstagramFollowersError.exportFailed(error.localizedDescription)
        }
    }


    private func replaceAtomically(staging: URL, destination: URL) throws {
        let status = staging.path.withCString { source in
            destination.path.withCString { target in
                rename(source, target)
            }
        }
        guard status == 0 else {
            throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
        }
    }

    private func csvField(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") || value.contains("\r") {
            return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return value
    }
}
