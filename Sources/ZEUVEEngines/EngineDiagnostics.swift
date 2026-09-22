import Foundation

public actor EngineDiagnosticService {
    private struct ResourceFingerprint: Equatable, Sendable {
        let path: String?
        let size: UInt64?
        let modificationDate: TimeInterval?
        let permissions: Int?
    }

    private struct DiagnosticFingerprint: Equatable, Sendable {
        let executable: ResourceFingerprint
        let license: ResourceFingerprint
    }

    private struct CachedDiagnostic: Sendable {
        let fingerprint: DiagnosticFingerprint
        let diagnostic: EngineDiagnostic
    }

    private let registry: EngineRegistry
    private let fileManager: FileManager
    private var cache: [String: CachedDiagnostic] = [:]

    public init(registry: EngineRegistry, fileManager: FileManager = .default) {
        self.registry = registry
        self.fileManager = fileManager
    }

    public func diagnoseAll(forceRefresh: Bool = false) async -> [EngineDiagnostic] {
        var results: [EngineDiagnostic] = []
        for descriptor in registry.manifest.engines {
            results.append(await diagnose(descriptor, forceRefresh: forceRefresh))
        }
        return results
    }

    public func diagnose(named name: String, forceRefresh: Bool = false) async -> EngineDiagnostic? {
        guard let descriptor = try? registry.descriptor(named: name) else { return nil }
        return await diagnose(descriptor, forceRefresh: forceRefresh)
    }

    public func requireReady(_ names: [String], forceRefresh: Bool = false) async throws -> [String: URL] {
        var urls: [String: URL] = [:]
        var unavailable: [String] = []
        for name in names {
            guard let descriptor = try? registry.descriptor(named: name) else {
                unavailable.append(name)
                continue
            }
            let diagnostic = await diagnose(descriptor, forceRefresh: forceRefresh)
            if diagnostic.isReady, let url = try? registry.executableURL(named: name) {
                urls[name] = url
            } else {
                unavailable.append(name)
            }
        }
        guard unavailable.isEmpty else { throw EngineRegistryError.requiredEnginesUnavailable(unavailable) }
        return urls
    }

    public func invalidateDiagnostics() {
        cache.removeAll(keepingCapacity: true)
    }

    func cachedDiagnosticCount() -> Int { cache.count }

    private func diagnose(_ descriptor: EngineDescriptor, forceRefresh: Bool) async -> EngineDiagnostic {
        let fingerprint = diagnosticFingerprint(for: descriptor)
        if !forceRefresh,
           let cached = cache[descriptor.name],
           cached.fingerprint == fingerprint {
            return cached.diagnostic
        }

        let diagnostic = await performDiagnostic(descriptor)
        cache[descriptor.name] = CachedDiagnostic(
            fingerprint: diagnosticFingerprint(for: descriptor),
            diagnostic: diagnostic
        )
        return diagnostic
    }

    private func performDiagnostic(_ descriptor: EngineDescriptor) async -> EngineDiagnostic {
        let url: URL
        do {
            url = try registry.executableURL(named: descriptor.name)
        } catch {
            return EngineDiagnostic(descriptor: descriptor, state: .invalidManifest, message: error.localizedDescription)
        }
        guard fileManager.fileExists(atPath: url.path) else {
            return EngineDiagnostic(descriptor: descriptor, state: .missing, message: "No se encuentra el ejecutable incluido.")
        }
        do {
            let license = try registry.licenseURL(for: descriptor)
            guard fileManager.fileExists(atPath: license.path) else {
                return EngineDiagnostic(descriptor: descriptor, state: .invalidManifest, message: "No se encuentra el aviso o la licencia de terceros asociada al motor.")
            }
        } catch {
            return EngineDiagnostic(descriptor: descriptor, state: .invalidManifest, message: "La ruta del aviso o licencia del motor no es segura.")
        }
        guard fileManager.isExecutableFile(atPath: url.path) else {
            return EngineDiagnostic(descriptor: descriptor, state: .notExecutable, message: "El archivo existe, pero no tiene permiso de ejecución.")
        }
        // El tamaño y la huella SHA-256 se verifican durante la preparación y el
        // empaquetado. No se comparan en tiempo de ejecución porque codesign
        // modifica los bytes y el tamaño de los ejecutables incluidos en la app.

        #if !os(macOS)
        return EngineDiagnostic(descriptor: descriptor, state: .unsupportedPlatform, message: "La verificación de ejecución requiere macOS Apple Silicon.")
        #else
        guard MachOInspector.satisfies(descriptor.architecture, at: url) else {
            return EngineDiagnostic(descriptor: descriptor, state: .wrongArchitecture, message: "La arquitectura no es compatible con \(descriptor.architecture.spanishName).")
        }

        let dependencies = await dynamicDependencies(for: url)
        if dependencies.contains(where: { $0.hasPrefix("FALTA:") }) {
            return EngineDiagnostic(
                descriptor: descriptor,
                state: .missingDynamicDependency,
                message: "Falta una dependencia dinámica necesaria.",
                dynamicDependencies: dependencies
            )
        }

        let runner = ExternalProcessRunner()
        let stdout = LockedDataCollector(maximumBytes: 262_144)
        let stderr = LockedDataCollector(maximumBytes: 262_144)
        do {
            let result = try await runner.run(
                ExternalProcessRequest(executable: url, arguments: descriptor.diagnosticArguments),
                onStdout: { stdout.append($0) },
                onStderr: { stderr.append($0) }
            )
            guard result.exitCode == 0, result.terminationSignal == 0 else {
                let details = EngineDiagnosticDetailFormatter.processFailureDetails(
                    result: result,
                    stdout: stdout.data,
                    stderr: stderr.data
                )
                let message: String
                if result.terminationSignal != 0 {
                    message = "El motor se inicia, pero macOS lo termina con la señal \(result.terminationSignal). Consulta los detalles técnicos."
                } else {
                    message = "El motor se inicia, pero termina con el código \(result.exitCode). Consulta los detalles técnicos."
                }
                return EngineDiagnostic(
                    descriptor: descriptor,
                    state: .launchFailed,
                    message: message,
                    dynamicDependencies: dependencies,
                    technicalDetails: details
                )
            }
            let output = String(decoding: stdout.data + stderr.data, as: UTF8.self)
            guard output.localizedCaseInsensitiveContains(descriptor.version) else {
                return EngineDiagnostic(
                    descriptor: descriptor,
                    state: .versionMismatch,
                    message: "La versión detectada no coincide con la versión registrada.",
                    detectedVersion: firstNonEmptyLine(output),
                    dynamicDependencies: dependencies
                )
            }
            return EngineDiagnostic(
                descriptor: descriptor,
                state: .ready,
                message: "Motor disponible y comprobado.",
                detectedVersion: firstNonEmptyLine(output),
                dynamicDependencies: dependencies
            )
        } catch {
            return EngineDiagnostic(
                descriptor: descriptor,
                state: .launchFailed,
                message: "No se ha podido iniciar el motor. Consulta los detalles técnicos.",
                dynamicDependencies: dependencies,
                technicalDetails: EngineDiagnosticDetailFormatter.launchFailureDetails(error)
            )
        }
        #endif
    }

    private func diagnosticFingerprint(for descriptor: EngineDescriptor) -> DiagnosticFingerprint {
        let executable = (try? registry.executableURL(named: descriptor.name))
        let license = (try? registry.licenseURL(for: descriptor))
        return DiagnosticFingerprint(
            executable: resourceFingerprint(for: executable),
            license: resourceFingerprint(for: license)
        )
    }

    private func resourceFingerprint(for url: URL?) -> ResourceFingerprint {
        guard let url else {
            return ResourceFingerprint(path: nil, size: nil, modificationDate: nil, permissions: nil)
        }
        guard let attributes = try? fileManager.attributesOfItem(atPath: url.path) else {
            return ResourceFingerprint(path: url.path, size: nil, modificationDate: nil, permissions: nil)
        }
        return ResourceFingerprint(
            path: url.path,
            size: (attributes[.size] as? NSNumber)?.uint64Value,
            modificationDate: (attributes[.modificationDate] as? Date)?.timeIntervalSinceReferenceDate,
            permissions: (attributes[.posixPermissions] as? NSNumber)?.intValue
        )
    }

    private func dynamicDependencies(for executable: URL) async -> [String] {
        #if os(macOS)
        let otool = URL(fileURLWithPath: "/usr/bin/otool")
        guard fileManager.isExecutableFile(atPath: otool.path) else { return ["FALTA: /usr/bin/otool"] }
        let collector = LockedDataCollector(maximumBytes: 1_048_576)
        do {
            let result = try await ExternalProcessRunner().run(
                ExternalProcessRequest(executable: otool, arguments: ["-L", executable.path]),
                onStdout: { collector.append($0) }
            )
            guard result.exitCode == 0 else { return ["FALTA: no se ha podido inspeccionar con otool"] }
            let lines = String(decoding: collector.data, as: UTF8.self)
                .split(separator: "\n")
                .dropFirst()
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
                .filter { !isDynamicDependencyHeader($0, for: executable) }
            return lines.map { line in
                let path = line.split(separator: " ").first.map(String.init) ?? line
                if path.hasPrefix("/usr/lib/") || path.hasPrefix("/System/Library/") {
                    return line
                }
                if path.hasPrefix("@loader_path/") || path.hasPrefix("@executable_path/") {
                    let suffix = path.split(separator: "/").dropFirst().joined(separator: "/")
                    let resolved = executable.deletingLastPathComponent().appendingPathComponent(suffix).resolvingSymlinksInPath()
                    return isIncludedAndPresent(resolved) ? line : "FALTA: dependencia no incluida: \(line)"
                }
                if path.hasPrefix("@rpath/") {
                    let name = URL(fileURLWithPath: path).lastPathComponent
                    let matches = (try? fileManager.subpathsOfDirectory(atPath: registry.resourceRoot.path))?.contains {
                        URL(fileURLWithPath: $0).lastPathComponent == name
                    } == true
                    return matches ? line : "FALTA: dependencia @rpath no incluida: \(line)"
                }
                let resolved = URL(fileURLWithPath: path).resolvingSymlinksInPath()
                return isIncludedAndPresent(resolved) ? line : "FALTA: dependencia externa no permitida: \(line)"
            }
        } catch {
            return ["FALTA: \(error.localizedDescription)"]
        }
        #else
        return []
        #endif
    }

    private func isDynamicDependencyHeader(_ line: String, for executable: URL) -> Bool {
        guard line.hasSuffix(":") else { return false }
        let header = String(line.dropLast())
        let executablePath = executable.path
        return header == executablePath || header.hasPrefix(executablePath + " (architecture ")
    }

    private func isIncludedAndPresent(_ url: URL) -> Bool {
        let root = registry.resourceRoot.resolvingSymlinksInPath().standardizedFileURL
        let candidate = url.resolvingSymlinksInPath().standardizedFileURL
        let prefix = root.path.hasSuffix("/") ? root.path : root.path + "/"
        return candidate.path.hasPrefix(prefix) && fileManager.fileExists(atPath: candidate.path)
    }

    private func firstNonEmptyLine(_ value: String) -> String? {
        value.split(separator: "\n").map(String.init).first { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
    }
}

enum EngineDiagnosticDetailFormatter {
    private static let maximumCharactersPerStream = 16_384

    static func processFailureDetails(
        result: ExternalProcessResult,
        stdout: Data,
        stderr: Data
    ) -> [String] {
        var details = ["Código de salida: \(result.exitCode)"]
        if result.terminationSignal != 0 {
            details.append("Señal de terminación: \(result.terminationSignal)")
        }
        if result.wasCancelled {
            details.append("El proceso figura como cancelado.")
        }
        if let value = printableStream(stdout) {
            details.append("Salida estándar:\n\(value)")
        }
        if let value = printableStream(stderr) {
            details.append("Salida de error:\n\(value)")
        }
        return details
    }

    static func launchFailureDetails(_ error: Error) -> [String] {
        ["Error al iniciar el proceso: \(error.localizedDescription)"]
    }

    private static func printableStream(_ data: Data) -> String? {
        let value = String(decoding: data, as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }
        guard value.count > maximumCharactersPerStream else { return value }
        return String(value.prefix(maximumCharactersPerStream)) + "\n… salida truncada por el diagnóstico."
    }
}

public final class LockedDataCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var storage = Data()
    private let maximumBytes: Int

    public init(maximumBytes: Int) { self.maximumBytes = max(0, maximumBytes) }

    public func append(_ data: Data) {
        lock.lock(); defer { lock.unlock() }
        guard storage.count < maximumBytes else { return }
        storage.append(data.prefix(maximumBytes - storage.count))
    }

    public var data: Data {
        lock.lock(); defer { lock.unlock() }
        return storage
    }
}
