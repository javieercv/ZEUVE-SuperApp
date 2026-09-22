import Foundation
import ZEUVEEngines

struct GalleryDLAnalysisAdapterResult: Sendable {
    let process: ExternalProcessResult
    let analysis: DownloadAnalysis?
    let stderr: String
}

struct GalleryDLAnalysisAdapter: Sendable {
    private let runner: ExternalProcessRunner
    private let parser: GalleryDLAnalysisParser

    init(runner: ExternalProcessRunner, parser: GalleryDLAnalysisParser = GalleryDLAnalysisParser()) {
        self.runner = runner
        self.parser = parser
    }

    func analyze(
        input: ValidatedDownloadURL,
        engines: DownloadEnginePaths,
        cookiesFile: URL?,
        proxy: String?,
        proxyCredentials: DownloadProxyCredentials?
    ) async throws -> GalleryDLAnalysisAdapterResult {
        guard let executable = engines.galleryDL else {
            throw UniversalDownloaderError.optionalEngineUnavailable("gallery-dl")
        }
        let arguments = try GalleryDLAnalysisCommandBuilder().arguments(
            for: input,
            cookiesFile: cookiesFile,
            proxy: proxy,
            proxyCredentials: proxyCredentials
        )
        let stdout = LockedDataCollector(maximumBytes: 64 * 1_048_576)
        let stderr = LockedDataCollector(maximumBytes: 1_048_576)
        let result = try await runner.run(
            ExternalProcessRequest(executable: executable, arguments: arguments),
            onStdout: { stdout.append($0) },
            onStderr: { stderr.append($0) }
        )
        let analysis: DownloadAnalysis?
        if result.succeeded, !stdout.data.isEmpty {
            analysis = try parser.parse(data: stdout.data, input: input)
        } else {
            analysis = nil
        }
        return .init(
            process: result,
            analysis: analysis,
            stderr: String(decoding: stderr.data, as: UTF8.self)
        )
    }
}
