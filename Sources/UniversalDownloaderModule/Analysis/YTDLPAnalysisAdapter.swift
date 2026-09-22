import Foundation
import ZEUVEEngines

struct YTDLPAnalysisAdapterResult: Sendable {
    let process: ExternalProcessResult
    let analyses: [DownloadAnalysis]
    let stderr: String
    let parseFailures: [String]
}

struct YTDLPAnalysisAdapter: Sendable {
    private let runner: ExternalProcessRunner
    private let parser: YTDLPAnalysisParser

    init(runner: ExternalProcessRunner, parser: YTDLPAnalysisParser = YTDLPAnalysisParser()) {
        self.runner = runner
        self.parser = parser
    }

    func analyze(
        input: ValidatedDownloadURL,
        engines: DownloadEnginePaths,
        cookiesFile: URL?,
        browserCookies: DownloadBrowserCookieSource?,
        proxy: String?,
        proxyCredentials: DownloadProxyCredentials?,
        onAnalysis: @escaping @Sendable (DownloadAnalysis, Int) -> Void
    ) async throws -> YTDLPAnalysisAdapterResult {
        let arguments = try YTDLPAnalysisCommandBuilder().arguments(
            for: input,
            engines: engines,
            cookiesFile: cookiesFile,
            browserCookies: browserCookies,
            proxy: proxy,
            proxyCredentials: proxyCredentials
        )
        let stderr = LockedDataCollector(maximumBytes: 1_048_576)
        let decoder = IncrementalLineDecoder(maximumBufferedBytes: 4_194_304)
        let values = AnalysisLockedArray<DownloadAnalysis>()
        let parseFailures = AnalysisLockedArray<String>()
        let result = try await runner.run(
            ExternalProcessRequest(executable: engines.ytDLP, arguments: arguments),
            onStdout: { [parser] data in
                do {
                    for line in try decoder.append(data) where !line.isEmpty {
                        let analysis = try parser.parse(data: Data(line.utf8), fallbackURL: input.canonicalURL)
                        values.append(analysis)
                        onAnalysis(analysis, values.count)
                    }
                } catch {
                    parseFailures.append(error.localizedDescription)
                }
            },
            onStderr: { stderr.append($0) }
        )
        return .init(
            process: result,
            analyses: values.values,
            stderr: String(decoding: stderr.data, as: UTF8.self),
            parseFailures: parseFailures.values
        )
    }
}

private final class AnalysisLockedArray<Element>: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [Element] = []

    func append(_ value: Element) {
        lock.lock()
        storage.append(value)
        lock.unlock()
    }

    var values: [Element] {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }

    var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return storage.count
    }
}
