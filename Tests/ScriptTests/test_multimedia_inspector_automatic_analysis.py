import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
VIEW_MODEL = ROOT / "Sources/ZEUVEApp/MultimediaInspector/MultimediaInspectorViewModel.swift"
POLICY = ROOT / "Sources/MultimediaInspectorModule/Analysis/MultimediaAutomaticAudioAnalysisPolicy.swift"


class MultimediaInspectorAutomaticAnalysisTests(unittest.TestCase):
    def test_policy_requires_exactly_one_audio_stream(self):
        source = POLICY.read_text()
        self.assertIn("audioStreamCount == 1", source)
        self.assertNotIn("audioStreamCount > 0", source)
        self.assertNotIn("audioStreamCount <= 1", source)

    def test_ffprobe_result_drives_automatic_analysis(self):
        source = VIEW_MODEL.read_text()
        decision = "MultimediaAutomaticAudioAnalysisPolicy.shouldRun(audioStreamCount: result.audioStreams.count)"
        self.assertIn(decision, source)
        self.assertIn("self.startAutomaticSingleTrackAudioAnalysis()", source)
        self.assertNotIn("pathExtension", source[source.find("func open(_ url: URL)"):source.find("private func resetCurrentInspectionSession")])

    def test_automatic_chain_is_sequential_and_cancellable(self):
        source = VIEW_MODEL.read_text()
        start = source.index("private func startAutomaticSingleTrackAudioAnalysis()")
        end = source.index("func analyzeLoudness(_ track:", start)
        body = source[start:end]
        self.assertLess(body.index("generateSpectrogram()"), body.index("self.analyzeSignal(track)"))
        self.assertLess(body.index("self.analyzeSignal(track)"), body.index("self.analyzeLoudness(track)"))
        self.assertIn("while self.isGeneratingSpectrogram", body)
        self.assertIn("_ = await currentSpectrogramTask?.result", body)
        self.assertIn("_ = await self.signalAnalysisTask?.result", body)
        self.assertIn("try Task.checkCancellation()", body)
        self.assertIn("automaticAudioAnalysisSessionID == sessionID", body)
        self.assertNotIn("async let", body)

    def test_session_reset_and_global_cancel_stop_automatic_chain(self):
        source = VIEW_MODEL.read_text()
        reset_start = source.index("private func resetCurrentInspectionSession()")
        reset_end = source.index("private func applyPreferencesToNewSession()", reset_start)
        reset = source[reset_start:reset_end]
        self.assertIn("automaticAudioAnalysisTask?.cancel()", reset)
        self.assertIn("signalAnalysisTask?.cancel()", reset)
        self.assertIn("signalAnalysisService?.cancel()", reset)
        self.assertIn("automaticAudioAnalysisSessionID = UUID()", reset)

        cancel_start = source.index("func cancelCurrentOperation()")
        cancel_end = source.index("func cancelAndWait()", cancel_start)
        cancel = source[cancel_start:cancel_end]
        self.assertIn("automaticAudioAnalysisTask?.cancel()", cancel)
        self.assertIn("signalAnalysisTask?.cancel()", cancel)

        wait_start = source.index("func cancelAndWait()")
        wait = source[wait_start:]
        self.assertIn("_ = await automaticAudioAnalysisTask?.result", wait)


if __name__ == "__main__":
    unittest.main()
