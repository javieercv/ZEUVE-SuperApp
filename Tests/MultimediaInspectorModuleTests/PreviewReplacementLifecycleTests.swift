import Foundation
import Testing
import ZEUVECore
@testable import MultimediaInspectorModule

private actor ReplacementEventLog {
    private var values: [String] = []

    func append(_ value: String) {
        values.append(value)
    }

    func snapshot() -> [String] {
        values
    }
}

private actor ControlledCleanup {
    private var hasEntered = false
    private var entryWaiters: [CheckedContinuation<Void, Never>] = []
    private var releaseWaiters: [CheckedContinuation<Void, Never>] = []

    func enterAndWait() async {
        hasEntered = true
        let waiters = entryWaiters
        entryWaiters.removeAll()
        waiters.forEach { $0.resume() }
        await withCheckedContinuation { continuation in
            releaseWaiters.append(continuation)
        }
    }

    func waitUntilEntered() async {
        guard !hasEntered else { return }
        await withCheckedContinuation { continuation in
            entryWaiters.append(continuation)
        }
    }

    func release() {
        let waiters = releaseWaiters
        releaseWaiters.removeAll()
        waiters.forEach { $0.resume() }
    }
}

@Test func previewReplacementStopsPreviousSessionBeforeStartingNext() async throws {
    let gate = PreviewSourceReplacementGate()
    let events = ReplacementEventLog()

    let ticket = try await gate.beginReplacement {
        await events.append("detener A")
        await Task.yield()
        await events.append("A detenida")
    }
    #expect(await gate.isCurrent(ticket))
    await events.append("iniciar B")

    #expect(await events.snapshot() == ["detener A", "A detenida", "iniciar B"])
}

@Test func rapidPreviewReplacementAuthorizesOnlyLatestSelection() async throws {
    let gate = PreviewSourceReplacementGate()
    let events = ReplacementEventLog()
    let controlledCleanup = ControlledCleanup()

    let selectionB = Task { () -> Bool in
        do {
            let ticket = try await gate.beginReplacement {
                await events.append("detener A")
                await controlledCleanup.enterAndWait()
                await events.append("A detenida")
            }
            guard await gate.isCurrent(ticket) else { return false }
            await events.append("iniciar B")
            return true
        } catch is CancellationError {
            return false
        } catch {
            Issue.record("El reemplazo B falló con un error inesperado: \(error)")
            return false
        }
    }

    await controlledCleanup.waitUntilEntered()
    let selectionC = Task { () throws -> PreviewSourceReplacementGate.Ticket in
        try await gate.beginReplacement {
            await events.append("limpieza previa a C")
        }
    }
    await controlledCleanup.release()

    #expect(await selectionB.value == false)
    let ticketC = try await selectionC.value
    #expect(await gate.isCurrent(ticketC))
    await events.append("iniciar C")
    #expect(await events.snapshot() == [
        "detener A",
        "A detenida",
        "limpieza previa a C",
        "iniciar C",
    ])
}

@Test func stoppingPreviewInvalidatesPendingReplacement() async {
    let gate = PreviewSourceReplacementGate()
    let controlledCleanup = ControlledCleanup()

    let pendingReplacement = Task { () -> Bool in
        do {
            let ticket = try await gate.beginReplacement {
                await controlledCleanup.enterAndWait()
            }
            return await gate.isCurrent(ticket)
        } catch {
            return false
        }
    }

    await controlledCleanup.waitUntilEntered()
    let stop = Task {
        await gate.invalidate {}
    }
    await controlledCleanup.release()
    await stop.value

    #expect(await pendingReplacement.value == false)
}

@Test func previewReplacementContinuityPreservesPlayingAndPausedIntent() {
    #expect(PreviewPlaybackContinuity.shouldPlayAfterReplacement(from: .playing))
    #expect(PreviewPlaybackContinuity.shouldPlayAfterReplacement(from: .loading))
    #expect(!PreviewPlaybackContinuity.shouldPlayAfterReplacement(from: .paused))
    #expect(!PreviewPlaybackContinuity.shouldPlayAfterReplacement(from: .finished))
    #expect(PreviewPlaybackContinuity.shouldPlayAfterReplacement(from: .idle))
    #expect(PreviewPlaybackContinuity.shouldPlayAfterReplacement(from: .failed))
}

@Test func previewCommandBuilderClampsSeekToShorterDestinationDuration() throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("preview-shorter-\(UUID().uuidString).mkv")
    try Data([1, 2, 3]).write(to: url)
    defer { try? FileManager.default.removeItem(at: url) }
    let source = MultimediaAudioPreviewSource(
        url: url,
        fingerprint: try FileFingerprint.read(from: url),
        streamIndex: 2,
        sampleRate: 48_000,
        channels: 2,
        duration: 30,
        channelLayout: "stereo",
        title: "Pista corta"
    )

    let arguments = try FFmpegAudioPreviewCommandBuilder().arguments(
        source: source,
        from: 82,
        channelSelection: .mix
    )
    let seekIndex = arguments.firstIndex(of: "-ss")
    #expect(seekIndex != nil)
    if let seekIndex {
        #expect(arguments[seekIndex + 1] == "30.000000")
    }
}
