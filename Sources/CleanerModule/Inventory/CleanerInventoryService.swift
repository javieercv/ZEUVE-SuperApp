import Foundation

public struct CleanerInventoryScanResult: Sendable {
    public let applications: [CleanerAppInventoryItem]
    public let inaccessibleLocations: [String]
    public init(applications: [CleanerAppInventoryItem], inaccessibleLocations: [String]) {
        self.applications = applications
        self.inaccessibleLocations = inaccessibleLocations
    }
}

public final class CleanerInventoryService: @unchecked Sendable {
    private let fileManager: FileManager
    private let identityProvider: any CleanerAppIdentityProviding
    private let standardRoots: [URL]

    public init(
        fileManager: FileManager = .default,
        identityProvider: any CleanerAppIdentityProviding = SystemCleanerAppIdentityProvider(),
        standardRoots: [URL]? = nil
    ) {
        self.fileManager = fileManager
        self.identityProvider = identityProvider
        self.standardRoots = standardRoots ?? [
            URL(fileURLWithPath: "/Applications", isDirectory: true),
            fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Applications", isDirectory: true),
        ]
    }

    public func scan(additionalRoots: [URL] = []) -> CleanerInventoryScanResult {
        let roots = standardRoots + additionalRoots
        var urls = identityProvider.knownApplicationURLs()
        var inaccessible: [String] = []
        for root in roots {
            if Task.isCancelled { break }
            guard fileManager.fileExists(atPath: root.path) else { continue }
            guard let enumerator = fileManager.enumerator(
                at: root,
                includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey],
                options: [.skipsHiddenFiles],
                errorHandler: { url, _ in inaccessible.append(url.path); return true }
            ) else {
                inaccessible.append(root.path)
                continue
            }
            for case let url as URL in enumerator {
                if Task.isCancelled { break }
                let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
                if values?.isSymbolicLink == true {
                    enumerator.skipDescendants()
                    continue
                }
                if values?.isDirectory == true, url.pathExtension.lowercased() == "app" {
                    urls.append(url)
                    enumerator.skipDescendants()
                }
            }
        }

        var seen: Set<String> = []
        var apps: [CleanerAppInventoryItem] = []
        for url in urls.map(\.standardizedFileURL) where seen.insert(url.path).inserted {
            if Task.isCancelled { break }
            guard let identity = identityProvider.identity(for: url) else { continue }
            let size = CleanerFileInspection.recursiveSize(at: url, fileManager: fileManager, shouldCancel: { Task.isCancelled }).logical
            if Task.isCancelled { break }
            apps.append(.init(identity: identity, logicalSize: size))
        }
        return .init(
            applications: apps.sorted { $0.identity.name.localizedCaseInsensitiveCompare($1.identity.name) == .orderedAscending },
            inaccessibleLocations: inaccessible
        )
    }
}
