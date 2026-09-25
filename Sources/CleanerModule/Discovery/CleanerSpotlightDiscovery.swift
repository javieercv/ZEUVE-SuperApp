import Foundation
#if os(macOS)
import CoreServices
#endif

public enum CleanerApplicationDiscoveryStatus: Sendable {
    case complete
    case unavailable
    case timedOut
    case cancelled
}

public struct CleanerApplicationDiscoveryResult: Sendable {
    public let urls: [URL]
    public let status: CleanerApplicationDiscoveryStatus

    public init(urls: [URL], status: CleanerApplicationDiscoveryStatus) {
        self.urls = urls
        self.status = status
    }
}

public protocol CleanerApplicationDiscovering: Sendable {
    func discoverApplications() async -> CleanerApplicationDiscoveryResult
}

public struct CleanerSpotlightApplicationDiscovery: CleanerApplicationDiscovering {
    private let timeout: Duration

    public init(timeout: Duration = .seconds(30)) { self.timeout = timeout }

    public func discoverApplications() async -> CleanerApplicationDiscoveryResult {
        #if os(macOS)
        let session = await MainActor.run { CleanerSpotlightQuerySession(timeout: timeout) }
        return await withTaskCancellationHandler {
            await session.start()
        } onCancel: {
            Task { @MainActor in session.cancel() }
        }
        #else
        if Task.isCancelled { return .init(urls: [], status: .cancelled) }
        return .init(urls: [], status: .unavailable)
        #endif
    }
}

#if os(macOS)
@MainActor
private final class CleanerSpotlightQuerySession {
    private let query = NSMetadataQuery()
    private let timeout: Duration
    private var observer: NSObjectProtocol?
    private var continuation: CheckedContinuation<CleanerApplicationDiscoveryResult, Never>?
    private var timeoutTask: Task<Void, Never>?
    private var cancelled = false

    init(timeout: Duration) { self.timeout = timeout }

    func start() async -> CleanerApplicationDiscoveryResult {
        if cancelled || Task.isCancelled { return .init(urls: [], status: .cancelled) }
        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            query.predicate = NSPredicate(format: "kMDItemContentType == %@", "com.apple.application-bundle")
            observer = NotificationCenter.default.addObserver(
                forName: .NSMetadataQueryDidFinishGathering,
                object: query,
                queue: .main
            ) { [self] _ in
                Task { @MainActor in self.finishGathering() }
            }
            guard query.start() else {
                finish(status: .unavailable)
                return
            }
            timeoutTask = Task { @MainActor [self] in
                try? await Task.sleep(for: timeout)
                guard !Task.isCancelled else { return }
                self.finish(status: .timedOut)
            }
        }
    }

    func cancel() {
        cancelled = true
        finish(status: .cancelled)
    }

    private func finishGathering() {
        guard continuation != nil else { return }
        let urls = query.results.compactMap {
            ($0 as? NSMetadataItem)?.value(forAttribute: NSMetadataItemPathKey) as? String
        }.map { URL(fileURLWithPath: $0) }
        finish(status: .complete, urls: urls)
    }

    private func finish(status: CleanerApplicationDiscoveryStatus, urls: [URL] = []) {
        guard let continuation else { return }
        self.continuation = nil
        timeoutTask?.cancel()
        timeoutTask = nil
        if let observer {
            NotificationCenter.default.removeObserver(observer)
            self.observer = nil
        }
        query.disableUpdates()
        query.stop()
        continuation.resume(returning: .init(urls: urls, status: status))
    }
}
#endif
