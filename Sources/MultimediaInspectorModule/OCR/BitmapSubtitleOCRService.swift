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
        var args = [
            "-hide_banner", "-nostdin", "-v", "error", "-i", request.url.path,
            "-filter_complex", filter, "-map", "[ocr]", "-vsync", "0",
            "-enc_time_base", "1:1000000", "-frame_pts", "1", "-c:v", "png",
        ]
        if let duration = request.duration, duration.isFinite, duration > 0 { args += ["-t", String(duration)] }
        args.append(pattern)
        let result = try await runner.run(.init(executable: ffmpeg, arguments: args))
        guard result.succeeded else { throw MultimediaInspectorError.processFailed }
        let urls = try FileManager.default.contentsOfDirectory(at: workspace.root, includingPropertiesForKeys: nil)
            .filter { $0.lastPathComponent.hasPrefix("ocr-") && $0.pathExtension.lowercased() == "png" }
            .sorted { framePTS($0) < framePTS($1) }
        guard !urls.isEmpty else { throw MultimediaInspectorError.invalidOutput("FFmpeg no ha producido imágenes de subtítulos bitmap") }
        var frames: [BitmapSubtitleOCRFrame] = []
        for url in urls {
            try Task.checkCancellation()
            if let activeID, await coordinator?.shouldCancel(id: activeID) == true { throw CancellationError() }
            guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil), let image = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else { continue }
            let start = Double(framePTS(url)) / 1_000_000
            if let duration = request.duration, duration.isFinite, start >= duration { continue }
            let clear = try isClear(image)
            let observation = clear ? (text: "", confidence: 0.0) : try await recognize(image: image, options: options)
            frames.append(.init(timestamp: start, text: observation.text, confidence: observation.confidence, isClear: clear))
        }
        let events = BitmapSubtitleOCRTimeline().events(frames: frames, duration: request.duration, threshold: options.lowConfidenceThreshold)
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
    private func isClear(_ image: CGImage) throws -> Bool {
        guard image.width > 0, image.height > 0, image.width <= 8192, image.height <= 8192 else {
            throw MultimediaInspectorError.invalidOutput("imagen de OCR fuera de los límites de seguridad")
        }
        guard let context = CGContext(data: nil, width: image.width, height: image.height, bitsPerComponent: 8,
                                      bytesPerRow: image.width * 4, space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue), let data = context.data else {
            throw MultimediaInspectorError.invalidOutput("no se pudo revisar la transparencia del subtítulo")
        }
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        let bytes = data.assumingMemoryBound(to: UInt8.self)
        for offset in stride(from: 3, to: image.width * image.height * 4, by: 4) where bytes[offset] != 0 { return false }
        return true
    }

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

}
