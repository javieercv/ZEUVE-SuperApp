import Foundation
import Testing
import ZEUVECore
import ZEUVEEngines
import ZEUVEOperations
@testable import UniversalConverterModule

private let conversionQAEnvironment = ProcessInfo.processInfo.environment

@Test(.enabled(if: conversionQAEnvironment["ZEUVE_QA_FIXTURES"] != nil && conversionQAEnvironment["ZEUVE_QA_ENGINES"] != nil), arguments: ["mono-opus", "mono-ogg", "stereo-opus", "txt-md", "md-txt", "html-txt", "txt-html", "md-html", "html-md"])
func nativeQAConversionHonorsMediaPolicyAndTextWriters(_ scenario: String) async throws {
    let fixtures = URL(fileURLWithPath: try #require(conversionQAEnvironment["ZEUVE_QA_FIXTURES"]))
    let registry = try EngineRegistry(resourceRoot: URL(fileURLWithPath: try #require(conversionQAEnvironment["ZEUVE_QA_ENGINES"])))
    let sources: [String: (String, ConverterFormat, ConverterFormat)] = [
        "mono-opus": ("mono.wav", .wav, .opus), "mono-ogg": ("mono.wav", .wav, .ogg), "stereo-opus": ("stereo.wav", .wav, .opus),
        "txt-md": ("c35_texto.txt", .txt, .markdown), "md-txt": ("c36_marcado.md", .markdown, .txt), "html-txt": ("c37_pagina.html", .html, .txt),
        "txt-html": ("c35_texto.txt", .txt, .html), "md-html": ("c36_marcado.md", .markdown, .html), "html-md": ("c37_pagina.html", .html, .markdown)
    ]
    let entry = try #require(sources[scenario]); let source = fixtures.appendingPathComponent(entry.0)
    let originalBytes = try Data(contentsOf: source); let fingerprint = try FileFingerprint.read(from: source)
    let input = ConverterInputItem(kind: .file, sourceURL: source, relativePath: source.lastPathComponent, displayName: source.lastPathComponent, size: fingerprint.size, format: entry.1, fingerprint: fingerprint, sourceRootName: source.deletingPathExtension().lastPathComponent)
    let output = URL(fileURLWithPath: conversionQAEnvironment["ZEUVE_QA_OUTPUTS"] ?? FileManager.default.temporaryDirectory.path).appendingPathComponent("zeuve-convert-\(scenario)-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
    var options = ConverterOperationOptions(); options.targetFormat = entry.2; options.quality = .maximum; options.preferRemuxWhenPossible = false
    if scenario == "stereo-opus" { options.audioBitrate = .kbps320 }
    let coordinator = OperationCoordinator()
    let service = UniversalConverterExecutionService(coordinator: coordinator, history: nil, logger: nil, engineLocator: .init(registry: registry))
    let inspections = try await service.inspectForPlanning(inputs: [input], options: options)
    let plan = try await ConversionPlanner().plan(inputs: [input], outputFolder: output, options: options, revision: 1, mediaInspections: inspections)
    if scenario.hasPrefix("mono") { #expect(plan.items[0].warnings.contains { $0.contains("256 kb/s") }) }
    let result = try await service.execute(plan)
    #expect(result.completedCount == 1, "\(result.items)"); #expect(result.failedCount == 0)
    #expect(await coordinator.current() == nil)
    #expect(try Data(contentsOf: source) == originalBytes)
    if entry.2 == .txt {
        let url = try #require(result.items.first?.outputURLs.first)
        let text = try String(contentsOf: url, encoding: .utf8)
        #expect(!text.contains("**negrita**")); #expect(!text.contains("# ")); #expect(!text.contains("<html"))
        #expect(!text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }
}

@Test(.enabled(if: conversionQAEnvironment["ZEUVE_QA_FIXTURES"] != nil && conversionQAEnvironment["ZEUVE_QA_ENGINES"] != nil))
func nativeAACAndM4AOutputsReimportAsAACAndConvertToFLAC() async throws {
    let fixtures = URL(fileURLWithPath: try #require(conversionQAEnvironment["ZEUVE_QA_FIXTURES"]))
    let registry = try EngineRegistry(resourceRoot: URL(fileURLWithPath: try #require(conversionQAEnvironment["ZEUVE_QA_ENGINES"])))
    let root = URL(fileURLWithPath: conversionQAEnvironment["ZEUVE_QA_OUTPUTS"] ?? FileManager.default.temporaryDirectory.path).appendingPathComponent("zeuve-aac-roundtrip-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let coordinator = OperationCoordinator()
    let service = UniversalConverterExecutionService(coordinator: coordinator, history: nil, logger: nil, engineLocator: .init(registry: registry))
    let detector = ConverterFormatDetector()
    let original = fixtures.appendingPathComponent("mono.wav")
    let bytes = try Data(contentsOf: original)
    var aacOutput: URL?
    for (ordinal, target) in [ConverterFormat.aac, .m4a, .flac].enumerated() {
        let source = target == .flac ? try #require(aacOutput) : original
        let detected = try detector.detectDetailed(url: source)
        #expect(detected.detectedFormat == (target == .flac ? .aac : .wav))
        #expect(detected.warning == nil)
        let fingerprint = try FileFingerprint.read(from: source)
        let input = ConverterInputItem(kind: .file, sourceURL: source, relativePath: source.lastPathComponent, displayName: source.lastPathComponent, size: fingerprint.size, format: detected.detectedFormat, fingerprint: fingerprint, sourceRootName: source.deletingPathExtension().lastPathComponent)
        var options = ConverterOperationOptions(); options.targetFormat = target; options.quality = .maximum
        let inspections = try await service.inspectForPlanning(inputs: [input], options: options)
        let plan = try await ConversionPlanner().plan(inputs: [input], outputFolder: root, options: options, revision: UInt64(ordinal + 1), mediaInspections: inspections)
        let result = try await service.execute(plan)
        #expect(result.completedCount == 1 && result.failedCount == 0)
        let output = try #require(result.items.first?.outputURLs.first)
        let info = try await MediaInspectionService().inspect(url: output, ffprobe: registry.executableURL(named: "ffprobe"), useCache: false)
        #expect(info.audioStreams.first?.codec_name == (target == .flac ? "flac" : "aac"))
        #expect(try detector.detectDetailed(url: output).warning == nil)
        if target == .aac { aacOutput = output }
        #expect(await coordinator.current() == nil)
        #expect(try Data(contentsOf: original) == bytes)
    }
}
