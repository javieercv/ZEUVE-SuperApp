import Foundation
import ZEUVEEngines

public struct ConverterDiagnosticCheck: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let name: String
    public let state: String
    public let detail: String

    public init(id: String, name: String, state: String, detail: String) {
        self.id = id
        self.name = name
        self.state = state
        self.detail = detail
    }
}

public struct UniversalConverterDiagnosticsReport: Sendable, Equatable {
    public let createdAt: Date
    public let availability: ConverterEngineAvailability
    public let engineDiagnostics: [EngineDiagnostic]
    public let checks: [ConverterDiagnosticCheck]
    public let compatibilityEntries: [ConverterCompatibilityEntry]

    public init(
        createdAt: Date = Date(),
        availability: ConverterEngineAvailability,
        engineDiagnostics: [EngineDiagnostic],
        checks: [ConverterDiagnosticCheck],
        compatibilityEntries: [ConverterCompatibilityEntry]
    ) {
        self.createdAt = createdAt
        self.availability = availability
        self.engineDiagnostics = engineDiagnostics
        self.checks = checks
        self.compatibilityEntries = compatibilityEntries
    }

    public var readyEngineCount: Int { engineDiagnostics.filter(\.isReady).count }
    public var unavailableEngineCount: Int { engineDiagnostics.filter { !$0.isReady }.count }
}

public actor UniversalConverterDiagnosticService {
    private let locator: UniversalConverterEngineLocator

    public init(locator: UniversalConverterEngineLocator) {
        self.locator = locator
    }

    public static func bundled(diagnosticsService: EngineDiagnosticService? = nil) throws -> UniversalConverterDiagnosticService {
        .init(locator: try .bundled(diagnosticsService: diagnosticsService))
    }

    public func snapshot(forceRefresh: Bool = false) async -> UniversalConverterDiagnosticsReport {
        let diagnostics = await locator.diagnosticsSnapshot(forceRefresh: forceRefresh)
        let availability = await locator.availability(forceRefresh: false)
        let registry = ConverterCompatibilityRegistry(availability: availability)
        var checks: [ConverterDiagnosticCheck] = []
        checks.append(.init(
            id: "native-imageio",
            name: "ImageIO",
            state: availability.imageIO ? "Disponible" : "No disponible",
            detail: availability.imageIO ? "Codificación y lectura nativas detectadas." : "Requiere macOS con ImageIO."
        ))
        checks.append(.init(
            id: "native-pdfkit",
            name: "PDFKit",
            state: availability.pdfKit ? "Disponible" : "No disponible",
            detail: availability.pdfKit ? "Lectura y generación de PDF nativas detectadas." : "Requiere macOS con PDFKit."
        ))
        checks.append(.init(
            id: "native-videotoolbox",
            name: "VideoToolbox",
            state: availability.videoToolbox ? "Disponible" : "No disponible",
            detail: availability.videoToolbox ? "Aceleración de vídeo del sistema detectada." : "La codificación por hardware no está disponible en este entorno."
        ))
        checks.append(contentsOf: diagnostics.map { diagnostic in
            ConverterDiagnosticCheck(
                id: "engine-\(diagnostic.descriptor.name)",
                name: diagnostic.descriptor.name,
                state: diagnostic.state == .ready ? "Disponible" : diagnostic.state.rawValue,
                detail: diagnostic.message
            )
        })
        checks.append(contentsOf: syntheticChecks())
        return UniversalConverterDiagnosticsReport(
            availability: availability,
            engineDiagnostics: diagnostics,
            checks: checks,
            compatibilityEntries: registry.entries.filter { availability.isAvailable($0.engine) }
        )
    }

    private func syntheticChecks() -> [ConverterDiagnosticCheck] {
        let detector = ConverterFormatDetector()
        let png = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
        let pdf = Data("%PDF-1.7\n".utf8)
        let pngOK = detector.detect(sample: png, filename: "prueba.bin") == .png
        let pdfOK = detector.detect(sample: pdf, filename: "prueba.dat") == .pdf
        return [
            .init(id: "selftest-detection-png", name: "Autocomprobación PNG", state: pngOK ? "Correcta" : "Error", detail: "Detección sintética local sin archivos personales."),
            .init(id: "selftest-detection-pdf", name: "Autocomprobación PDF", state: pdfOK ? "Correcta" : "Error", detail: "Detección sintética local sin archivos personales."),
        ]
    }
}
