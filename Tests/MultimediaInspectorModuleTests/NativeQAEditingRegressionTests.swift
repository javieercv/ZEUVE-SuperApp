import Foundation
import Testing
import ZEUVECore
import ZEUVEEngines
import ZEUVEOperations
@testable import MultimediaInspectorModule

private let nativeQAEnvironment = ProcessInfo.processInfo.environment

@Test(.enabled(if: nativeQAEnvironment["ZEUVE_QA_FIXTURES"] != nil && nativeQAEnvironment["ZEUVE_QA_ENGINES"] != nil), arguments: ["metadata-attachment", "keep-mkv-artwork", "add-mp4", "replace-mp4", "remove-mp4"])
func nativeQAEditingPreservesStructureAndOriginals(_ scenario: String) async throws {
    let fixtures = URL(fileURLWithPath: try #require(nativeQAEnvironment["ZEUVE_QA_FIXTURES"]))
    let registry = try EngineRegistry(resourceRoot: URL(fileURLWithPath: try #require(nativeQAEnvironment["ZEUVE_QA_ENGINES"])))
    let outputRoot = URL(fileURLWithPath: nativeQAEnvironment["ZEUVE_QA_OUTPUTS"] ?? FileManager.default.temporaryDirectory.path)
        .appendingPathComponent("zeuve-native-\(scenario)-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: outputRoot, withIntermediateDirectories: true)
    let name = scenario == "metadata-attachment" ? "I99_estructura.mkv" : (scenario == "keep-mkv-artwork" ? "I128_caratula_original.mkv" : (scenario == "add-mp4" ? "I130_base.mp4" : "I130_contraste_sin_titulo.mp4"))
    let source = fixtures.appendingPathComponent(name)
    let originalBytes = try Data(contentsOf: source)
    let ffprobe = try registry.executableURL(named: "ffprobe")
    let inspection = try await MediaInspectionService().inspect(url: source, ffprobe: ffprobe, useCache: false)
    var draft = try MediaEditDraft(originalURL: source, originalFingerprint: .read(from: source), inspection: inspection, container: #require(EditableMediaContainer.detect(from: inspection, url: source)))
    if scenario == "metadata-attachment" {
        draft.setVideoMetadata("QA nuevo título", for: "title", streamIndex: 0)
        draft.attachments[0].filename = "qa-renamed.txt"
        draft.attachments[0].mimeType = "text/x-qa"
    } else if scenario == "keep-mkv-artwork" {
        draft.metadata.setContainerValue("QA preservando portada", for: "title")
    } else if scenario == "remove-mp4" {
        draft.artworks.removeAll()
    } else {
        let image = fixtures.appendingPathComponent("I131_cover_B.png")
        draft.artworks = [.init(source: .external(url: image, fingerprint: try .read(from: image), streamIndex: 0), codec: "png")]
    }
    let plan = try MediaEditPlanner().plan(from: draft)
    #expect(plan.targetContainer == (source.pathExtension == "mkv" ? .mkv : .mp4))
    let coordinator = OperationCoordinator()
    let service = MultimediaEditService(coordinator: coordinator, engineRegistry: registry, history: .init(repository: nil))
    let result = try await service.execute(plan: plan, originalInspection: inspection, proposedOutput: outputRoot.appendingPathComponent("result.\(plan.targetContainer.fileExtension)"))
    #expect(await coordinator.current() == nil)
    #expect(result.inspection.videoStreams.count == inspection.videoStreams.count)
    #expect(result.inspection.audioStreams.count == inspection.audioStreams.count)
    #expect(result.inspection.streams.filter(\.isAttachedPicture).count == draft.artworks.count)
    #expect(try Data(contentsOf: source) == originalBytes)
    if scenario == "keep-mkv-artwork" {
        let ffmpeg = try registry.executableURL(named: "ffmpeg")
        let runner = ExternalProcessRunner()
        var copies: [Data] = []
        for (ordinal, media) in [source, result.outputURL].enumerated() {
            let probed = try await MediaInspectionService().inspect(url: media, ffprobe: ffprobe, useCache: false)
            let index = try #require(probed.attachedPictureStream?.index)
            let image = outputRoot.appendingPathComponent("cover-\(ordinal).jpg")
            let extraction = try await runner.run(.init(executable: ffmpeg, arguments: ["-hide_banner", "-nostdin", "-y", "-i", media.path, "-map", "0:\(index)", "-frames:v", "1", "-c:v", "copy", "-f", "image2", "-update", "1", image.path]))
            #expect(extraction.succeeded)
            copies.append(try Data(contentsOf: image))
        }
        #expect(copies[0] == copies[1])
    }
}
