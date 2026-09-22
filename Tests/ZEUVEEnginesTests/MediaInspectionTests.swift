import Foundation
import Testing
@testable import ZEUVEEngines

private func decodeInspection(_ json: String) throws -> MediaInspectionResult {
    try MediaInspectionParser.decode(Data(json.utf8))
}

@Test func mediaInspectionParsesRichMultimediaStructure() throws {
    let json = #"""
{
      "streams": [
        {"index":0,"codec_name":"hevc","codec_long_name":"H.265 / HEVC","profile":"Main 10","codec_type":"video","level":153,"width":3840,"height":2160,"coded_width":3840,"coded_height":2160,"sample_aspect_ratio":"1:1","display_aspect_ratio":"16:9","pix_fmt":"yuv420p10le","bits_per_raw_sample":"10","bit_rate":"25000000","r_frame_rate":"24000/1001","avg_frame_rate":"24000/1001","time_base":"1/1000","duration":"120.5","nb_frames":"2889","field_order":"progressive","color_range":"tv","color_space":"bt2020nc","color_transfer":"smpte2084","color_primaries":"bt2020","side_data_list":[{"side_data_type":"Display Matrix","rotation":90},{"side_data_type":"Mastering display metadata","red_x":"34000/50000","red_y":"16000/50000","max_luminance":"10000000/10000"}],"disposition":{"default":1}},
        {"index":1,"codec_name":"truehd","codec_long_name":"TrueHD","codec_type":"audio","profile":"TrueHD + Atmos","sample_fmt":"s32p","sample_rate":"48000","channels":8,"channel_layout":"7.1","bits_per_raw_sample":"24","bit_rate":"5000000","duration":"120.4","tags":{"language":"eng","title":"Atmos"},"disposition":{"default":1}},
        {"index":2,"codec_name":"subrip","codec_type":"subtitle","tags":{"language":"spa","title":"Completos"},"disposition":{"default":1,"forced":0}},
        {"index":3,"codec_name":"hdmv_pgs_subtitle","codec_type":"subtitle","tags":{"language":"eng"},"disposition":{"forced":1}},
        {"index":4,"codec_name":"mjpeg","codec_type":"video","disposition":{"attached_pic":1}},
        {"index":5,"codec_name":"ttf","codec_type":"attachment"},
        {"index":6,"codec_name":"bin_data","codec_type":"data"},
        {"index":7,"codec_name":"unknown","codec_type":"mystery"}
      ],
      "format":{"filename":"private/movie.mkv","nb_streams":8,"nb_programs":1,"format_name":"matroska,webm","format_long_name":"Matroska / WebM","start_time":"0.000000","duration":"120.500000","size":"1000000","bit_rate":"66390","probe_score":100,"tags":{"title":"Película","encoder":"test"}},
      "chapters":[{"id":0,"time_base":"1/1000","start":0,"start_time":"0.000000","end":60000,"end_time":"60.000000","tags":{"title":"Capítulo 1"}}],
      "programs":[{"program_id":1,"program_num":1,"nb_streams":2,"tags":{"service_name":"Programa"}}]
    }
"""#
    let r = try decodeInspection(json)
    #expect(r.videoStreams.count == 1)
    #expect(r.audioStreams.count == 1)
    #expect(r.subtitleStreams.count == 2)
    #expect(r.attachedPictureStream?.index == 4)
    #expect(r.attachmentStreams.count == 1)
    #expect(r.dataStreams.count == 1)
    #expect(r.unknownStreams.count == 1)
    #expect(r.chapters?.count == 1)
    #expect(r.programs?.count == 1)
    #expect(r.videoStream?.frameRate != nil)
    #expect(abs((r.videoStream?.frameRate ?? 0) - 23.976) < 0.01)
    #expect(r.videoStream?.rotationDegrees == 90)
    #expect(r.videoStream?.inferredHDRDescription == "HDR (PQ · BT.2020)")
    #expect(r.audioStream?.sampleRateValue == 48_000)
    #expect(r.audioStream?.language == "eng")
    #expect(r.subtitleStreams[0].subtitleRepresentation == .text)
    #expect(r.subtitleStreams[1].subtitleRepresentation == .bitmap)
    #expect(r.subtitleStreams[1].isForced)
    #expect(r.videoStream?.side_data_list?.last?.red_x == "34000/50000")
    #expect(r.durationSeconds == 120.5)
    #expect(r.format?.sizeBytes == 1_000_000)
}

@Test func mediaInspectionToleratesMissingNAAndUnknownFields() throws {
    let json = #"{"streams":[{"index":0,"codec_type":"video","avg_frame_rate":"N/A","r_frame_rate":"0/0","duration":"","nb_frames":"N/A","bits_per_raw_sample":"N/A","unexpected":{"nested":true}},{"index":1,"codec_type":"audio","sample_rate":"N/A","bit_rate":"N/A"}],"format":{"duration":"N/A","size":"N/A","start_time":""}}"#
    let r = try decodeInspection(json)
    #expect(r.videoStream?.frameRate == nil)
    #expect(r.durationSeconds == nil)
    #expect(r.format?.sizeBytes == nil)
    #expect(r.audioStream?.sampleRateValue == nil)
    #expect(r.isPartial == false)
}

@Test func mediaInspectionRecognizesPartialResult() throws {
    let r = try decodeInspection(#"{"streams":[]}"#)
    #expect(r.isPartial)
}

@Test func mediaInspectionRejectsInvalidAndEmptyJSON() {
    #expect(throws: MediaInspectionError.self) { try MediaInspectionParser.decode(Data()) }
    #expect(throws: MediaInspectionError.self) { try MediaInspectionParser.decode(Data("not-json".utf8)) }
}

@Test(arguments: ["24000/1001", "25/1", "60", "N/A", "0/0", ""]) func rationalParserIsRobust(_ raw: String) {
    let value = MediaInspectionStream.rationalValue(raw)
    if raw == "24000/1001" { #expect(abs((value ?? 0) - 23.976) < 0.01) }
    if raw == "25/1" { #expect(value == 25) }
    if raw == "60" { #expect(value == 60) }
    if ["N/A", "0/0", ""].contains(raw) { #expect(value == nil) }
}

private func makeFakeFFprobe() throws -> (executable: URL, directory: URL) {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("zeuve-ffprobe-tests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let source = root.appendingPathComponent("fake_ffprobe.c")
    let executable = root.appendingPathComponent("fake_ffprobe")
    let program = #"""
#include <stdio.h>
#include <string.h>
#include <unistd.h>

int main(int argc, char **argv) {
    const char *input = argc > 1 ? argv[argc - 1] : "";
    if (strstr(input, "slow") != NULL) {
        sleep(30);
        return 0;
    }
    if (strstr(input, "fail") != NULL) {
        fprintf(stderr, "synthetic failure\n");
        return 7;
    }
    char counter[4096];
    snprintf(counter, sizeof(counter), "%s.count", input);
    FILE *count = fopen(counter, "a");
    if (count) { fputs("1\n", count); fclose(count); }
    fputs("{\"streams\":[{\"index\":0,\"codec_type\":\"audio\",\"codec_name\":\"flac\",\"sample_rate\":\"48000\",\"channels\":2}],\"format\":{\"format_name\":\"flac\",\"duration\":\"1.0\"}}", stdout);
    fflush(stdout);
    return 0;
}
"""#
    try program.write(to: source, atomically: true, encoding: .utf8)
    let compiler = Process()
    compiler.executableURL = URL(fileURLWithPath: "/usr/bin/cc")
    compiler.arguments = [source.path, "-O2", "-o", executable.path]
    try compiler.run()
    compiler.waitUntilExit()
    guard compiler.terminationStatus == 0 else {
        throw NSError(domain: "MediaInspectionTests", code: Int(compiler.terminationStatus))
    }
    return (executable, root)
}

@Test func mediaInspectionServiceRunsFFprobeCachesAndInvalidatesOnFingerprintChange() async throws {
    let helper = try makeFakeFFprobe()
    defer { try? FileManager.default.removeItem(at: helper.directory) }
    let input = helper.directory.appendingPathComponent("cache.media")
    try Data("first".utf8).write(to: input)
    let service = MediaInspectionService()

    let first = try await service.inspect(url: input, ffprobe: helper.executable)
    let second = try await service.inspect(url: input, ffprobe: helper.executable)
    #expect(first.audioStream?.sampleRateValue == 48_000)
    #expect(second.audioStream?.codec_name == "flac")
    #expect(await service.cachedEntryCount() == 1)

    let counter = URL(fileURLWithPath: input.path + ".count")
    #expect((try String(contentsOf: counter, encoding: .utf8)).split(separator: "\n").count == 1)

    try Data("changed".utf8).write(to: input)
    _ = try await service.inspect(url: input, ffprobe: helper.executable)
    #expect((try String(contentsOf: counter, encoding: .utf8)).split(separator: "\n").count == 2)
    #expect(await service.cachedEntryCount() == 1)
}

@Test func mediaInspectionServiceDifferentiatesProcessFailure() async throws {
    let helper = try makeFakeFFprobe()
    defer { try? FileManager.default.removeItem(at: helper.directory) }
    let input = helper.directory.appendingPathComponent("fail.media")
    try Data("x".utf8).write(to: input)
    let service = MediaInspectionService()
    do {
        _ = try await service.inspect(url: input, ffprobe: helper.executable)
        Issue.record("FFprobe sintético debía fallar")
    } catch let error as MediaInspectionError {
        #expect(error == .processFailed(exitCode: 7))
    }
}

@Test func mediaInspectionServiceCancellationStopsActiveProcess() async throws {
    let helper = try makeFakeFFprobe()
    defer { try? FileManager.default.removeItem(at: helper.directory) }
    let input = helper.directory.appendingPathComponent("slow.media")
    try Data("x".utf8).write(to: input)
    let service = MediaInspectionService()
    let task = Task { try await service.inspect(url: input, ffprobe: helper.executable, useCache: false) }
    try await Task.sleep(for: .milliseconds(150))
    await service.cancel()
    do {
        _ = try await task.value
        Issue.record("La inspección cancelada no debe completar como éxito")
    } catch {
        #expect(error is CancellationError)
    }
}
