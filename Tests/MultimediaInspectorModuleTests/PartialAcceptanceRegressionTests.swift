import Foundation
import Testing
import ZEUVECore
import ZEUVEEngines
import ZEUVEOperations
@testable import MultimediaInspectorModule

@Test func ocrTimelineUsesClearBoundariesMergesHeldFramesAndClampsEOF() {
    let frames: [BitmapSubtitleOCRFrame] = [
        .init(timestamp: 0, text: "UNO", confidence: 1, isClear: false),
        .init(timestamp: 1.999999, text: "UNO", confidence: 0.9, isClear: false),
        .init(timestamp: 2, text: "", confidence: 0, isClear: true),
        .init(timestamp: 3.999999, text: "", confidence: 0, isClear: true),
        .init(timestamp: 4, text: "DOS", confidence: 1, isClear: false),
        .init(timestamp: 5.999999, text: "DOS", confidence: 1, isClear: false),
        .init(timestamp: 6, text: "", confidence: 0, isClear: true),
        .init(timestamp: 8, text: "TRES", confidence: 1, isClear: false),
        .init(timestamp: 10, text: "", confidence: 0, isClear: true),
        .init(timestamp: 4294977.295, text: "", confidence: 0, isClear: true)
    ]
    let events = BitmapSubtitleOCRTimeline().events(frames: frames, duration: 12, threshold: 0.55)
    #expect(events.map(\.start) == [0, 4, 8]); #expect(events.map(\.end) == [2, 6, 10])
    #expect(events.map(\.text) == ["UNO", "DOS", "TRES"])
    let srt = String(decoding: BitmapSubtitleOCRExporter().srtData(from: .init(events: events, sourceCodec: "hdmv_pgs_subtitle", sourceStreamIndex: 1, language: "spa")), as: UTF8.self)
    #expect(srt.contains("00:00:00,000 --> 00:00:02,000"))
    #expect(srt.contains("00:00:08,000 --> 00:00:10,000"))
    #expect(!srt.contains("4294"))
}

@Test func unreadableVisibleOCRRemainsReviewableAndInvalidSRTEventsAreExcluded() {
    let events = BitmapSubtitleOCRTimeline().events(frames: [
        .init(timestamp: 2, text: "", confidence: 0, isClear: false),
        .init(timestamp: 3, text: "", confidence: 0, isClear: true),
        .init(timestamp: 4, text: "Hola", confidence: 0.3, isClear: false)
    ], duration: 5, threshold: 0.55)
    #expect(events.count == 2 && events.allSatisfy(\.needsReview))
    #expect(events.last?.end == 5)
    let invalid: [BitmapSubtitleOCREvent] = [
        .init(start: .nan, end: 5, text: "Inválido", confidence: 1, needsReview: false),
        .init(start: 4, end: .infinity, text: "Inválido", confidence: 1, needsReview: false),
        .init(start: 5, end: 4, text: "Inválido", confidence: 1, needsReview: false)
    ]
    let srt = String(decoding: BitmapSubtitleOCRExporter().srtData(from: .init(events: events + invalid, sourceCodec: "pgs", sourceStreamIndex: 1, language: nil)), as: UTF8.self)
    #expect(!srt.contains("Inválido")); #expect(srt.contains("1\n00:00:04,000 --> 00:00:05,000\nHola"))
}

@Test func editReviewShowsEffectiveVideoRemovalAndLanguageBeforeAfter() throws {
    let workspace = try MultimediaWorkspace(operationID: UUID(), extension: "mkv"); defer { workspace.cleanup() }
    try Data([1,2,3]).write(to: workspace.output)
    let original = try MediaInspectionParser.decode(Data(#"{"streams":[{"index":0,"codec_name":"h264","codec_type":"video","tags":{"title":"Vídeo"}},{"index":1,"codec_name":"aac","codec_type":"audio","tags":{"language":"eng","title":"Audio"}}]}"#.utf8))
    var draft = try MediaEditDraft(originalURL: workspace.output, originalFingerprint: .read(from: workspace.output), inspection: original, container: .mkv)
    draft.videoTracks = []; draft.audioTracks[0].language = "spa"
    let plan = try MediaEditPlanner().plan(from: draft)
    let review = MediaEditReview(plan: plan, original: original)
    #expect(review.tracks.filter { $0.kind == .video && $0.action != .remove }.isEmpty)
    #expect(review.tracks.filter { $0.kind == .video && $0.action == .remove }.count == 1)
    #expect(review.changes.contains { $0.field.contains("Idioma") && $0.before == "eng" && $0.after == "spa" })
}

private func qtBox(_ type: String, _ bytes: Data) -> Data {
    let size = UInt32(bytes.count + 8)
    return Data([UInt8(size >> 24), UInt8((size >> 16) & 255), UInt8((size >> 8) & 255), UInt8(size & 255)]) + Data(type.utf8) + bytes
}

@Test func quickTimeArtworkOnlyUpdatesOwnedMovieMetadataAndPreservesMdat() throws {
    let workspace = try MultimediaWorkspace(operationID: UUID(), extension: "mov"); defer { workspace.cleanup() }
    let payload = Data("Paquetes audiovisuales intactos".utf8)
    let ftyp = qtBox("ftyp", Data("qt  ".utf8) + Data(repeating: 0, count: 4))
    let mdat = qtBox("mdat", payload)
    let oldTag = qtBox("name", Data("Metadata previa".utf8))
    let original = ftyp + mdat + qtBox("moov", qtBox("udta", oldTag))
    try original.write(to: workspace.output)
    let image = workspace.auxiliaryFile(named: "cover.jpg"); let pixels = Data([0xff,0xd8,0xff,0xd9]); try pixels.write(to: image)
    try QuickTimeArtworkWriter().write(image: image, codec: "mjpeg", workspace: workspace)
    let result = try Data(contentsOf: workspace.output)
    #expect(result.prefix(ftyp.count + mdat.count) == original.prefix(ftyp.count + mdat.count))
    #expect(result.range(of: oldTag) != nil); #expect(result.range(of: pixels) != nil)
    #expect(result.range(of: Data("covr".utf8)) != nil)
    let secondImage = workspace.auxiliaryFile(named: "replace.png")
    let replacement = Data([8,7,6,5]); try replacement.write(to: secondImage)
    try QuickTimeArtworkWriter().write(image: secondImage, codec: "png", workspace: workspace)
    let replaced = try Data(contentsOf: workspace.output)
    #expect(replaced.range(of: pixels) == nil && replaced.range(of: replacement) != nil)
    #expect(replaced.range(of: oldTag) != nil)
    #expect(replaced.prefix(ftyp.count + mdat.count) == original.prefix(ftyp.count + mdat.count))
    try FileManager.default.removeItem(at: workspace.root.appendingPathComponent(".zeuve-owned"))
    defer { try? Data(workspace.root.lastPathComponent.utf8).write(to: workspace.root.appendingPathComponent(".zeuve-owned")) }
    #expect(throws: (any Error).self) { try QuickTimeArtworkWriter().write(image: image, codec: "mjpeg", workspace: workspace) }
    #expect(try Data(contentsOf: workspace.output) == replaced)
}

@Test func quickTimeArtworkRejectsNonterminalMoovAndMalformedAtomsWithoutWriting() throws {
    let workspace = try MultimediaWorkspace(operationID: UUID(), extension: "mov"); defer { workspace.cleanup() }
    let image = workspace.auxiliaryFile(named: "cover.png"); try Data([1,2,3]).write(to: image)
    let ftyp = qtBox("ftyp", Data("qt  ".utf8) + Data(repeating: 0, count: 4))
    for original in [ftyp + qtBox("moov", Data()) + qtBox("mdat", Data([1])), ftyp + qtBox("moov", Data([1,2,3]))] {
        try original.write(to: workspace.output)
        #expect(throws: (any Error).self) { try QuickTimeArtworkWriter().write(image: image, codec: "png", workspace: workspace) }
        #expect(try Data(contentsOf: workspace.output) == original)
    }
}

@Test(.enabled(if: ProcessInfo.processInfo.environment["ZEUVE_QA_PARTIAL_FIXTURES"] != nil))
func nativeBitmapOCRProducesThreeEventsWithRealTimestamps() async throws {
    let root = URL(fileURLWithPath: try #require(ProcessInfo.processInfo.environment["ZEUVE_QA_PARTIAL_FIXTURES"]))
    let ffmpeg = URL(fileURLWithPath: try #require(ProcessInfo.processInfo.environment["ZEUVE_QA_FFMPEG"]))
    let source = root.appendingPathComponent("I90_bitmap.mkv")
    let coordinator = OperationCoordinator()
    let request = BitmapSubtitleOCRRequest(url: source, fingerprint: try .read(from: source), streamIndex: 1, codec: "hdmv_pgs_subtitle", timeBase: "1/1000", duration: 12, language: "spa")
    let draft = try await BitmapSubtitleOCRService(coordinator: coordinator).recognize(ffmpeg: ffmpeg, request: request, options: .init())
    #expect(draft.events.count == 3)
    #expect(draft.events.map(\.start) == [0,4,8]); #expect(draft.events.map(\.end) == [2,6,10])
    #expect(zip(draft.events, ["UNO", "DOS", "TRES"]).allSatisfy { $0.0.text.contains($0.1) })
    #expect(await coordinator.current() == nil)
}
