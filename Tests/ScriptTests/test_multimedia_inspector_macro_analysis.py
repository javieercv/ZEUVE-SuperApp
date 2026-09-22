import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
VIEW_MODEL = ROOT / "Sources/ZEUVEApp/MultimediaInspector/MultimediaInspectorViewModel.swift"
LOUDNESS_SERVICE = ROOT / "Sources/MultimediaInspectorModule/Analysis/AudioLoudnessAnalysisService.swift"
LOUDNESS_TIMELINE = ROOT / "Sources/MultimediaInspectorModule/Analysis/AudioLoudnessTimeline.swift"
REPORT = ROOT / "Sources/MultimediaInspectorModule/Reporting/MultimediaTechnicalReportExporter.swift"
TRACKS_VIEW = ROOT / "Sources/ZEUVEApp/MultimediaInspector/Views/MultimediaTracksView.swift"
TIMELINE_VIEW = ROOT / "Sources/ZEUVEApp/MultimediaInspector/Spectrogram/MultimediaLoudnessTimelineView.swift"


class MultimediaInspectorMacroAnalysisTests(unittest.TestCase):
    def test_loudness_timeline_reuses_existing_ebur128_pass(self):
        service = LOUDNESS_SERVICE.read_text()
        timeline = LOUDNESS_TIMELINE.read_text()
        self.assertIn("timelineAccumulator", service)
        self.assertIn("timelineAccumulator.append", service)
        self.assertEqual(service.count("ebur128=peak=true"), 1)
        self.assertIn("AudioLoudnessTimelineAccumulator", timeline)
        self.assertIn("maximumSamples", timeline)
        self.assertNotIn("ExternalProcessRunner", timeline)

    def test_ab_switch_does_not_change_spectrogram_selection(self):
        source = VIEW_MODEL.read_text()
        start = source.index("func selectComparisonSlot")
        end = source.index("func previewSourceID(for track:", start)
        body = source[start:end]
        self.assertIn("synchronizeSpectrogramSelection: false", body)
        self.assertNotIn("synchronizeSelectedAudioStreamIndex", body)
        self.assertIn("runSignalAnalysis(source: source)", body)
        self.assertIn("runLoudnessAnalysis(source: source)", body)
        self.assertNotIn("async let", body)

    def test_waveform_and_spectrogram_use_distinct_analysis_sources(self):
        source = VIEW_MODEL.read_text()
        self.assertIn("var selectedSpectrogramSourceID: String?", source)
        self.assertIn("var selectedSpectrogramSignalAnalysis: AudioSignalAnalysisResult?", source)
        self.assertIn("var currentWaveformSignalAnalysis: AudioSignalAnalysisResult?", source)
        spectrogram = (ROOT / "Sources/ZEUVEApp/MultimediaInspector/Spectrogram/SpectrogramView.swift").read_text()
        waveform = (ROOT / "Sources/ZEUVEApp/MultimediaInspector/Views/MultimediaWaveformView.swift").read_text()
        self.assertIn("model.selectedSpectrogramSignalAnalysis", spectrogram)
        self.assertIn("model.currentWaveformSignalAnalysis", waveform)

    def test_ab_ui_is_in_tracks_and_analysis_is_explicit(self):
        source = TRACKS_VIEW.read_text()
        self.assertIn('Text("COMPARAR A/B")', source)
        self.assertIn('"Completar análisis A/B"', source)
        self.assertIn("model.selectComparisonSlot", source)
        self.assertIn("model.toggleComparisonPreview", source)
        self.assertIn("multimediaABComparison", source)

    def test_loudness_timeline_uses_shared_seek_and_selected_spectrogram_result(self):
        source = TIMELINE_VIEW.read_text()
        self.assertIn("model.selectedSpectrogramLoudness?.timeline", source)
        self.assertIn("result.startTime", source)
        self.assertIn("result.endTime", source)
        self.assertIn("model.seekPreview", source)
        self.assertIn("multimediaLoudnessTimeline", source)
        self.assertNotIn("AudioLoudnessAnalysisService", source)

    def test_report_schema_three_adds_signal_timeline_and_new_private_safe_summaries(self):
        source = REPORT.read_text()
        self.assertIn("schemaVersion = 3", source)
        self.assertIn("AudioSignalReportItem", source)
        self.assertIn("let timeline: LoudnessTimeline?", source)
        self.assertIn("let signal: [Signal]", source)
        report_model = source[source.index("private struct ReportPayload") :]
        self.assertNotIn("sourceID", report_model)
        self.assertNotIn("fingerprint", report_model)
        self.assertNotIn("originalURL.path", report_model)


if __name__ == "__main__":
    unittest.main()
