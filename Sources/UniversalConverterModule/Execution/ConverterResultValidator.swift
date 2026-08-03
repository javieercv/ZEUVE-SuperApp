import Foundation

public actor ConverterResultValidator {
    private let detector: ConverterFormatDetector
    private let probeService: MediaProbeService

    public init(
        detector: ConverterFormatDetector = ConverterFormatDetector(),
        probeService: MediaProbeService = MediaProbeService()
    ) {
        self.detector = detector
        self.probeService = probeService
    }

    public func validate(
        url: URL,
        expectedFormat: ConverterFormat,
        directory: Bool,
        ffprobe: URL? = nil
    ) async throws {
        if directory {
            let sample = try regularFileSample(in: url, expectedFormat: expectedFormat)
            guard sample.count > 0 else {
                throw UniversalConverterError.invalidResult("No se ha generado ningún archivo.")
            }
            for file in sample.files {
                try Task.checkCancellation()
                let detected = try detector.detectDetailed(url: file)
                if expectedFormat != .unknown,
                   detected.detectedFormat != expectedFormat,
                   !(expectedFormat == .jpeg && detected.detectedFormat == .jpeg) {
                    throw UniversalConverterError.invalidResult("«\(file.lastPathComponent)» no tiene el formato esperado \(expectedFormat.displayName).")
                }
            }
            return
        }

        let values = try url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey, .isSymbolicLinkKey])
        guard values.isRegularFile == true,
              values.isSymbolicLink != true,
              (values.fileSize ?? 0) > 0 else {
            throw UniversalConverterError.invalidResult("El archivo generado está vacío o no es un archivo regular.")
        }

        switch expectedFormat.category {
        case .audio:
            guard let ffprobe else { return try validateDetected(url, expected: expectedFormat) }
            let probe = try await probeService.probe(url: url, ffprobe: ffprobe)
            guard probe.audioStream != nil else {
                throw UniversalConverterError.invalidResult("FFprobe no ha encontrado una pista de audio válida.")
            }
        case .video:
            guard let ffprobe else { return try validateDetected(url, expected: expectedFormat) }
            let probe = try await probeService.probe(url: url, ffprobe: ffprobe)
            guard probe.videoStream != nil else {
                throw UniversalConverterError.invalidResult("FFprobe no ha encontrado una pista de vídeo válida.")
            }
        case .animation:
            if let ffprobe {
                let probe = try await probeService.probe(url: url, ffprobe: ffprobe)
                guard probe.videoStream != nil else {
                    throw UniversalConverterError.invalidResult("La animación no contiene fotogramas válidos.")
                }
            } else {
                try validateDetected(url, expected: expectedFormat)
            }
        case .image, .vectorImage, .pdf, .ebook, .text, .markup, .data, .archive:
            try validateDetected(url, expected: expectedFormat)
        case .unknown:
            break
        }
    }

    /// Conserva únicamente fotogramas completos al cancelar o fallar una extracción.
    /// Solo puede eliminar el último archivo si está vacío, dañado o no corresponde al formato esperado.
    @discardableResult
    public func retainValidFramePrefix(url: URL, expectedFormat: ConverterFormat) async throws -> Int {
        let summary = try frameFileSummary(in: url, expectedFormat: expectedFormat)
        guard let last = summary.last else { return 0 }
        let values = try last.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey, .isSymbolicLinkKey])
        var valid = values.isRegularFile == true && values.isSymbolicLink != true && (values.fileSize ?? 0) > 0
        if valid {
            do {
                let detected = try detector.detectDetailed(url: last)
                valid = detected.detectedFormat == expectedFormat
            } catch {
                valid = false
            }
        }
        if !valid {
            try? FileManager.default.removeItem(at: last)
            return max(summary.count - 1, 0)
        }
        return summary.count
    }

    public func cancel() async {
        await probeService.cancel()
    }

    private func validateDetected(_ url: URL, expected: ConverterFormat) throws {
        let detection = try detector.detectDetailed(url: url)
        guard detection.detectedFormat == expected else {
            throw UniversalConverterError.invalidResult(
                "Se esperaba \(expected.displayName), pero el contenido generado se ha detectado como \(detection.detectedFormat.displayName)."
            )
        }
        guard detection.isReliable || expected.category == .text || expected.category == .markup else {
            throw UniversalConverterError.invalidResult("El formato generado no ha podido confirmarse mediante su contenido.")
        }
    }

    private func regularFileSample(in root: URL, expectedFormat: ConverterFormat) throws -> (count: Int, files: [URL]) {
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey],
            options: [.skipsHiddenFiles]
        ) else { return (0, []) }

        var count = 0
        var first: [URL] = []
        var tail: [URL] = []
        for case let url as URL in enumerator {
            if Task.isCancelled { throw CancellationError() }
            guard expectedFormat == .unknown || url.pathExtension.lowercased() == expectedFormat.fileExtension.lowercased() else { continue }
            let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
            guard values.isRegularFile == true, values.isSymbolicLink != true else { continue }
            count += 1
            if first.count < 16 {
                first.append(url)
            } else {
                tail.append(url)
                if tail.count > 16 { tail.removeFirst() }
            }
        }
        return (count, first + tail)
    }

    private func frameFileSummary(in root: URL, expectedFormat: ConverterFormat) throws -> (count: Int, last: URL?) {
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey],
            options: [.skipsHiddenFiles]
        ) else { return (0, nil) }
        var count = 0
        var last: URL?
        for case let url as URL in enumerator {
            guard url.pathExtension.lowercased() == expectedFormat.fileExtension.lowercased() else { continue }
            let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
            guard values.isRegularFile == true, values.isSymbolicLink != true else { continue }
            count += 1
            if let current = last {
                if current.lastPathComponent.localizedStandardCompare(url.lastPathComponent) == .orderedAscending {
                    last = url
                }
            } else {
                last = url
            }
        }
        return (count, last)
    }
}
