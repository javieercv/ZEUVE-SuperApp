from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]


class MultimediaInspectorHelpTests(unittest.TestCase):
    def read(self, relative: str) -> str:
        return (ROOT / relative).read_text()

    def test_help_topics_cover_settings_and_analysis(self):
        help_source = self.read("Sources/ZEUVEApp/MultimediaInspector/MultimediaInspectorHelp.swift")
        required = [
            "multimediaInspectorOverview",
            "multimediaSummaryTab",
            "multimediaTracksTab",
            "multimediaSpectrogramTab",
            "multimediaMetadataTab",
            "multimediaBatchMode",
            "multimediaAutomaticSpectrogram",
            "multimediaAutomaticSignal",
            "multimediaAutomaticLoudness",
            "multimediaPreviewVolume",
            "multimediaTrackSwitchPosition",
            "multimediaTimelineZoom",
            "multimediaTimelinePan",
            "multimediaWaveformStyle",
            "multimediaWaveformRepresentation",
            "multimediaSignalAnalysis",
            "multimediaSilenceThreshold",
            "multimediaSilenceDuration",
            "multimediaClippingThreshold",
            "multimediaClippingSamples",
            "multimediaSpectrogramTrack",
            "multimediaSpectrogramChannel",
            "multimediaFFTSize",
            "multimediaWindow",
            "multimediaDynamicRange",
            "multimediaFrequencyScale",
            "multimediaNyquist",
            "multimediaLoudness",
            "multimediaIntegratedLUFS",
            "multimediaLRA",
            "multimediaTruePeak",
            "multimediaSamplePeak",
            "multimediaShortTermStats",
            "multimediaAudioTiming",
            "multimediaChapters",
            "multimediaAttachments",
            "multimediaAttachmentMIME",
            "multimediaMetadata",
            "multimediaPartialInspection",
            "multimediaReportFormat",
            "multimediaReportSections",
            "multimediaPreferredContainer",
            "multimediaBatchPreset",
            "multimediaBatchOperations",
            "multimediaBatchOutputFolder",
            "multimediaBatchStatuses",
        ]
        for token in required:
            self.assertIn(token, help_source)

    def test_settings_use_shared_contextual_help_components(self):
        settings = self.read("Sources/ZEUVEApp/MultimediaInspector/MultimediaInspectorSettingsView.swift")
        for token in [
            "HelpPickerRow",
            "HelpToggleRow",
            "HelpLabel",
            "ContextualHelpButton",
            "multimediaAutomaticSpectrogram",
            "multimediaAutomaticSignal",
            "multimediaAutomaticLoudness",
            "multimediaPreviewVolume",
            "multimediaTrackSwitchPosition",
            "multimediaTrackSwitchPlayback",
            "multimediaTimelineZoom",
            "multimediaTimelinePan",
            "multimediaWaveformStyle",
            "multimediaWaveformRepresentation",
            "multimediaSilenceThreshold",
            "multimediaClippingThreshold",
            "multimediaFFTSize",
            "multimediaWindow",
            "multimediaFrequencyScale",
            "multimediaSpectrogramChannel",
            "multimediaSpectrogramColumns",
            "multimediaSpectrogramExportSize",
            "multimediaReportFormat",
            "multimediaReportSections",
            "multimediaPreferredContainer",
            "multimediaBatchPreset",
            "multimediaBatchOperations",
        ]:
            self.assertIn(token, settings)

    def test_each_primary_inspector_surface_has_general_help(self):
        surfaces = {
            "Sources/ZEUVEApp/MultimediaInspector/MultimediaInspectorView.swift": "multimediaInspectorOverview",
            "Sources/ZEUVEApp/MultimediaInspector/Views/MultimediaSummaryView.swift": "multimediaSummaryTab",
            "Sources/ZEUVEApp/MultimediaInspector/Views/MultimediaTracksView.swift": "multimediaTracksTab",
            "Sources/ZEUVEApp/MultimediaInspector/Spectrogram/SpectrogramView.swift": "multimediaSpectrogramTab",
            "Sources/ZEUVEApp/MultimediaInspector/Views/MultimediaMetadataView.swift": "multimediaMetadataTab",
            "Sources/ZEUVEApp/MultimediaInspector/Batch/MultimediaBatchView.swift": "multimediaBatchMode",
        }
        for path, token in surfaces.items():
            self.assertIn(token, self.read(path), path)

    def test_ambiguous_metrics_and_structural_data_have_help(self):
        summary = self.read("Sources/ZEUVEApp/MultimediaInspector/Views/MultimediaSummaryView.swift")
        for token in [
            "multimediaIntegratedLUFS",
            "multimediaLRA",
            "multimediaTruePeak",
            "multimediaSamplePeak",
            "multimediaShortTermStats",
            "multimediaAudioTiming",
            "multimediaPartialInspection",
        ]:
            self.assertIn(token, summary)

        tracks = self.read("Sources/ZEUVEApp/MultimediaInspector/Views/MultimediaTracksView.swift")
        for token in [
            "multimediaABComparison",
            "multimediaSignalAnalysis",
            "multimediaLoudness",
            "multimediaIntegratedLUFS",
            "multimediaLRA",
            "multimediaTruePeak",
            "multimediaSamplePeak",
            "multimediaAudioTiming",
        ]:
            self.assertIn(token, tracks)

        structure = self.read("Sources/ZEUVEApp/MultimediaInspector/Views/MultimediaTechnicalStructureView.swift")
        for token in ["multimediaChapters", "multimediaAttachments", "multimediaAttachmentMIME", "multimediaAudioTiming"]:
            self.assertIn(token, structure)

        spectrogram = self.read("Sources/ZEUVEApp/MultimediaInspector/Spectrogram/SpectrogramView.swift")
        for token in ["multimediaSpectrogramTrack", "multimediaSpectrogramChannel", "multimediaFFTSize", "multimediaNyquist"]:
            self.assertIn(token, spectrogram)

    def test_inspector_does_not_create_parallel_information_ui(self):
        for path in (ROOT / "Sources/ZEUVEApp/MultimediaInspector").rglob("*.swift"):
            source = path.read_text()
            self.assertNotIn('Image(systemName: "info.circle")', source, str(path))
            self.assertNotIn('Image(systemName: "info.circle.fill")', source, str(path))
        help_source = self.read("Sources/ZEUVEApp/MultimediaInspector/MultimediaInspectorHelp.swift")
        for forbidden in ["generateSpectrogram", "analyzeSignal", "analyzeLoudness", "resetAnalysis", "persistPreferences"]:
            self.assertNotIn(forbidden, help_source)


if __name__ == "__main__":
    unittest.main()
