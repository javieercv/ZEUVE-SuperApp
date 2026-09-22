#!/usr/bin/env python3
from __future__ import annotations

import json
import os
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
os.chdir(ROOT)

package = Path("Package.swift").read_text()
catalog = Path("Sources/ZEUVEApp/BuiltInModules/BuiltInModuleCatalog.swift").read_text()
router = Path("Sources/ZEUVEApp/BuiltInModules/BuiltInModuleViewRouter.swift").read_text()
settings_router = Path("Sources/ZEUVEApp/BuiltInModules/BuiltInModuleSettingsRouter.swift").read_text()
app_model = Path("Sources/ZEUVEApp/AppModel.swift").read_text()
app = Path("Sources/ZEUVEApp/ZEUVEApp.swift").read_text()
manifest_path = Path("Sources/MultimediaInspectorModule/Resources/manifest.json")
manifest = json.loads(manifest_path.read_text())

required_package = [
    '.library(name: "MultimediaInspectorModule"',
    'name: "MultimediaInspectorModule"',
    'path: "Sources/MultimediaInspectorModule"',
    'name: "MultimediaInspectorModuleTests"',
]
for snippet in required_package:
    if snippet not in package:
        raise SystemExit("Package.swift no integra completamente Inspector multimedia: " + snippet)

for key, expected in {
    "identifier": "com.zeuve.multimedia-inspector",
    "name": "Inspector multimedia",
    "version": "0.7.0",
    "minimumZEUVEVersion": "0.13.0",
    "executionMode": "builtIn",
}.items():
    if manifest.get(key) != expected:
        raise SystemExit(f"Manifest Inspector multimedia: {key} debe ser {expected!r}")
if "networkAccess" in manifest.get("permissions", []):
    raise SystemExit("Inspector multimedia no puede solicitar red.")
for permission in ["readUserSelectedFiles", "writeUserSelectedFolder", "executeBundledTools", "openExternalApplications"]:
    if permission not in manifest.get("permissions", []):
        raise SystemExit("Falta permiso declarado del Inspector: " + permission)
for capability in ["presets", "favorites"]:
    if capability not in manifest.get("capabilities", []):
        raise SystemExit("Inspector multimedia debe declarar capacidad: " + capability)
if manifest.get("presentation", {}).get("systemImage") != "waveform.path.ecg":
    raise SystemExit("El icono del Inspector debe ser waveform.path.ecg.")

for snippet in [
    "case multimediaInspector",
    "id: .multimediaInspector",
    "primaryIdentifier: multimediaInspectorModuleIdentifier",
    'registrationName: "Inspector multimedia"',
    "navigationOrder: 60",
    "settingsOrder: 50",
    'defaultShortcut: .command("6")',
]:
    target = catalog + "\n" + Path("Sources/MultimediaInspectorModule/MultimediaInspectorModuleDefinition.swift").read_text()
    if snippet not in target:
        raise SystemExit("Falta integración built-in del Inspector: " + snippet)
if "case .multimediaInspector:" not in router or "MultimediaInspectorView()" not in router:
    raise SystemExit("BuiltInModuleViewRouter no resuelve Inspector multimedia.")
if "case .multimediaInspector:" not in settings_router or "MultimediaInspectorSettingsView" not in settings_router:
    raise SystemExit("BuiltInModuleSettingsRouter debe resolver los Ajustes centralizados del Inspector.")
for snippet in [
    "let multimediaInspector: MultimediaInspectorViewModel",
    "multimediaInspector = MultimediaInspectorViewModel(",
    "&& !multimediaInspector.isBusy",
    "await multimediaInspector.cancelAndWait()",
]:
    if snippet not in app_model:
        raise SystemExit("AppModel no integra completamente Inspector multimedia: " + snippet)
if 'model.historyShortcut' not in app or 'Button("Ver historial") { model.selection = .history }' not in app:
    raise SystemExit("Historial debe usar el atajo dinámico centralizado.")

required_files = [
    "Sources/ZEUVEEngines/MediaInspection/MediaInspectionService.swift",
    "Sources/ZEUVEEngines/MediaInspection/MediaInspectionModels.swift",
    "Sources/ZEUVEEngines/MediaInspection/MediaInspectionError.swift",
    "Sources/MultimediaInspectorModule/Models/MultimediaInspectorPreferences.swift",
    "Sources/MultimediaInspectorModule/Batch/MultimediaBatchModels.swift",
    "Sources/MultimediaInspectorModule/Batch/MultimediaBatchOutputPolicy.swift",
    "Sources/MultimediaInspectorModule/Batch/MultimediaBatchProcessor.swift",
    "Sources/MultimediaInspectorModule/Presets/MultimediaInspectorBatchPresetStore.swift",
    "Sources/MultimediaInspectorModule/Presets/MultimediaInspectorRuleSetStore.swift",
    "Sources/MultimediaInspectorModule/Presets/MultimediaInspectorFavoritesStore.swift",
    "Sources/MultimediaInspectorModule/Batch/MultimediaBatchFolderEnumerator.swift",
    "Sources/MultimediaInspectorModule/Batch/MultimediaBatchStructuralRules.swift",
    "Sources/MultimediaInspectorModule/Batch/MultimediaBatchPreflight.swift",
    "Sources/MultimediaInspectorModule/Preview/MultimediaVideoPreviewService.swift",
    "Sources/MultimediaInspectorModule/Preview/FFmpegVideoPreviewCommandBuilder.swift",
    "Sources/MultimediaInspectorModule/Preview/MultimediaSubtitlePreviewService.swift",
    "Sources/MultimediaInspectorModule/Analysis/AudioSourceQualityAnalysisService.swift",
    "Sources/MultimediaInspectorModule/OCR/BitmapSubtitleOCRService.swift",
    "Sources/MultimediaInspectorModule/OCR/BitmapSubtitleOCRExporter.swift",
    "Sources/MultimediaInspectorModule/Models/MediaEditableArtwork.swift",
    "Sources/MultimediaInspectorModule/Execution/MultimediaArtworkService.swift",
    "Sources/MultimediaInspectorModule/Models/AudioTimelineViewport.swift",
    "Sources/MultimediaInspectorModule/Storage/MultimediaInspectorSettingsStore.swift",
    "Sources/MultimediaInspectorModule/Waveform/WaveformModels.swift",
    "Sources/MultimediaInspectorModule/Waveform/WaveformAccumulator.swift",
    "Sources/MultimediaInspectorModule/Waveform/WaveformAnalysisService.swift",
    "Sources/MultimediaInspectorModule/Analysis/AudioLoudnessAnalysisService.swift",
    "Sources/MultimediaInspectorModule/Analysis/AudioLoudnessTimeline.swift",
    "Sources/MultimediaInspectorModule/Analysis/AudioTimingAnalysis.swift",
    "Sources/MultimediaInspectorModule/Analysis/AudioSignalAnalysis.swift",
    "Sources/MultimediaInspectorModule/Analysis/AudioSignalAnalysisService.swift",
    "Sources/MultimediaInspectorModule/Reporting/MultimediaTechnicalReportExporter.swift",
    "Sources/MultimediaInspectorModule/Models/AudioTrackComparison.swift",
    "Sources/MultimediaInspectorModule/Models/MediaEditDraft.swift",
    "Sources/MultimediaInspectorModule/Models/MediaEditPlan.swift",
    "Sources/MultimediaInspectorModule/Models/MediaEditableChapter.swift",
    "Sources/MultimediaInspectorModule/Models/MediaEditableAttachment.swift",
    "Sources/MultimediaInspectorModule/Models/MediaMetadataDraft.swift",
    "Sources/MultimediaInspectorModule/Models/AudioChannelLayout.swift",
    "Sources/MultimediaInspectorModule/Models/MediaInspectionTextFormatter.swift",
    "Sources/MultimediaInspectorModule/Preview/FFmpegAudioPreviewCommandBuilder.swift",
    "Sources/MultimediaInspectorModule/Preview/MultimediaAudioPreviewService.swift",
    "Sources/MultimediaInspectorModule/Compatibility/MediaContainerCompatibilityRegistry.swift",
    "Sources/MultimediaInspectorModule/Compatibility/MediaMetadataCompatibilityRegistry.swift",
    "Sources/MultimediaInspectorModule/Planning/MediaEditValidator.swift",
    "Sources/MultimediaInspectorModule/Planning/MediaEditPlanner.swift",
    "Sources/MultimediaInspectorModule/Execution/FFmpegTrackEditCommandBuilder.swift",
    "Sources/MultimediaInspectorModule/Execution/FFmpegMediaEditCommandBuilder.swift",
    "Sources/MultimediaInspectorModule/Execution/FFmpegChapterMetadataBuilder.swift",
    "Sources/MultimediaInspectorModule/Execution/MultimediaAttachmentExtractionService.swift",
    "Sources/MultimediaInspectorModule/Execution/MultimediaEditService.swift",
    "Sources/MultimediaInspectorModule/Execution/MultimediaResultValidator.swift",
    "Sources/MultimediaInspectorModule/Spectrogram/FFmpegPCMDecoder.swift",
    "Sources/MultimediaInspectorModule/Spectrogram/SpectrogramFFTProcessor.swift",
    "Sources/MultimediaInspectorModule/Spectrogram/SpectrogramRenderMapping.swift",
    "Sources/MultimediaInspectorModule/Spectrogram/SpectrogramInspectionMapping.swift",
    "Sources/MultimediaInspectorModule/Spectrogram/SpectrogramRasterizer.swift",
    "Sources/MultimediaInspectorModule/Spectrogram/SpectrogramAnalysisService.swift",
    "Sources/MultimediaInspectorModule/Spectrogram/SpectrogramExportService.swift",
    "Sources/ZEUVEApp/MultimediaInspector/MultimediaInspectorView.swift",
    "Sources/ZEUVEApp/MultimediaInspector/MultimediaInspectorViewModel.swift",
    "Sources/ZEUVEApp/MultimediaInspector/Spectrogram/SpectrogramAxesView.swift",
    "Sources/ZEUVEApp/MultimediaInspector/Spectrogram/MultimediaLoudnessTimelineView.swift",
    "Sources/ZEUVEApp/MultimediaInspector/Views/MultimediaPreviewPlayerView.swift",
    "Sources/ZEUVEApp/MultimediaInspector/Views/MultimediaWaveformView.swift",
    "Sources/ZEUVEApp/MultimediaInspector/MultimediaInspectorSettingsView.swift",
    "Sources/ZEUVEApp/MultimediaInspector/Batch/MultimediaBatchView.swift",
    "Sources/ZEUVEApp/MultimediaInspector/Batch/MultimediaBatchViewModel.swift",
    "Sources/ZEUVEApp/MultimediaInspector/Views/MultimediaTechnicalStructureView.swift",
    "Sources/ZEUVEApp/MultimediaInspector/Views/MultimediaClipboard.swift",
    "Tests/ZEUVEEnginesTests/MediaInspectionTests.swift",
    "Tests/MultimediaInspectorModuleTests/MediaEditingTests.swift",
    "Tests/MultimediaInspectorModuleTests/StructuralEditingTests.swift",
    "Tests/MultimediaInspectorModuleTests/MultimediaInspectorCoreTests.swift",
    "Tests/MultimediaInspectorModuleTests/SpectrogramMathTests.swift",
    "Tests/MultimediaInspectorModuleTests/PreviewReplacementLifecycleTests.swift",
    "Tests/MultimediaInspectorModuleTests/AudioSignalAnalysisTests.swift",
    "Tests/MultimediaInspectorModuleTests/BatchAndPresetTests.swift",
    "Docs/Modulos/Funcionales/MULTIMEDIA_INSPECTOR.md",
]
for relative in required_files:
    path = Path(relative)
    if not path.is_file() or path.stat().st_size < 80:
        raise SystemExit("Falta una pieza obligatoria del Inspector: " + relative)

module_sources = "\n".join(path.read_text() for path in Path("Sources/MultimediaInspectorModule").rglob("*.swift"))
ui_sources = "\n".join(path.read_text() for path in Path("Sources/ZEUVEApp/MultimediaInspector").rglob("*.swift"))
engine_sources = "\n".join(path.read_text() for path in Path("Sources/ZEUVEEngines/MediaInspection").rglob("*.swift"))
all_new = module_sources + "\n" + ui_sources + "\n" + engine_sources

for forbidden in [
    "/bin/sh",
    "Process()",
    "UserDefaults.",
    "URLSession",
    "http://",
    "https://",
    "Spek",
    "wxWidgets",
    "ExifTool",
    "MediaInfo",
    "MKVToolNix",
]:
    if forbidden in all_new:
        raise SystemExit("Inspector multimedia contiene una dependencia/patrón prohibido: " + forbidden)
for marker in ["TODO", "FIXME", "fatalError(", "print("]:
    if marker in all_new:
        raise SystemExit("Inspector multimedia contiene código incompleto/debug: " + marker)

for required in [
    "MediaEditDraftHistory",
    "undoStack",
    "redoStack",
    "authorizedSubtitleConversions",
    "MediaContainerCompatibilityRegistry",
    "MediaEditValidator",
    "MediaEditPlanner",
    "FFmpegTrackEditCommandBuilder",
    "FFmpegMediaEditCommandBuilder",
    "FFmpegChapterMetadataBuilder",
    "MediaEditableChapter",
    "MediaEditableAttachment",
    "MediaMetadataDraft",
    "MultimediaAttachmentExtractionService",
    'arguments += ["-c", "copy"]',
    "MultimediaResultValidator",
    "MultimediaOutputPublisher",
    "MultimediaDiskSpaceChecker",
    "OperationCoordinator",
    "FileFingerprint",
]:
    if required not in module_sources:
        raise SystemExit("Falta una garantía estructural de edición: " + required)

for required in [
    'Label("Modo inspección · solo lectura"',
    'Button("Editar")',
    'Button("Cancelar edición")',
    '.keyboardShortcut("z", modifiers: [.command])',
    '.keyboardShortcut("z", modifiers: [.command, .shift])',
    'Button("Revisar cambios")',
    'Button("Añadir audio…")',
    '"Añadir subtítulo…"',
    '"Default"',
    '"Forced"',
    'Button("Exportar PNG")',
    'Button("Añadir capítulo en posición actual")',
    'Button("Añadir adjunto…")',
    'Button("Extraer…")',
    'Metadatos globales editables',
    '"Escuchar"',
    'MultimediaPreviewPlayerView',
    'Button("Analizar otro archivo…")',
    'Button("Cerrar análisis")',
    'MultimediaWaveformView',
    'Analizar sonoridad',
    'Análisis de señal',
    'Posible clipping',
    'COMPARAR A/B',
    'Completar análisis A/B',
    'Sonoridad temporal · Short-term LUFS',
    'Exportar informe',
    'SpectrogramFrequencyAxis',
    'SpectrogramTimeAxis',
    'SpectrogramDBLegend',
    'Analizar varios archivos…',
    'Inspector multimedia · Lote',
    'Reintentar fallidos',
    'Abrir carpeta de resultados',
    'Lotes y presets',
    '.dropDestination(for: URL.self)',
]:
    if required not in ui_sources:
        raise SystemExit("Falta comportamiento visible requerido del Inspector: " + required)

batch_processor = Path("Sources/MultimediaInspectorModule/Batch/MultimediaBatchProcessor.swift").read_text()
batch_models = Path("Sources/MultimediaInspectorModule/Batch/MultimediaBatchModels.swift").read_text()
batch_presets = Path("Sources/MultimediaInspectorModule/Presets/MultimediaInspectorBatchPresetStore.swift").read_text()
batch_view_model = Path("Sources/ZEUVEApp/MultimediaInspector/Batch/MultimediaBatchViewModel.swift").read_text()
batch_view = Path("Sources/ZEUVEApp/MultimediaInspector/Batch/MultimediaBatchView.swift").read_text()
inspector_view_model_source = Path("Sources/ZEUVEApp/MultimediaInspector/MultimediaInspectorViewModel.swift").read_text()
settings_view = Path("Sources/ZEUVEApp/MultimediaInspector/MultimediaInspectorSettingsView.swift").read_text()
settings_store = Path("Sources/MultimediaInspectorModule/Storage/MultimediaInspectorSettingsStore.swift").read_text()
batch_preferences_source = Path("Sources/MultimediaInspectorModule/Models/MultimediaInspectorPreferences.swift").read_text()
for required in [
    "MultimediaBatchConfiguration",
    "MultimediaBatchItemStatus",
    "MultimediaBatchRunSummary",
    "MultimediaTechnicalReportSections",
]:
    if required not in batch_models:
        raise SystemExit("Falta modelo de lote del Inspector: " + required)
for required in [
    "inspection.audioStreams.count == 1",
    "inspection.audioStreams.count > 1",
    "ZEUVE no selecciona una silenciosamente",
    "AudioSignalAnalysisService",
    "AudioLoudnessAnalysisService",
    "SpectrogramAnalysisService",
    "runWhenCoordinatorIsFree",
    "protectedOriginals",
]:
    if required not in batch_processor:
        raise SystemExit("Falta garantía del procesador de lotes: " + required)
if "async let" in batch_processor or "TaskGroup" in batch_processor or "withTaskGroup" in batch_processor:
    raise SystemExit("El lote del Inspector debe procesar análisis pesados secuencialmente.")
for required in [
    "quickInspectionPresetID",
    "technicalReportPresetID",
    "completeAudioAnalysisPresetID",
    "spectrogramsPresetID",
    "multimediaInspector.batchPresets.v1",
]:
    target = batch_presets + "\n" + settings_store
    if required not in target:
        raise SystemExit("Falta persistencia/versionado estable de presets de lote: " + required)
for required in [
    "allowsMultipleSelection = true",
    "resetConfiguration: false",
    "saveBatch",
    "retryFailures",
    "NSWorkspace.shared.open",
]:
    if required not in (inspector_view_model_source + "\n" + batch_view_model):
        raise SystemExit("Falta flujo de productividad del lote: " + required)
if "LazyVStack" not in batch_view:
    raise SystemExit("La lista de lote debe renderizarse de forma perezosa para colas grandes.")
for required in [
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
    "defaultReportFormat",
    "reportSections",
    "defaultBatchPresetID",
]:
    if required not in batch_preferences_source or required not in settings_view:
        raise SystemExit("Falta configuración centralizada del Inspector: " + required)

inspection = Path("Sources/ZEUVEEngines/MediaInspection/MediaInspectionService.swift").read_text()
for required in ["-show_streams", "-show_format", "-show_chapters", "-show_programs", "CacheKey", "FileFingerprint", "useCache"]:
    if required not in inspection:
        raise SystemExit("MediaInspection compartido está incompleto: " + required)
converter_sources = "\n".join(path.read_text() for path in Path("Sources/UniversalConverterModule").rglob("*.swift"))
if "MediaInspectionService" not in converter_sources:
    raise SystemExit("El Conversor no usa MediaInspectionService compartido.")
if Path("Sources/UniversalConverterModule/MediaProbe.swift").exists():
    raise SystemExit("Sigue existiendo el parser FFprobe antiguo del Conversor.")

spectrogram = "\n".join(path.read_text() for path in Path("Sources/MultimediaInspectorModule/Spectrogram").rglob("*.swift"))
for required in ["pcm_f32le", '"f32le"', "pipe:1", "canImport(Accelerate)", "vDSP_DFT", "maximumColumns", "nyquist", "log10f", "Cancellation", "SpectrogramRenderMapping", "SpectrogramRasterizer", "analyzePowerMix"]:
    if required not in spectrogram:
        raise SystemExit("Motor de espectrograma incompleto: " + required)

preview = "\n".join(path.read_text() for path in Path("Sources/MultimediaInspectorModule/Preview").rglob("*.swift"))
for required in ["MultimediaAudioPreviewService", "FFmpegAudioPreviewCommandBuilder", "PreviewSourceReplacementGate", "DetachedPreviewPlaybackResources", "replaceSource(", "AVAudioEngine", "AVAudioPlayerNode", "DispatchSemaphore(value: 6)", '"-map"', '"pcm_f32le"', '"pipe:1"', "FileFingerprint"]:
    if required not in preview:
        raise SystemExit("Previsualización de audio incompleta: " + required)
for required in ["PreviewPlaybackContinuity", "preservePlaybackState: Bool = false", "guard shouldPlay else { return }"]:
    if required not in preview:
        raise SystemExit("Falta continuidad Play/Pausa en la sustitución de audio: " + required)
if "OperationCoordinator(" in preview or "coordinator.acquire" in preview:
    raise SystemExit("La previsualización ligera no debe reservar OperationCoordinator.")

view_model = Path("Sources/ZEUVEApp/MultimediaInspector/MultimediaInspectorViewModel.swift").read_text()
waveform_view = Path("Sources/ZEUVEApp/MultimediaInspector/Views/MultimediaWaveformView.swift").read_text()
for required in [
    "previewOperationID",
    "requestedPreviewSourceID",
    "synchronizeSelectedAudioStreamIndex",
    "refreshPreviewSnapshot(operationID:",
    "previewPosition = target",
]:
    if required not in view_model:
        raise SystemExit("Falta protección de cambio de pista/seek del reproductor: " + required)
if "else if hadPreview { stopPreview() }" in view_model:
    raise SystemExit("El cambio de pista no debe programar un stop separado antes del nuevo preview.")
seek_call = "model.seekPreview(to: target)"
drag_clear = "dragPosition = nil"
seek_index = waveform_view.find(seek_call)
clear_index = waveform_view.find(drag_clear, seek_index)
if seek_index < 0 or clear_index < 0 or seek_index > clear_index:
    raise SystemExit("La waveform debe publicar el seek optimista antes de liberar la posición local del drag.")
if 'Label("Cargando…"' not in ui_sources:
    raise SystemExit("La pista solicitada debe mostrar el estado Cargando durante la sustitución.")
if "model.defaultPreferences.allowedFFTSizes" not in ui_sources:
    raise SystemExit("El selector FFT debe seguir usando defaultPreferences.allowedFFTSizes.")

for required in [
    "AudioTimelineViewport",
    "AudioTimelineVisibleRange",
    "visibleRange(totalDuration:",
    "zoomed(",
    "panned(byFraction",
]:
    if required not in module_sources:
        raise SystemExit("Falta el viewport temporal compartido del Inspector: " + required)
if "maximumBuckets: 65_536" not in view_model or "65_536" not in Path("Sources/MultimediaInspectorModule/Waveform/WaveformAccumulator.swift").read_text():
    raise SystemExit("La waveform ampliada debe conservar una envolvente acotada de hasta 65.536 buckets.")
for required in [
    "zoomAudioTimelineIn()",
    "zoomAudioTimelineOut()",
    "panAudioTimeline(",
    "resetAudioTimelineViewport()",
    "AudioTimelineChapterMarker",
]:
    if required not in view_model:
        raise SystemExit("Falta navegación temporal compartida en el ViewModel: " + required)
if "spectrogramZoomStart" in view_model or "spectrogramZoomDuration" in view_model:
    raise SystemExit("Waveform y Espectrograma no deben mantener viewports temporales independientes.")
if ui_sources.count("model.zoomAudioTimelineIn()") < 2 or ui_sources.count("model.panAudioTimeline(") < 4:
    raise SystemExit("Waveform y Espectrograma deben controlar el mismo zoom/pan temporal.")
if "visibleRange: AudioTimelineVisibleRange" not in waveform_view or "audioTimelineChapterMarkers" not in waveform_view:
    raise SystemExit("La waveform debe recortar por viewport y representar capítulos sobre la línea temporal.")

spectrogram_view = Path("Sources/ZEUVEApp/MultimediaInspector/Spectrogram/SpectrogramView.swift").read_text()
if "model.previewSelectedSpectrogram(at: 0)" in spectrogram_view:
    raise SystemExit("El botón Escuchar del Espectrograma no debe reiniciar la pista en 00:00.")
if "model.previewSelectedSpectrogram(preservePlaybackState: true)" not in spectrogram_view:
    raise SystemExit("El botón Escuchar del Espectrograma debe usar el estado compartido del reproductor.")
if ".frame(minHeight: 420)" in spectrogram_view:
    raise SystemExit("El Espectrograma no debe imponer 420 pt mínimos que oculten el reproductor inferior.")
if spectrogram_view.count(".frame(maxHeight: .infinity)") < 3:
    raise SystemExit("El gráfico, eje y leyenda del Espectrograma deben adaptarse a la altura disponible.")
if "previewSourceID != nil || requestedPreviewSourceID != nil || activePreviewSource != nil" not in view_model:
    raise SystemExit("El cambio rápido de pista debe reconocer también una sustitución pendiente.")
if "previewService.seek(to: target, preservePlaybackState: true)" not in view_model:
    raise SystemExit("El seek de la UI debe conservar el estado Play/Pausa.")

tracks_view = Path("Sources/ZEUVEApp/MultimediaInspector/Views/MultimediaTracksView.swift").read_text()
for required in [
    "func previewPlaybackState(for sourceID: String?)",
    "private func previewControlMatches(_ sourceID: String?)",
    "switch previewState",
    "case .loading:",
    "return requestedPreviewSourceID == sourceID",
    "case .playing, .paused, .finished:",
    "return previewSourceID == sourceID",
    "switch previewPlaybackState(for: targetSourceID)",
]:
    if required not in view_model:
        raise SystemExit("Falta resolución centralizada estable de los controles de preview: " + required)
if "if let requestedPreviewSourceID { return requestedPreviewSourceID == sourceID }" in view_model:
    raise SystemExit("Una petición pendiente no debe tener prioridad sobre la fuente confirmada en estados estables.")
if "private func shouldTogglePreviewControl" in view_model:
    raise SystemExit("Pistas y Espectrograma no deben mantener una segunda decisión paralela para pausar/reanudar.")
if "model.previewPlaybackState(for: sourceID)" not in tracks_view:
    raise SystemExit("Pistas debe representar Play/Pausa desde el estado centralizado del ViewModel.")
if "model.previewPlaybackState(for: selectedSpectrogramSourceID)" not in spectrogram_view:
    raise SystemExit("Espectrograma debe representar Play/Pausa desde el estado centralizado del ViewModel.")
if "if selectedSpectrogramSourceIsPlaying { model.togglePreviewPause() }" in spectrogram_view:
    raise SystemExit("Espectrograma no debe decidir localmente si el botón pausa o inicia la sesión.")
if "model.previewSelectedSpectrogram(preservePlaybackState: true)" not in spectrogram_view:
    raise SystemExit("El botón del Espectrograma debe delegar su decisión completa al ViewModel.")

# Las filas de Pistas deben conservar identidad durante los updates de preview (~100 ms).
for required in [
    "private var inspectionAudioTracks: [MediaEditableTrack] = []",
    "private var inspectionSubtitleTracks: [MediaEditableTrack] = []",
    "var audioTracks: [MediaEditableTrack] { currentDraft?.audioTracks ?? inspectionAudioTracks }",
    "var subtitleTracks: [MediaEditableTrack] { currentDraft?.subtitleTracks ?? inspectionSubtitleTracks }",
    "private func cacheInspectionTracks(_ inspection: MediaInspectionResult)",
    "self.cacheInspectionTracks(result)",
    "self.cacheInspectionTracks(result.inspection)",
]:
    if required not in view_model:
        raise SystemExit("Falta identidad estable de las filas del Inspector: " + required)
for forbidden in [
    "inspection?.audioStreams.compactMap { .from(stream: $0, kind: .audio) }",
    "inspection?.subtitleStreams.compactMap { .from(stream: $0, kind: .subtitle) }",
]:
    if forbidden in view_model:
        raise SystemExit("Las pistas de solo lectura no deben regenerar UUID durante cada render: " + forbidden)
if view_model.count("inspectionAudioTracks = []") < 2 or view_model.count("inspectionSubtitleTracks = []") < 2:
    raise SystemExit("La caché estable de pistas debe limpiarse al fallar/cerrar una inspección.")

automatic_policy = Path("Sources/MultimediaInspectorModule/Analysis/MultimediaAutomaticAudioAnalysisPolicy.swift").read_text()
if "audioStreamCount == 1" not in automatic_policy:
    raise SystemExit("El análisis automático debe activarse únicamente con una pista de audio.")
for required in [
    "MultimediaAutomaticAudioAnalysisPolicy.shouldRun(audioStreamCount: result.audioStreams.count)",
    "private func startAutomaticSingleTrackAudioAnalysis()",
    "while self.isGeneratingSpectrogram",
    "_ = await currentSpectrogramTask?.result",
    "self.analyzeLoudness(track)",
    "automaticAudioAnalysisTask?.cancel()",
    "automaticAudioAnalysisSessionID = UUID()",
]:
    if required not in view_model:
        raise SystemExit("Falta la orquestación automática mono-pista del Inspector: " + required)
automatic_start = view_model.index("private func startAutomaticSingleTrackAudioAnalysis()")
automatic_end = view_model.index("func analyzeLoudness(_ track:", automatic_start)
automatic_body = view_model[automatic_start:automatic_end]
if automatic_body.index("generateSpectrogram()") > automatic_body.index("self.analyzeLoudness(track)"):
    raise SystemExit("El análisis automático debe generar primero el espectrograma y después la sonoridad.")
if "async let" in automatic_body:
    raise SystemExit("Espectrograma, señal y sonoridad no deben ejecutarse en paralelo.")

signal_analysis = Path("Sources/MultimediaInspectorModule/Analysis/AudioSignalAnalysis.swift").read_text()
signal_service = Path("Sources/MultimediaInspectorModule/Analysis/AudioSignalAnalysisService.swift").read_text()
preferences_source = Path("Sources/MultimediaInspectorModule/Models/MultimediaInspectorPreferences.swift").read_text()
for required in [
    "AudioSignalAnalysisConfiguration",
    "AudioSilenceSegment",
    "AudioClippingEvent",
    "AudioSignalAnalysisResult",
    "silenceWindowSquares",
    "minimumConsecutiveClippedSamples",
]:
    if required not in signal_analysis:
        raise SystemExit("Falta el análisis de señal PCM completo del Inspector: " + required)
for required in [
    "OperationCoordinator",
    "fingerprint.matches",
    '"pcm_f32le"',
    '"f32le"',
    '"pipe:1"',
    "Float32LEStreamDecoder",
    "requestCancellation",
]:
    if required not in signal_service:
        raise SystemExit("Falta garantía del servicio de análisis de señal: " + required)
if '"-ar"' in signal_service or '"-ac"' in signal_service:
    raise SystemExit("El análisis de señal debe preservar sample rate y canales originales; no debe forzar -ar/-ac.")
for required in [
    "signalSilenceThresholdDBFS",
    "signalMinimumSilenceDuration",
    "signalClippingThresholdDBFS",
    "signalMinimumConsecutiveClippedSamples",
]:
    if required not in preferences_source:
        raise SystemExit("Falta preferencia centralizada del análisis de señal: " + required)
for required in [
    "currentWaveformSignalAnalysis",
    "selectedSpectrogramSignalAnalysis",
    "self.analyzeSignal(track)",
    "_ = await signalAnalysisTask?.result",
    "signalAnalysisService?.cancel()",
]:
    if required not in view_model:
        raise SystemExit("Falta integración/cancelación del análisis de señal: " + required)
if automatic_body.index("generateSpectrogram()") > automatic_body.index("self.analyzeSignal(track)"):
    raise SystemExit("El análisis automático debe ejecutar el espectrograma antes del análisis de señal.")
if automatic_body.index("self.analyzeSignal(track)") > automatic_body.index("self.analyzeLoudness(track)"):
    raise SystemExit("El análisis automático debe ejecutar señal antes de sonoridad.")
if "signalAnalysisOverlay" not in spectrogram_view or "AudioSilenceSegment" not in waveform_view or "AudioClippingEvent" not in waveform_view:
    raise SystemExit("Silencios y posible clipping deben proyectarse sobre la línea temporal compartida.")

loudness_service = Path("Sources/MultimediaInspectorModule/Analysis/AudioLoudnessAnalysisService.swift").read_text()
loudness_timeline = Path("Sources/MultimediaInspectorModule/Analysis/AudioLoudnessTimeline.swift").read_text()
comparison_model = Path("Sources/MultimediaInspectorModule/Models/AudioTrackComparison.swift").read_text()
loudness_timeline_view = Path("Sources/ZEUVEApp/MultimediaInspector/Spectrogram/MultimediaLoudnessTimelineView.swift").read_text()
report_exporter = Path("Sources/MultimediaInspectorModule/Reporting/MultimediaTechnicalReportExporter.swift").read_text()
for required in [
    "AudioLoudnessTimeline",
    "AudioLoudnessTimelineAccumulator",
    "momentaryLUFS",
    "shortTermLUFS",
    "integratedLUFS",
    "maximumSamples",
]:
    if required not in loudness_timeline:
        raise SystemExit("Falta la serie temporal EBU R128 acotada: " + required)
for required in [
    "timelineAccumulator",
    "timelineAccumulator.append",
    "ebur128=peak=true",
]:
    if required not in loudness_service:
        raise SystemExit("La sonoridad temporal debe reutilizar la misma ejecución EBU R128: " + required)
if "AudioLoudnessAnalysisService" in loudness_timeline_view or "ExternalProcessRunner" in loudness_timeline_view:
    raise SystemExit("La vista de sonoridad temporal no debe lanzar otro análisis pesado.")
for required in [
    "selectedSpectrogramLoudness",
    "result.startTime",
    "result.endTime",
    "seekPreview",
    "multimediaLoudnessTimeline",
]:
    if required not in loudness_timeline_view:
        raise SystemExit("Falta integración del mapa de sonoridad con el viewport/reproductor compartidos: " + required)
for required in [
    "AudioComparisonSlot",
    "AudioTrackComparisonMetrics",
]:
    if required not in comparison_model:
        raise SystemExit("Falta modelo de comparación A/B: " + required)
for required in [
    "comparisonTrackAID",
    "comparisonTrackBID",
    "selectComparisonSlot",
    "synchronizeSpectrogramSelection: false",
    "completeComparisonAnalysis()",
    "runSignalAnalysis(source: source)",
    "runLoudnessAnalysis(source: source)",
    "selectedSpectrogramSourceID",
    "currentWaveformSignalAnalysis",
]:
    if required not in view_model:
        raise SystemExit("Falta integración A/B o separación de fuentes: " + required)
if "async let" in view_model[view_model.index("func completeComparisonAnalysis()"):view_model.index("func previewSourceID(for track:")]:
    raise SystemExit("El análisis A/B debe completar datos secuencialmente, nunca en paralelo.")
if "synchronizeSpectrogramSelection: false" not in view_model[view_model.index("func selectComparisonSlot"):view_model.index("func previewSourceID(for track:")]:
    raise SystemExit("A/B no debe cambiar silenciosamente la pista seleccionada para Espectrograma.")
for required in [
    "schemaVersion = 3",
    "AudioSignalReportItem",
    "let timeline: LoudnessTimeline?",
    "let signal: [Signal]",
]:
    if required not in report_exporter:
        raise SystemExit("El informe técnico actual debe incluir señal/timeline con schema 3: " + required)
for forbidden in ["sourceID", "fingerprint", "originalURL.path"]:
    json_section = report_exporter[report_exporter.find("private struct ReportPayload"): ]
    if forbidden in json_section:
        raise SystemExit("El informe JSON no debe exponer identificadores/rutas privadas: " + forbidden)

for required in [
    "MultimediaWaveformAccumulator",
    "MultimediaWaveformAnalysisService",
    "MultimediaInspectorSettingsStore",
    "AudioLoudnessAnalysisService",
    "AudioTimingAnalyzer",
    "AudioSignalAnalysisService",
    "MultimediaTechnicalReportExporter",
]:
    if required not in module_sources:
        raise SystemExit("Falta ampliación 0.15 del Inspector: " + required)

for required in [
    "MultimediaInspectorSettingsView(model: app.multimediaInspector)",
    "restorePersistentDefaultsForGlobalReset()",
]:
    if required not in settings_router + "\n" + app_model:
        raise SystemExit("Falta integración de Ajustes 0.15 del Inspector: " + required)

history = Path("Sources/MultimediaInspectorModule/History/MultimediaInspectorHistory.swift").read_text()
for forbidden in [
    "baseFolder: plan.originalURL",
    "originalURL.path",
    "track.title",
    "track.language",
    "MediaInspectionResult",
    "SpectrogramResult",
]:
    if forbidden in history:
        raise SystemExit("El historial del Inspector persiste detalle privado no permitido: " + forbidden)


for required in [
    "chapters: [MediaEditableChapter]",
    "attachments: [MediaEditableAttachment]",
    "metadata: MediaMetadataDraft",
]:
    if required not in module_sources:
        raise SystemExit("Falta estado estructural editable 0.17: " + required)

media_builder = Path("Sources/MultimediaInspectorModule/Execution/FFmpegMediaEditCommandBuilder.swift").read_text()
for required in ["-attach", "-map_chapters", "-map_metadata", "-metadata:s:t:", 'arguments += ["-c", "copy"]']:
    if required not in media_builder:
        raise SystemExit("Falta integración FFmpeg de edición estructural 0.17: " + required)
if "/bin/sh" in media_builder or "Process()" in media_builder:
    raise SystemExit("La edición estructural no puede usar shell ni Process directo.")

chapter_builder = Path("Sources/MultimediaInspectorModule/Execution/FFmpegChapterMetadataBuilder.swift").read_text()
for required in [";FFMETADATA1", "[CHAPTER]", "TIMEBASE=1/1000", "START=", "END="]:
    if required not in chapter_builder:
        raise SystemExit("Falta generación FFmetadata segura: " + required)

# Ayuda contextual obligatoria del Inspector 0.18.1.0.
help_topics = Path("Sources/ZEUVEApp/MultimediaInspector/MultimediaInspectorHelp.swift").read_text()
settings_help = Path("Sources/ZEUVEApp/MultimediaInspector/MultimediaInspectorSettingsView.swift").read_text()
help_surfaces = {
    "Sources/ZEUVEApp/MultimediaInspector/MultimediaInspectorView.swift": "multimediaInspectorOverview",
    "Sources/ZEUVEApp/MultimediaInspector/Views/MultimediaSummaryView.swift": "multimediaSummaryTab",
    "Sources/ZEUVEApp/MultimediaInspector/Views/MultimediaTracksView.swift": "multimediaTracksTab",
    "Sources/ZEUVEApp/MultimediaInspector/Spectrogram/SpectrogramView.swift": "multimediaSpectrogramTab",
    "Sources/ZEUVEApp/MultimediaInspector/Views/MultimediaMetadataView.swift": "multimediaMetadataTab",
    "Sources/ZEUVEApp/MultimediaInspector/Batch/MultimediaBatchView.swift": "multimediaBatchMode",
}
for path, topic in help_surfaces.items():
    if topic not in Path(path).read_text():
        raise SystemExit(f"Falta ayuda contextual general del Inspector: {path} -> {topic}")
for topic in [
    "multimediaAutomaticSpectrogram", "multimediaAutomaticSignal", "multimediaAutomaticLoudness",
    "multimediaPreviewVolume", "multimediaTrackSwitchPosition", "multimediaTrackSwitchPlayback",
    "multimediaTimelineZoom", "multimediaTimelinePan", "multimediaWaveformStyle",
    "multimediaWaveformRepresentation", "multimediaSilenceThreshold", "multimediaClippingThreshold",
    "multimediaFFTSize", "multimediaWindow", "multimediaFrequencyScale", "multimediaSpectrogramChannel",
    "multimediaSpectrogramColumns", "multimediaSpectrogramExportSize", "multimediaReportFormat",
    "multimediaReportSections", "multimediaPreferredContainer", "multimediaBatchPreset",
    "multimediaBatchOperations", "multimediaVideoPreview", "multimediaVideoDecoder",
    "multimediaBitmapSubtitles", "multimediaAdvancedAudioAnalysis", "multimediaBatchFolders",
    "multimediaStructuralRules",
]:
    if topic not in settings_help:
        raise SystemExit("Falta ayuda contextual en Ajustes del Inspector: " + topic)
for topic in [
    "multimediaIntegratedLUFS", "multimediaLRA", "multimediaTruePeak", "multimediaSamplePeak",
    "multimediaShortTermStats", "multimediaAudioTiming", "multimediaSignalAnalysis",
    "multimediaChapters", "multimediaAttachments", "multimediaAttachmentMIME", "multimediaMetadata",
    "multimediaPartialInspection",
]:
    if topic not in help_topics:
        raise SystemExit("Falta tema contextual analítico/estructural del Inspector: " + topic)
for path in Path("Sources/ZEUVEApp/MultimediaInspector").rglob("*.swift"):
    source = path.read_text()
    if 'Image(systemName: "info.circle")' in source or 'Image(systemName: "info.circle.fill")' in source:
        raise SystemExit(f"{path}: el Inspector debe reutilizar ContextualHelpButton, no crear iconos info paralelos.")
for forbidden in ["generateSpectrogram", "analyzeSignal", "analyzeLoudness", "resetAnalysis", "persistPreferences"]:
    if forbidden in help_topics:
        raise SystemExit("La ayuda contextual no puede ejecutar ni invalidar análisis: " + forbidden)

for path, snippets in {
    "Sources/MultimediaInspectorModule/Models/MediaEditDraft.swift": ["videoTracks", "artworks"],
    "Sources/MultimediaInspectorModule/Execution/FFmpegMediaEditCommandBuilder.swift": ["plan.videoTracks", "attached_pic", '\"-c\", \"copy\"'],
    "Sources/ZEUVEApp/MultimediaInspector/Views/MultimediaPreviewPlayerView.swift": ["MultimediaVideoPreviewSurface", "selectedVideoStreamIndex", "previewPlaybackRate"],
    "Sources/ZEUVEApp/MultimediaInspector/Batch/MultimediaBatchView.swift": ["Añadir carpeta…", "Edición estructural por lotes", "Guardar conjunto"],
    "Sources/ZEUVEApp/MultimediaInspector/Views/MultimediaSubtitleOCRView.swift": ["OCR", "exportOCRDraft"],
}.items():
    source = Path(path).read_text()
    for snippet in snippets:
        if snippet not in source:
            raise SystemExit(f"Falta cierre 0.19 del Inspector en {path}: {snippet}")

print("Inspector multimedia 0.7.0: preview de vídeo, edición estructural, lotes, análisis avanzado, OCR, favoritos, privacidad y ayuda contextual verificados.")
