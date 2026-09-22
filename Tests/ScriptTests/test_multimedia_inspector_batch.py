from pathlib import Path
import json
import unittest

ROOT = Path(__file__).resolve().parents[2]


class MultimediaInspectorBatchTests(unittest.TestCase):
    def read(self, relative):
        return (ROOT / relative).read_text()

    def test_batch_is_sequential_and_does_not_choose_multitrack_audio(self):
        source = self.read("Sources/MultimediaInspectorModule/Batch/MultimediaBatchProcessor.swift")
        self.assertIn("inspection.audioStreams.count == 1", source)
        self.assertIn("inspection.audioStreams.count > 1", source)
        self.assertIn("ZEUVE no selecciona una silenciosamente", source)
        self.assertIn("runWhenCoordinatorIsFree", source)
        self.assertNotIn("async let", source)
        self.assertNotIn("withTaskGroup", source)
        self.assertNotIn("TaskGroup", source)

    def test_batch_does_not_generate_interactive_waveform_or_preview(self):
        source = self.read("Sources/MultimediaInspectorModule/Batch/MultimediaBatchProcessor.swift")
        self.assertNotIn("WaveformAnalysisService", source)
        self.assertNotIn("MultimediaAudioPreviewService", source)
        self.assertNotIn("AudioTrackComparison", source)

    def test_batch_presets_are_versioned_and_centralized(self):
        store = self.read("Sources/MultimediaInspectorModule/Presets/MultimediaInspectorBatchPresetStore.swift")
        settings = self.read("Sources/ZEUVEApp/MultimediaInspector/MultimediaInspectorSettingsView.swift")
        keys = self.read("Sources/MultimediaInspectorModule/Storage/MultimediaInspectorSettingsStore.swift")
        self.assertIn("multimediaInspector.batchPresets.v1", keys)
        for token in ["quickInspectionPresetID", "technicalReportPresetID", "completeAudioAnalysisPresetID", "spectrogramsPresetID"]:
            self.assertIn(token, store)
        self.assertIn('HelpLabel("Lotes y presets"', settings)
        self.assertIn("defaultBatchPresetID", settings)
        self.assertIn("restoreDefaultPresets", settings)

    def test_inspector_preferences_expose_personalizable_behaviors(self):
        preferences = self.read("Sources/MultimediaInspectorModule/Models/MultimediaInspectorPreferences.swift")
        settings = self.read("Sources/ZEUVEApp/MultimediaInspector/MultimediaInspectorSettingsView.swift")
        required = [
            "automaticSpectrogramForSingleTrack",
            "automaticSignalAnalysisForSingleTrack",
            "automaticLoudnessForSingleTrack",
            "previewTrackSwitchKeepsPosition",
            "previewTrackSwitchKeepsPlaybackState",
            "timelineZoomFactor",
            "timelinePanFraction",
            "showChapterMarkersOnWaveform",
            "showSignalOverlaysOnWaveform",
            "showSignalOverlaysOnSpectrogram",
            "showLoudnessTimeline",
            "spectrogramExportWidth",
            "spectrogramExportHeight",
            "defaultReportFormat",
            "reportSections",
            "defaultBatchPresetID",
        ]
        for token in required:
            self.assertIn(token, preferences)
            self.assertIn(token, settings)

    def test_manifest_declares_only_local_batch_requirements(self):
        manifest = json.loads((ROOT / "Sources/MultimediaInspectorModule/Resources/manifest.json").read_text())
        self.assertEqual(manifest["version"], "0.7.0")
        self.assertIn("presets", manifest["capabilities"])
        self.assertIn("openExternalApplications", manifest["permissions"])
        self.assertNotIn("networkAccess", manifest["permissions"])

    def test_retry_keeps_current_batch_configuration(self):
        vm = self.read("Sources/ZEUVEApp/MultimediaInspector/Batch/MultimediaBatchViewModel.swift")
        body = vm.split("func retryFailures()", 1)[1].split("func openResultsFolder()", 1)[0]
        self.assertIn("resetConfiguration: false", body)

    def test_large_queue_uses_lazy_rendering(self):
        view = self.read("Sources/ZEUVEApp/MultimediaInspector/Batch/MultimediaBatchView.swift")
        self.assertIn("LazyVStack", view)


if __name__ == "__main__":
    unittest.main()
