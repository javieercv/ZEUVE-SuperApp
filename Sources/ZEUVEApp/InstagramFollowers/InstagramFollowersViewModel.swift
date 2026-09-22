import Foundation
import AppKit
import UniformTypeIdentifiers
import ZEUVECore
import ZEUVEStorage
import ZEUVEOperations
import InstagramFollowersModule

enum InstagramFollowersImportMode: String, CaseIterable, Identifiable {
    case archive
    case jsonFiles

    var id: String { rawValue }
    var title: String { self == .archive ? "ZIP completo" : "JSON separados" }
}

@MainActor
final class InstagramFollowersViewModel: ObservableObject {
    @Published var importMode: InstagramFollowersImportMode = .archive
    @Published private(set) var archiveURL: URL?
    @Published private(set) var followingURL: URL?
    @Published private(set) var followerURLs: [URL] = []
    @Published private(set) var preparedInput: InstagramFollowersPreparedInput?
    @Published private(set) var result: InstagramFollowersComparisonResult?
    @Published private(set) var isPreparing = false
    @Published private(set) var isAnalyzing = false
    @Published var selectedCategory: InstagramFollowersCategory = .notFollowingBack
    @Published var searchText = "" { didSet { scheduleSearchUpdate() } }
    @Published private(set) var appliedSearchText = ""
    @Published var sortAscending = true
    @Published var errorMessage: String?
    @Published var warningMessage: String?
    @Published var showingGuide = false
    @Published var showingExport = false

    private let service: InstagramFollowersService
    private let exporter = InstagramFollowersExporter()
    private var searchTask: Task<Void, Never>?
    private var analysisTask: Task<Void, Never>?
    private var preparationRevision = 0

    init(coordinator: OperationCoordinator, storage: StorageContainer?, logger: LocalLogger? = nil) {
        service = InstagramFollowersService(
            coordinator: coordinator,
            history: InstagramFollowersHistoryService(repository: storage?.history),
            logger: logger
        )
    }

    var catalog: InstagramFollowersInputCatalog? { preparedInput?.catalog }
    var canAnalyze: Bool { preparedInput != nil && !isPreparing && !isAnalyzing }

    var visibleAccounts: [InstagramAccount] {
        guard let result else { return [] }
        let query = appliedSearchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        var accounts = result.accounts(in: selectedCategory)
        if !query.isEmpty { accounts = accounts.filter { $0.username.lowercased().contains(query) } }
        return accounts.sorted { sortAscending ? $0 < $1 : $1 < $0 }
    }

    var categoryTotal: Int {
        result?.accounts(in: selectedCategory).count ?? 0
    }

    func changeMode(_ mode: InstagramFollowersImportMode) {
        guard importMode != mode else { return }
        importMode = mode
        clearInput()
    }

    func selectArchive() {
        let panel = NSOpenPanel()
        panel.title = "Seleccionar exportación de Instagram"
        panel.prompt = "Inspeccionar"
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.zip]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        prepareArchive(url)
    }

    func selectFollowing() {
        let panel = NSOpenPanel()
        panel.title = "Seleccionar following.json"
        panel.prompt = "Seleccionar"
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.json]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        followingURL = url
        result = nil
        prepareAdvancedIfComplete()
    }

    func selectFollowers() {
        let panel = NSOpenPanel()
        panel.title = "Seleccionar todos los followers_<número>.json"
        panel.prompt = "Seleccionar"
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.json]
        guard panel.runModal() == .OK else { return }
        followerURLs = panel.urls
        result = nil
        prepareAdvancedIfComplete()
    }

    func handleDropped(urls: [URL]) {
        guard !urls.isEmpty else { return }
        switch importMode {
        case .archive:
            guard urls.count == 1, urls[0].pathExtension.lowercased() == "zip" else {
                errorMessage = "En el modo ZIP debes soltar una única exportación .zip de Instagram."
                return
            }
            prepareArchive(urls[0])
        case .jsonFiles:
            var following = followingURL
            var followers = followerURLs
            for url in urls where url.pathExtension.lowercased() == "json" {
                let name = url.lastPathComponent.lowercased()
                if name == "following.json" {
                    if following != nil && following?.standardizedFileURL != url.standardizedFileURL {
                        errorMessage = "Solo puede seleccionarse un following.json."
                        return
                    }
                    following = url
                } else if name.range(of: #"^followers_[0-9]+\.json$"#, options: .regularExpression) != nil {
                    followers.append(url)
                } else {
                    errorMessage = "El archivo «\(url.lastPathComponent)» no es following.json ni followers_<número>.json."
                    return
                }
            }
            followingURL = following
            followerURLs = Array(Set(followers.map(\.standardizedFileURL)))
            result = nil
            prepareAdvancedIfComplete()
        }
    }

    func prepareArchive(_ url: URL) {
        archiveURL = url
        followingURL = nil
        followerURLs = []
        preparedInput = nil
        result = nil
        isPreparing = true
        errorMessage = nil
        preparationRevision += 1
        let revision = preparationRevision
        Task {
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            do {
                let prepared = try await service.inspectArchive(url: url)
                guard revision == preparationRevision else { return }
                preparedInput = prepared
            } catch {
                guard revision == preparationRevision else { return }
                archiveURL = nil
                errorMessage = error.localizedDescription
            }
            if revision == preparationRevision { isPreparing = false }
        }
    }

    func prepareAdvancedIfComplete() {
        preparedInput = nil
        guard followingURL != nil, !followerURLs.isEmpty else { return }
        isPreparing = true
        errorMessage = nil
        preparationRevision += 1
        let revision = preparationRevision
        let following = followingURL
        let followers = followerURLs
        Task {
            let urls = ([following].compactMap { $0 } + followers)
            let scopes = urls.filter { $0.startAccessingSecurityScopedResource() }
            defer { scopes.forEach { $0.stopAccessingSecurityScopedResource() } }
            do {
                let prepared = try await service.inspectJSONFiles(following: following, followers: followers)
                guard revision == preparationRevision else { return }
                preparedInput = prepared
                if case .jsonFiles(let orderedFollowing, let orderedFollowers, _) = prepared {
                    followingURL = orderedFollowing
                    followerURLs = orderedFollowers
                }
            } catch {
                guard revision == preparationRevision else { return }
                errorMessage = error.localizedDescription
            }
            if revision == preparationRevision { isPreparing = false }
        }
    }

    func analyze() {
        guard let preparedInput, !isAnalyzing else { return }
        isAnalyzing = true
        errorMessage = nil
        warningMessage = nil
        analysisTask = Task {
            let scopes = preparedInput.securityScopedURLs.filter { $0.startAccessingSecurityScopedResource() }
            defer { scopes.forEach { $0.stopAccessingSecurityScopedResource() } }
            do {
                let newResult = try await service.analyze(preparedInput) { [weak self] warning in
                    Task { @MainActor in self?.warningMessage = warning }
                }
                result = newResult
                selectedCategory = .notFollowingBack
                searchText = ""
                appliedSearchText = ""
                sortAscending = true
                if !newResult.warnings.isEmpty { warningMessage = newResult.warnings.joined(separator: "\n") }
            } catch is CancellationError {
                warningMessage = "La comparación se ha cancelado. No se han guardado listas parciales."
            } catch {
                errorMessage = error.localizedDescription
            }
            isAnalyzing = false
        }
    }

    func cancel() {
        analysisTask?.cancel()
        Task { await service.cancel() }
    }

    func cancelAndWait() async {
        analysisTask?.cancel()
        await service.cancel()
        await analysisTask?.value
    }

    func clearInput() {
        archiveURL = nil
        followingURL = nil
        followerURLs = []
        preparedInput = nil
        result = nil
        preparationRevision += 1
        isPreparing = false
        searchText = ""
        appliedSearchText = ""
        searchTask?.cancel()
    }

    func analyzeAnother() { clearInput() }

    func openProfile(_ account: InstagramAccount) {
        NSWorkspace.shared.open(account.profileURL)
    }

    func export(category: InstagramFollowersCategory, visibleOnly: Bool, format: InstagramFollowersExportFormat) {
        guard let result else { return }
        let accounts = visibleOnly ? visibleAccounts : result.accounts(in: category).sorted()
        let panel = NSSavePanel()
        panel.title = "Exportar \(accounts.count) cuentas"
        panel.prompt = "Exportar"
        panel.canCreateDirectories = true
        panel.allowedContentTypes = format == .csv ? [.commaSeparatedText] : [.plainText]
        panel.nameFieldStringValue = "instagram-\(category.exportValue).\(format.rawValue)"
        guard panel.runModal() == .OK, let destination = panel.url else { return }
        let scoped = destination.deletingLastPathComponent().startAccessingSecurityScopedResource()
        defer { if scoped { destination.deletingLastPathComponent().stopAccessingSecurityScopedResource() } }
        do {
            try exporter.export(accounts: accounts, category: category, format: format, destination: destination, overwrite: true)
            serviceMarkExported(resultID: result.id)
            warningMessage = "Se han exportado \(accounts.count) cuentas en \(destination.lastPathComponent)."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func serviceMarkExported(resultID: UUID) {
        Task { try? await service.markExported(resultID: resultID) }
    }

    private func scheduleSearchUpdate() {
        searchTask?.cancel()
        let value = searchText
        searchTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(180))
            guard !Task.isCancelled else { return }
            self?.appliedSearchText = value
        }
    }
}
