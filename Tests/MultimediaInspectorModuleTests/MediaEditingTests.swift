import Foundation
import Testing
import ZEUVECore
import ZEUVEEngines
@testable import MultimediaInspectorModule

private func tempMediaFile(_ data: Data = Data([1,2,3,4])) throws -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("zeuve-media-\(UUID().uuidString).mkv")
    try data.write(to: url)
    return url
}

private func inspect(_ json: String) throws -> MediaInspectionResult {
    try MediaInspectionParser.decode(Data(json.utf8))
}

private func draftFixture(json: String, container: EditableMediaContainer = .mkv) throws -> (URL, MediaEditDraft) {
    let url = try tempMediaFile()
    let result = try inspect(json)
    return (url, try MediaEditDraft(originalURL: url, originalFingerprint: .read(from: url), inspection: result, container: container))
}

@Test func historyCoversAddRemoveReorderLanguageTitleAndForced() throws {
    let (url, initial) = try draftFixture(json: #"{"streams":[{"index":1,"codec_name":"aac","codec_type":"audio","tags":{"language":"spa","title":"A"}},{"index":2,"codec_name":"aac","codec_type":"audio","tags":{"language":"eng","title":"B"}},{"index":3,"codec_name":"subrip","codec_type":"subtitle","disposition":{"forced":0}}]}"#)
    defer { try? FileManager.default.removeItem(at: url) }
    var history = MediaEditDraftHistory(initial)

    history.perform { $0.audioTracks.swapAt(0, 1) }
    #expect(history.current.audioTracks[0].language == "eng")
    history.perform { $0.audioTracks[0].language = "cat"; $0.audioTracks[0].title = "Català" }
    history.perform { $0.subtitleTracks[0].isForced = true }
    history.perform { $0.audioTracks.removeLast() }
    #expect(history.current.audioTracks.count == 1)
    let didUndoRemove = history.undo(); #expect(didUndoRemove); #expect(history.current.audioTracks.count == 2)
    let didUndoForced = history.undo(); #expect(didUndoForced); #expect(!history.current.subtitleTracks[0].isForced)
    let didUndoMetadata = history.undo(); #expect(didUndoMetadata); #expect(history.current.audioTracks[0].language == "eng")
    let didUndoReorder = history.undo(); #expect(didUndoReorder); #expect(history.current.audioTracks[0].language == "spa")

    let external = try tempMediaFile(Data([9,8,7]))
    defer { try? FileManager.default.removeItem(at: external) }
    let fp = try FileFingerprint.read(from: external)
    let added = MediaEditableTrack(kind: .audio, source: .external(url: external, fingerprint: fp, streamIndex: 0), codec: "flac", language: "cat")
    history.perform { $0.audioTracks.append(added) }
    #expect(history.current.audioTracks.last?.id == added.id)
    let didUndoAdd = history.undo(); #expect(didUndoAdd); #expect(!history.current.audioTracks.contains { $0.id == added.id })
    let didRedoAdd = history.redo(); #expect(didRedoAdd); #expect(history.current.audioTracks.contains { $0.id == added.id })
}

@Test func plannerKeepsRemovesAddsAndReordersDeterministically() throws {
    let (url, base) = try draftFixture(json: #"{"streams":[{"index":0,"codec_name":"h264","codec_type":"video"},{"index":1,"codec_name":"aac","codec_type":"audio","tags":{"language":"spa"}},{"index":2,"codec_name":"aac","codec_type":"audio","tags":{"language":"eng"}},{"index":3,"codec_name":"subrip","codec_type":"subtitle"}]}"#)
    defer { try? FileManager.default.removeItem(at: url) }
    let external = try tempMediaFile(Data([5,5,5]))
    defer { try? FileManager.default.removeItem(at: external) }
    let fp = try FileFingerprint.read(from: external)
    var draft = base
    draft.audioTracks.removeFirst()
    draft.audioTracks.insert(MediaEditableTrack(kind: .audio, source: .external(url: external, fingerprint: fp, streamIndex: 7), codec: "flac", language: "cat", title: "Nova"), at: 0)
    draft.subtitleTracks.removeAll()

    let plan = try MediaEditPlanner().plan(from: draft)
    #expect(plan.targetContainer == .mkv)
    #expect(plan.audioTracks.map(\.action) == [.add, .keep])
    #expect(plan.audioTracks.map { $0.track.language } == ["cat", "eng"])
    #expect(plan.removedOriginalStreamIndices == [1, 3])
    #expect(plan.removedTracks.map(\.action) == [.remove, .remove])
    #expect(plan.removedTracks.map { $0.track.source.streamIndex } == [1, 3])
}

@Test func plannerChangesContainerInsteadOfTranscodingAudio() throws {
    let source = try tempMediaFile(); defer { try? FileManager.default.removeItem(at: source) }
    let inspection = try inspect(#"{"streams":[{"index":0,"codec_name":"hevc","codec_type":"video"},{"index":1,"codec_name":"dts","codec_type":"audio"}],"format":{"format_name":"mov,mp4,m4a,3gp,3g2,mj2"}}"#)
    let draft = try MediaEditDraft(originalURL: source, originalFingerprint: .read(from: source), inspection: inspection, container: .mp4)
    let plan = try MediaEditPlanner().plan(from: draft)
    #expect(plan.targetContainer == .mkv)
    #expect(plan.audioTracks[0].action == .keep)
    #expect(plan.audioTracks[0].outputCodec == "dts")
    #expect(plan.warnings.contains { $0.contains("stream copy") })
}

@Test func authorizedSRTToMovTextIsExplicitAndLocalizedToSubtitle() throws {
    let source = try tempMediaFile(); defer { try? FileManager.default.removeItem(at: source) }
    let inspection = try inspect(#"{"streams":[{"index":0,"codec_name":"h264","codec_type":"video"},{"index":1,"codec_name":"aac","codec_type":"audio"},{"index":2,"codec_name":"subrip","codec_type":"subtitle"}],"format":{"format_name":"mov,mp4,m4a,3gp,3g2,mj2"}}"#)
    var draft = try MediaEditDraft(originalURL: source, originalFingerprint: .read(from: source), inspection: inspection, container: .mp4)
    let subtitleID = try #require(draft.subtitleTracks.first?.id)
    draft.authorizedSubtitleConversions.insert(subtitleID)
    let plan = try MediaEditPlanner().plan(from: draft)
    #expect(plan.targetContainer == .mp4)
    #expect(plan.audioTracks.allSatisfy { $0.outputCodec == $0.track.codec })
    #expect(plan.subtitleTracks[0].action == .convertSubtitle)
    #expect(plan.subtitleTracks[0].outputCodec == "mov_text")
}

@Test(arguments: [EditableMediaContainer.mkv, .mp4, .mov, .webm])
func compatibilityRegistryCoversEditableContainers(_ container: EditableMediaContainer) {
    let registry = MediaContainerCompatibilityRegistry()
    switch container {
    case .mkv:
        #expect(registry.supportsVideo(codec: "hevc", container: container)); #expect(registry.decision(kind: .audio, codec: "flac", container: container) == .streamCopy)
    case .mp4:
        #expect(registry.supportsVideo(codec: "h264", container: container)); #expect(registry.decision(kind: .subtitle, codec: "srt", container: container) == .convertSubtitle(to: "mov_text"))
    case .mov:
        #expect(registry.supportsVideo(codec: "prores", container: container)); #expect(registry.decision(kind: .audio, codec: "pcm_s24le", container: container) == .streamCopy)
    case .webm:
        #expect(registry.supportsVideo(codec: "vp9", container: container)); #expect(registry.decision(kind: .audio, codec: "opus", container: container) == .streamCopy)
    }
}


@Test func compatibilityRejectsUnsupportedAttachedPictureWhenChangingContainer() throws {
    let (url, draft) = try draftFixture(json: #"{"streams":[{"index":0,"codec_name":"vp9","codec_type":"video"},{"index":1,"codec_name":"opus","codec_type":"audio"},{"index":2,"codec_name":"mjpeg","codec_type":"video","disposition":{"attached_pic":1}}]}"#, container: .mkv)
    defer { try? FileManager.default.removeItem(at: url) }
    let registry = MediaContainerCompatibilityRegistry()
    #expect(!registry.isCompatible(draft: draft, container: .webm, allowAuthorizedSubtitleConversion: true))
    #expect(registry.isCompatible(draft: draft, container: .mkv, allowAuthorizedSubtitleConversion: true))
}

@Test func commandBuilderUsesSeparatedArgumentsCopyAndExactMaps() throws {
    let source = try tempMediaFile(); defer { try? FileManager.default.removeItem(at: source) }
    let external = try tempMediaFile(); defer { try? FileManager.default.removeItem(at: external) }
    let sourceFP = try FileFingerprint.read(from: source), externalFP = try FileFingerprint.read(from: external)
    let a = MediaEditableTrack(kind: .audio, source: .original(streamIndex: 2), codec: "aac", language: "eng", title: "Main", isDefault: true, preservedDispositions: ["comment"])
    let s = MediaEditableTrack(kind: .subtitle, source: .external(url: external, fingerprint: externalFP, streamIndex: 4), codec: "subrip", language: "spa", title: "Sub", isDefault: true, isForced: true)
    let plan = MediaEditPlan(originalURL: source, originalFingerprint: sourceFP, targetContainer: .mp4, audioTracks: [.init(track: a, action: .keep, outputCodec: "aac")], subtitleTracks: [.init(track: s, action: .convertSubtitle, outputCodec: "mov_text")], removedOriginalStreamIndices: [1,3], warnings: [])
    let ffmpeg = URL(fileURLWithPath: "/opt/zeuve/ffmpeg")
    let output = URL(fileURLWithPath: "/tmp/output.mp4")
    let command = try FFmpegMediaEditCommandBuilder().command(ffmpeg: ffmpeg, plan: plan, outputURL: output)
    #expect(command.request.executable.path == "/opt/zeuve/ffmpeg")
    #expect(command.request.arguments.prefix(5) == ["-hide_banner", "-nostdin", "-y", "-i", source.path])
    #expect(command.request.arguments.contains(["-map", "0"].first!))
    #expect(command.request.arguments.contains("-0:1")); #expect(command.request.arguments.contains("-0:2")); #expect(command.request.arguments.contains("-0:3"))
    #expect(command.request.arguments.contains("0:2")); #expect(command.request.arguments.contains("1:4"))
    #expect(command.request.arguments.contains("copy")); #expect(command.request.arguments.contains("mov_text"))
    #expect(command.request.arguments.contains("language=eng")); #expect(command.request.arguments.contains("title=Sub"))
    #expect(command.request.arguments.contains("comment+default")); #expect(command.request.arguments.contains("default+forced"))
    #expect(command.request.arguments.last == output.path)
    #expect(!command.request.arguments.contains("/bin/sh")); #expect(!command.request.arguments.contains("-c:v"))
}

@Test func commandBuilderCanDisableMetadataThroughInjectedPreference() throws {
    let source = try tempMediaFile(); defer { try? FileManager.default.removeItem(at: source) }
    let fp = try FileFingerprint.read(from: source)
    let plan = MediaEditPlan(originalURL: source, originalFingerprint: fp, targetContainer: .mkv, audioTracks: [], subtitleTracks: [], preserveMetadata: false, removedOriginalStreamIndices: [], warnings: [])
    let args = try FFmpegMediaEditCommandBuilder().command(ffmpeg: URL(fileURLWithPath:"/x/ffmpeg"), plan: plan, outputURL: URL(fileURLWithPath:"/tmp/x.mkv")).request.arguments
    if let index = args.firstIndex(of: "-map_metadata") { #expect(args[index + 1] == "-1") } else { Issue.record("Falta -map_metadata") }
    if let index = args.firstIndex(of: "-map_chapters") { #expect(args[index + 1] == "-1") } else { Issue.record("Falta -map_chapters") }
}

@available(*, deprecated, message: "Prueba deliberada del adaptador legacy")
@Test func legacyTrackEditCommandBuilderStillDelegatesToCurrentBuilder() throws {
    let source = try tempMediaFile(); defer { try? FileManager.default.removeItem(at: source) }
    let fingerprint = try FileFingerprint.read(from: source)
    let plan = MediaEditPlan(originalURL: source, originalFingerprint: fingerprint, targetContainer: .mkv, audioTracks: [], subtitleTracks: [], removedOriginalStreamIndices: [], warnings: [])
    let ffmpeg = URL(fileURLWithPath: "/x/ffmpeg")
    let output = URL(fileURLWithPath: "/tmp/legacy-output.mkv")
    let legacy = try FFmpegTrackEditCommandBuilder(preserveMetadata: false).command(ffmpeg: ffmpeg, plan: plan, outputURL: output)
    let currentPlan = MediaEditPlan(originalURL: source, originalFingerprint: fingerprint, targetContainer: .mkv, audioTracks: [], subtitleTracks: [], preserveMetadata: false, removedOriginalStreamIndices: [], warnings: [])
    let current = try FFmpegMediaEditCommandBuilder().command(ffmpeg: ffmpeg, plan: currentPlan, outputURL: output)
    #expect(legacy == current)
}

@Test func plannerHonorsInjectedPreferredContainerOnlyWhenCompatible() throws {
    let (url, draft) = try draftFixture(json: #"{"streams":[{"index":0,"codec_name":"vp9","codec_type":"video"},{"index":1,"codec_name":"opus","codec_type":"audio"}]}"#, container: .mkv)
    defer { try? FileManager.default.removeItem(at: url) }
    var preferences = MultimediaInspectorPreferences.defaults
    preferences.preferredContainer = .webm
    #expect(try MediaEditPlanner(preferences: preferences).plan(from: draft).targetContainer == .webm)
    preferences.preferredContainer = .mp4
    #expect(try MediaEditPlanner(preferences: preferences).plan(from: draft).targetContainer == .mkv)
}

@Test func validatorDetectsChangedExternalInput() throws {
    let (url, base) = try draftFixture(json: #"{"streams":[{"index":0,"codec_name":"h264","codec_type":"video"}]}"#)
    defer { try? FileManager.default.removeItem(at: url) }
    let external = try tempMediaFile(Data([1])); defer { try? FileManager.default.removeItem(at: external) }
    let fp = try FileFingerprint.read(from: external)
    var draft = base
    draft.audioTracks.append(.init(kind: .audio, source: .external(url: external, fingerprint: fp, streamIndex: 0), codec: "aac"))
    try Data([1,2,3,4,5,6]).write(to: external)
    #expect(throws: MultimediaInspectorError.self) { try MediaEditValidator().validateDraft(draft) }
}

@Test func publisherNeverOverwritesOriginalAndResolvesConflicts() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent("zeuve-publish-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let original = directory.appendingPathComponent("movie.mkv"), temporary = directory.appendingPathComponent("temp.mkv")
    try Data([1,2,3]).write(to: original); try Data([9,9,9]).write(to: temporary)
    #expect(throws: MultimediaInspectorError.self) { try MultimediaOutputPublisher().publish(temporary: temporary, proposed: original, protectedOriginals: [original]) }
    let requested = directory.appendingPathComponent("movie_editado.mkv")
    try Data([4]).write(to: requested)
    let output = try MultimediaOutputPublisher().publish(temporary: temporary, proposed: requested, protectedOriginals: [original])
    #expect(output.lastPathComponent == "movie_editado 2.mkv")
    #expect(try Data(contentsOf: original) == Data([1,2,3]))
    #expect(try Data(contentsOf: output) == Data([9,9,9]))
}

@Test func draftRejectsSymlinkAsEditableOriginal() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent("zeuve-link-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let real = directory.appendingPathComponent("real.mkv"), link = directory.appendingPathComponent("link.mkv")
    try Data([1]).write(to: real); try FileManager.default.createSymbolicLink(at: link, withDestinationURL: real)
    let inspection = try inspect(#"{"streams":[{"index":0,"codec_name":"aac","codec_type":"audio"}]}"#)
    #expect(throws: MultimediaInspectorError.self) { _ = try MediaEditDraft(originalURL: link, originalFingerprint: .read(from: link), inspection: inspection, container: .mkv) }
}
