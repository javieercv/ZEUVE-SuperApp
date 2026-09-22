import Foundation
import Testing
import ZEUVECore
import ZEUVEEngines
import ZEUVEStorage
@testable import UniversalConverterModule

private func regressionTempDirectory(_ name: String = UUID().uuidString) throws -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("ZEUVE-ConverterRegression-\(name)-\(UUID().uuidString)", isDirectory: true)
    try? FileManager.default.removeItem(at: url)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

private func regressionInput(url: URL, format: ConverterFormat) throws -> ConverterInputItem {
    let fingerprint = try FileFingerprint.read(from: url)
    return ConverterInputItem(
        kind: .file,
        sourceURL: url,
        relativePath: url.lastPathComponent,
        displayName: url.lastPathComponent,
        size: fingerprint.size,
        format: format,
        fingerprint: fingerprint,
        sourceRootName: url.deletingPathExtension().lastPathComponent
    )
}

@Test func legacyQualityAndSettingsMigrateWithoutDataLoss() throws {
    let legacy = Data(#"{"quality":"balanced","conflictPolicy":"skip","filenameStyle":"suffix","preserveMetadata":false}"#.utf8)
    let settings = try JSONDecoder().decode(UniversalConverterSettings.self, from: legacy)
    #expect(settings.quality == .medium)
    #expect(settings.conflictPolicy == .skip)
    #expect(settings.filenameStyle == .suffix)
    #expect(settings.metadataPolicy == .allCompatible)
    #expect(settings.outputSubfolderName == "ZEUVE Converted")
    #expect(settings.manualParallelism == 2)

    let reencoded = try JSONEncoder().encode(settings)
    let decodedAgain = try JSONDecoder().decode(UniversalConverterSettings.self, from: reencoded)
    #expect(decodedAgain == settings)
}

@Test func legacyPresetOptionsMigrateMissingNewFields() throws {
    let legacy = Data(#"{"operation":"convert","targetFormat":"mp3","advancedMode":false,"quality":"compact","conflictPolicy":"renameAutomatically","filenameStyle":"suffix","preserveMetadata":true}"#.utf8)
    let options = try JSONDecoder().decode(ConverterOperationOptions.self, from: legacy)
    #expect(options.quality == .low)
    #expect(options.targetFormat == .mp3)
    #expect(options.metadataPolicy == .allCompatible)
    #expect(options.zipStructureMode == .preserve)
    #expect(options.accelerationMode == .automatic)
}

@Test func detailedDetectionWarnsWhenExtensionAndContentDisagree() throws {
    let root = try regressionTempDirectory("mismatch")
    let disguised = root.appendingPathComponent("foto.jpg")
    try Data([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 0, 0, 0, 0]).write(to: disguised)
    let detection = try ConverterFormatDetector().detectDetailed(url: disguised)
    #expect(detection.extensionFormat == .jpeg)
    #expect(detection.detectedFormat == .png)
    #expect(detection.hasMismatch)
    #expect(detection.warning != nil)
}

@Test func officeContainersAreRejectedEvenWhenTheirInternalStructureIsRecognizable() throws {
    let root = try regressionTempDirectory("office-rejected")
    let expanded = root.appendingPathComponent("expanded", isDirectory: true)
    try FileManager.default.createDirectory(at: expanded.appendingPathComponent("word", isDirectory: true), withIntermediateDirectories: true)
    try Data("<w:document/>".utf8).write(to: expanded.appendingPathComponent("word/document.xml"))
    try Data("[Content_Types]".utf8).write(to: expanded.appendingPathComponent("[Content_Types].xml"))
    let archive = root.appendingPathComponent("documento.docx")
    try ConverterZIPWriter().createZIP(from: expanded, at: archive)
    let detection = try ConverterFormatDetector().detectDetailed(url: archive)
    #expect(detection.detectedFormat == .unknown)
    #expect(detection.warning?.contains("no son compatibles") == true)
}

@Test func compatibilityMatrixKeepsCSVAndExcludesOfficeFormats() {
    let registry = ConverterCompatibilityRegistry(availability: .logicalTestEnvironment)
    #expect(ConverterFormat.from(pathExtension: "csv") == .csv)
    #expect(ConverterFormat.from(pathExtension: "docx") == .unknown)
    #expect(!ConverterFormat.allCases.contains(where: { ["doc", "docx", "xls", "xlsx", "ppt", "pptx", "odt", "ods", "odp", "rtf"].contains($0.rawValue) }))
    #expect(registry.outputFormats(for: [.csv]) == [.csv])
}

@Test func removedConvertersDoNotExposeEbookOrEPSOutputs() {
    let registry = ConverterCompatibilityRegistry(availability: ConverterEngineAvailability())
    #expect(registry.outputFormats(for: [.csv]) == [.csv])
    #expect(registry.outputFormats(for: [.epub]).isEmpty)
    #expect(registry.outputFormats(for: [.mobi]).isEmpty)
    #expect(registry.outputFormats(for: [.eps]).isEmpty)
}

@Test func plannerAcceptsMixedFormatsWithinOneCategory() async throws {
    let root = try regressionTempDirectory("mixed-images")
    let png = root.appendingPathComponent("uno.png")
    let jpg = root.appendingPathComponent("dos.jpg")
    try Data([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]).write(to: png)
    try Data([0xff, 0xd8, 0xff, 0xd9]).write(to: jpg)
    let inputs = try [regressionInput(url: png, format: .png), regressionInput(url: jpg, format: .jpeg)]
    var options = ConverterOperationOptions()
    options.targetFormat = .tiff
    let plan = try await ConversionPlanner().plan(inputs: inputs, outputFolder: root, options: options, revision: 1)
    #expect(plan.items.count == 2)
    #expect(plan.items.allSatisfy { $0.targetFormat == .tiff })
}

@Test func plannerRejectsMixedGeneralCategories() async throws {
    let root = try regressionTempDirectory("mixed-categories")
    let image = root.appendingPathComponent("uno.png")
    let audio = root.appendingPathComponent("dos.wav")
    try Data([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]).write(to: image)
    try Data("RIFF0000WAVE".utf8).write(to: audio)
    let inputs = try [regressionInput(url: image, format: .png), regressionInput(url: audio, format: .wav)]
    var options = ConverterOperationOptions()
    options.targetFormat = .png
    await #expect(throws: UniversalConverterError.self) {
        _ = try await ConversionPlanner().plan(inputs: inputs, outputFolder: root, options: options, revision: 1)
    }
}

@Test func publisherProtectsEveryOriginalInTheBatch() throws {
    let root = try regressionTempDirectory("all-originals")
    let firstOriginal = root.appendingPathComponent("primero.txt")
    let secondOriginal = root.appendingPathComponent("segundo.txt")
    try Data("primero".utf8).write(to: firstOriginal)
    try Data("segundo".utf8).write(to: secondOriginal)
    let generatedRoot = try regressionTempDirectory("all-originals-generated")
    let generated = generatedRoot.appendingPathComponent("nuevo.txt")
    try Data("nuevo".utf8).write(to: generated)

    let output = try ConverterOutputPublisher().publish(
        source: generated,
        relativePath: "segundo.txt",
        to: root,
        policy: .replaceConfirmed,
        protectedOriginals: [firstOriginal, secondOriginal]
    )
    #expect(output?.lastPathComponent == "segundo - converted.txt")
    #expect(String(data: try Data(contentsOf: secondOriginal), encoding: .utf8) == "segundo")
}

@Test func zipDepthLimitRejectsExcessivelyNestedEntries() throws {
    let root = try regressionTempDirectory("zip-depth")
    let expanded = root.appendingPathComponent("expanded", isDirectory: true)
    let nested = expanded.appendingPathComponent("a/b/c/d", isDirectory: true)
    try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
    try Data("x".utf8).write(to: nested.appendingPathComponent("file.txt"))
    let archive = root.appendingPathComponent("deep.zip")
    try ConverterZIPWriter().createZIP(from: expanded, at: archive)
    let limits = ConverterArchiveLimits(compressedMaximumBytes: 1_000_000, entryMaximumCount: 100, totalDeclaredMaximumBytes: 1_000_000, compressionRatioMaximum: 100, individualEntryMaximumBytes: 1_000_000, maximumFolderDepth: 2)
    #expect(throws: UniversalConverterError.self) {
        _ = try ConverterArchiveReader(url: archive, limits: limits).catalog()
    }
}

@Test func favoritesAndPortableFilesDoNotPersistPrivateInputFiles() throws {
    var options = ConverterOperationOptions()
    options.operation = .audioToVideo
    options.audioVideoBackground = .image
    options.audioVideoImageURL = URL(fileURLWithPath: "/tmp/private-cover.png")
    let favorite = UniversalConverterFavorite(
        name: "Audio a vídeo",
        sourceCategories: [.audio],
        sourceFormats: [.flac],
        targetFormat: .mp4,
        engine: .ffmpeg,
        options: options,
        outputFolder: nil,
        isPinned: true
    )
    #expect(favorite.options.audioVideoImageURL == nil)
    #expect(favorite.options.audioVideoBackground == .black)
    let data = try ConverterRecipeFileService.encodeFavorites([favorite])
    #expect(!String(decoding: data, as: UTF8.self).contains("private-cover"))
    let decoded = try ConverterRecipeFileService.decodeFavorites(data)
    #expect(decoded.count == 1)
    #expect(decoded.first?.id == favorite.id)
    #expect(decoded.first?.name == favorite.name)
    #expect(decoded.first?.options == favorite.options)
    #expect(decoded.first?.outputFolder == nil)
}

@Test func presetAndSettingsPortableFilesRoundTrip() throws {
    let presets = UniversalConverterPreset.defaults
    #expect(try ConverterRecipeFileService.decodePresets(ConverterRecipeFileService.encodePresets(presets)) == presets)
    var settings = UniversalConverterSettings()
    settings.outputSubfolderName = "Convertidos"
    settings.manualParallelism = 7
    let decoded = try ConverterRecipeFileService.decodeSettings(ConverterRecipeFileService.encodeSettings(settings))
    #expect(decoded.outputSubfolderName == "Convertidos")
    #expect(decoded.manualParallelism == 7)
}

@Test func converterBookmarkResolutionFailurePreservesRememberedData() throws {
    let root = try regressionTempDirectory("bookmark-preserve")
    let storage = try StorageContainer(databaseURL: root.appendingPathComponent("settings.sqlite"))
    let key = "universalConverter.outputFolderBookmark.v1"
    let remembered = Data("remembered-bookmark".utf8)
    try storage.settings.set(remembered, forKey: key)
    let store = ConverterOutputBookmarkStore(settings: storage.settings, key: key, codec: BrokenConverterBookmarkCodec())

    #expect(try store.resolve() == nil)
    #expect(try storage.settings.value(forKey: key, as: Data.self) == remembered)
}

@Test func converterBookmarkClearForgetsRememberedOutputFolder() throws {
    let root = try regressionTempDirectory("bookmark-clear")
    let storage = try StorageContainer(databaseURL: root.appendingPathComponent("settings.sqlite"))
    let output = root.appendingPathComponent("output", isDirectory: true)
    try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
    let store = ConverterOutputBookmarkStore(settings: storage.settings, codec: PortableConverterBookmarkCodec())
    try store.save(output)
    #expect(try store.resolve() == output.standardizedFileURL)

    try store.clear()

    #expect(try store.resolve() == nil)
}

@Test func ffmpegCapabilityListsAreParsedFromRealisticOutput() {
    let encoders = FFmpegCapabilityProbe.parseEncoders("""
     V..... libx264              libx264 H.264
     V..... h264_videotoolbox    VideoToolbox H.264 Encoder
     V..... libwebp_anim         libwebp WebP image
     V..... apng                 APNG image
     V..... gif                  GIF image
    """)
    let muxers = FFmpegCapabilityProbe.parseMuxers("""
     E apng            Animated Portable Network Graphics
     E gif             CompuServe Graphics Interchange Format
     E webp            WebP
    """)
    let filters = FFmpegCapabilityProbe.parseFilters("""
     T.. scale             V->V Scale the input video size and/or convert the image format.
     ... palettegen        V->V Generate one palette for a whole video stream.
    """)
    let capabilities = FFmpegCapabilities(encoders: encoders, muxers: muxers, filters: filters)
    #expect(capabilities.hasSoftwareH264)
    #expect(capabilities.hasVideoToolboxH264)
    #expect(capabilities.hasWebPEncoder)
    #expect(capabilities.hasAPNGEncoder)
    #expect(filters.contains("scale"))
}

@Test func abandonedTemporaryWorkspacesAreCleanedSafely() throws {
    let base = try regressionTempDirectory("temporary-cleanup")
    let oldID = UUID()
    let recentID = UUID()
    _ = try ConverterWorkspace(operationID: oldID, baseDirectory: base)
    _ = try ConverterWorkspace(operationID: recentID, baseDirectory: base)

    struct Marker: Codable { let operationID: UUID; let createdAt: Date }
    let oldMarker = Marker(operationID: oldID, createdAt: Date(timeIntervalSince1970: 1_000))
    try JSONEncoder().encode(oldMarker).write(to: base.appendingPathComponent(oldID.uuidString).appendingPathComponent("operation.json"), options: .atomic)
    let recentMarker = Marker(operationID: recentID, createdAt: Date(timeIntervalSince1970: 9_900))
    try JSONEncoder().encode(recentMarker).write(to: base.appendingPathComponent(recentID.uuidString).appendingPathComponent("operation.json"), options: .atomic)

    let removed = try ConverterWorkspace.cleanupAbandoned(olderThan: 1_000, baseDirectory: base, now: Date(timeIntervalSince1970: 10_000))
    #expect(removed == 1)
    #expect(!FileManager.default.fileExists(atPath: base.appendingPathComponent(oldID.uuidString).path))
    #expect(FileManager.default.fileExists(atPath: base.appendingPathComponent(recentID.uuidString).path))
}

@Test func scannerRejectsOfficeFilesInsideZIP() async throws {
    let root = try regressionTempDirectory("nested-office-rejected")
    let docExpanded = root.appendingPathComponent("doc-expanded", isDirectory: true)
    try FileManager.default.createDirectory(at: docExpanded.appendingPathComponent("word", isDirectory: true), withIntermediateDirectories: true)
    try Data("<w:document/>".utf8).write(to: docExpanded.appendingPathComponent("word/document.xml"))
    try Data("types".utf8).write(to: docExpanded.appendingPathComponent("[Content_Types].xml"))
    let docx = root.appendingPathComponent("real.docx")
    try ConverterZIPWriter().createZIP(from: docExpanded, at: docx)
    let outerExpanded = root.appendingPathComponent("outer", isDirectory: true)
    try FileManager.default.createDirectory(at: outerExpanded, withIntermediateDirectories: true)
    try FileManager.default.copyItem(at: docx, to: outerExpanded.appendingPathComponent("inside.docx"))
    let outer = root.appendingPathComponent("documents.zip")
    try ConverterZIPWriter().createZIP(from: outerExpanded, at: outer)
    let scan = try await ConverterInputScanner().scan(urls: [outer])
    #expect(scan.items.isEmpty)
    #expect(scan.rejected.contains(where: { $0.contains("inside.docx") }))
}

@Test func pandocBuilderUsesSeparatedSafeArgumentsAndRejectsEPUB() throws {
    let root = try regressionTempDirectory("pandoc-builder")
    let source = root.appendingPathComponent("entrada con espacios.md")
    try Data("# Título".utf8).write(to: source)
    let destination = root.appendingPathComponent("salida con espacios.html")

    let pandoc = try PandocCommandBuilder().request(
        executable: URL(fileURLWithPath: "/Engines/pandoc/bin/pandoc"),
        source: source,
        target: .html,
        destination: destination,
        metadataPolicy: .removeAll
    )
    #expect(pandoc.arguments.first == source.path)
    #expect(pandoc.arguments.contains(destination.path))
    #expect(!pandoc.arguments.contains(where: { $0.contains("/bin/sh") || $0.contains(";") }))

    #expect(throws: UniversalConverterError.self) {
        _ = try PandocCommandBuilder().request(
            executable: URL(fileURLWithPath: "/Engines/pandoc/bin/pandoc"),
            source: source,
            target: .epub,
            destination: root.appendingPathComponent("libro.epub"),
            metadataPolicy: .allCompatible
        )
    }
}

@Test func scannerRejectsRecognizedEbooksAndEPSWithClearMessages() async throws {
    let root = try regressionTempDirectory("removed-formats")
    let expanded = root.appendingPathComponent("epub", isDirectory: true)
    try FileManager.default.createDirectory(at: expanded.appendingPathComponent("META-INF", isDirectory: true), withIntermediateDirectories: true)
    try Data("application/epub+zip".utf8).write(to: expanded.appendingPathComponent("mimetype"))
    try Data("<container/>".utf8).write(to: expanded.appendingPathComponent("META-INF/container.xml"))
    let epub = root.appendingPathComponent("libro.epub")
    try ConverterZIPWriter().createZIP(from: expanded, at: epub)

    let eps = root.appendingPathComponent("dibujo.eps")
    try Data("%!PS-Adobe-3.0 EPSF-3.0".utf8).write(to: eps)

    let result = try await ConverterInputScanner().scan(urls: [epub, eps])
    #expect(result.items.isEmpty)
    #expect(result.rejected.contains(where: { $0.contains("formato de libro electrónico no compatible") }))
    #expect(result.rejected.contains(where: { $0.contains("EPS") && $0.contains("ya no es compatible") }))
}

@Test func engineManifestKeepsPandocAndExcludesRemovedConverters() throws {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let manifestURL = root.appendingPathComponent("Resources/Engines/engines.json")
    let manifest = try JSONDecoder().decode(EngineManifest.self, from: Data(contentsOf: manifestURL))
    try manifest.validate()
    let names = Set(manifest.engines.map(\.name))
    #expect(!names.contains("calibre"))
    #expect(!names.contains("ghostscript"))
    if let pandoc = manifest.engines.first(where: { $0.name == "pandoc" }) {
        #expect(pandoc.requirement == .optional)
    }
}

private struct BrokenConverterBookmarkCodec: FolderBookmarkCodec {
    enum Failure: Error { case unavailable }
    func makeBookmark(for url: URL) throws -> Data { Data() }
    func resolveBookmark(_ data: Data) throws -> FolderBookmarkResolution { throw Failure.unavailable }
}

private struct PortableConverterBookmarkCodec: FolderBookmarkCodec {
    func makeBookmark(for url: URL) throws -> Data {
        Data(url.standardizedFileURL.path.utf8)
    }

    func resolveBookmark(_ data: Data) throws -> FolderBookmarkResolution {
        guard let path = String(data: data, encoding: .utf8), !path.isEmpty else {
            throw FolderBookmarkError.invalidBookmarkData
        }
        return .init(url: URL(fileURLWithPath: path, isDirectory: true).standardizedFileURL, isStale: false)
    }
}
