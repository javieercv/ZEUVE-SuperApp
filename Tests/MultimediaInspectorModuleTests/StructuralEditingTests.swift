import Foundation
import Testing
import ZEUVECore
import ZEUVEEngines
@testable import MultimediaInspectorModule

private func structuralTempFile(_ suffix: String = "mkv", data: Data = Data([1, 2, 3])) throws -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("zeuve-structural-\(UUID().uuidString).\(suffix)")
    try data.write(to: url)
    return url
}

private func structuralInspection(_ json: String) throws -> MediaInspectionResult {
    try MediaInspectionParser.decode(Data(json.utf8))
}

@Test func draftLoadsChaptersAttachmentsAndManagedMetadata() throws {
    let url = try structuralTempFile(); defer { try? FileManager.default.removeItem(at: url) }
    let inspection = try structuralInspection(#"{"streams":[{"index":0,"codec_name":"h264","codec_type":"video","tags":{"title":"Vídeo"}},{"index":1,"codec_name":"aac","codec_type":"audio"},{"index":2,"codec_name":"ttf","codec_type":"attachment","tags":{"filename":"font.ttf","mimetype":"application/x-truetype-font"}}],"format":{"duration":"10.0","tags":{"title":"Película","artist":"Autor","CUSTOM":"privado"}},"chapters":[{"id":0,"start_time":"0.000","end_time":"5.000","tags":{"title":"Inicio"}},{"id":1,"start_time":"5.000","end_time":"10.000","tags":{"title":"Final"}}]}"#)
    let draft = try MediaEditDraft(originalURL: url, originalFingerprint: .read(from: url), inspection: inspection, container: .mkv)
    #expect(draft.chapters.map(\.title) == ["Inicio", "Final"])
    #expect(draft.attachments.count == 1)
    #expect(draft.attachments[0].filename == "font.ttf")
    #expect(draft.metadata.containerValues["title"] == "Película")
    #expect(draft.metadata.containerValues["artist"] == "Autor")
    #expect(draft.metadata.containerValues["CUSTOM"] == nil)
    #expect(draft.metadata.touchedContainerKeys.isEmpty)
}

@Test func chapterAndMetadataChangesParticipateInUndoRedo() throws {
    let url = try structuralTempFile(); defer { try? FileManager.default.removeItem(at: url) }
    let inspection = try structuralInspection(#"{"streams":[{"index":0,"codec_name":"aac","codec_type":"audio"}],"format":{"duration":"20"},"chapters":[{"id":0,"start_time":"0","end_time":"20","tags":{"title":"Uno"}}]}"#)
    var history = MediaEditDraftHistory(try MediaEditDraft(originalURL: url, originalFingerprint: .read(from: url), inspection: inspection, container: .mkv))
    history.perform { $0.chapters[0].title = "Nuevo"; $0.metadata.setContainerValue("Título", for: "title") }
    #expect(history.current.chapters[0].title == "Nuevo")
    #expect(history.current.metadata.touchedContainerKeys.contains("title"))
    let didUndo = history.undo(); #expect(didUndo)
    #expect(history.current.chapters[0].title == "Uno")
    #expect(history.current.metadata.touchedContainerKeys.isEmpty)
    let didRedo = history.redo(); #expect(didRedo)
    #expect(history.current.chapters[0].title == "Nuevo")
}

@Test func validatorRejectsDuplicateOrOutOfRangeChapters() throws {
    let url = try structuralTempFile(); defer { try? FileManager.default.removeItem(at: url) }
    let inspection = try structuralInspection(#"{"streams":[{"index":0,"codec_name":"aac","codec_type":"audio"}],"format":{"duration":"10"}}"#)
    var draft = try MediaEditDraft(originalURL: url, originalFingerprint: .read(from: url), inspection: inspection, container: .mkv)
    draft.chapters = [.init(startTime: 1, title: "A"), .init(startTime: 1, title: "B")]
    #expect(throws: MultimediaInspectorError.self) { try MediaEditValidator().validateDraft(draft) }
    draft.chapters = [.init(startTime: 10, title: "Fuera")]
    #expect(throws: MultimediaInspectorError.self) { try MediaEditValidator().validateDraft(draft) }
}

@Test func externalAttachmentForcesMKVWithoutTranscoding() throws {
    let source = try structuralTempFile("mp4"); defer { try? FileManager.default.removeItem(at: source) }
    let attachmentURL = try structuralTempFile("ttf", data: Data([9, 8, 7])); defer { try? FileManager.default.removeItem(at: attachmentURL) }
    let inspection = try structuralInspection(#"{"streams":[{"index":0,"codec_name":"h264","codec_type":"video"},{"index":1,"codec_name":"aac","codec_type":"audio"}],"format":{"format_name":"mov,mp4,m4a,3gp,3g2,mj2","duration":"2"}}"#)
    var draft = try MediaEditDraft(originalURL: source, originalFingerprint: .read(from: source), inspection: inspection, container: .mp4)
    draft.attachments.append(.init(source: .external(url: attachmentURL, fingerprint: try .read(from: attachmentURL)), filename: "font.ttf", mimeType: "font/ttf"))
    let plan = try MediaEditPlanner().plan(from: draft)
    #expect(plan.targetContainer == .mkv)
    #expect(plan.attachments.count == 1)
    #expect(plan.attachments[0].action == .add)
    #expect(plan.audioTracks.allSatisfy { $0.outputCodec == $0.track.codec })
}

@Test func validatorProtectsAttachmentNamesMimeAndFingerprint() throws {
    let source = try structuralTempFile(); defer { try? FileManager.default.removeItem(at: source) }
    let external = try structuralTempFile("ttf"); defer { try? FileManager.default.removeItem(at: external) }
    let inspection = try structuralInspection(#"{"streams":[{"index":0,"codec_name":"aac","codec_type":"audio"}],"format":{"duration":"2"}}"#)
    var draft = try MediaEditDraft(originalURL: source, originalFingerprint: .read(from: source), inspection: inspection, container: .mkv)
    let fp = try FileFingerprint.read(from: external)
    draft.attachments = [
        .init(source: .external(url: external, fingerprint: fp), filename: "../font.ttf", mimeType: "font/ttf")
    ]
    #expect(throws: MultimediaInspectorError.self) { try MediaEditValidator().validateDraft(draft) }
    draft.attachments = [
        .init(source: .external(url: external, fingerprint: fp), filename: "font.ttf", mimeType: "invalid")
    ]
    #expect(throws: MultimediaInspectorError.self) { try MediaEditValidator().validateDraft(draft) }
    try Data([0, 1, 2, 3, 4]).write(to: external)
    draft.attachments = [
        .init(source: .external(url: external, fingerprint: fp), filename: "font.ttf", mimeType: "font/ttf")
    ]
    #expect(throws: MultimediaInspectorError.self) { try MediaEditValidator().validateDraft(draft) }
}

@Test func ffmetadataBuilderEscapesChapterValues() throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("chapters-\(UUID().uuidString).ffmeta")
    defer { try? FileManager.default.removeItem(at: url) }
    let chapter = MediaEditableChapter(startTime: 1.25, title: "A=B;#\\C")
    let planned = PlannedChapter(chapter: chapter, endTime: 2.5)
    let builder = FFmpegChapterMetadataBuilder()
    try builder.write(chapters: [planned], to: url)
    let text = try String(contentsOf: url, encoding: .utf8)
    #expect(text.contains("START=1250"))
    #expect(text.contains("END=2500"))
    #expect(text.contains("title=A\\=B\\;\\#\\\\C"))
}

@Test func mediaCommandMapsEditedChaptersAttachmentsAndMetadata() throws {
    let source = try structuralTempFile(); defer { try? FileManager.default.removeItem(at: source) }
    let external = try structuralTempFile("ttf"); defer { try? FileManager.default.removeItem(at: external) }
    let fp = try FileFingerprint.read(from: source)
    let attachmentFP = try FileFingerprint.read(from: external)
    let chapter = PlannedChapter(chapter: .init(startTime: 0, title: "Intro"), endTime: 5)
    var metadata = MediaMetadataDraft()
    metadata.setContainerValue("Título nuevo", for: "title")
    let plan = MediaEditPlan(
        originalURL: source,
        originalFingerprint: fp,
        targetContainer: .mkv,
        audioTracks: [],
        subtitleTracks: [],
        originalVideoStreamIndices: [0],
        chapters: [chapter],
        attachments: [.init(attachment: .init(source: .external(url: external, fingerprint: attachmentFP), filename: "font.ttf", mimeType: "font/ttf"), action: .add)],
        metadata: metadata,
        preserveMetadata: false,
        removedOriginalStreamIndices: [],
        warnings: []
    )
    let chapterURL = URL(fileURLWithPath: "/tmp/chapters.ffmeta")
    let args = try FFmpegMediaEditCommandBuilder().command(ffmpeg: URL(fileURLWithPath: "/x/ffmpeg"), plan: plan, outputURL: URL(fileURLWithPath: "/tmp/out.mkv"), chapterMetadataURL: chapterURL).request.arguments
    if let index = args.firstIndex(of: "-map_metadata") { #expect(args[index + 1] == "-1") } else { Issue.record("Falta -map_metadata") }
    #expect(args.contains("-map_chapters"))
    #expect(args.contains("-attach"))
    #expect(args.contains(external.path))
    #expect(args.contains("filename=font.ttf"))
    #expect(args.contains("mimetype=font/ttf"))
    #expect(args.contains("title=Título nuevo"))
    #expect(args.contains("copy"))
}

@Test func chaptersAreIndependentFromPreserveMetadata() throws {
    let source = try structuralTempFile(); defer { try? FileManager.default.removeItem(at: source) }
    let fp = try FileFingerprint.read(from: source)
    let chapter = PlannedChapter(chapter: .init(startTime: 0, title: "Intro"), endTime: 1)
    let plan = MediaEditPlan(originalURL: source, originalFingerprint: fp, targetContainer: .mkv, audioTracks: [], subtitleTracks: [], chapters: [chapter], preserveMetadata: false, removedOriginalStreamIndices: [], warnings: [])
    let args = try FFmpegMediaEditCommandBuilder().command(ffmpeg: URL(fileURLWithPath: "/x/ffmpeg"), plan: plan, outputURL: URL(fileURLWithPath: "/tmp/out.mkv"), chapterMetadataURL: URL(fileURLWithPath: "/tmp/c.ffmeta")).request.arguments
    let metadataIndex = try #require(args.firstIndex(of: "-map_metadata"))
    #expect(args[metadataIndex + 1] == "-1")
    let chapterIndex = try #require(args.firstIndex(of: "-map_chapters"))
    #expect(args[chapterIndex + 1] != "-1")
}
