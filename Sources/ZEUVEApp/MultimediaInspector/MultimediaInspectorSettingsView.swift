import SwiftUI
import MultimediaInspectorModule

struct MultimediaInspectorSettingsView: View {
    @ObservedObject var model: MultimediaInspectorViewModel
    @State private var confirmRestore = false
    @State private var confirmRestorePresets = false
    @State private var newPresetName = ""
    @State private var editingPresetID: UUID?
    @State private var editingPresetName = ""
    @State private var editingPresetConfiguration = MultimediaBatchConfiguration()

    var body: some View {
        Form {
            inspectorSection
            automationSection
            playerSection
            videoPreviewSection
            timelineSection
            waveformSection
            signalAnalysisSection
            advancedAnalysisSection
            spectrogramSection
            ocrSection
            batchFolderSection
            reportSection
            outputSection
            batchPresetsSection
            resetSection
        }
        .formStyle(.grouped)
        .padding()
        .onChange(of: model.defaultPreferences) { _, _ in model.persistPreferences() }
        .confirmationDialog("¿Restaurar los ajustes del Inspector multimedia?", isPresented: $confirmRestore, titleVisibility: .visible) {
            Button("Restaurar", role: .destructive) { model.restoreDefaultPreferences() }
            Button("Cancelar", role: .cancel) { }
        } message: {
            Text("Se recuperarán las preferencias y los presets de lote predeterminados. No se modificará ningún archivo, borrador ni resultado anterior.")
        }
        .confirmationDialog("¿Restaurar los presets de lote predeterminados?", isPresented: $confirmRestorePresets, titleVisibility: .visible) {
            Button("Restaurar", role: .destructive) { model.batch.restoreDefaultPresets() }
            Button("Cancelar", role: .cancel) { }
        } message: {
            Text("Se sustituirán los presets de lote actuales por los incluidos con ZEUVE.")
        }
        .sheet(isPresented: Binding(
            get: { editingPresetID != nil },
            set: { if !$0 { editingPresetID = nil } }
        )) {
            presetEditorSheet
        }
    }

    private var inspectorSection: some View {
        Section {
            HelpPickerRow("Pestaña inicial", topic: ZEUVEHelpTopics.multimediaInitialTab, selection: $model.defaultPreferences.initialTab) {
                ForEach(MultimediaInspectorInitialTab.allCases) { Text($0.displayName).tag($0) }
            }
            HelpPickerRow("Detalle técnico", topic: ZEUVEHelpTopics.multimediaTechnicalDetail, selection: $model.defaultPreferences.detailLevel) {
                ForEach(MultimediaInspectorDetailLevel.allCases) { Text($0.displayName).tag($0) }
            }
            HelpToggleRow("Preservar metadatos al editar", topic: ZEUVEHelpTopics.multimediaPreserveMetadata, isOn: $model.defaultPreferences.preserveMetadata)
        } header: { Text("Inspector") }
        footer: { Text("Las preferencias se aplican a nuevas sesiones o nuevas ediciones. Las garantías de seguridad y validación del original no se pueden desactivar.") }
    }

    private var automationSection: some View {
        Section {
            HelpToggleRow("Generar espectrograma automáticamente", topic: ZEUVEHelpTopics.multimediaAutomaticSpectrogram, isOn: $model.defaultPreferences.automaticSpectrogramForSingleTrack)
            HelpToggleRow("Analizar señal automáticamente", topic: ZEUVEHelpTopics.multimediaAutomaticSignal, isOn: $model.defaultPreferences.automaticSignalAnalysisForSingleTrack)
            HelpToggleRow("Analizar sonoridad automáticamente", topic: ZEUVEHelpTopics.multimediaAutomaticLoudness, isOn: $model.defaultPreferences.automaticLoudnessForSingleTrack)
        } header: { Text("Automatización con una sola pista") }
        footer: { Text("Solo se aplica cuando FFprobe detecta exactamente una pista de audio. Con varias pistas ZEUVE nunca selecciona una silenciosamente.") }
    }

    private var playerSection: some View {
        Section {
            HStack {
                HelpLabel("Volumen inicial", topic: ZEUVEHelpTopics.multimediaPreviewVolume)
                Slider(value: $model.defaultPreferences.previewVolume, in: 0...1)
                Text("\(Int((model.defaultPreferences.previewVolume * 100).rounded())) %")
                    .monospacedDigit().frame(width: 52, alignment: .trailing)
            }
            HelpPickerRow("Salto rápido", topic: ZEUVEHelpTopics.multimediaPreviewSkip, selection: $model.defaultPreferences.previewSkipSeconds) {
                ForEach(MultimediaInspectorPreferences.allowedPreviewSkipSeconds, id: \.self) { value in
                    Text("\(value) segundos").tag(value)
                }
            }
            HelpToggleRow("Conservar posición al cambiar de pista", topic: ZEUVEHelpTopics.multimediaTrackSwitchPosition, isOn: $model.defaultPreferences.previewTrackSwitchKeepsPosition)
            HelpToggleRow("Conservar Play/Pausa al cambiar de pista", topic: ZEUVEHelpTopics.multimediaTrackSwitchPlayback, isOn: $model.defaultPreferences.previewTrackSwitchKeepsPlaybackState)
        } header: { Text("Reproductor") }
        footer: { Text("Estos valores se aplican al comenzar una nueva sesión de inspección.") }
    }

    private var videoPreviewSection: some View {
        Section {
            HelpPickerRow("Decodificación", topic: ZEUVEHelpTopics.multimediaVideoDecoder, selection: $model.defaultPreferences.videoPreviewDecoder) {
                ForEach(MultimediaVideoPreviewDecoder.allCases) { Text($0.displayName).tag($0) }
            }
            HelpPickerRow("Escalado", topic: ZEUVEHelpTopics.multimediaVideoPreview, selection: $model.defaultPreferences.videoPreviewScaleMode) {
                ForEach(MultimediaVideoPreviewScaleMode.allCases) { Text($0.displayName).tag($0) }
            }
            HStack(spacing: 10) {
                HelpLabel("Resolución interna máxima", topic: ZEUVEHelpTopics.multimediaVideoPreview)
                Spacer()
                Stepper("\(model.defaultPreferences.videoPreviewLimits.maximumWidth)×\(model.defaultPreferences.videoPreviewLimits.maximumHeight)", value: $model.defaultPreferences.videoPreviewLimits.maximumWidth, in: 640...3840, step: 160)
                Stepper("alto", value: $model.defaultPreferences.videoPreviewLimits.maximumHeight, in: 360...2160, step: 90)
            }
            HStack(spacing: 8) {
                HelpLabel("FPS máximos", topic: ZEUVEHelpTopics.multimediaVideoPreview)
                Slider(value: Binding(get: { Double(model.defaultPreferences.videoPreviewLimits.maximumFPS) }, set: { model.defaultPreferences.videoPreviewLimits.maximumFPS = Int($0.rounded()) }), in: 5...60, step: 5)
                Text("\(model.defaultPreferences.videoPreviewLimits.maximumFPS)").monospacedDigit().frame(width: 30)
            }
            HStack {
                HelpLabel("Buffer de frames", topic: ZEUVEHelpTopics.multimediaVideoPreview)
                Spacer()
                Stepper("\(model.defaultPreferences.videoPreviewLimits.maximumBufferedFrames)", value: $model.defaultPreferences.videoPreviewLimits.maximumBufferedFrames, in: 1...8)
            }
            HelpPickerRow("Velocidad inicial", topic: ZEUVEHelpTopics.multimediaVideoPreview, selection: $model.defaultPreferences.previewPlaybackRate) {
                ForEach([0.5, 0.75, 1.0, 1.25, 1.5, 2.0], id: \.self) { Text("\($0, specifier: "%g")×").tag($0) }
            }
            HStack {
                HelpLabel("Tamaño de subtítulos", topic: ZEUVEHelpTopics.multimediaBitmapSubtitles)
                Slider(value: $model.defaultPreferences.subtitlePreviewFontSize, in: 14...48, step: 1)
                Text("\(Int(model.defaultPreferences.subtitlePreviewFontSize)) pt").monospacedDigit().frame(width: 52)
            }
            HStack {
                HelpLabel("Fondo de subtítulos", topic: ZEUVEHelpTopics.multimediaBitmapSubtitles)
                Slider(value: $model.defaultPreferences.subtitlePreviewBackgroundOpacity, in: 0...0.95, step: 0.05)
                Text("\(Int((model.defaultPreferences.subtitlePreviewBackgroundOpacity * 100).rounded())) %").monospacedDigit().frame(width: 48)
            }
        } header: { Text("Previsualización de vídeo") }
        footer: { Text("Los límites reducen trabajo de decodificación y memoria. ZEUVE mantiene además límites internos de seguridad que no pueden desactivarse.") }
    }

    private var advancedAnalysisSection: some View {
        Section {
            HelpToggleRow("Analizar indicios de fuente con pérdida automáticamente", topic: ZEUVEHelpTopics.multimediaAdvancedAudioAnalysis, isOn: $model.defaultPreferences.automaticAdvancedAudioAnalysisForSingleTrack)
            HelpToggleRow("Mostrar anomalías avanzadas en overlays", topic: ZEUVEHelpTopics.multimediaAdvancedAudioAnalysis, isOn: $model.defaultPreferences.showAdvancedAudioOverlays)
        } header: { Text("Análisis avanzado") }
        footer: { Text("Los resultados son indicios técnicos explicables, nunca una afirmación absoluta sobre el origen del archivo.") }
    }

    private var ocrSection: some View {
        Section {
            HelpPickerRow("Precisión OCR", topic: ZEUVEHelpTopics.multimediaBitmapSubtitles, selection: $model.defaultPreferences.bitmapSubtitleOCROptions.recognitionLevel) {
                ForEach(BitmapSubtitleOCRRecognitionLevel.allCases) { Text($0.displayName).tag($0) }
            }
            HStack {
                HelpLabel("Idioma OCR", topic: ZEUVEHelpTopics.multimediaBitmapSubtitles)
                TextField("Automático (ej. es-ES)", text: Binding(
                    get: { model.defaultPreferences.bitmapSubtitleOCROptions.language ?? "" },
                    set: { value in
                        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                        model.defaultPreferences.bitmapSubtitleOCROptions.language = trimmed.isEmpty ? nil : trimmed
                    }
                ))
                .textFieldStyle(.roundedBorder)
            }
            HelpToggleRow("Corrección lingüística", topic: ZEUVEHelpTopics.multimediaBitmapSubtitles, isOn: $model.defaultPreferences.bitmapSubtitleOCROptions.usesLanguageCorrection)
            HStack {
                HelpLabel("Confianza baja", topic: ZEUVEHelpTopics.multimediaBitmapSubtitles)
                Slider(value: $model.defaultPreferences.bitmapSubtitleOCROptions.lowConfidenceThreshold, in: 0...1, step: 0.05)
                Text("\(Int(model.defaultPreferences.bitmapSubtitleOCROptions.lowConfidenceThreshold * 100)) %").monospacedDigit().frame(width: 48)
            }
        } header: { Text("OCR de subtítulos bitmap") }
        footer: { Text("Vision se ejecuta exclusivamente en el Mac. El texto OCR no se guarda en logs ni sustituye automáticamente la pista original.") }
    }

    private var batchFolderSection: some View {
        Section {
            HelpToggleRow("Incluir subcarpetas", topic: ZEUVEHelpTopics.multimediaBatchFolders, isOn: $model.defaultPreferences.batchFolderOptions.includeSubfolders)
            HStack {
                HelpLabel("Profundidad máxima", topic: ZEUVEHelpTopics.multimediaBatchFolders)
                Stepper("\(model.defaultPreferences.batchFolderOptions.maximumDepth)", value: $model.defaultPreferences.batchFolderOptions.maximumDepth, in: 0...32)
            }
            HelpToggleRow("Incluir ocultos", topic: ZEUVEHelpTopics.multimediaBatchFolders, isOn: $model.defaultPreferences.batchFolderOptions.includeHidden)
            HelpPickerRow("Orden", topic: ZEUVEHelpTopics.multimediaBatchFolders, selection: $model.defaultPreferences.batchFolderOptions.order) {
                ForEach(MultimediaBatchFolderOrder.allCases) { Text($0.displayName).tag($0) }
            }
            HelpPickerRow("Archivos incompatibles", topic: ZEUVEHelpTopics.multimediaBatchFolders, selection: $model.defaultPreferences.batchFolderOptions.incompatiblePolicy) {
                ForEach(MultimediaBatchIncompatiblePolicy.allCases) { Text($0.displayName).tag($0) }
            }
            HStack(alignment: .top) {
                HelpLabel("Extensiones", topic: ZEUVEHelpTopics.multimediaBatchFolders)
                TextField("mkv, mp4, mov, …", text: Binding(
                    get: { model.defaultPreferences.batchFolderOptions.allowedExtensions.sorted().joined(separator: ", ") },
                    set: { value in
                        model.defaultPreferences.batchFolderOptions.allowedExtensions = Set(value.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespacesAndNewlines).lowercased().trimmingCharacters(in: CharacterSet(charactersIn: ".")) }.filter { !$0.isEmpty })
                    }
                ))
                .textFieldStyle(.roundedBorder)
            }
            HStack {
                HelpLabel("Reglas estructurales reutilizables", topic: ZEUVEHelpTopics.multimediaStructuralRules)
                Spacer()
                Text("Se guardan desde el modo Lote").font(.caption).foregroundStyle(.secondary)
            }
        } header: { Text("Carpetas en lotes") }
        footer: { Text("Los enlaces simbólicos no se siguen aunque esta sección cambie; es una protección de seguridad no configurable. Las reglas y favoritos reutilizables no guardan rutas multimedia.") }
    }

    private var timelineSection: some View {
        Section {
            HStack {
                HelpLabel("Paso de zoom", topic: ZEUVEHelpTopics.multimediaTimelineZoom)
                Slider(value: $model.defaultPreferences.timelineZoomFactor, in: 0.25...0.8, step: 0.05)
                Text("×\(String(format: "%.2f", model.defaultPreferences.timelineZoomFactor))")
                    .monospacedDigit().frame(width: 58, alignment: .trailing)
            }
            HStack {
                HelpLabel("Paso de desplazamiento", topic: ZEUVEHelpTopics.multimediaTimelinePan)
                Slider(value: $model.defaultPreferences.timelinePanFraction, in: 0.1...1, step: 0.1)
                Text("\(Int((model.defaultPreferences.timelinePanFraction * 100).rounded())) %")
                    .monospacedDigit().frame(width: 52, alignment: .trailing)
            }
        } header: { Text("Línea temporal") }
        footer: { Text("Waveform, espectrograma y sonoridad temporal comparten el mismo viewport.") }
    }

    private var waveformSection: some View {
        Section {
            HelpPickerRow("Estilo", topic: ZEUVEHelpTopics.multimediaWaveformStyle, selection: $model.defaultPreferences.waveformStyle) {
                ForEach(MultimediaWaveformStyle.allCases) { Text($0.displayName).tag($0) }
            }
            HelpPickerRow("Representación", topic: ZEUVEHelpTopics.multimediaWaveformRepresentation, selection: $model.defaultPreferences.waveformRepresentation) {
                ForEach(MultimediaWaveformRepresentation.allCases) { Text($0.displayName).tag($0) }
            }
            HelpToggleRow("Mostrar guía central", topic: ZEUVEHelpTopics.multimediaWaveformCenterGuide, isOn: $model.defaultPreferences.waveformShowsCenterGuide)
            HelpToggleRow("Mostrar capítulos", topic: ZEUVEHelpTopics.multimediaChapterMarkers, isOn: $model.defaultPreferences.showChapterMarkersOnWaveform)
            HelpToggleRow("Mostrar silencios y posible clipping", topic: ZEUVEHelpTopics.multimediaSignalOverlays, isOn: $model.defaultPreferences.showSignalOverlaysOnWaveform)
        } header: { Text("Forma de onda") }
        footer: { Text("Las opciones visuales no vuelven a decodificar el audio.") }
    }

    private var signalAnalysisSection: some View {
        Section {
            HStack {
                HelpLabel("Umbral de silencio", topic: ZEUVEHelpTopics.multimediaSilenceThreshold)
                Slider(value: $model.defaultPreferences.signalSilenceThresholdDBFS, in: -120 ... -10, step: 1)
                Text("\(Int(model.defaultPreferences.signalSilenceThresholdDBFS)) dBFS")
                    .monospacedDigit().frame(width: 72, alignment: .trailing)
            }
            HStack {
                HelpLabel("Duración mínima", topic: ZEUVEHelpTopics.multimediaSilenceDuration)
                Slider(value: $model.defaultPreferences.signalMinimumSilenceDuration, in: 0.05 ... 30, step: 0.05)
                Text(String(format: "%.2f s", model.defaultPreferences.signalMinimumSilenceDuration))
                    .monospacedDigit().frame(width: 64, alignment: .trailing)
            }
            HStack {
                HelpLabel("Umbral de posible clipping", topic: ZEUVEHelpTopics.multimediaClippingThreshold)
                Slider(value: $model.defaultPreferences.signalClippingThresholdDBFS, in: -6 ... 0, step: 0.1)
                Text(String(format: "%.1f dBFS", model.defaultPreferences.signalClippingThresholdDBFS))
                    .monospacedDigit().frame(width: 76, alignment: .trailing)
            }
            HStack(spacing: 6) {
                Stepper(
                    "Muestras consecutivas: \(model.defaultPreferences.signalMinimumConsecutiveClippedSamples)",
                    value: $model.defaultPreferences.signalMinimumConsecutiveClippedSamples,
                    in: 2 ... 64
                )
                ContextualHelpButton(topic: ZEUVEHelpTopics.multimediaClippingSamples)
            }
        } header: { Text("Análisis de señal") }
        footer: { Text("El silencio exige que todos los canales permanezcan bajo el umbral. «Posible clipping» sigue siendo una detección conservadora, no una afirmación absoluta.") }
    }

    private var spectrogramSection: some View {
        Section {
            HelpPickerRow("FFT", topic: ZEUVEHelpTopics.multimediaFFTSize, selection: $model.defaultPreferences.defaultFFTSize) {
                ForEach(model.defaultPreferences.allowedFFTSizes, id: \.self) { Text(String($0)).tag($0) }
            }
            HelpPickerRow("Ventana", topic: ZEUVEHelpTopics.multimediaWindow, selection: $model.defaultPreferences.defaultWindow) {
                ForEach(SpectrogramWindowFunction.allCases) { Text($0.displayName).tag($0) }
            }
            HelpPickerRow("Escala de frecuencia", topic: ZEUVEHelpTopics.multimediaFrequencyScale, selection: $model.defaultPreferences.defaultFrequencyScale) {
                ForEach(SpectrogramFrequencyScale.allCases) { Text($0.displayName).tag($0) }
            }
            HelpPickerRow("Canal inicial", topic: ZEUVEHelpTopics.multimediaSpectrogramChannel, selection: $model.defaultPreferences.defaultChannel) {
                ForEach(SpectrogramInitialChannel.allCases) { Text($0.displayName).tag($0) }
            }
            HStack {
                HelpLabel("Rango mínimo", topic: ZEUVEHelpTopics.multimediaDynamicRange)
                Slider(
                    value: Binding(
                        get: { Double(model.defaultPreferences.defaultDynamicRange.lowerBound) },
                        set: { model.defaultPreferences.defaultDynamicRange = Float($0)...model.defaultPreferences.defaultDynamicRange.upperBound }
                    ),
                    in: -180 ... -20,
                    step: 5
                )
                Text("\(Int(model.defaultPreferences.defaultDynamicRange.lowerBound)) dB")
                    .monospacedDigit().frame(width: 62, alignment: .trailing)
            }
            HStack {
                HelpLabel("Rango máximo", topic: ZEUVEHelpTopics.multimediaDynamicRange)
                Slider(
                    value: Binding(
                        get: { Double(model.defaultPreferences.defaultDynamicRange.upperBound) },
                        set: { value in
                            let minimum = model.defaultPreferences.defaultDynamicRange.lowerBound
                            model.defaultPreferences.defaultDynamicRange = minimum...max(Float(value), minimum + 1)
                        }
                    ),
                    in: -19 ... 12,
                    step: 1
                )
                Text("\(Int(model.defaultPreferences.defaultDynamicRange.upperBound)) dB")
                    .monospacedDigit().frame(width: 62, alignment: .trailing)
            }
            HStack(spacing: 6) {
                Stepper("Columnas máximas: \(model.defaultPreferences.spectrogramMaximumColumns)", value: $model.defaultPreferences.spectrogramMaximumColumns, in: 256...8192, step: 128)
                ContextualHelpButton(topic: ZEUVEHelpTopics.multimediaSpectrogramColumns)
            }
            HStack(spacing: 12) {
                Stepper("PNG ancho: \(model.defaultPreferences.spectrogramExportWidth) px", value: $model.defaultPreferences.spectrogramExportWidth, in: 320...4096, step: 80)
                Stepper("alto: \(model.defaultPreferences.spectrogramExportHeight) px", value: $model.defaultPreferences.spectrogramExportHeight, in: 180...4096, step: 45)
                ContextualHelpButton(topic: ZEUVEHelpTopics.multimediaSpectrogramExportSize)
            }
            HelpToggleRow("Mostrar silencios y posible clipping", topic: ZEUVEHelpTopics.multimediaSignalOverlays, isOn: $model.defaultPreferences.showSignalOverlaysOnSpectrogram)
            HelpToggleRow("Mostrar mapa temporal de sonoridad", topic: ZEUVEHelpTopics.multimediaLoudnessTimeline, isOn: $model.defaultPreferences.showLoudnessTimeline)
        } header: { Text("Espectrograma") }
        footer: { Text("Son valores iniciales y de exportación. Cambiarlos no altera silenciosamente un espectrograma ya generado.") }
    }

    private var reportSection: some View {
        Section {
            HelpPickerRow("Formato predeterminado", topic: ZEUVEHelpTopics.multimediaReportFormat, selection: $model.defaultPreferences.defaultReportFormat) {
                ForEach(MultimediaTechnicalReportFormat.allCases) { Text($0.displayName).tag($0) }
            }
            HelpToggleRow("Metadatos globales", topic: ZEUVEHelpTopics.multimediaReportSections, isOn: $model.defaultPreferences.reportSections.includeGlobalMetadata)
            HelpToggleRow("Streams", topic: ZEUVEHelpTopics.multimediaReportSections, isOn: $model.defaultPreferences.reportSections.includeStreams)
            HelpToggleRow("Detalles de vídeo", topic: ZEUVEHelpTopics.multimediaReportSections, isOn: $model.defaultPreferences.reportSections.includeVideoDetails)
            HelpToggleRow("Carátulas", topic: ZEUVEHelpTopics.multimediaReportSections, isOn: $model.defaultPreferences.reportSections.includeArtwork)
            HelpToggleRow("Capítulos", topic: ZEUVEHelpTopics.multimediaReportSections, isOn: $model.defaultPreferences.reportSections.includeChapters)
            HelpToggleRow("Sincronización", topic: ZEUVEHelpTopics.multimediaReportSections, isOn: $model.defaultPreferences.reportSections.includeTiming)
            HelpToggleRow("Sonoridad", topic: ZEUVEHelpTopics.multimediaReportSections, isOn: $model.defaultPreferences.reportSections.includeLoudness)
            HelpToggleRow("Análisis de señal", topic: ZEUVEHelpTopics.multimediaReportSections, isOn: $model.defaultPreferences.reportSections.includeSignalAnalysis)
            HelpToggleRow("Análisis avanzado", topic: ZEUVEHelpTopics.multimediaReportSections, isOn: $model.defaultPreferences.reportSections.includeAdvancedAudioAnalysis)
            HelpToggleRow("Resumen OCR", topic: ZEUVEHelpTopics.multimediaReportSections, isOn: $model.defaultPreferences.reportSections.includeOCRSummary)
            HelpToggleRow("Edición estructural", topic: ZEUVEHelpTopics.multimediaReportSections, isOn: $model.defaultPreferences.reportSections.includeStructuralEditSummary)
        } header: { Text("Informes") }
        footer: { Text("Los informes solo incluyen resultados que ya se hayan calculado; exportar no lanza análisis pesados por sorpresa.") }
    }

    private var outputSection: some View {
        Section {
            HStack(spacing: 12) {
                HelpLabel("Sufijo de salida", topic: ZEUVEHelpTopics.multimediaOutputSuffix)
                Spacer(minLength: 12)
                TextField("Sufijo de salida", text: $model.defaultPreferences.outputSuffix)
                    .frame(maxWidth: 360)
            }
            HelpPickerRow("Contenedor preferido", topic: ZEUVEHelpTopics.multimediaPreferredContainer, selection: $model.defaultPreferences.preferredContainer) {
                Text("Automático").tag(EditableMediaContainer?.none)
                ForEach(EditableMediaContainer.allCases) { container in
                    Text(container.displayName).tag(Optional(container))
                }
            }
        } header: { Text("Edición y salida") }
        footer: { Text("Automático conserva el contenedor cuando es compatible. ZEUVE nunca recodifica vídeo o audio de forma silenciosa.") }
    }

    private var batchPresetsSection: some View {
        Section {
            HelpPickerRow("Preset predeterminado", topic: ZEUVEHelpTopics.multimediaBatchPreset, selection: $model.defaultPreferences.defaultBatchPresetID) {
                Text("Primero disponible").tag(UUID?.none)
                ForEach(model.batch.presets) { preset in Text(preset.name).tag(Optional(preset.id)) }
            }

            ForEach(model.batch.presets) { preset in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(preset.name)
                        Text(presetSummary(preset.configuration))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Editar") { beginEditing(preset) }
                    Menu {
                        Button("Duplicar") { model.batch.duplicatePreset(preset) }
                        Button("Eliminar", role: .destructive) { deletePresetAndRepairDefault(preset) }
                    } label: { Image(systemName: "ellipsis.circle") }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                }
            }

            HStack {
                TextField("Nuevo preset", text: $newPresetName)
                Button("Crear") {
                    model.batch.createPreset(named: newPresetName, configuration: model.defaultPreferences.batchConfigurationDefaults)
                    newPresetName = ""
                }
                .disabled(newPresetName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            Button("Restaurar presets de lote predeterminados", role: .destructive) { confirmRestorePresets = true }
        } header: { HelpLabel("Lotes y presets", topic: ZEUVEHelpTopics.multimediaBatchPreset) }
        footer: { Text("Los presets guardan qué análisis y exportaciones ejecutar, pero nunca rutas, carpetas ni archivos del usuario.") }
    }

    private var resetSection: some View {
        Section {
            Button("Restaurar valores predeterminados del Inspector", role: .destructive) { confirmRestore = true }
        } footer: { Text("No elimina archivos, historial ni resultados. Restablece preferencias y presets del módulo.") }
    }

    private var presetEditorSheet: some View {
        NavigationStack {
            Form {
                Section("Preset") { TextField("Nombre", text: $editingPresetName) }
                Section("Operaciones") {
                    HelpToggleRow("Analizar señal", topic: ZEUVEHelpTopics.multimediaBatchOperations, isOn: $editingPresetConfiguration.analyzeSignal)
                    HelpToggleRow("Analizar sonoridad", topic: ZEUVEHelpTopics.multimediaBatchOperations, isOn: $editingPresetConfiguration.analyzeLoudness)
                    HelpToggleRow("Exportar espectrograma", topic: ZEUVEHelpTopics.multimediaBatchOperations, isOn: $editingPresetConfiguration.exportSpectrogram)
                    HelpPickerRow("Informe", topic: ZEUVEHelpTopics.multimediaReportFormat, selection: $editingPresetConfiguration.reportFormat) {
                        Text("Ninguno").tag(MultimediaTechnicalReportFormat?.none)
                        ForEach(MultimediaTechnicalReportFormat.allCases) { Text($0.displayName).tag(Optional($0)) }
                    }
                }
                Section("Espectrograma del lote") {
                    HelpPickerRow("FFT", topic: ZEUVEHelpTopics.multimediaFFTSize, selection: $editingPresetConfiguration.spectrogramFFTSize) {
                        ForEach(MultimediaInspectorPreferences.defaultAllowedFFTSizes, id: \.self) { Text(String($0)).tag($0) }
                    }
                    HelpPickerRow("Ventana", topic: ZEUVEHelpTopics.multimediaWindow, selection: $editingPresetConfiguration.spectrogramWindow) {
                        ForEach(SpectrogramWindowFunction.allCases) { Text($0.displayName).tag($0) }
                    }
                    HelpPickerRow("Escala", topic: ZEUVEHelpTopics.multimediaFrequencyScale, selection: $editingPresetConfiguration.spectrogramFrequencyScale) {
                        ForEach(SpectrogramFrequencyScale.allCases) { Text($0.displayName).tag($0) }
                    }
                    HelpPickerRow("Canal", topic: ZEUVEHelpTopics.multimediaSpectrogramChannel, selection: $editingPresetConfiguration.spectrogramChannel) {
                        ForEach(SpectrogramInitialChannel.allCases) { Text($0.displayName).tag($0) }
                    }
                    HStack {
                        HelpLabel("Rango mínimo", topic: ZEUVEHelpTopics.multimediaDynamicRange)
                        Slider(
                            value: Binding(
                                get: { Double(editingPresetConfiguration.spectrogramDynamicRange.lowerBound) },
                                set: { editingPresetConfiguration.spectrogramDynamicRange = Float($0)...editingPresetConfiguration.spectrogramDynamicRange.upperBound }
                            ),
                            in: -180 ... -20,
                            step: 5
                        )
                        Text("\(Int(editingPresetConfiguration.spectrogramDynamicRange.lowerBound)) dB").monospacedDigit()
                    }
                    HStack {
                        HelpLabel("Rango máximo", topic: ZEUVEHelpTopics.multimediaDynamicRange)
                        Slider(
                            value: Binding(
                                get: { Double(editingPresetConfiguration.spectrogramDynamicRange.upperBound) },
                                set: { value in
                                    let minimum = editingPresetConfiguration.spectrogramDynamicRange.lowerBound
                                    editingPresetConfiguration.spectrogramDynamicRange = minimum...max(Float(value), minimum + 1)
                                }
                            ),
                            in: -19 ... 12,
                            step: 1
                        )
                        Text("\(Int(editingPresetConfiguration.spectrogramDynamicRange.upperBound)) dB").monospacedDigit()
                    }
                    HStack(spacing: 6) {
                        Stepper("Columnas máximas: \(editingPresetConfiguration.spectrogramMaximumColumns)", value: $editingPresetConfiguration.spectrogramMaximumColumns, in: 256...8192, step: 128)
                        ContextualHelpButton(topic: ZEUVEHelpTopics.multimediaSpectrogramColumns)
                    }
                    HStack(spacing: 6) {
                        Stepper("PNG ancho: \(editingPresetConfiguration.spectrogramExportWidth) px", value: $editingPresetConfiguration.spectrogramExportWidth, in: 320...4096, step: 80)
                        ContextualHelpButton(topic: ZEUVEHelpTopics.multimediaSpectrogramExportSize)
                    }
                    HStack(spacing: 6) {
                        Stepper("PNG alto: \(editingPresetConfiguration.spectrogramExportHeight) px", value: $editingPresetConfiguration.spectrogramExportHeight, in: 180...4096, step: 45)
                        ContextualHelpButton(topic: ZEUVEHelpTopics.multimediaSpectrogramExportSize)
                    }
                }
                Section("Señal del lote") {
                    HStack {
                        HelpLabel("Silencio", topic: ZEUVEHelpTopics.multimediaSilenceThreshold)
                        Slider(value: $editingPresetConfiguration.signalSilenceThresholdDBFS, in: -120 ... -10, step: 1)
                        Text("\(Int(editingPresetConfiguration.signalSilenceThresholdDBFS)) dBFS").monospacedDigit()
                    }
                    HStack {
                        HelpLabel("Duración", topic: ZEUVEHelpTopics.multimediaSilenceDuration)
                        Slider(value: $editingPresetConfiguration.signalMinimumSilenceDuration, in: 0.05 ... 30, step: 0.05)
                        Text(String(format: "%.2f s", editingPresetConfiguration.signalMinimumSilenceDuration)).monospacedDigit()
                    }
                    HStack {
                        HelpLabel("Clipping", topic: ZEUVEHelpTopics.multimediaClippingThreshold)
                        Slider(value: $editingPresetConfiguration.signalClippingThresholdDBFS, in: -6 ... 0, step: 0.1)
                        Text(String(format: "%.1f dBFS", editingPresetConfiguration.signalClippingThresholdDBFS)).monospacedDigit()
                    }
                    HStack(spacing: 6) {
                        Stepper("Muestras consecutivas: \(editingPresetConfiguration.signalMinimumConsecutiveClippedSamples)", value: $editingPresetConfiguration.signalMinimumConsecutiveClippedSamples, in: 2...64)
                        ContextualHelpButton(topic: ZEUVEHelpTopics.multimediaClippingSamples)
                    }
                }
                Section("Secciones del informe") {
                    HelpToggleRow("Metadatos globales", topic: ZEUVEHelpTopics.multimediaReportSections, isOn: $editingPresetConfiguration.reportSections.includeGlobalMetadata)
                    HelpToggleRow("Streams", topic: ZEUVEHelpTopics.multimediaReportSections, isOn: $editingPresetConfiguration.reportSections.includeStreams)
                    HelpToggleRow("Detalles de vídeo", topic: ZEUVEHelpTopics.multimediaReportSections, isOn: $editingPresetConfiguration.reportSections.includeVideoDetails)
                    HelpToggleRow("Carátulas", topic: ZEUVEHelpTopics.multimediaReportSections, isOn: $editingPresetConfiguration.reportSections.includeArtwork)
                    HelpToggleRow("Capítulos", topic: ZEUVEHelpTopics.multimediaReportSections, isOn: $editingPresetConfiguration.reportSections.includeChapters)
                    HelpToggleRow("Sincronización", topic: ZEUVEHelpTopics.multimediaReportSections, isOn: $editingPresetConfiguration.reportSections.includeTiming)
                    HelpToggleRow("Sonoridad", topic: ZEUVEHelpTopics.multimediaReportSections, isOn: $editingPresetConfiguration.reportSections.includeLoudness)
                    HelpToggleRow("Análisis de señal", topic: ZEUVEHelpTopics.multimediaReportSections, isOn: $editingPresetConfiguration.reportSections.includeSignalAnalysis)
                    HelpToggleRow("Análisis avanzado", topic: ZEUVEHelpTopics.multimediaReportSections, isOn: $editingPresetConfiguration.reportSections.includeAdvancedAudioAnalysis)
                    HelpToggleRow("Resumen OCR", topic: ZEUVEHelpTopics.multimediaReportSections, isOn: $editingPresetConfiguration.reportSections.includeOCRSummary)
                    HelpToggleRow("Edición estructural", topic: ZEUVEHelpTopics.multimediaReportSections, isOn: $editingPresetConfiguration.reportSections.includeStructuralEditSummary)
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Editar preset de lote")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { editingPresetID = nil } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") { saveEditedPreset() }
                        .disabled(editingPresetName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .frame(minWidth: 620, minHeight: 680)
        }
    }

    private func deletePresetAndRepairDefault(_ preset: MultimediaInspectorBatchPreset) {
        if model.defaultPreferences.defaultBatchPresetID == preset.id {
            model.defaultPreferences.defaultBatchPresetID = nil
        }
        model.batch.deletePreset(preset)
    }

    private func beginEditing(_ preset: MultimediaInspectorBatchPreset) {
        editingPresetID = preset.id
        editingPresetName = preset.name
        editingPresetConfiguration = preset.configuration
    }

    private func saveEditedPreset() {
        guard let id = editingPresetID, let preset = model.batch.presets.first(where: { $0.id == id }) else { return }
        model.batch.renamePreset(preset, to: editingPresetName)
        if let updated = model.batch.presets.first(where: { $0.id == id }) {
            model.batch.updatePreset(updated, configuration: editingPresetConfiguration)
        }
        editingPresetID = nil
    }

    private func presetSummary(_ configuration: MultimediaBatchConfiguration) -> String {
        var values: [String] = []
        if configuration.analyzeSignal { values.append("señal") }
        if configuration.analyzeLoudness { values.append("sonoridad") }
        if configuration.exportSpectrogram { values.append("PNG") }
        if let report = configuration.reportFormat { values.append("informe \(report.rawValue.uppercased())") }
        return values.isEmpty ? "Solo inspección técnica" : values.joined(separator: " · ")
    }
}
