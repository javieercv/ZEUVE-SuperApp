import Testing
@testable import MultimediaInspectorModule

@Test func previewControlResolverMapsConfirmedTransportActions() {
    let playing = MultimediaPreviewControlResolver.resolve(
        targetSourceID: "video-a", requestedSourceID: nil, confirmedSourceID: "video-a", transportState: .playing
    )
    let paused = MultimediaPreviewControlResolver.resolve(
        targetSourceID: "video-a", requestedSourceID: nil, confirmedSourceID: "video-a", transportState: .paused
    )
    let finished = MultimediaPreviewControlResolver.resolve(
        targetSourceID: "video-a", requestedSourceID: nil, confirmedSourceID: "video-a", transportState: .finished
    )

    #expect(playing == .init(state: .playing, action: .pause))
    #expect(paused == .init(state: .paused, action: .resume))
    #expect(finished == .init(state: .finished, action: .restart))
}

@Test func previewControlResolverGivesRequestedSourceExclusiveLoadingOwnership() {
    let requested = MultimediaPreviewControlResolver.resolve(
        targetSourceID: "video-c", requestedSourceID: "video-c", confirmedSourceID: "video-a", transportState: .playing
    )
    let obsolete = MultimediaPreviewControlResolver.resolve(
        targetSourceID: "video-a", requestedSourceID: "video-c", confirmedSourceID: "video-a", transportState: .playing
    )

    #expect(requested == .init(state: .loading, action: .wait))
    #expect(obsolete == .init(state: .idle, action: .start))
}

@Test func videoControlUsesGlobalPausedStateEvenIfDecoderStateWouldBeStale() {
    let resolution = MultimediaPreviewControlResolver.resolve(
        targetSourceID: "video", requestedSourceID: nil, confirmedSourceID: "video", transportState: .paused
    )
    #expect(resolution.state == .paused)
    #expect(resolution.action == .resume)
}

@Test func previewOwnershipPreservesOnlyFullyOriginalSessions() {
    let originals: Set<String> = ["audio-original", "video-original"]

    #expect(MultimediaPreviewSessionOwnershipResolver.resolve(
        hasSession: false, sourceIDs: [], originalSourceIDs: originals
    ) == .noSession)
    #expect(MultimediaPreviewSessionOwnershipResolver.resolve(
        hasSession: true,
        sourceIDs: ["audio-original", "video-original"],
        originalSourceIDs: originals
    ) == .originalOnly)
    #expect(MultimediaPreviewSessionOwnershipResolver.resolve(
        hasSession: true,
        sourceIDs: ["audio-original", "video-external"],
        originalSourceIDs: originals
    ) == .containsExternalOrUnavailable)
    #expect(MultimediaPreviewSessionOwnershipResolver.resolve(
        hasSession: true, sourceIDs: [], originalSourceIDs: originals
    ) == .containsExternalOrUnavailable)
}
