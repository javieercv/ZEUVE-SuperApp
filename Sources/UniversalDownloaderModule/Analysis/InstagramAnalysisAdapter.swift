import Foundation
import ZEUVEEngines

struct InstagramDirectAnalysisAdapterResult: Sendable {
    let process: ExternalProcessResult
    let parsed: InstagramDirectParseResult?
    let stderr: String
}

struct InstagramProfileAnalysisAdapterResult: Sendable {
    let process: ExternalProcessResult
    let parsed: InstagramCatalogParseResult?
    let stderr: String
}

struct InstagramAnalysisAdapter: Sendable {
    private let runner: ExternalProcessRunner
    private let parser: InstagramCatalogParser

    init(runner: ExternalProcessRunner, parser: InstagramCatalogParser = InstagramCatalogParser()) {
        self.runner = runner
        self.parser = parser
    }

    func analyzeDirect(
        input: ValidatedDownloadURL,
        engines: DownloadEnginePaths,
        cookiesFile: URL?,
        cookieHeaderFile: URL?
    ) async throws -> InstagramDirectAnalysisAdapterResult {
        guard let executable = engines.instagramCatalog else {
            throw UniversalDownloaderError.optionalEngineUnavailable("Motor específico de Instagram")
        }
        let arguments = try InstagramCatalogCommandBuilder().directArguments(
            for: input,
            cookiesFile: cookiesFile,
            cookieHeaderFile: cookieHeaderFile
        )
        let stdout = LockedDataCollector(maximumBytes: 32 * 1_048_576)
        let stderr = LockedDataCollector(maximumBytes: 1_048_576)
        let process = try await runner.run(
            ExternalProcessRequest(executable: executable, arguments: arguments),
            onStdout: { stdout.append($0) },
            onStderr: { stderr.append($0) }
        )
        let parsed = stdout.data.isEmpty ? nil : try parser.parseDirectResult(data: stdout.data, input: input)
        return .init(
            process: process,
            parsed: parsed,
            stderr: String(decoding: stderr.data, as: UTF8.self)
        )
    }

    func analyzeProfile(
        input: ValidatedDownloadURL,
        engines: DownloadEnginePaths,
        cookiesFile: URL?,
        cookieHeaderFile: URL?,
        limit: Int,
        cursor: String?
    ) async throws -> InstagramProfileAnalysisAdapterResult {
        guard let executable = engines.instagramCatalog else {
            throw UniversalDownloaderError.optionalEngineUnavailable("Catálogo de Instagram")
        }
        guard let username = input.profileUsername else {
            throw UniversalDownloaderError.invalidInstagramUsername
        }
        let arguments = try InstagramCatalogCommandBuilder().arguments(
            username: username,
            limit: limit,
            cursor: cursor,
            cookiesFile: cookiesFile,
            cookieHeaderFile: cookieHeaderFile
        )
        let stdout = LockedDataCollector(maximumBytes: 32 * 1_048_576)
        let stderr = LockedDataCollector(maximumBytes: 1_048_576)
        let process = try await runner.run(
            ExternalProcessRequest(executable: executable, arguments: arguments),
            onStdout: { stdout.append($0) },
            onStderr: { stderr.append($0) }
        )
        let parsed = stdout.data.isEmpty ? nil : try parser.parseResult(data: stdout.data, input: input)
        return .init(
            process: process,
            parsed: parsed,
            stderr: String(decoding: stderr.data, as: UTF8.self)
        )
    }
}
