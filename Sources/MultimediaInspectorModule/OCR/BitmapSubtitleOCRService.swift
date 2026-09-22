import Foundation
import ZEUVEEngines
import ZEUVEOperations

#if canImport(Vision) && canImport(ImageIO)
import Vision
import ImageIO
#endif

public actor BitmapSubtitleOCRService {
    private let runner: ExternalProcessRunner
    private let coordinator: OperationCoordinator?
    private var operationID: UUID?

    public init(runner: ExternalProcessRunner = .init(), coordinator: OperationCoordinator? = nil) {
        self.runner = runner
        self.coordinator = coordinator
    }

    public func recognize(ffmpeg: URL, request: BitmapSubtitleOCRRequest, options inputOptions: BitmapSubtitleOCROptions) async throws -> BitmapSubtitleOCRDraft {
        #if canImport(Vision) && canImport(ImageIO)
        let activeID = try await coordinator?.begin(moduleID: multimediaInspectorModuleIdentifier, name: "OCR de subtítulos bitmap")
        operationID = activeID
        do {
        guard request.fingerprint.matches(request.url) else { throw MultimediaInspectorError.inputChanged(request.url.lastPathComponent) }
        let codec = request.codec.lowercased()
        guard ["hdmv_pgs_subtitle", "dvd_subtitle", "dvb_subtitle", "xsub"].contains(codec) else {
            throw MultimediaInspectorError.notEditable("la pista seleccionada no es un subtítulo bitmap compatible con OCR")
        }
        var options = inputOptions; options.normalize()
        let workspaceOperationID = UUID()
        let workspace = try MultimediaWorkspace(operationID: workspaceOperationID, extension: "tmp")
        defer { workspace.cleanup() }
        let pattern = workspace.root.appendingPathComponent("ocr-%012d.png").path
        let filter = "[0:\(request.streamIndex)]format=rgba[ocr]"
        let args = [
            "-hide_banner", "-nostdin", "-v", "error", "-i", request.url.path,
            "-filter_complex", filter, "-map", "[ocr]", "-vsync", "0", "-frame_pts", "1",
            "-c:v", "png", pattern,
        ]
        let result = try await runner.run(.init(executable: ffmpeg, arguments: args))
        guard result.succeeded else { throw MultimediaInspectorError.processFailed }
        let urls = try FileManager.default.contentsOfDirectory(at: workspace.root, includingPropertiesForKeys: nil)
            .filter { $0.lastPathComponent.hasPrefix("ocr-") && $0.pathExtension.lowercased() == "png" }
            .sorted { framePTS($0) < framePTS($1) }
        guard !urls.isEmpty else { throw MultimediaInspectorError.invalidOutput("FFmpeg no ha producido imágenes de subtítulos bitmap") }
        let timeBase = parseRational(request.timeBase) ?? (1.0 / 1000.0)
        var events: [BitmapSubtitleOCREvent] = []
        for (index, url) in urls.enumerated() {
            try Task.checkCancellation()
            guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil), let image = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else { continue }
            let observation = try await recognize(image: image, options: options)
            let start = Double(framePTS(url)) * timeBase
            let nextStart = index + 1 < urls.count ? Double(framePTS(urls[index + 1])) * timeBase : min(request.duration ?? (start + 2), start + 2)
            let end = max(start + 0.05, nextStart)
            events.append(.init(start: start, end: end, text: observation.text, confidence: observation.confidence, needsReview: observation.confidence < options.lowConfidenceThreshold || observation.text.isEmpty))
        }
        let output = BitmapSubtitleOCRDraft(events: events, sourceCodec: request.codec, sourceStreamIndex: request.streamIndex, language: options.language ?? request.language)
        if let activeID, let coordinator { try? await coordinator.finish(id: activeID) }
        operationID = nil
        return output
        } catch {
            if let activeID, let coordinator { try? await coordinator.finish(id: activeID) }
            operationID = nil
            throw error
        }
        #else
        throw MultimediaInspectorError.exportUnavailable
        #endif
    }

    public func cancel() async {
        if let operationID, let coordinator { try? await coordinator.requestCancellation(id: operationID) }
        try? await runner.cancel()
    }

    #if canImport(Vision) && canImport(ImageIO)
    private func recognize(image: CGImage, options: BitmapSubtitleOCROptions) async throws -> (text: String, confidence: Double) {
        try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error { continuation.resume(throwing: error); return }
                let observations = (request.results as? [VNRecognizedTextObservation]) ?? []
                let candidates = observations.compactMap { $0.topCandidates(1).first }
                let text = candidates.map(\.string).joined(separator: "\n")
                let confidence = candidates.isEmpty ? 0 : candidates.map { Double($0.confidence) }.reduce(0, +) / Double(candidates.count)
                continuation.resume(returning: (text, confidence))
            }
            request.recognitionLevel = options.recognitionLevel == .accurate ? .accurate : .fast
            request.usesLanguageCorrection = options.usesLanguageCorrection
            if let language = options.language, !language.isEmpty { request.recognitionLanguages = [language] }
            let handler = VNImageRequestHandler(cgImage: image)
            DispatchQueue.global(qos: .userInitiated).async {
                do { try handler.perform([request]) }
                catch { continuation.resume(throwing: error) }
            }
        }
    }
    #endif

    private func framePTS(_ url: URL) -> Int64 {
        let stem = url.deletingPathExtension().lastPathComponent
        return Int64(stem.split(separator: "-").last ?? "0") ?? 0
    }

    private func parseRational(_ raw: String?) -> Double? {
        guard let raw else { return nil }
        let p = raw.split(separator: "/")
        guard p.count == 2, let n = Double(p[0]), let d = Double(p[1]), d != 0 else { return nil }
        return n / d
    }
}
