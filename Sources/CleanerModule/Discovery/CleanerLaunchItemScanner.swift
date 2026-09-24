import Foundation

public struct CleanerLaunchScanResult: Sendable {
    public let candidates: [CleanerCandidate]
    public let inaccessible: [String]
}

public final class CleanerLaunchItemScanner: @unchecked Sendable {
    private let fileManager: FileManager
    private let roots: [URL]

    public init(fileManager: FileManager = .default, roots: [URL]? = nil) {
        self.fileManager = fileManager
        self.roots = roots ?? [
            fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Library/LaunchAgents"),
            URL(fileURLWithPath: "/Library/LaunchAgents"),
            URL(fileURLWithPath: "/Library/LaunchDaemons"),
        ]
    }

    public func scan() -> CleanerLaunchScanResult {
        var candidates: [CleanerCandidate] = []
        var inaccessible: [String] = []
        for root in roots where fileManager.fileExists(atPath: root.path) {
            if Task.isCancelled { break }
            guard let urls = try? fileManager.contentsOfDirectory(at: root, includingPropertiesForKeys: nil) else {
                inaccessible.append(root.path)
                continue
            }
            for url in urls where url.pathExtension.lowercased() == "plist" {
                if Task.isCancelled { break }
                guard let data = try? Data(contentsOf: url),
                      let dictionary = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] else { continue }
                let program = (dictionary["Program"] as? String) ?? (dictionary["ProgramArguments"] as? [String])?.first
                guard let program, program.hasPrefix("/"), !fileManager.fileExists(atPath: program) else { continue }
                let associated = (dictionary["AssociatedBundleIdentifiers"] as? [String])?.first
                let fingerprint = CleanerFileInspection.fingerprint(at: url, fileManager: fileManager)
                let systemLocation = root.path.hasPrefix("/Library/")
                candidates.append(.init(
                    url: url,
                    category: .launchItem,
                    associatedBundleID: associated,
                    evidences: [.init(strength: .strong, explanation: "La entrada de inicio apunta a un ejecutable absoluto que ya no existe.")],
                    confidence: .high,
                    status: .possibleResidue,
                    risk: systemLocation ? .high : .medium,
                    logicalSize: fingerprint?.logicalSize,
                    allocatedSize: fingerprint?.allocatedSize,
                    requiresAdministrator: systemLocation,
                    consequence: "Entrada de inicio rota. Revisa el servicio antes de retirarlo.",
                    fingerprint: fingerprint
                ))
            }
        }
        return .init(candidates: candidates, inaccessible: inaccessible)
    }
}
