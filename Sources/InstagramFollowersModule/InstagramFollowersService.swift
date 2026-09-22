import Foundation
import ZEUVECore
import ZEUVEOperations

public actor InstagramFollowersService {
    private let coordinator: OperationCoordinator
    private let history: InstagramFollowersHistoryService
    private let logger: LocalLogger?
    private let parser = InstagramFollowersJSONParser()
    private let comparator = InstagramFollowersComparator()
    private var activeTask: Task<InstagramFollowersComparisonResult, Error>?
    private var activeOperationID: UUID?

    public init(
        coordinator: OperationCoordinator,
        history: InstagramFollowersHistoryService,
        logger: LocalLogger? = nil
    ) {
        self.coordinator = coordinator
        self.history = history
        self.logger = logger
    }

    public func inspectArchive(url: URL) async throws -> InstagramFollowersPreparedInput {
        let reader = InstagramFollowersArchiveReader(url: url)
        let catalog = try await Task.detached(priority: .utility) { try reader.catalog() }.value
        return .archive(url: url, catalog: catalog)
    }

    public func inspectJSONFiles(following: URL?, followers: [URL]) async throws -> InstagramFollowersPreparedInput {
        guard let following else { throw InstagramFollowersError.inputNotProvided("following.json") }
        guard !followers.isEmpty else { throw InstagramFollowersError.inputNotProvided("al menos un followers_<número>.json") }
        let checked = try await Task.detached(priority: .utility) {
            try Self.catalogJSONFiles(following: following, followers: followers)
        }.value
        return .jsonFiles(following: following, followers: checked.orderedURLs, catalog: checked.catalog)
    }

    public func analyze(
        _ input: InstagramFollowersPreparedInput,
        onWarning: @escaping @Sendable (String) -> Void = { _ in }
    ) async throws -> InstagramFollowersComparisonResult {
        guard activeTask == nil else {
            if let snapshot = await coordinator.current() { throw OperationCoordinatorError.busy(snapshot) }
            throw OperationCoordinatorError.operationNotActive(UUID())
        }
        let operationID = try await coordinator.begin(moduleID: instagramFollowersModuleIdentifier, name: "Comparar seguidores de Instagram")
        activeOperationID = operationID
        let startedAt = Date()
        let parser = self.parser
        let comparator = self.comparator
        let coordinator = self.coordinator
        let task = Task.detached(priority: .userInitiated) {
            try await coordinator.update(id: operationID, progress: OperationProgress(completed: 0, total: input.catalog.followers.count + 3, phase: "Leyendo archivos"))
            let payloads = try Self.readPayloads(input)
            try Task.checkCancellation()

            try await coordinator.update(id: operationID, progress: OperationProgress(completed: 1, total: input.catalog.followers.count + 3, phase: "Interpretando following.json", currentItem: input.catalog.following.name))
            let followingResult = try parser.parse(data: payloads.following, role: .following, sourceName: input.catalog.following.name)

            var followerResults: [[InstagramAccount]] = []
            var ignored = followingResult.ignoredEntries
            for (index, descriptor) in input.catalog.followers.enumerated() {
                try Task.checkCancellation()
                try await coordinator.update(id: operationID, progress: OperationProgress(completed: index + 2, total: input.catalog.followers.count + 3, phase: "Interpretando seguidores", currentItem: descriptor.name))
                guard let data = payloads.followers[descriptor.path] else { throw InstagramFollowersError.inputMissing(descriptor.name) }
                let parsed = try parser.parse(data: data, role: .followers, sourceName: descriptor.name)
                followerResults.append(parsed.accounts)
                ignored += parsed.ignoredEntries
            }

            try await coordinator.update(id: operationID, progress: OperationProgress(completed: input.catalog.followers.count + 2, total: input.catalog.followers.count + 3, phase: "Comparando listas"))
            var warnings = input.catalog.warnings
            if ignored > 0 { warnings.append("Se han ignorado \(ignored) entradas sin un nombre de usuario compatible.") }
            let result = try comparator.compare(
                following: followingResult.accounts,
                followers: followerResults,
                startedAt: startedAt,
                inputType: input.catalog.inputType,
                warnings: warnings
            )
            try await coordinator.update(id: operationID, progress: OperationProgress(completed: input.catalog.followers.count + 3, total: input.catalog.followers.count + 3, phase: "Completado"))
            return result
        }
        activeTask = task

        do {
            let result = try await task.value
            if let failure = ZEUVEHistoryPersistence.attempt({ try history.save(result) }) {
                onWarning(failure.warning)
                _ = try? await logger?.write(
                    .warning,
                    category: "instagram-followers",
                    message: "No se ha podido guardar el historial",
                    metadata: failure.logMetadata
                )
            }
            try await coordinator.finish(id: operationID)
            activeTask = nil
            activeOperationID = nil
            return result
        } catch {
            try? await coordinator.finish(id: operationID)
            activeTask = nil
            activeOperationID = nil
            throw error
        }
    }

    public func cancel() async {
        activeTask?.cancel()
        if let activeOperationID { try? await coordinator.requestCancellation(id: activeOperationID) }
    }

    public func markExported(resultID: UUID) throws {
        try history.markExported(id: resultID)
    }

    private struct Payloads: Sendable {
        let following: Data
        let followers: [String: Data]
    }

    private static func readPayloads(_ input: InstagramFollowersPreparedInput) throws -> Payloads {
        switch input {
        case .archive(let url, let catalog):
            let data = try InstagramFollowersArchiveReader(url: url).readRelevantFiles(catalog: catalog)
            guard let following = data[catalog.following.path] else { throw InstagramFollowersError.inputMissing(catalog.following.name) }
            return Payloads(following: following, followers: data.filter { $0.key != catalog.following.path })
        case .jsonFiles(let followingURL, let followerURLs, let catalog):
            let following = try readFile(followingURL)
            var followers: [String: Data] = [:]
            for (url, descriptor) in zip(followerURLs, catalog.followers) {
                try Task.checkCancellation()
                followers[descriptor.path] = try readFile(url)
            }
            return Payloads(following: following, followers: followers)
        }
    }

    private static func readFile(_ url: URL) throws -> Data {
        guard FileManager.default.fileExists(atPath: url.path) else { throw InstagramFollowersError.inputMissing(url.lastPathComponent) }
        do { return try Data(contentsOf: url, options: [.mappedIfSafe]) }
        catch { throw InstagramFollowersError.inputUnreadable(url.lastPathComponent) }
    }

    private static func catalogJSONFiles(following: URL, followers: [URL]) throws -> (catalog: InstagramFollowersInputCatalog, orderedURLs: [URL]) {
        guard following.lastPathComponent.lowercased() == "following.json" else {
            throw InstagramFollowersError.unsupportedInput(following.lastPathComponent)
        }
        let followingValues = try resourceValues(for: following)
        var items: [(url: URL, descriptor: InstagramFollowersFileDescriptor)] = []
        var seenSequences = Set<Int>()
        var seenURLs = Set<URL>()
        let regex = try NSRegularExpression(pattern: #"(?i)^followers_([0-9]+)\.json$"#)
        for url in followers {
            let name = url.lastPathComponent
            let range = NSRange(name.startIndex..., in: name)
            guard let match = regex.firstMatch(in: name, range: range),
                  let sequenceRange = Range(match.range(at: 1), in: name),
                  let sequence = Int(name[sequenceRange]) else {
                throw InstagramFollowersError.unsupportedInput(name)
            }
            let standardized = url.standardizedFileURL
            guard seenURLs.insert(standardized).inserted else { throw InstagramFollowersError.archiveConflict("archivo repetido: \(name)") }
            guard seenSequences.insert(sequence).inserted else { throw InstagramFollowersError.archiveConflict("más de un archivo followers_\(sequence).json") }
            let values = try resourceValues(for: standardized)
            items.append((standardized, .init(name: name, path: standardized.path, size: Int64(values.fileSize ?? 0), sequence: sequence)))
        }
        items.sort {
            if $0.descriptor.sequence == $1.descriptor.sequence { return $0.url.path < $1.url.path }
            return ($0.descriptor.sequence ?? 0) < ($1.descriptor.sequence ?? 0)
        }
        let followingDescriptor = InstagramFollowersFileDescriptor(
            name: following.lastPathComponent,
            path: following.standardizedFileURL.path,
            size: Int64(followingValues.fileSize ?? 0)
        )
        return (
            InstagramFollowersInputCatalog(inputType: .jsonFiles, following: followingDescriptor, followers: items.map(\.descriptor)),
            items.map(\.url)
        )
    }

    private static func resourceValues(for url: URL) throws -> URLResourceValues {
        guard FileManager.default.fileExists(atPath: url.path) else { throw InstagramFollowersError.inputMissing(url.lastPathComponent) }
        do {
            let values = try url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
            guard values.isRegularFile == true else { throw InstagramFollowersError.inputUnreadable(url.lastPathComponent) }
            return values
        } catch let error as InstagramFollowersError { throw error }
        catch { throw InstagramFollowersError.inputUnreadable(url.lastPathComponent) }
    }
}
