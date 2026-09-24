"""Ejecuta el observador real con Combine; SwiftPM no incluye ZEUVEApp."""

import platform
import subprocess
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
VIEW_MODEL = ROOT / "Sources/ZEUVEApp/MultimediaInspector/MultimediaInspectorViewModel.swift"


@unittest.skipUnless(platform.system() == "Darwin", "Requiere Combine de macOS")
class MultimediaInspectorPlaybackRateTests(unittest.TestCase):
    def test_session_restore_and_rate_changes_terminate_and_update_once(self):
        source = VIEW_MODEL.read_text()
        start = source.index("    @Published var previewPlaybackRate:")
        end = source.index("    @Published var previewVolume:", start)
        # Se compila el código de producción, sin duplicar su normalización.
        observer = source[start:end]
        harness = r'''
import Combine
import Foundation

@MainActor
final class PreviewServiceSpy {
    var rates: [Float] = []
    func setPlaybackRate(_ rate: Float) async { rates.append(rate) }
}

enum MultimediaPreviewPlaybackState {
    case idle, loading, playing, paused, finished, failed
}

@MainActor
final class InspectorHarness: ObservableObject {
    let previewService: PreviewServiceSpy? = PreviewServiceSpy()
    var videoPreviewSourceID: String?
    var previewPosition: TimeInterval = 12
    var previewState: MultimediaPreviewPlaybackState = .playing
    var videoRestarts: [(TimeInterval, Bool)] = []
    func replaceSelectedVideoPreview(at position: TimeInterval, shouldPlay: Bool) {
        videoRestarts.append((position, shouldPlay))
    }
__PRODUCTION_OBSERVER__
}

@main
struct Regression {
    @MainActor
    static func main() async throws {
        let model = InspectorHarness()
        let cases: [(Double, Double)] = [
            (1, 1), (1, 1), (0.5, 0.5), (1.25, 1.25), (2, 2),
            (0, 0.5), (-1, 0.5), (3, 2),
            (.nan, 1), (.infinity, 1), (-.infinity, 1)
        ]
        for hasVideo in [false, true] {
            model.videoPreviewSourceID = hasVideo ? "synthetic-video" : nil
            for (input, expected) in cases {
                let previousAudioCount = model.previewService!.rates.count
                let previousVideoCount = model.videoRestarts.count
                // Restaurar preferencias al abrir/cerrar usa esta misma asignación.
                model.previewPlaybackRate = input
                precondition(model.previewPlaybackRate == expected, "Velocidad inválida")
                try await Task.sleep(for: .milliseconds(20))
                precondition(model.previewService!.rates.count == previousAudioCount + 1,
                             "Cada asignación debe actualizar audio una sola vez")
                precondition(model.previewService!.rates.last == Float(expected))
                precondition(model.videoRestarts.count == previousVideoCount + (hasVideo ? 1 : 0),
                             "Normalizar no debe reiniciar vídeo dos veces")
                if hasVideo {
                    precondition(model.videoRestarts.last?.0 == 12)
                    precondition(model.videoRestarts.last?.1 == true)
                }
            }
        }
        print("PASS: 22 asignaciones; restauración, límites, valores no finitos y sincronización A/V")
    }
}
'''.replace("__PRODUCTION_OBSERVER__", observer)
        with tempfile.TemporaryDirectory(prefix="zeuve-playback-rate-") as directory:
            folder = Path(directory)
            swift = folder / "Regression.swift"
            executable = folder / "regression"
            swift.write_text(harness)
            compiled = subprocess.run(
                ["swiftc", "-swift-version", "6", "-parse-as-library",
                 "-module-cache-path", str(folder / "module-cache"),
                 str(swift), "-o", str(executable)],
                capture_output=True, text=True, timeout=120,
            )
            self.assertEqual(compiled.returncode, 0, compiled.stderr)
            result = subprocess.run(
                [str(executable)], capture_output=True, text=True, timeout=10,
            )
            self.assertEqual(result.returncode, 0, result.stderr[-4000:])
            self.assertIn("PASS: 22 asignaciones", result.stdout)


if __name__ == "__main__":
    unittest.main()
