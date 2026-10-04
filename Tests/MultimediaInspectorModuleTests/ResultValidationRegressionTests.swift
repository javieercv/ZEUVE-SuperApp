import Foundation
import Testing
import ZEUVECore
import ZEUVEEngines
@testable import MultimediaInspectorModule

@Test func absentAttachmentCodecAndUnspecifiedLanguageAreEquivalentButRealChangesFail() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("zeuve-result-validation-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let program = root.appendingPathComponent("probe.c"), executable = root.appendingPathComponent("probe")
    try #"""
#include <stdio.h>
int main(int argc, char **argv) {
    FILE *input = fopen(argv[argc - 1], "rb"); if (!input) return 1;
    int byte; while ((byte = fgetc(input)) != EOF) putchar(byte); fclose(input); return 0;
}
"""#.write(to: program, atomically: true, encoding: .utf8)
    let compiler = Process(); compiler.executableURL = URL(fileURLWithPath: "/usr/bin/cc"); compiler.arguments = [program.path, "-o", executable.path]
    try compiler.run(); compiler.waitUntilExit(); #expect(compiler.terminationStatus == 0)
    let originalJSON = #"{"streams":[{"index":0,"codec_type":"video","codec_name":"h264","tags":{"title":"Old"}},{"index":1,"codec_type":"audio","codec_name":"aac","tags":{"language":"und"}},{"index":2,"codec_type":"attachment","extradata_size":15,"tags":{"filename":"qa.bin","mimetype":"application/octet-stream"}}]}"#
    let original = try MediaInspectionParser.decode(Data(originalJSON.utf8))
    let source = root.appendingPathComponent("source.mkv"); try Data(originalJSON.utf8).write(to: source)
    var draft = try MediaEditDraft(originalURL: source, originalFingerprint: .read(from: source), inspection: original, container: .mkv)
    draft.setVideoMetadata("New", for: "title", streamIndex: 0)
    draft.attachments[0].filename = "renamed.bin"
    let plan = try MediaEditPlanner().plan(from: draft)
    let good = originalJSON.replacingOccurrences(of: "Old", with: "New").replacingOccurrences(of: "qa.bin", with: "renamed.bin").replacingOccurrences(of: #","tags":{"language":"und"}"#, with: "")
    let output = root.appendingPathComponent("out.mkv")
    let validator = MultimediaResultValidator()
    try Data(good.utf8).write(to: output)
    _ = try await validator.validate(url: output, plan: plan, original: original, ffprobe: executable)
    for changed in [good.replacingOccurrences(of: "\"extradata_size\":15", with: "\"extradata_size\":16"), good.replacingOccurrences(of: "\"codec_type\":\"attachment\"", with: "\"codec_type\":\"attachment\",\"codec_name\":\"ttf\""), good.replacingOccurrences(of: "renamed.bin", with: "unexpected.bin"), good.replacingOccurrences(of: "New", with: "Old")] {
        try Data(changed.utf8).write(to: output)
        await #expect(throws: MultimediaInspectorError.self) { try await validator.validate(url: output, plan: plan, original: original, ffprobe: executable) }
    }
    draft.audioTracks[0].language = "spa"
    let realLanguage = try MediaEditPlanner().plan(from: draft)
    try Data(good.utf8).write(to: output)
    await #expect(throws: MultimediaInspectorError.self) { try await validator.validate(url: output, plan: realLanguage, original: original, ffprobe: executable) }
}
