import Foundation
import Testing
import ZEUVECore
@testable import MultimediaInspectorModule

@Test func pausedVideoSeekPublishesNewFrameAndRapidReplacementLeavesNoBusyRunner() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("zeuve-video-lifecycle-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let program = root.appendingPathComponent("decoder.c"), executable = root.appendingPathComponent("decoder")
    try #"""
#include <unistd.h>
#include <stdlib.h>
#include <string.h>
int main(int argc, char **argv) {
    int position = 0;
    for (int i = 1; i + 1 < argc; i++) if (!strcmp(argv[i], "-ss")) position = atoi(argv[i + 1]);
    unsigned char frame[16]; memset(frame, position, sizeof(frame));
    for (int i = 0; i < 500; i++) { if (write(1, frame, sizeof(frame)) < 0) break; usleep(20000); }
    return 0;
}
"""#.write(to: program, atomically: true, encoding: .utf8)
    let compiler = Process(); compiler.executableURL = URL(fileURLWithPath: "/usr/bin/cc"); compiler.arguments = [program.path, "-o", executable.path]
    try compiler.run(); compiler.waitUntilExit(); #expect(compiler.terminationStatus == 0)
    let file = root.appendingPathComponent("synthetic.mkv"); try Data([1, 2, 3]).write(to: file)
    let source = MultimediaVideoPreviewSource(url: file, fingerprint: try .read(from: file), streamIndex: 0, codec: "h264", width: 2, height: 2, frameRate: 30, duration: 100, title: "Synthetic")
    let service = MultimediaVideoPreviewService()
    func waitForPausedFrame(at position: Double) async throws {
        for _ in 0..<200 {
            let snapshot = await service.snapshot(position: position)
            #expect(snapshot.state != .failed, "\(snapshot.errorMessage ?? "")")
            if snapshot.state == .paused, let frame = snapshot.frame {
                #expect(frame.timestamp == position); #expect(frame.pixelsBGRA.first == UInt8(position))
                return
            }
            try await Task.sleep(for: .milliseconds(10))
        }
        Issue.record("El seek pausado no entregó el frame nuevo")
    }
    try await service.start(ffmpeg: executable, source: source, from: 3, limits: .init(), decoder: .software, shouldPlay: false)
    try await waitForPausedFrame(at: 3)
    try await service.start(ffmpeg: executable, source: source, from: 17, limits: .init(), decoder: .software, shouldPlay: false)
    try await waitForPausedFrame(at: 17)
    let replacements = (20..<30).map { position in
        Task {
            do { try await service.start(ffmpeg: executable, source: source, from: Double(position), limits: .init(), decoder: .software) }
            catch is CancellationError { }
            catch { Issue.record("Reemplazo inesperadamente fallido: \(error)") }
        }
    }
    for replacement in replacements { await replacement.value }
    try await service.start(ffmpeg: executable, source: source, from: 42, limits: .init(), decoder: .software, shouldPlay: false)
    try await waitForPausedFrame(at: 42)
    await service.stop()
    #expect(await service.snapshot(position: 0).state == .idle)
}
