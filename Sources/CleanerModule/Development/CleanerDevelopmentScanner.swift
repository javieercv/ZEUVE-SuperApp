import Foundation

public final class CleanerDevelopmentScanner: @unchecked Sendable {
    private let fileManager: FileManager
    private let homeDirectory: URL

    public init(fileManager: FileManager = .default, homeDirectory: URL? = nil) {
        self.fileManager = fileManager
        self.homeDirectory = homeDirectory ?? fileManager.homeDirectoryForCurrentUser
    }

    public func scanXcode() -> [CleanerCandidate] {
        let derivedData = homeDirectory.appendingPathComponent("Library/Developer/Xcode/DerivedData")
        guard fileManager.fileExists(atPath: derivedData.path),
              let children = try? fileManager.contentsOfDirectory(
                at: derivedData,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
              ) else { return [] }

        return children.compactMap { url in
            guard let fingerprint = CleanerFileInspection.fingerprint(at: url, fileManager: fileManager) else { return nil }
            let lower = url.lastPathComponent.lowercased()
            let isIndex = lower.contains("index") || lower.contains("modulecache")
            return CleanerCandidate(
                url: url,
                category: isIndex ? .xcodeIndex : .xcodeDerivedData,
                evidences: [.init(strength: .strong, explanation: "Contenido de DerivedData regenerable por Xcode.")],
                confidence: .high,
                status: .regenerable,
                risk: .low,
                logicalSize: fingerprint.logicalSize,
                allocatedSize: fingerprint.allocatedSize,
                containsPotentialUserData: false,
                consequence: isIndex ? "Xcode regenerará este índice cuando sea necesario." : "Xcode volverá a compilar estos datos cuando sean necesarios.",
                selected: false,
                fingerprint: fingerprint
            )
        }
    }
}
