import Foundation
import Testing
import ZEUVECore
import ZEUVEEngines
@testable import MultimediaInspectorModule

@Test func manifestIsOfficialLocalModule() throws {
    let manifest = try MultimediaInspectorModuleDefinition.manifest()
    #expect(manifest.identifier == multimediaInspectorModuleIdentifier)
    #expect(manifest.version == "0.7.3")
    #expect(!manifest.permissions.contains(.networkAccess))
    #expect(manifest.capabilities.contains(.undo))
}

@Test func draftStartsCleanAndUndoRedoBranchesCorrectly() throws {
    let dir=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString); try Data([1]).write(to:dir)
    defer { try? FileManager.default.removeItem(at:dir) }
    let stream=try JSONDecoder().decode(MediaInspectionStream.self,from:Data(#"{"index":1,"codec_name":"aac","codec_type":"audio","disposition":{"default":1},"tags":{"language":"spa"}}"#.utf8))
    let result=MediaInspectionResult(streams:[stream],format:nil)
    var history=MediaEditDraftHistory(try MediaEditDraft(originalURL:dir,originalFingerprint:FileFingerprint.read(from:dir),inspection:result,container:.mkv))
    #expect(!history.isDirty); history.perform { $0.audioTracks[0].title="Principal" }; #expect(history.isDirty); #expect(history.canUndo)
    let didUndo1 = history.undo(); #expect(didUndo1); #expect(!history.isDirty); let didRedo1 = history.redo(); #expect(didRedo1); #expect(history.current.audioTracks[0].title == "Principal")
    let didUndo2 = history.undo(); #expect(didUndo2); history.perform { $0.audioTracks[0].language="eng" }; #expect(!history.canRedo)
}

@Test func defaultChangeCanBeOneLogicalUndoUnit() throws {
    let u=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString); try Data([1]).write(to:u); defer {try? FileManager.default.removeItem(at:u)}
    let json=#"{"streams":[{"index":1,"codec_name":"aac","codec_type":"audio","disposition":{"default":1}},{"index":2,"codec_name":"aac","codec_type":"audio","disposition":{"default":0}}]}"#
    let inspection=try MediaInspectionParser.decode(Data(json.utf8)); var h=MediaEditDraftHistory(try .init(originalURL:u,originalFingerprint:.read(from:u),inspection:inspection,container:.mkv))
    h.perform { draft in for i in draft.audioTracks.indices { draft.audioTracks[i].isDefault = i == 1 } }
    #expect(h.current.audioTracks[0].isDefault == false); #expect(h.current.audioTracks[1].isDefault == true); let didUndo = h.undo(); #expect(didUndo); #expect(h.current.audioTracks[0].isDefault == true)
}

@Test func compatibilityEnforcesHybridPolicy() {
    let registry=MediaContainerCompatibilityRegistry()
    #expect(registry.decision(kind:.audio,codec:"dts",container:.mp4) == .incompatible)
    #expect(registry.decision(kind:.subtitle,codec:"subrip",container:.mp4) == .convertSubtitle(to:"mov_text"))
    #expect(registry.decision(kind:.subtitle,codec:"hdmv_pgs_subtitle",container:.mp4) == .incompatible)
    #expect(registry.supportsVideo(codec:"hevc",container:.mp4))
    #expect(!registry.supportsVideo(codec:"hevc",container:.webm))
}

@Test(arguments:[256,512,1024]) func fftFindsOneKilohertz(_ size:Int) throws {
    let sr=8192.0, hz=1024.0; let samples=(0..<size).map { Float(sin(2*Double.pi*hz*Double($0)/sr)) }
    let db=try SpectrogramFFTProcessor().analyze(samples:samples,sampleRate:sr,window:.hann,dynamicRange:.init(minimumDB:-140,maximumDB:0))
    let peak=db.enumerated().max(by:{$0.element<$1.element})!.offset; let frequency=Double(peak)*sr/Double(size)
    #expect(abs(frequency-hz) <= sr/Double(size))
}

@Test func fftSilenceStaysAtFloor() throws {
    let range=SpectrogramDynamicRange(minimumDB:-100,maximumDB:0); let db=try SpectrogramFFTProcessor().analyze(samples:[Float](repeating:0,count:512),sampleRate:48000,window:.hann,dynamicRange:range)
    #expect(db.allSatisfy { abs($0 - range.minimumDB) < 0.001 })
}

@Test func nyquistComesFromSampleRate() {
    let r=SpectrogramResult(sampleRate:44100,fftSize:4096,startTime:0,endTime:1,dynamicRange:.init(),columns:[])
    #expect(r.nyquist == 22050)
}

@Test func automaticAudioAnalysisRunsOnlyForExactlyOneAudioStream() {
    #expect(!MultimediaAutomaticAudioAnalysisPolicy.shouldRun(audioStreamCount: 0))
    #expect(MultimediaAutomaticAudioAnalysisPolicy.shouldRun(audioStreamCount: 1))
    #expect(!MultimediaAutomaticAudioAnalysisPolicy.shouldRun(audioStreamCount: 2))
    #expect(!MultimediaAutomaticAudioAnalysisPolicy.shouldRun(audioStreamCount: 6))
}
