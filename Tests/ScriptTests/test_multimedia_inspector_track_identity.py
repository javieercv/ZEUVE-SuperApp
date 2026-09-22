import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
VIEW_MODEL = ROOT / "Sources/ZEUVEApp/MultimediaInspector/MultimediaInspectorViewModel.swift"


class MultimediaInspectorTrackIdentityTests(unittest.TestCase):
    def setUp(self):
        self.source = VIEW_MODEL.read_text()

    def test_read_only_tracks_use_session_snapshots(self):
        self.assertIn(
            "var audioTracks: [MediaEditableTrack] { currentDraft?.audioTracks ?? inspectionAudioTracks }",
            self.source,
        )
        self.assertIn(
            "var subtitleTracks: [MediaEditableTrack] { currentDraft?.subtitleTracks ?? inspectionSubtitleTracks }",
            self.source,
        )
        self.assertNotIn(
            "inspection?.audioStreams.compactMap { .from(stream: $0, kind: .audio) }",
            self.source,
        )
        self.assertNotIn(
            "inspection?.subtitleStreams.compactMap { .from(stream: $0, kind: .subtitle) }",
            self.source,
        )

    def test_snapshots_are_rebuilt_only_for_new_inspection_results(self):
        self.assertIn("private func cacheInspectionTracks(_ inspection: MediaInspectionResult)", self.source)
        self.assertIn("self.cacheInspectionTracks(result)", self.source)
        self.assertIn("self.cacheInspectionTracks(result.inspection)", self.source)
        self.assertGreaterEqual(self.source.count("inspectionAudioTracks = []"), 2)
        self.assertGreaterEqual(self.source.count("inspectionSubtitleTracks = []"), 2)


if __name__ == "__main__":
    unittest.main()
