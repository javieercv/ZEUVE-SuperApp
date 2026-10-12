import Foundation
import Combine
import ZEUVEStorage
import ZEUVEOperations
#if os(macOS)
import Darwin
#endif

public enum NewFileFormat: String, Codable, CaseIterable, Sendable {
    case text, markdown, json, csv, empty
    public var fileExtension: String {
        switch self { case .text: "txt"; case .markdown: "md"; case .json: "json"; case .csv: "csv"; case .empty: "" }
    }
    public var title: String {
        switch self { case .text: "Texto"; case .markdown: "Markdown"; case .json: "JSON"; case .csv: "CSV"; case .empty: "Archivo vacío" }
    }
    public var initialContent: String { self == .json ? "{}\n" : "" }
}
public struct FileTemplate: Codable, Sendable, Equatable, Identifiable {
    public var id: UUID
    public var name: String
    public var fileExtension: String
    public var content: String
    public init(id: UUID = UUID(), name: String, fileExtension: String, content: String) {
        self.id = id; self.name = name; self.fileExtension = fileExtension; self.content = content
    }
    public func validate() throws {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw QuickUtilityError.failure("La plantilla necesita un nombre.") }
        try SafeNewFilePublisher.validate(name: "archivo." + fileExtension)
    }
}
public struct NewFilePreferences: Codable, Sendable, Equatable {
    public var schemaVersion = 1
    public var format = NewFileFormat.text
    public var templates: [FileTemplate] = []
    public init() {}
    public func validate() throws {
        guard schemaVersion == 1 else { throw QuickUtilityError.failure("Configuración de plantillas incompatible.") }
        for template in templates { try template.validate() }
    }
}

public actor SafeNewFilePublisher {
    public init() {}
    public nonisolated static func validate(name: String) throws {
        let forbidden = CharacterSet.controlCharacters.union(CharacterSet(charactersIn: "/:"))
        guard !name.isEmpty, name != ".", name != "..", !name.hasPrefix("."),
              name == name.trimmingCharacters(in: .whitespacesAndNewlines),
              name.utf8.count <= 255, name.rangeOfCharacter(from: forbidden) == nil else {
            throw QuickUtilityError.failure("Usa un nombre visible, sin barras, dos puntos ni caracteres de control.")
        }
        let ext = URL(fileURLWithPath: name).pathExtension.lowercased()
        let allowed: Set<String> = ["", "txt", "md", "markdown", "json", "csv", "tsv", "xml", "yaml", "yml", "html", "css", "js", "swift", "py", "log", "ini", "toml"]
        guard allowed.contains(ext) else { throw QuickUtilityError.failure("La extensión no está permitida para crear un archivo vacío o una plantilla.") }
    }
    public func create(directory: URL, name: String, content: String, cancellationCheck: @escaping @Sendable () async -> Bool = { false }) async throws -> URL {
        try Self.validate(name: name); try Task.checkCancellation()
        if await cancellationCheck() { throw CancellationError() }
        guard directory.isFileURL, directory.host == nil || directory.host == "" || directory.host == "localhost",
              !directory.path.utf8.contains(0) else { throw QuickUtilityError.failure("El destino debe ser una carpeta local válida elegida.") }
        #if os(macOS)
        var parent = open("/", O_RDONLY | O_DIRECTORY)
        guard parent >= 0 else { throw QuickUtilityError.failure("No se pudo abrir el destino.") }
        defer { close(parent) }
        // Walk from a pinned descriptor. Never follow a symlink in any component.
        for component in directory.pathComponents where component != "/" {
            guard component != "..", component != "." else { throw QuickUtilityError.failure("La ruta del destino no es válida.") }
            let next = component.withCString { openat(parent, $0, O_RDONLY | O_DIRECTORY | O_NOFOLLOW) }
            guard next >= 0 else { throw QuickUtilityError.failure("No se pudo abrir la carpeta. Comprueba permisos y enlaces simbólicos.") }
            close(parent); parent = next
        }
        let temporary = ".zeuve-new-\(UUID().uuidString)"
        let descriptor = temporary.withCString { openat(parent, $0, O_RDWR | O_CREAT | O_EXCL | O_NOFOLLOW, 0o600) }
        guard descriptor >= 0 else { throw QuickUtilityError.failure("No se pudo preparar el archivo nuevo.") }
        var identity = stat()
        guard fstat(descriptor, &identity) == 0 else { close(descriptor); throw QuickUtilityError.failure("No se pudo verificar el archivo temporal.") }
        defer {
            close(descriptor)
            var current = stat()
            if temporary.withCString({ fstatat(parent, $0, &current, AT_SYMLINK_NOFOLLOW) }) == 0,
               current.st_ino == identity.st_ino, current.st_dev == identity.st_dev {
                _ = temporary.withCString { unlinkat(parent, $0, 0) }
            }
        }
        let data = Data(content.utf8)
        var offset = 0
        while offset < data.count {
            try Task.checkCancellation()
            if await cancellationCheck() { throw CancellationError() }
            let count = data.withUnsafeBytes { raw in Darwin.write(descriptor, raw.baseAddress!.advanced(by: offset), min(65536, raw.count - offset)) }
            if count < 0 && errno == EINTR { continue }
            guard count > 0 else { throw QuickUtilityError.failure("No se pudo escribir el archivo nuevo.") }
            offset += count
        }
        guard fchmod(descriptor, 0o644) == 0, fsync(descriptor) == 0 else { throw QuickUtilityError.failure("No se pudo confirmar la escritura del archivo.") }
        try Task.checkCancellation()
        if await cancellationCheck() { throw CancellationError() }
        // Publish from the descriptor, never from a replaceable temporary pathname.
        // APFS cloning creates the complete destination exclusively and atomically.
        let result = name.withCString { fclonefileat(descriptor, parent, $0, UInt32(CLONE_NOOWNERCOPY)) }
        if result != 0 {
            let cloneError = errno
            if cloneError == EEXIST { throw QuickUtilityError.failure("Ya existe un archivo con ese nombre. Elige otro nombre; el original se ha conservado.") }
            guard [ENOTSUP, EINVAL, EXDEV, ENOSYS].contains(cloneError) else { throw QuickUtilityError.failure("No se pudo publicar el archivo nuevo; comprueba permisos y espacio disponible.") }
            // Filesystems without cloning use exclusive destination creation. The
            // result becomes visible during writing, but never replaces another
            // object. Errors/cancellation remove only the verified owned inode.
            let target = name.withCString { openat(parent, $0, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW, 0o600) }
            guard target >= 0 else { throw QuickUtilityError.failure("El nombre está ocupado o el destino no permite crear el archivo. No se ha reemplazado nada.") }
            var targetIdentity = stat()
            guard fstat(target, &targetIdentity) == 0 else { close(target); throw QuickUtilityError.failure("No se pudo verificar el destino nuevo.") }
            var committed = false
            defer {
                close(target)
                if !committed {
                    var current = stat()
                    if name.withCString({ fstatat(parent, $0, &current, AT_SYMLINK_NOFOLLOW) }) == 0,
                       current.st_ino == targetIdentity.st_ino, current.st_dev == targetIdentity.st_dev {
                        _ = name.withCString { unlinkat(parent, $0, 0) }
                    }
                }
            }
            var offset = 0
            while offset < data.count {
                try Task.checkCancellation()
                if await cancellationCheck() { throw CancellationError() }
                let count = data.withUnsafeBytes { raw in Darwin.write(target, raw.baseAddress!.advanced(by: offset), min(65536, raw.count - offset)) }
                if count < 0 && errno == EINTR { continue }
                guard count > 0 else { throw QuickUtilityError.failure("No se pudo completar el archivo nuevo.") }
                offset += count
            }
            guard fchmod(target, 0o644) == 0, fsync(target) == 0 else { throw QuickUtilityError.failure("No se pudo confirmar la escritura del archivo nuevo.") }
            var current = stat()
            guard name.withCString({ fstatat(parent, $0, &current, AT_SYMLINK_NOFOLLOW) }) == 0,
                  current.st_ino == targetIdentity.st_ino, current.st_dev == targetIdentity.st_dev,
                  current.st_mode & S_IFMT == S_IFREG else { throw QuickUtilityError.failure("El destino cambió durante la escritura. No se modificará el objeto que lo sustituyó.") }
            committed = true
        }
        return directory.appendingPathComponent(name)
        #else
        throw QuickUtilityError.unavailable("La publicación segura requiere macOS.")
        #endif
    }
}

@MainActor public final class NewFileUtilityService: ObservableObject, QuickUtilityService {
    public let id = QuickUtilityID.newFile
    @Published public private(set) var state = QuickUtilityState.disabled { didSet { stateDidChange?(state) } }
    public var stateDidChange: (@MainActor (QuickUtilityState) -> Void)?
    public var willStop: (@MainActor () -> Void)?
    @Published public private(set) var preferences = NewFilePreferences()
    private let settings: SettingsRepository?
    private let publisher = SafeNewFilePublisher()
    private var operations: [UUID: Task<URL, any Error>] = [:]
    private let operationCoordinator: OperationCoordinator?
    private var configurationLoaded = false
    public init(settings: SettingsRepository?, operationCoordinator: OperationCoordinator? = nil) {
        self.settings = settings
        self.operationCoordinator = operationCoordinator
    }
    public func prepareSettings() throws { try loadConfiguration() }
    private func loadConfiguration() throws {
        guard let settings else { throw QuickUtilityError.failure("El almacenamiento local no está disponible.") }
        let loaded = try settings.value(forKey: "quickUtilities.newFile.v1", as: NewFilePreferences.self) ?? .init()
        try loaded.validate(); preferences = loaded; configurationLoaded = true
    }
    public func start() async throws {
        guard state != .active else { return }
        state = .activating
        do {
            try loadConfiguration(); state = .active
        } catch { state = .failed("No se pudieron recuperar las plantillas."); throw error }
    }
    public func stop() async throws {
        state = .deactivating
        willStop?()
        let pending = Array(operations.values)
        pending.forEach { $0.cancel() }
        for task in pending { _ = await task.result }
        state = .disabled
    }
    public func save(_ preferences: NewFilePreferences) throws {
        if !configurationLoaded { try loadConfiguration() }
        try preferences.validate()
        guard let settings else { throw QuickUtilityError.failure("El almacenamiento local no está disponible.") }
        try settings.set(preferences, forKey: "quickUtilities.newFile.v1"); self.preferences = preferences
    }
    public func restoreDefaultSettings() async throws {
        try loadConfiguration()
        var defaults = NewFilePreferences(); defaults.templates = preferences.templates
        try save(defaults)
    }
    public func create(directory: URL, name: String, content: String) async throws -> URL {
        guard state == .active else { throw QuickUtilityError.failure("Activa Crear archivos en Ajustes > Utilidades rápidas.") }
        let id = UUID(), publisher = publisher, coordinator = operationCoordinator
        let task = Task {
            var reservation: UUID?
            if content.utf8.count > 1_048_576 {
                guard let coordinator else { throw QuickUtilityError.failure("La coordinación de operaciones no está disponible para esta plantilla grande.") }
                reservation = try await coordinator.begin(moduleID: self.id.id, name: "Crear archivo desde plantilla")
            }
            do {
                let token = reservation
                let result = try await publisher.create(directory: directory, name: name, content: content, cancellationCheck: {
                    guard let token, let coordinator else { return false }
                    return await coordinator.shouldCancel(id: token)
                })
                if let reservation, let coordinator { try await coordinator.finish(id: reservation) }
                return result
            } catch {
                if let reservation, let coordinator { try await coordinator.finish(id: reservation) }
                throw error
            }
        }
        operations[id] = task
        defer { operations[id] = nil }
        return try await withTaskCancellationHandler { try await task.value } onCancel: { task.cancel() }
    }
}
