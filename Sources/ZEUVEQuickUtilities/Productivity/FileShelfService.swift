import Foundation

public struct FileShelfItem: Identifiable, Sendable, Equatable {
    public let id: UUID
    public let url: URL
    public var name: String { url.lastPathComponent }
    public init(url: URL) { id = UUID(); self.url = url }
}
@MainActor public final class FileShelfUtilityService: QuickUtilityService {
    public let id = QuickUtilityID.fileShelf
    public private(set) var state = QuickUtilityState.disabled { didSet { stateDidChange?(state) } }
    public var stateDidChange: (@MainActor (QuickUtilityState) -> Void)?
    public var itemsDidChange: (@MainActor () -> Void)?
    public var presentShelf: (@MainActor () -> Void)?
    public var dismissShelf: (@MainActor () -> Void)?
    public private(set) var items: [FileShelfItem] = []
    public let maximumReferences = 500
    public init() {}
    public func start() async throws { try Task.checkCancellation(); state = .active }
    public func stop() async throws { dismissShelf?(); items.removeAll(); itemsDidChange?(); state = .disabled }
    public func restoreDefaultSettings() async throws { try await stop() }
    public func show() throws {
        guard state == .active else { throw QuickUtilityError.failure("Activa la Bandeja temporal en Ajustes > Utilidades rápidas.") }
        presentShelf?()
    }
    public func add(_ urls: [URL]) throws {
        guard state == .active else { throw QuickUtilityError.failure("La bandeja está desactivada.") }
        var failures = 0
        var overCapacity = 0
        for url in urls {
            guard url.isFileURL, url.host == nil || url.host == "" || url.host == "localhost",
                  !url.path.utf8.contains(0), FileManager.default.fileExists(atPath: url.path) else { failures += 1; continue }
            let normalized = url.standardizedFileURL
            if !items.contains(where: { $0.url == normalized }) {
                if items.count < maximumReferences { items.append(.init(url: normalized)) }
                else { overCapacity += 1 }
            }
        }
        itemsDidChange?()
        if overCapacity > 0 { throw QuickUtilityError.failure("La bandeja admite hasta \(maximumReferences) referencias para acotar su memoria. Se omitieron \(overCapacity) elementos; los archivos permanecen intactos.") }
        if failures > 0 { throw QuickUtilityError.failure("Se omitieron \(failures) referencias que no son archivos locales disponibles.") }
    }
    public func remove(_ id: UUID) { items.removeAll { $0.id == id }; itemsDidChange?() }
    @discardableResult public func removeMissing() -> Int {
        let previous = items.count
        items.removeAll { !FileManager.default.fileExists(atPath: $0.url.path) }
        if previous != items.count { itemsDidChange?() }
        return previous - items.count
    }
    public func referencesForDrag() throws -> [URL] {
        guard state == .active else { throw QuickUtilityError.failure("La bandeja está desactivada.") }
        removeMissing()
        return items.map(\.url)
    }
    public func referenceForDrag(id: UUID) throws -> URL {
        guard state == .active else { throw QuickUtilityError.failure("La bandeja está desactivada.") }
        removeMissing()
        guard let item = items.first(where: { $0.id == id }) else { throw QuickUtilityError.failure("El archivo ya no está disponible; su referencia se ha retirado.") }
        return item.url
    }
}
