import Foundation
import Testing
import ZEUVECore
import ZEUVEEngines
@testable import UniversalConverterModule

private func tempDirectory(_ name: String = UUID().uuidString) throws -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("ZEUVE-ConverterTests-\(name)", isDirectory: true)
    try? FileManager.default.removeItem(at: url)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

private func inputItem(url: URL, format: ConverterFormat, relativePath: String? = nil) throws -> ConverterInputItem {
    let fingerprint = try FileFingerprint.read(from: url)
    return ConverterInputItem(
        kind: .file,
        sourceURL: url,
        relativePath: relativePath ?? url.lastPathComponent,
        displayName: url.lastPathComponent,
        size: fingerprint.size,
        format: format,
        fingerprint: fingerprint,
        sourceRootName: url.deletingPathExtension().lastPathComponent
    )
}

@Test func safePathsRejectTraversalAndNormalizeSeparators() throws {
    #expect(try ConverterSafePath.normalize("carpeta\\sub/archivo.txt") == "carpeta/sub/archivo.txt")
    #expect(throws: UniversalConverterError.self) { try ConverterSafePath.normalize("../secreto.txt") }
    #expect(throws: UniversalConverterError.self) { try ConverterSafePath.normalize("/tmp/archivo.txt") }
}

@Test func zipRoundTripPreservesStructureAndExtractsOnlyRequestedEntry() throws {
    let root = try tempDirectory("zip-root")
    let nested = root.appendingPathComponent("sub", isDirectory: true)
    try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
    try Data("uno".utf8).write(to: root.appendingPathComponent("uno.txt"))
    try Data("dos".utf8).write(to: nested.appendingPathComponent("dos.csv"))
    let output = try tempDirectory("zip-output").appendingPathComponent("entrada.zip")
    try ConverterZIPWriter().createZIP(from: root, at: output)

    let reader = ConverterArchiveReader(url: output)
    let catalog = try reader.catalog()
    #expect(Set(catalog.entries.filter { !$0.isDirectory }.map(\.path)) == ["uno.txt", "sub/dos.csv"])
    let extracted = output.deletingLastPathComponent().appendingPathComponent("extraido/dos.csv")
    try reader.extract(path: "sub/dos.csv", to: extracted)
    #expect(String(data: try Data(contentsOf: extracted), encoding: .utf8) == "dos")
}

@Test func scannerProcessesRepresentativeFolderWithoutArbitraryLimit() async throws {
    let root = try tempDirectory("many")
    for index in 0..<600 {
        try Data("fila,\(index)\n".utf8).write(to: root.appendingPathComponent(String(format: "archivo-%04d.csv", index)))
    }
    let scanner = ConverterInputScanner()
    let first = try await scanner.scan(urls: [root])
    let second = try await scanner.scan(urls: [root])
    #expect(first.items.count == 600)
    #expect(second == first)
    #expect(first.rejected.isEmpty)
}

@Test func plannerReusesCachedPlanAndChangesRevisionOnly() async throws {
    let root = try tempDirectory("planner")
    let source = root.appendingPathComponent("foto.png")
    try Data([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]).write(to: source)
    let item = try inputItem(url: source, format: .png)
    var options = ConverterOperationOptions()
    options.targetFormat = .jpeg
    let planner = ConversionPlanner()
    let first = try await planner.plan(inputs: [item], outputFolder: root, options: options, revision: 1)
    let second = try await planner.plan(inputs: [item], outputFolder: root, options: options, revision: 9)
    #expect(first.id == second.id)
    #expect(second.revision == 9)
    #expect(second.items.first?.executionKind == .nativeImage)
}

@Test func frameExtractionUsesAllFramesAndLosslessOutput() throws {
    let root = try tempDirectory("frames")
    let source = root.appendingPathComponent("video.mp4")
    try Data("video".utf8).write(to: source)
    let item = try inputItem(url: source, format: .mp4)
    let planItem = ConversionPlanItem(
        sources: [item], operation: .extractFrames, targetFormat: .png, executionKind: .ffmpeg,
        destinationRelativePath: "Fotogramas", estimatedOutputBytes: nil
    )
    var options = ConverterOperationOptions()
    options.operation = .extractFrames
    options.frameFormat = .png
    options.normalize()
    let command = try FFmpegCommandBuilder().command(
        ffmpeg: URL(fileURLWithPath: "/usr/bin/ffmpeg"), source: source, planItem: planItem,
        options: options, destination: root.appendingPathComponent("Fotogramas"), probe: nil
    )
    #expect(command.request.arguments.contains("passthrough"))
    #expect(command.request.arguments.contains("png"))
    #expect(command.request.arguments.contains("showinfo=checksum=0"))
    let compressionIndex = try #require(command.request.arguments.firstIndex(of: "-compression_level"))
    #expect(command.request.arguments[compressionIndex + 1] == "3")
    let predictorIndex = try #require(command.request.arguments.firstIndex(of: "-pred"))
    #expect(command.request.arguments[predictorIndex + 1] == "up")
    #expect(command.outputIsDirectory)
}

@Test func audioToVideoSupportsBlackAndSelectedImage() throws {
    let root = try tempDirectory("audio-video")
    let audio = root.appendingPathComponent("audio.flac")
    let image = root.appendingPathComponent("portada.png")
    try Data("audio".utf8).write(to: audio)
    try Data("image".utf8).write(to: image)
    let item = try inputItem(url: audio, format: .flac)
    let planItem = ConversionPlanItem(
        sources: [item], operation: .audioToVideo, targetFormat: .mp4, executionKind: .ffmpeg,
        destinationRelativePath: "salida.mp4", estimatedOutputBytes: nil
    )
    var options = ConverterOperationOptions()
    options.operation = .audioToVideo
    options.audioVideoBackground = .black
    options.normalize()
    let black = try FFmpegCommandBuilder().command(ffmpeg: URL(fileURLWithPath: "/ffmpeg"), source: audio, planItem: planItem, options: options, destination: root.appendingPathComponent("negro.mp4"))
    #expect(black.request.arguments.contains(where: { $0.contains("color=c=black") }))
    #expect(black.request.arguments.contains("libx264"))
    #expect(black.request.arguments.contains("-crf"))

    options.accelerationMode = .hardware
    let hardware = try FFmpegCommandBuilder().command(ffmpeg: URL(fileURLWithPath: "/ffmpeg"), source: audio, planItem: planItem, options: options, destination: root.appendingPathComponent("hardware.mp4"))
    #expect(hardware.request.arguments.contains("h264_videotoolbox"))

    options.accelerationMode = .automatic
    options.audioVideoBackground = .image
    options.audioVideoImageURL = image
    let withImage = try FFmpegCommandBuilder().command(ffmpeg: URL(fileURLWithPath: "/ffmpeg"), source: audio, planItem: planItem, options: options, destination: root.appendingPathComponent("imagen.mp4"))
    #expect(withImage.request.arguments.contains(image.path))
    #expect(withImage.request.arguments.contains("-loop"))
}

@Test func csvRemainsARecognizedGenericDataFormat() async throws {
    let root = try tempDirectory("csv-generic")
    let source = root.appendingPathComponent("datos.csv")
    try Data("nombre,valor\nuno,1\n".utf8).write(to: source)
    let item = try inputItem(url: source, format: .csv)
    var options = ConverterOperationOptions()
    options.targetFormat = .csv
    let plan = try await ConversionPlanner().plan(inputs: [item], outputFolder: root, options: options, revision: 1)
    #expect(plan.items.first?.executionKind == .copy)
    #expect(plan.items.first?.targetFormat == .csv)
}

@Test func publisherNeverOverwritesWithoutExplicitPolicy() throws {
    let root = try tempDirectory("publish")
    let original = root.appendingPathComponent("resultado.txt")
    try Data("original".utf8).write(to: original)
    let generatedRoot = try tempDirectory("generated")
    let generated = generatedRoot.appendingPathComponent("resultado.txt")
    try Data("nuevo".utf8).write(to: generated)
    let publisher = ConverterOutputPublisher()
    let renamed = try publisher.publish(source: generated, relativePath: "resultado.txt", to: root, policy: .renameAutomatically)
    #expect(renamed?.lastPathComponent == "resultado - converted.txt")
    #expect(String(data: try Data(contentsOf: original), encoding: .utf8) == "original")
    #expect(try publisher.publish(source: generated, relativePath: "resultado.txt", to: root, policy: .skip) == nil)
}

@Test func sourceFingerprintDetectsChangesBeforeExecution() throws {
    let root = try tempDirectory("fingerprint")
    let source = root.appendingPathComponent("entrada.txt")
    try Data("a".utf8).write(to: source)
    let fingerprint = try FileFingerprint.read(from: source)
    #expect(fingerprint.matches(source))
    try Data("contenido cambiado".utf8).write(to: source)
    #expect(!fingerprint.matches(source))
}

@Test func presetsNeverPersistSelectedImagesAndCanBeRestored() throws {
    var options = ConverterOperationOptions()
    options.operation = .audioToVideo
    options.audioVideoBackground = .image
    options.audioVideoImageURL = URL(fileURLWithPath: "/tmp/private-cover.png")
    options.normalize()

    let preset = UniversalConverterPreset(name: "Vídeo privado", options: options)
    #expect(preset.options.audioVideoImageURL == nil)
    #expect(preset.options.audioVideoBackground == .black)
    #expect(UniversalConverterPreset.defaults.count >= 5)
    #expect(Set(UniversalConverterPreset.defaults.map(\.name)).contains("Todos los fotogramas en PNG"))
}

@Test func encryptedZIPUsesOnlyTheProvidedInMemoryPassword() throws {
    let root = try tempDirectory("encrypted-zip")
    let source = root.appendingPathComponent("privado.txt")
    try Data("contenido privado".utf8).write(to: source)
    let archive = root.appendingPathComponent("protegido.zip")

    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
    process.currentDirectoryURL = root
    process.arguments = ["-q", "-P", "secreto", archive.path, source.lastPathComponent]
    try process.run()
    process.waitUntilExit()
    #expect(process.terminationStatus == 0)

    #expect(throws: UniversalConverterError.archivePasswordRequired) {
        _ = try ConverterArchiveReader(url: archive).catalog()
    }
    #expect(throws: UniversalConverterError.archivePasswordIncorrect) {
        _ = try ConverterArchiveReader(url: archive, password: "incorrecta").catalog()
    }

    let reader = ConverterArchiveReader(url: archive, password: "secreto")
    let catalog = try reader.catalog()
    #expect(catalog.entries.contains(where: { $0.path == "privado.txt" }))
    let extracted = root.appendingPathComponent("extraido/privado.txt")
    try reader.extract(path: "privado.txt", to: extracted)
    #expect(String(data: try Data(contentsOf: extracted), encoding: .utf8) == "contenido privado")
}

@Test func sameFormatConversionUsesExactCopyPlan() async throws {
    let root = try tempDirectory("exact-copy")
    let source = root.appendingPathComponent("audio.mp3")
    try Data("audio sintético".utf8).write(to: source)
    let item = try inputItem(url: source, format: .mp3)
    var options = ConverterOperationOptions()
    options.operation = .convert
    options.targetFormat = .mp3
    let plan = try await ConversionPlanner().plan(inputs: [item], outputFolder: root, options: options, revision: 1)
    #expect(plan.items.first?.executionKind == .copy)
    #expect(plan.items.first?.warnings.contains(where: { $0.contains("copia") }) == true)

    options.preserveCoverArt = false
    let withoutCoverCopy = try await ConversionPlanner().plan(inputs: [item], outputFolder: root, options: options, revision: 2)
    #expect(withoutCoverCopy.items.first?.executionKind == .ffmpeg)
}

@Test func advancedAudioOptionsAreAppliedToFFmpeg() throws {
    let root = try tempDirectory("advanced-audio")
    let source = root.appendingPathComponent("audio.wav")
    try Data("audio".utf8).write(to: source)
    let item = try inputItem(url: source, format: .wav)
    let planItem = ConversionPlanItem(
        sources: [item], operation: .convert, targetFormat: .mp3, executionKind: .ffmpeg,
        destinationRelativePath: "audio.mp3", estimatedOutputBytes: nil
    )
    var options = ConverterOperationOptions()
    options.targetFormat = .mp3
    options.audioBitrate = .kbps256
    options.audioSampleRate = .hz48000
    options.audioChannels = .stereo
    options.normalizeAudio = true
    let command = try FFmpegCommandBuilder().command(
        ffmpeg: URL(fileURLWithPath: "/ffmpeg"), source: source, planItem: planItem,
        options: options, destination: root.appendingPathComponent("audio.mp3")
    )
    #expect(command.request.arguments.contains("256k"))
    #expect(command.request.arguments.contains("48000"))
    #expect(command.request.arguments.contains("2"))
    #expect(command.request.arguments.contains(where: { $0.contains("loudnorm") }))
}

@Test func advancedVideoOptionsSelectCodecResolutionFPSAndTrackPolicy() throws {
    let root = try tempDirectory("advanced-video")
    let source = root.appendingPathComponent("video.mkv")
    try Data("video".utf8).write(to: source)
    let item = try inputItem(url: source, format: .mkv)
    let planItem = ConversionPlanItem(
        sources: [item], operation: .convert, targetFormat: .mov, executionKind: .ffmpeg,
        destinationRelativePath: "video.mov", estimatedOutputBytes: nil
    )
    var options = ConverterOperationOptions()
    options.targetFormat = .mov
    options.videoCodec = .hevc
    options.videoResolution = .fullHD1080
    options.videoFrameRate = .fps30
    options.videoAudioMode = .remove
    options.preserveSubtitles = false
    options.preserveChapters = false
    options.normalize()
    let command = try FFmpegCommandBuilder().command(
        ffmpeg: URL(fileURLWithPath: "/ffmpeg"), source: source, planItem: planItem,
        options: options, destination: root.appendingPathComponent("video.mov")
    )
    #expect(command.request.arguments.contains("hevc_videotoolbox"))
    #expect(command.request.arguments.contains(where: { $0.contains("1920") && $0.contains("1080") }))
    #expect(command.request.arguments.contains(where: { $0 == "fps=30" || $0.contains("fps=30") }))
    #expect(command.request.arguments.contains("-an"))
    #expect(!command.request.arguments.contains("0:s?"))
    #expect(command.request.arguments.suffix(2).contains("-1") || command.request.arguments.contains("-map_chapters"))

    options.videoCodec = .proRes
    options.videoAudioMode = .preserve
    options.videoResolution = .original
    options.videoFrameRate = .original
    options.normalize()
    let proRes = try FFmpegCommandBuilder().command(
        ffmpeg: URL(fileURLWithPath: "/ffmpeg"), source: source, planItem: planItem,
        options: options, destination: root.appendingPathComponent("video-prores.mov")
    )
    #expect(proRes.request.arguments.contains("prores_ks"))
    #expect(proRes.request.arguments.contains("-qscale:v"))
    #expect(!proRes.request.arguments.contains("55"))
}

@Test func audioConversionPreservesAttachedCoverOnlyForCompatibleTargets() throws {
    let root = try tempDirectory("cover-art")
    let source = root.appendingPathComponent("audio.flac")
    try Data("audio".utf8).write(to: source)
    let item = try inputItem(url: source, format: .flac)
    let probeJSON = Data(#"{"streams":[{"index":0,"codec_name":"flac","codec_type":"audio"},{"index":1,"codec_name":"mjpeg","codec_type":"video","disposition":{"attached_pic":1}}],"format":{"duration":"1.0"}}"#.utf8)
    let probe = try JSONDecoder().decode(MediaInspectionResult.self, from: probeJSON)
    #expect(probe.attachedPictureStream?.codec_name == "mjpeg")

    var options = ConverterOperationOptions()
    options.targetFormat = .mp3
    options.preserveCoverArt = true
    let mp3Plan = ConversionPlanItem(
        sources: [item], operation: .convert, targetFormat: .mp3, executionKind: .ffmpeg,
        destinationRelativePath: "audio.mp3", estimatedOutputBytes: nil
    )
    let withCover = try FFmpegCommandBuilder().command(
        ffmpeg: URL(fileURLWithPath: "/ffmpeg"), source: source, planItem: mp3Plan,
        options: options, destination: root.appendingPathComponent("audio.mp3"), probe: probe
    )
    #expect(withCover.request.arguments.contains("0:1?"))
    #expect(withCover.request.arguments.contains("attached_pic"))
    #expect(!withCover.request.arguments.contains("-vn"))

    options.targetFormat = .wav
    let wavPlan = ConversionPlanItem(
        sources: [item], operation: .convert, targetFormat: .wav, executionKind: .ffmpeg,
        destinationRelativePath: "audio.wav", estimatedOutputBytes: nil
    )
    let withoutCover = try FFmpegCommandBuilder().command(
        ffmpeg: URL(fileURLWithPath: "/ffmpeg"), source: source, planItem: wavPlan,
        options: options, destination: root.appendingPathComponent("audio.wav"), probe: probe
    )
    #expect(withoutCover.request.arguments.contains("-vn"))
    #expect(!withoutCover.request.arguments.contains("attached_pic"))
}


@Test func simpleMP4ConversionAlwaysReencodesVideo() throws {
    let root = try tempDirectory("video-real-mp4")
    let source = root.appendingPathComponent("video.mp4")
    try Data("video".utf8).write(to: source)
    let item = try inputItem(url: source, format: .mp4)
    let planItem = ConversionPlanItem(
        sources: [item], operation: .convert, targetFormat: .mp4, executionKind: .ffmpeg,
        destinationRelativePath: "convertido.mp4", estimatedOutputBytes: nil
    )
    let probeJSON = Data(#"{"streams":[{"index":0,"codec_name":"h264","codec_type":"video"},{"index":1,"codec_name":"aac","codec_type":"audio"}],"format":{"duration":"1.0"}}"#.utf8)
    let probe = try JSONDecoder().decode(MediaInspectionResult.self, from: probeJSON)
    var options = ConverterOperationOptions()
    options.targetFormat = .mp4
    options.advancedMode = false
    options.preferRemuxWhenPossible = true
    let command = try FFmpegCommandBuilder().command(
        ffmpeg: URL(fileURLWithPath: "/ffmpeg"), source: source, planItem: planItem,
        options: options, destination: root.appendingPathComponent("convertido.mp4"), probe: probe
    )
    let arguments = command.request.arguments
    let videoCodecIndex = try #require(arguments.firstIndex(of: "-c:v"))
    #expect(arguments[videoCodecIndex + 1] == "libx264")
    #expect(!zip(arguments, arguments.dropFirst()).contains(where: { $0.0 == "-c:v" && $0.1 == "copy" }))
}

@Test func plannerDoesNotUseExactCopyForSimpleMP4ToMP4() async throws {
    let root = try tempDirectory("planner-real-mp4")
    let source = root.appendingPathComponent("video.mp4")
    try Data("video".utf8).write(to: source)
    let item = try inputItem(url: source, format: .mp4)
    var options = ConverterOperationOptions()
    options.targetFormat = .mp4
    options.advancedMode = false
    options.preferRemuxWhenPossible = true
    let plan = try await ConversionPlanner().plan(inputs: [item], outputFolder: root, options: options, revision: 1)
    #expect(plan.items.first?.executionKind == .ffmpeg)
    #expect(plan.items.first?.warnings.contains(where: { $0.contains("recodificará realmente") }) == true)
}

@Test func converterDefaultsPreferRealVideoConversion() {
    #expect(UniversalConverterSettings().preferRemuxWhenPossible == false)
    let videoPreset = UniversalConverterPreset.defaults.first(where: { $0.name == "Vídeo MP4 compatible" })
    #expect(videoPreset?.options.preferRemuxWhenPossible == false)
}

@Test func frameTimingCollectorWritesShowInfoWithoutSecondPass() throws {
    let root = try tempDirectory("frame-timing-showinfo")
    let csv = root.appendingPathComponent("tiempos.csv")
    let collector = try FrameTimingCSVCollector(url: csv)
    collector.append(Data("[Parsed_showinfo_0 @ 0x1] n:   0 pts:      0 pts_time:0 duration:1 duration_time:0.04 fmt:rgb24\n".utf8))
    collector.append(Data("[Parsed_showinfo_0 @ 0x1] n:   1 pts:      1 pts_time:0.04 duration:1 duration_time:0.04 fmt:rgb24\n".utf8))
    try collector.finish()
    let content = try String(contentsOf: csv, encoding: .utf8)
    #expect(content.contains("1,0,0.04"))
    #expect(content.contains("2,0.04,0.04"))
    #expect(collector.frameCount == 2)
}

@Test func visibleFrameFolderCompletesWithoutCopyingTheTree() throws {
    let root = try tempDirectory("visible-frame-complete")
    let recordRoot = try tempDirectory("visible-frame-record")
    let record = recordRoot.appendingPathComponent("visible-frame.json")
    let coordinator = VisibleFrameOutputCoordinator()
    let preparedSession = try coordinator.prepare(
        operationID: UUID(),
        relativePath: "Vídeo - Fotogramas",
        outputRoot: root,
        policy: .renameAutomatically,
        protectedCanonicalPaths: [],
        recordURL: record
    )
    let session = try #require(preparedSession)
    #expect(session.workingURL.lastPathComponent.contains("Procesando"))
    #expect(FileManager.default.fileExists(atPath: session.workingURL.path))
    let frame = session.workingURL.appendingPathComponent("fotograma_00000001.png")
    try Data([0x89, 0x50, 0x4E, 0x47]).write(to: frame)
    let completed = try coordinator.complete(session, protectedCanonicalPaths: [])
    #expect(completed.lastPathComponent == "Vídeo - Fotogramas")
    #expect(FileManager.default.fileExists(atPath: completed.appendingPathComponent(frame.lastPathComponent).path))
    #expect(!FileManager.default.fileExists(atPath: session.workingURL.path))
    #expect(!FileManager.default.fileExists(atPath: record.path))
}

@Test func visibleFrameFolderPreservesPartialResults() throws {
    let root = try tempDirectory("visible-frame-incomplete")
    let recordRoot = try tempDirectory("visible-frame-incomplete-record")
    let record = recordRoot.appendingPathComponent("visible-frame.json")
    let coordinator = VisibleFrameOutputCoordinator()
    let preparedSession = try coordinator.prepare(
        operationID: UUID(),
        relativePath: "Vídeo - Fotogramas",
        outputRoot: root,
        policy: .renameAutomatically,
        protectedCanonicalPaths: [],
        recordURL: record
    )
    let session = try #require(preparedSession)
    try Data([0x89, 0x50, 0x4E, 0x47]).write(to: session.workingURL.appendingPathComponent("fotograma_00000001.png"))
    try Data("fotograma,tiempo_segundos,duracion_segundos\n1,0,0.04\n".utf8).write(to: session.workingURL.appendingPathComponent("tiempos.csv"))
    let preservedURL = try coordinator.preserveIncomplete(session)
    let incomplete = try #require(preservedURL)
    #expect(incomplete.lastPathComponent.contains("Incompleto"))
    #expect(FileManager.default.fileExists(atPath: incomplete.appendingPathComponent("fotograma_00000001.png").path))
    #expect(FileManager.default.fileExists(atPath: incomplete.appendingPathComponent("tiempos_parcial.csv").path))
    #expect(!FileManager.default.fileExists(atPath: incomplete.appendingPathComponent("tiempos.csv").path))
}

@Test func cancelledFrameExtractionRemovesOnlyDamagedTail() async throws {
    let root = try tempDirectory("frame-tail-validation")
    let validPNG = try #require(Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAusB9Y9Z9Z8AAAAASUVORK5CYII="))
    let first = root.appendingPathComponent("fotograma_00000001.png")
    let damaged = root.appendingPathComponent("fotograma_00000002.png")
    try validPNG.write(to: first)
    try Data().write(to: damaged)

    let count = try await ConverterResultValidator().retainValidFramePrefix(url: root, expectedFormat: .png)
    #expect(count == 1)
    #expect(FileManager.default.fileExists(atPath: first.path))
    #expect(!FileManager.default.fileExists(atPath: damaged.path))
}

@Test func abandonedVisibleFrameFolderIsRecoveredAsIncomplete() throws {
    let workspaceBase = try tempDirectory("visible-frame-recovery-workspace")
    let outputRoot = try tempDirectory("visible-frame-recovery-output")
    let operationID = UUID()
    let workspace = try ConverterWorkspace(operationID: operationID, baseDirectory: workspaceBase)
    let coordinator = VisibleFrameOutputCoordinator()
    let prepared = try coordinator.prepare(
        operationID: operationID,
        relativePath: "Vídeo - Fotogramas",
        outputRoot: outputRoot,
        policy: .renameAutomatically,
        protectedCanonicalPaths: [],
        recordURL: workspace.visibleFrameRecordURL(itemID: UUID())
    )
    let session = try #require(prepared)
    try Data([0x89, 0x50, 0x4E, 0x47]).write(to: session.workingURL.appendingPathComponent("fotograma_00000001.png"))

    let recovered = try ConverterWorkspace.recoverAbandonedVisibleFrameOutputs(baseDirectory: workspaceBase)
    #expect(recovered.count == 1)
    #expect(recovered[0].lastPathComponent.contains("Incompleto"))
    #expect(FileManager.default.fileExists(atPath: recovered[0].appendingPathComponent("fotograma_00000001.png").path))
    #expect(!FileManager.default.fileExists(atPath: workspace.root.path))
}

@Test func compatibleAudioCanBeRemuxedAcrossContainersWithoutReencoding() throws {
    let root = try tempDirectory("audio-remux")
    let source = root.appendingPathComponent("audio.aac")
    try Data("audio".utf8).write(to: source)
    let item = try inputItem(url: source, format: .aac)
    let planItem = ConversionPlanItem(
        sources: [item], operation: .convert, targetFormat: .m4a, executionKind: .ffmpeg,
        destinationRelativePath: "audio.m4a", estimatedOutputBytes: nil
    )
    let probeJSON = Data(#"{"streams":[{"index":0,"codec_name":"aac","codec_type":"audio"}],"format":{"duration":"1.0"}}"#.utf8)
    let probe = try JSONDecoder().decode(MediaInspectionResult.self, from: probeJSON)
    var options = ConverterOperationOptions()
    options.targetFormat = .m4a
    options.preferRemuxWhenPossible = true
    let command = try FFmpegCommandBuilder().command(
        ffmpeg: URL(fileURLWithPath: "/ffmpeg"), source: source, planItem: planItem,
        options: options, destination: root.appendingPathComponent("audio.m4a"), probe: probe
    )
    let arguments = command.request.arguments
    #expect(arguments.contains("-c:a"))
    #expect(arguments.contains("copy"))
    #expect(!arguments.contains("libmp3lame"))
}

@Test func videoCanCopyItsPictureWhileConvertingOnlyTheAudio() throws {
    let root = try tempDirectory("video-stream-copy")
    let source = root.appendingPathComponent("video.mkv")
    try Data("video".utf8).write(to: source)
    let item = try inputItem(url: source, format: .mkv)
    let planItem = ConversionPlanItem(
        sources: [item], operation: .convert, targetFormat: .mp4, executionKind: .ffmpeg,
        destinationRelativePath: "video.mp4", estimatedOutputBytes: nil
    )
    let probeJSON = Data(#"{"streams":[{"index":0,"codec_name":"h264","codec_type":"video"},{"index":1,"codec_name":"flac","codec_type":"audio"}],"format":{"duration":"1.0"}}"#.utf8)
    let probe = try JSONDecoder().decode(MediaInspectionResult.self, from: probeJSON)
    var options = ConverterOperationOptions()
    options.targetFormat = .mp4
    options.videoAudioMode = .aac
    options.advancedMode = true
    options.preferRemuxWhenPossible = true
    let command = try FFmpegCommandBuilder().command(
        ffmpeg: URL(fileURLWithPath: "/ffmpeg"), source: source, planItem: planItem,
        options: options, destination: root.appendingPathComponent("video.mp4"), probe: probe
    )
    let arguments = command.request.arguments
    let videoCodecIndex = try #require(arguments.firstIndex(of: "-c:v"))
    #expect(arguments[videoCodecIndex + 1] == "copy")
    #expect(arguments.contains("aac"))
    #expect(!arguments.contains("h264_videotoolbox"))
}
