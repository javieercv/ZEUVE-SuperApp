import Foundation
#if SWIFT_PACKAGE
import ZEUVECore
#endif

public typealias OrganizerProgressHandler = @Sendable (OperationProgress) -> Void

public struct OrganizerPlanner {
    private let fileManager: FileManager

    private static let packageSuffixes: Set<String> = ["app", "bundle", "framework", "photoslibrary", "pkg"]
    private static let systemFileNames: Set<String> = [".DS_Store", "Thumbs.db", "desktop.ini"]
    private static let temporarySuffixes: Set<String> = ["tmp", "temp", "part", "crdownload", "download"]
    private static let criticalPaths = ["/", "/System", "/Library", "/Applications", "/usr", "/bin", "/sbin", "/private"]

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    public func buildPlan(
        folder: URL,
        options: OrganizerOptions = OrganizerOptions(),
        progress: OrganizerProgressHandler? = nil
    ) throws -> OrganizerPlan {
        let baseFolder = try validate(folder)
        let rules = OrganizerExtensionRules.merged(with: options.customRules)
        let managedFolders = Set(rules.values.map(\.category)).union(["Otros", organizerRelatedFolder])
        let scan = try scan(
            baseFolder: baseFolder,
            options: options,
            managedFolders: managedFolders,
            progress: progress
        )

        var groups: [String: [URL]] = [:]
        for file in scan.files.sorted(by: { $0.path.localizedCaseInsensitiveCompare($1.path) == .orderedAscending }) {
            groups[normalizedStem(file), default: []].append(file)
        }

        var operations: [OrganizerMoveOperation] = []
        var ignored = scan.ignored
        var reserved = Set<String>()
        let orderedKeys = groups.keys.sorted()

        for (offset, key) in orderedKeys.enumerated() {
            try Task.checkCancellation()
            guard let groupedFiles = groups[key] else { continue }
            let extensions = Set(groupedFiles.map { $0.pathExtension.lowercased() })
            let shouldGroup = options.keepRelated && groupedFiles.count > 1 && extensions.count > 1
            let groupKey = shouldGroup ? groupedFiles[0].deletingPathExtension().lastPathComponent : nil

            if shouldGroup {
                let classifications = groupedFiles.map { OrganizerExtensionRules.classify($0, custom: options.customRules) }
                let categories = Set(classifications.map(\.category))
                let visibleStem = groupedFiles[0].deletingPathExtension().lastPathComponent.isEmpty
                    ? "Sin nombre"
                    : groupedFiles[0].deletingPathExtension().lastPathComponent
                let category: String
                let targetFolder: URL
                let reason: String
                if categories.count == 1, let onlyCategory = categories.first {
                    category = onlyCategory
                    targetFolder = baseFolder
                        .appendingPathComponent(category, isDirectory: true)
                        .appendingPathComponent(visibleStem, isDirectory: true)
                    reason = "Mismo nombre, formatos distintos · \(category)"
                } else {
                    category = organizerRelatedFolder
                    targetFolder = baseFolder
                        .appendingPathComponent(organizerRelatedFolder, isDirectory: true)
                        .appendingPathComponent(visibleStem, isDirectory: true)
                    reason = "Mismo nombre en categorías distintas"
                }

                for source in groupedFiles {
                    let classification = OrganizerExtensionRules.classify(source, custom: options.customRules)
                    let rawDestination = targetFolder.appendingPathComponent(source.lastPathComponent)
                    let hasConflict = destinationExists(rawDestination, reserved: reserved)
                    if hasConflict && options.conflictPolicy == .skip {
                        ignored.append(.init(url: source, reason: "Conflicto de nombre: configurado para omitir"))
                        continue
                    }
                    let destination = safeDestination(rawDestination, reserved: &reserved)
                    operations.append(
                        OrganizerMoveOperation(
                            source: source,
                            destination: destination,
                            reason: reason,
                            category: category,
                            formatFolder: classification.formatFolder,
                            groupKey: groupKey,
                            conflict: hasConflict,
                            sourceFingerprint: try FileFingerprint.read(from: source, fileManager: fileManager)
                        )
                    )
                }
            } else {
                for source in groupedFiles {
                    let classification = OrganizerExtensionRules.classify(source, custom: options.customRules)
                    let rawDestination = destination(
                        source: source,
                        baseFolder: baseFolder,
                        rule: classification,
                        level: options.organizationLevel
                    )
                    let hasConflict = destinationExists(rawDestination, reserved: reserved)
                    if hasConflict && options.conflictPolicy == .skip {
                        ignored.append(.init(url: source, reason: "Conflicto de nombre: configurado para omitir"))
                        continue
                    }
                    let finalDestination = safeDestination(rawDestination, reserved: &reserved)
                    let reason = options.organizationLevel == .simple
                        ? "Clasificado como \(classification.category)"
                        : "Clasificado como \(classification.category) · \(classification.formatFolder)"
                    operations.append(
                        OrganizerMoveOperation(
                            source: source,
                            destination: finalDestination,
                            reason: reason,
                            category: classification.category,
                            formatFolder: classification.formatFolder,
                            groupKey: nil,
                            conflict: hasConflict,
                            sourceFingerprint: try FileFingerprint.read(from: source, fileManager: fileManager)
                        )
                    )
                }
            }

            progress?(
                OperationProgress(
                    completed: offset + 1,
                    total: orderedKeys.count,
                    phase: "Preparando vista previa",
                    currentItem: groupedFiles.first?.lastPathComponent
                )
            )
        }

        return OrganizerPlan(
            baseFolder: baseFolder,
            operations: operations,
            ignored: ignored,
            options: options,
            subfolderCount: scan.subfolders
        )
    }

    public func validate(_ folder: URL) throws -> URL {
        let url = folder.standardizedFileURL.resolvingSymlinksInPath()
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
            throw OrganizerError.folderDoesNotExist
        }
        guard isDirectory.boolValue else { throw OrganizerError.selectionIsNotFolder }

        for criticalPath in Self.criticalPaths {
            if url.path == criticalPath || (criticalPath != "/" && url.path.hasPrefix(criticalPath + "/")) {
                throw OrganizerError.unsafeSystemLocation(url.path)
            }
        }
        guard fileManager.isReadableFile(atPath: url.path), fileManager.isWritableFile(atPath: url.path) else {
            throw OrganizerError.insufficientPermissions
        }
        return url
    }

    private func scan(
        baseFolder: URL,
        options: OrganizerOptions,
        managedFolders: Set<String>,
        progress: OrganizerProgressHandler?
    ) throws -> (files: [URL], ignored: [OrganizerIgnoredItem], subfolders: Int) {
        var files: [URL] = []
        var ignored: [OrganizerIgnoredItem] = []
        var subfolders = 0
        var processed = 0
        var stack = [baseFolder]

        while let current = stack.popLast() {
            try Task.checkCancellation()
            let entries = try fileManager.contentsOfDirectory(
                at: current,
                includingPropertiesForKeys: [.isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey, .isPackageKey],
                options: []
            ).sorted { $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending }

            for entry in entries {
                try Task.checkCancellation()
                let values = try entry.resourceValues(forKeys: [.isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey, .isPackageKey])
                if values.isSymbolicLink == true {
                    ignored.append(.init(url: entry, reason: "Enlace simbólico"))
                    continue
                }

                if values.isDirectory == true {
                    subfolders += 1
                    let isPackage = values.isPackage == true || Self.packageSuffixes.contains(entry.pathExtension.lowercased())
                    if isPackage {
                        ignored.append(.init(url: entry, reason: "Paquete de macOS"))
                        continue
                    }
                    if !options.includeHidden && isHidden(entry, relativeTo: baseFolder) {
                        ignored.append(.init(url: entry, reason: "Carpeta oculta"))
                        continue
                    }
                    if options.recursive && current.path == baseFolder.path && managedFolders.contains(entry.lastPathComponent) {
                        ignored.append(.init(url: entry, reason: "Categoría ya organizada"))
                        continue
                    }
                    if options.recursive { stack.append(entry) }
                    continue
                }

                processed += 1
                if let reason = ignoreReason(entry, relativeTo: baseFolder, includeHidden: options.includeHidden) {
                    ignored.append(.init(url: entry, reason: reason))
                } else if values.isRegularFile == true {
                    files.append(entry)
                } else {
                    ignored.append(.init(url: entry, reason: "Otro elemento no compatible"))
                }
                progress?(
                    OperationProgress(
                        completed: processed,
                        total: nil,
                        phase: options.recursive ? "Analizando subcarpetas" : "Analizando carpeta",
                        currentItem: entry.lastPathComponent
                    )
                )
            }

            if !options.recursive { break }
        }
        return (files, ignored, subfolders)
    }

    private func ignoreReason(_ url: URL, relativeTo baseFolder: URL, includeHidden: Bool) -> String? {
        if Self.systemFileNames.contains(url.lastPathComponent) { return "Archivo interno o del sistema" }
        if !includeHidden && isHidden(url, relativeTo: baseFolder) { return "Archivo oculto" }
        if Self.temporarySuffixes.contains(url.pathExtension.lowercased()) || url.lastPathComponent.hasSuffix("~") {
            return "Archivo temporal"
        }
        if !fileManager.isReadableFile(atPath: url.path) { return "Archivo sin permisos" }
        return nil
    }

    private func isHidden(_ url: URL, relativeTo baseFolder: URL) -> Bool {
        let baseComponents = baseFolder.standardizedFileURL.pathComponents
        let components = url.standardizedFileURL.pathComponents
        guard components.count >= baseComponents.count else { return false }
        return components.dropFirst(baseComponents.count).contains { $0.hasPrefix(".") }
    }

    private func normalizedStem(_ url: URL) -> String {
        url.deletingPathExtension().lastPathComponent.lowercased()
    }

    private func destination(
        source: URL,
        baseFolder: URL,
        rule: ExtensionRule,
        level: OrganizationLevel
    ) -> URL {
        var folder = baseFolder.appendingPathComponent(rule.category, isDirectory: true)
        if level == .detailed {
            folder.appendPathComponent(rule.formatFolder, isDirectory: true)
        }
        return folder.appendingPathComponent(source.lastPathComponent)
    }

    private func destinationExists(_ destination: URL, reserved: Set<String>) -> Bool {
        fileManager.fileExists(atPath: destination.path) || reserved.contains(destination.standardizedFileURL.path)
    }

    private func safeDestination(_ destination: URL, reserved: inout Set<String>) -> URL {
        var candidate = destination
        var counter = 2
        while destinationExists(candidate, reserved: reserved) {
            let stem = destination.deletingPathExtension().lastPathComponent
            let extensionName = destination.pathExtension
            let name = extensionName.isEmpty ? "\(stem)_\(counter)" : "\(stem)_\(counter).\(extensionName)"
            candidate = destination.deletingLastPathComponent().appendingPathComponent(name)
            counter += 1
        }
        reserved.insert(candidate.standardizedFileURL.path)
        return candidate
    }
}
