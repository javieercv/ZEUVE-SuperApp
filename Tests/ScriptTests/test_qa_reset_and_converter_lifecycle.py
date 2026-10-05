"""Regresiones ejecutables de métodos reales de ZEUVEApp, fuera de SwiftPM."""
import platform
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def production_method(path, signature):
    source = (ROOT / path).read_text()
    start = source.index(signature)
    opening = source.index('{', start)
    depth = 1
    end = opening + 1
    while depth:
        depth += (source[end] == '{') - (source[end] == '}')
        end += 1
    return source[start:end]


@unittest.skipUnless(platform.system() == 'Darwin', 'Requiere Swift de macOS')
class ApprovedQARegressionTests(unittest.TestCase):
    def compile_and_run(self, harness):
        with tempfile.TemporaryDirectory(prefix='zeuve-qa-lifecycle-') as directory:
            folder = Path(directory)
            source, executable = folder / 'Regression.swift', folder / 'regression'
            source.write_text(harness)
            compiled = subprocess.run(['swiftc', '-swift-version', '6', '-parse-as-library', '-module-cache-path', str(folder / 'cache'), str(source), '-o', str(executable)], capture_output=True, text=True, timeout=120)
            self.assertEqual(compiled.returncode, 0, compiled.stderr)
            result = subprocess.run([str(executable)], capture_output=True, text=True, timeout=15)
            self.assertEqual(result.returncode, 0, result.stderr[-4000:])
            self.assertIn('PASS', result.stdout)

    def test_converter_cancellation_releases_controls_and_allows_another_operation(self):
        path = 'Sources/ZEUVEApp/UniversalConverter/UniversalConverterViewModel.swift'
        methods = '\n'.join(production_method(path, signature) for signature in ['    func executePlan()', '    func cancel()'])
        harness = r'''
import Foundation
struct Plan: Sendable {}
struct Result: Sendable { let cancelled: Bool }
enum State { case idle, preview, running, result }
actor ExecutionSpy {
    var busy = false
    var returnsSummary = false
    func mode(summary: Bool) { returnsSummary = summary }
    func execute(_ plan: Plan, archivePassword: String?, progress: @escaping @Sendable (String) -> Void, onWarning: @escaping @Sendable (String) -> Void) async throws -> Result {
        precondition(!busy, "La operación anterior debe liberar su reserva")
        busy = true
        defer { busy = false }
        do { try await Task.sleep(for: .milliseconds(100)) }
        catch { if returnsSummary { return Result(cancelled: true) }; throw error }
        return Result(cancelled: false)
    }
    func cancel() async {}
}
@MainActor final class Harness {
    var plan: Plan? = Plan()
    var state: State = .preview
    var inputs = [1]
    var result: Result?
    var progress: String?
    var errorMessage: String?
    var warningMessage: String?
    var archivePassword = "synthetic-secret"
    var isArchivePasswordVisible = true
    var executionTask: Task<Void, Never>?
    let execution = ExecutionSpy()
    var canExecute: Bool { plan != nil && state == .preview }
__METHODS__
}
@main struct Regression {
    @MainActor static func main() async throws {
        for summary in [false, true] {
            let model = Harness()
            await model.execution.mode(summary: summary)
            model.executePlan()
            precondition(model.state == .running && !model.canExecute)
            try await Task.sleep(for: .milliseconds(20))
            model.cancel()
            let pending = model.executionTask
            await pending?.value
            precondition(model.state != .running && model.executionTask == nil)
            precondition(model.archivePassword.isEmpty && !model.isArchivePasswordVisible)
            precondition(!(await model.execution.busy))
            if summary { precondition(model.result?.cancelled == true) }
            model.state = .preview
            await model.execution.mode(summary: false)
            model.executePlan()
            await model.executionTask?.value
            precondition(model.state == .result && model.result?.cancelled == false)
        }
        print("PASS: cancelación con excepción/resumen y nueva operación")
    }
}
'''.replace('__METHODS__', methods).replace('            precondition(!(await model.execution.busy))', '            let busy = await model.execution.busy\n            precondition(!busy)')
        self.compile_and_run(harness)

    def test_applied_converter_recipe_survives_swiftui_callbacks_until_real_edit(self):
        path = 'Sources/ZEUVEApp/UniversalConverter/UniversalConverterViewModel.swift'
        methods = '\n'.join(production_method(path, signature) for signature in [
            '    func operationChanged()', '    func optionsChanged(', '    func qualityChanged()',
            '    func applyPreset(', '    func applyFavorite('
        ])
        self.compile_and_run(r"""
import Foundation
enum Quality { case balanced, custom }
struct Options: Equatable {
    var operation = "audio", targetFormat = "flac", quality = Quality.balanced
    var audioVideoImageURL: URL?
    mutating func normalize() {}
}
struct Recipe { let id: UUID; let options: Options; var presetID: UUID?; var outputFolder: URL? }
enum ConverterOutputBookmarkStore { static func validate(_ folder: URL) throws {} }
@MainActor final class Harness {
    var options = Options(), appliedRecipeOptions: Options?
    var selectedFavoriteID: UUID?, selectedPresetID: UUID?
    var presets: [Recipe] = [], favorites: [Recipe] = []
    var defaultSettings = (rememberOutputFolder: false, other: false)
    var allowed = true
    func synchronizeOperation() { if !allowed { options.targetFormat = "wav" } }
    func schedulePlan(delayNanoseconds: UInt64 = 1) {}
    func setOutputFolder(_ url: URL, persistBookmark: Bool) {}
__METHODS__
}
@main struct Regression {
    @MainActor static func main() {
        let model = Harness(), preset = UUID(), favorite = UUID()
        model.presets = [.init(id: preset, options: Options())]
        model.favorites = [.init(id: favorite, options: Options(), presetID: preset)]
        model.applyFavorite(favorite)
        model.operationChanged(); model.optionsChanged(); model.qualityChanged()
        precondition(model.selectedFavoriteID == favorite && model.selectedPresetID == preset)
        precondition(model.options.quality == .balanced)
        model.options.targetFormat = "aac"; model.optionsChanged()
        precondition(model.selectedFavoriteID == nil && model.selectedPresetID == nil && model.options.quality == .custom)
        model.applyFavorite(favorite); model.applyPreset(preset)
        model.operationChanged(); model.optionsChanged(); model.qualityChanged()
        precondition(model.selectedFavoriteID == nil && model.selectedPresetID == preset)
        model.allowed = false; model.applyFavorite(favorite)
        model.optionsChanged()
        precondition(model.selectedFavoriteID == nil && model.selectedPresetID == nil && model.options.targetFormat == "wav")
        print("PASS: favorito y preset estables; edición real y destino incompatible invalidan selección")
    }
}
""".replace('__METHODS__', methods))

    def test_global_reset_preserves_custom_presets_rules_and_favorites(self):
        method = production_method('Sources/ZEUVEApp/MultimediaInspector/MultimediaInspectorViewModel.swift', '    func restorePersistentDefaultsForGlobalReset()')
        self.compile_and_run(r'''
import Foundation
struct Preferences { static let defaults = Preferences() }
struct Store { func restoreDefaults() throws -> Preferences { .defaults } }
final class BatchSpy {
    var presets = ["custom preset"]
    var rules = ["custom rules"]
    var favorites = ["custom favorite"]
    func updatePreferences(_ prefs: Preferences) {}
    func restoreDefaultPresets() { presets = ["default"] }
}
final class Harness {
    let settingsStore = Store()
    var defaultPreferences = Preferences.defaults
    let batch = BatchSpy()
__METHOD__
}
@main struct Regression {
    static func main() {
        let model = Harness()
        precondition(model.restorePersistentDefaultsForGlobalReset().isEmpty)
        precondition(model.batch.presets == ["custom preset"])
        precondition(model.batch.rules == ["custom rules"])
        precondition(model.batch.favorites == ["custom favorite"])
        print("PASS: reset conserva datos reutilizables")
    }
}
'''.replace('__METHOD__', method))
