import SwiftUI
import UniversalConverterModule

struct UniversalConverterSettingsView: View {
    @ObservedObject var model: UniversalConverterViewModel
    @State private var confirmRestore = false
    @State private var confirmRestorePresets = false
    @State private var newPresetName = ""
    @State private var newFavoriteName = ""

    var body: some View {
        Form {
            generalSection
            outputSection
            performanceSection
            zipSection
            presetsSection
            favoritesSection
            imageSection
            audioSection
            videoSection
            sequenceSection
            pdfSection
            diagnosticsSection
            portabilitySection
            currentOperationSection
            resetSection
        }
        .formStyle(.grouped)
        .padding()
        .onChange(of: model.defaultSettings) { _, _ in model.persistDefaultSettings() }
        .confirmationDialog("¿Restaurar los ajustes del Conversor universal?", isPresented: $confirmRestore, titleVisibility: .visible) {
            Button("Restaurar", role: .destructive) { model.restoreDefaults() }
            Button("Cancelar", role: .cancel) { }
        } message: {
            Text("Se recuperarán los valores predeterminados. No se modificará ningún archivo ni operación anterior.")
        }
        .confirmationDialog("¿Restaurar los preajustes del Conversor universal?", isPresented: $confirmRestorePresets, titleVisibility: .visible) {
            Button("Restaurar", role: .destructive) { model.restoreDefaultPresets() }
            Button("Cancelar", role: .cancel) { }
        } message: {
            Text("Se sustituirá la lista actual por los preajustes oficiales. No se modificará ningún archivo.")
        }
    }

    private var generalSection: some View {
        Section {
            Toggle("Abrir nuevas conversiones en modo avanzado", isOn: $model.defaultSettings.defaultAdvancedMode)
            HelpPickerRow("Preajuste de calidad", topic: ZEUVEHelpTopics.converterQuality, selection: $model.defaultSettings.quality) {
                ForEach(ConverterQualityProfile.allCases) { Text($0.displayName).tag($0) }
            }
            HelpPickerRow("Política de metadatos", topic: ZEUVEHelpTopics.converterMetadata, selection: $model.defaultSettings.metadataPolicy) {
                ForEach(ConverterMetadataPolicy.allCases) { Text($0.displayName).tag($0) }
            }
            Toggle("Conservar fechas compatibles", isOn: $model.defaultSettings.preserveDates)
            Toggle("Evitar ampliar resolución", isOn: $model.defaultSettings.avoidUpscaling)
            HelpToggleRow("Permitir copia rápida sin recodificar", topic: ZEUVEHelpTopics.converterStreamCopy, isOn: $model.defaultSettings.preferRemuxWhenPossible)
        } header: {
            HStack { Text("Valores predeterminados"); ContextualHelpButton(topic: ZEUVEHelpTopics.moduleDefaults) }
        } footer: {
            Text("Se aplican únicamente a nuevas conversiones. No alteran una vista previa ni una operación en curso.")
        }
    }

    private var outputSection: some View {
        Section {
            HelpPickerRow("Ubicación de resultados", topic: ZEUVEHelpTopics.converterOutputFolder, selection: $model.defaultSettings.outputFolderMode) {
                ForEach(ConverterOutputFolderMode.allCases) { Text($0.displayName).tag($0) }
            }
            if model.defaultSettings.outputFolderMode == .subfolder {
                TextField("Nombre de la subcarpeta", text: $model.defaultSettings.outputSubfolderName)
            }
            Toggle("Recordar la última carpeta", isOn: $model.defaultSettings.rememberOutputFolder)
            Picker("Estilo de nombre", selection: $model.defaultSettings.filenameStyle) {
                ForEach(ConverterFilenameStyle.allCases) { Text($0.displayName).tag($0) }
            }
            TextField("Prefijo", text: $model.defaultSettings.filenamePrefix)
            TextField("Sufijo", text: $model.defaultSettings.filenameSuffix)
            TextField("Separador", text: $model.defaultSettings.filenameSeparator)
            HelpPickerRow("Conflictos de nombres", topic: ZEUVEHelpTopics.converterConflict, selection: $model.defaultSettings.conflictPolicy) {
                ForEach(ConverterConflictPolicy.allCases) { Text($0.displayName).tag($0) }
            }
            Toggle("Guardar rutas de salida en el historial", isOn: $model.defaultSettings.saveOutputPathsInHistory)
        } header: { Text("Salida y nombres") }
        footer: {
            Text("Los originales nunca se sustituyen. Reemplazar solo afecta a un resultado anterior y se publica después de validarlo.")
        }
    }

    private var performanceSection: some View {
        Section {
            HelpPickerRow("Paralelismo", topic: ZEUVEHelpTopics.converterParallelism, selection: $model.defaultSettings.parallelismMode) {
                ForEach(ConverterParallelismMode.allCases) { Text($0.displayName).tag($0) }
            }
            if model.defaultSettings.parallelismMode == .manual {
                Stepper("Trabajos simultáneos: \(model.defaultSettings.manualParallelism)", value: $model.defaultSettings.manualParallelism, in: 1...8)
            }
            HelpPickerRow("Codificación de vídeo", topic: ZEUVEHelpTopics.converterHardware, selection: $model.defaultSettings.accelerationMode) {
                ForEach(ConverterAccelerationMode.allCases) { Text($0.displayName).tag($0) }
            }
            Stepper("Limpiar temporales tras \(model.defaultSettings.cleanupTemporaryMaximumAgeDays) días", value: $model.defaultSettings.cleanupTemporaryMaximumAgeDays, in: 1...365)
        } header: { Text("Rendimiento y temporales") }
        footer: {
            Text("Automático limita las conversiones pesadas. La limpieza solo elimina temporales verificables que pertenecen al Conversor.")
        }
    }

    private var zipSection: some View {
        Section {
            HelpPickerRow("Estructura predeterminada", topic: ZEUVEHelpTopics.converterZIPStructure, selection: $model.defaultSettings.zipStructureMode) {
                ForEach(ConverterZIPStructureMode.allCases) { Text($0.displayName).tag($0) }
            }
            Toggle("Empaquetar todos los resultados en un ZIP", isOn: $model.defaultSettings.recompressZIPResults)
            numericField("Máximo de entradas", value: $model.defaultSettings.archiveLimits.entryMaximumCount)
            numericField("Profundidad máxima", value: $model.defaultSettings.archiveLimits.maximumFolderDepth)
            decimalField("Relación máxima de compresión", value: $model.defaultSettings.archiveLimits.compressionRatioMaximum)
            byteField("Tamaño comprimido máximo", value: $model.defaultSettings.archiveLimits.compressedMaximumBytes)
            byteField("Tamaño total descomprimido máximo", value: $model.defaultSettings.archiveLimits.totalDeclaredMaximumBytes)
            byteField("Tamaño máximo por archivo", value: $model.defaultSettings.archiveLimits.individualEntryMaximumBytes)
        } header: {
            HStack { Text("ZIP"); ContextualHelpButton(topic: ZEUVEHelpTopics.converterZIPBomb) }
        } footer: {
            Text("Estos límites son protecciones estructurales. La inspección lee metadatos y muestras mínimas antes de extraer contenido pesado.")
        }
    }

    private var presetsSection: some View {
        Section {
            HStack {
                TextField("Nombre del preajuste", text: $newPresetName)
                Button("Guardar configuración actual") {
                    model.createPreset(name: newPresetName)
                    newPresetName = ""
                }
                .disabled(model.isBusy)
            }
            ForEach(model.presets) { preset in
                HStack {
                    TextField("Nombre", text: Binding(
                        get: { model.presets.first(where: { $0.id == preset.id })?.name ?? preset.name },
                        set: { model.renamePreset(preset.id, to: $0) }
                    ))
                    if preset.isBuiltIn {
                        Text("Oficial").font(.caption).foregroundStyle(.secondary)
                    }
                    Button { model.duplicatePreset(preset.id) } label: { Image(systemName: "plus.square.on.square") }
                        .help("Duplicar preajuste")
                    Button(role: .destructive) { model.deletePreset(preset.id) } label: { Image(systemName: "trash") }
                        .help("Eliminar preajuste")
                        .disabled(preset.isBuiltIn)
                }
            }
            HStack {
                Button("Importar") { model.importPresets() }
                Button("Exportar") { model.exportPresets() }
                Spacer()
                Button("Restaurar oficiales", role: .destructive) { confirmRestorePresets = true }
            }
        } header: {
            HStack { Text("Preajustes"); ContextualHelpButton(topic: ZEUVEHelpTopics.converterPresets) }
        } footer: {
            Text("La creación, edición, importación y restauración se administran aquí. Dentro del módulo solo se seleccionan.")
        }
    }

    private var favoritesSection: some View {
        Section {
            HStack {
                TextField("Nombre de la favorita", text: $newFavoriteName)
                Button("Crear desde la operación actual") {
                    model.createFavorite(name: newFavoriteName)
                    newFavoriteName = ""
                }
                .disabled(model.inputs.isEmpty)
            }
            if model.favorites.isEmpty {
                Text("Todavía no hay favoritas.").foregroundStyle(.secondary)
            }
            ForEach(model.favorites.sorted { ($0.isPinned ? 0 : 1, $0.name.localizedLowercase) < ($1.isPinned ? 0 : 1, $1.name.localizedLowercase) }) { favorite in
                HStack {
                    Button { model.togglePinnedFavorite(favorite.id) } label: {
                        Image(systemName: favorite.isPinned ? "pin.fill" : "pin")
                    }
                    .buttonStyle(.plain)
                    .help(favorite.isPinned ? "Quitar de accesos rápidos" : "Fijar como acceso rápido")
                    TextField("Nombre", text: Binding(
                        get: { model.favorites.first(where: { $0.id == favorite.id })?.name ?? favorite.name },
                        set: { model.renameFavorite(favorite.id, to: $0) }
                    ))
                    Text(favorite.targetFormat?.displayName ?? "Sin formato")
                        .font(.caption).foregroundStyle(.secondary)
                    Button { model.duplicateFavorite(favorite.id) } label: { Image(systemName: "plus.square.on.square") }
                        .help("Duplicar favorita")
                    Button(role: .destructive) { model.deleteFavorite(favorite.id) } label: { Image(systemName: "trash") }
                        .help("Eliminar favorita")
                }
            }
            HStack {
                Button("Importar") { model.importFavorites() }
                Button("Exportar") { model.exportFavorites() }
            }
        } header: { Text("Favoritas") }
        footer: {
            Text("No guardan entradas, contraseñas ni imágenes privadas. La carpeta solo se conserva cuando se solicita expresamente al crearla.")
        }
    }

    private var imageSection: some View {
        Section("Imágenes") {
            Picker("Tamaño predeterminado", selection: $model.defaultSettings.imageResizeMode) {
                ForEach(ConverterImageResizeMode.allCases) { Text($0.displayName).tag($0) }
            }
            if model.defaultSettings.imageResizeMode == .percentage {
                Stepper("Escala: \(model.defaultSettings.imageResizePercentage)%", value: $model.defaultSettings.imageResizePercentage, in: 1...400)
            } else if model.defaultSettings.imageResizeMode == .dimensions {
                Stepper("Ancho máximo: \(model.defaultSettings.imageMaximumWidth)", value: $model.defaultSettings.imageMaximumWidth, in: 1...32_768)
                Stepper("Alto máximo: \(model.defaultSettings.imageMaximumHeight)", value: $model.defaultSettings.imageMaximumHeight, in: 1...32_768)
                Toggle("Mantener proporción", isOn: $model.defaultSettings.imageMaintainAspectRatio)
            }
        }
    }

    private var audioSection: some View {
        Section("Audio") {
            HelpPickerRow("Bitrate", topic: ZEUVEHelpTopics.converterBitrate, selection: $model.defaultSettings.audioBitrate) {
                ForEach(ConverterAudioBitrate.allCases) { Text($0.displayName).tag($0) }
            }
            Picker("Frecuencia de muestreo", selection: $model.defaultSettings.audioSampleRate) {
                ForEach(ConverterAudioSampleRate.allCases) { Text($0.displayName).tag($0) }
            }
            Picker("Canales", selection: $model.defaultSettings.audioChannels) {
                ForEach(ConverterAudioChannels.allCases) { Text($0.displayName).tag($0) }
            }
            Toggle("Normalizar volumen", isOn: $model.defaultSettings.normalizeAudio)
            HelpToggleRow("Conservar portada integrada", topic: ZEUVEHelpTopics.converterCoverArt, isOn: $model.defaultSettings.preserveCoverArt)
        }
    }

    private var videoSection: some View {
        Section("Vídeo") {
            HelpPickerRow("Códec", topic: ZEUVEHelpTopics.converterCodec, selection: $model.defaultSettings.videoCodec) {
                ForEach(ConverterVideoCodec.allCases) { Text($0.displayName).tag($0) }
            }
            Picker("Resolución", selection: $model.defaultSettings.videoResolution) {
                ForEach(ConverterVideoResolution.allCases) { Text($0.displayName).tag($0) }
            }
            if model.defaultSettings.videoResolution == .custom {
                Stepper("Ancho: \(model.defaultSettings.videoWidth)", value: $model.defaultSettings.videoWidth, in: 16...8_192)
                Stepper("Alto: \(model.defaultSettings.videoHeight)", value: $model.defaultSettings.videoHeight, in: 16...8_192)
            }
            Picker("Fotogramas por segundo", selection: $model.defaultSettings.videoFrameRate) {
                ForEach(ConverterVideoFrameRate.allCases) { Text($0.displayName).tag($0) }
            }
            Picker("Audio", selection: $model.defaultSettings.videoAudioMode) {
                ForEach(ConverterVideoAudioMode.allCases) { Text($0.displayName).tag($0) }
            }
            Toggle("Conservar subtítulos", isOn: $model.defaultSettings.preserveSubtitles)
            Toggle("Conservar capítulos", isOn: $model.defaultSettings.preserveChapters)
        }
    }

    private var sequenceSection: some View {
        Section("Secuencias, fotogramas y vídeo desde audio") {
            Picker("Formato de fotogramas", selection: $model.defaultSettings.frameFormat) {
                ForEach(ConverterFrameFormat.allCases) { Text($0.displayName).tag($0) }
            }
            Toggle("16 bits automáticos cuando sea necesario", isOn: $model.defaultSettings.automaticHighBitDepthFrames)
            Toggle("Crear tiempos.csv", isOn: $model.defaultSettings.createFrameTimingCSV)
            Picker("Lienzo de vídeo desde audio", selection: $model.defaultSettings.audioVideoCanvas) {
                ForEach(ConverterVideoCanvas.allCases) { Text($0.displayName).tag($0) }
            }
            if model.defaultSettings.audioVideoCanvas == .custom {
                Stepper("Ancho: \(model.defaultSettings.audioVideoWidth)", value: $model.defaultSettings.audioVideoWidth, in: 16...8_192)
                Stepper("Alto: \(model.defaultSettings.audioVideoHeight)", value: $model.defaultSettings.audioVideoHeight, in: 16...8_192)
            }
            Stepper("Fotogramas por segundo: \(model.defaultSettings.audioVideoFPS)", value: $model.defaultSettings.audioVideoFPS, in: 1...120)
            Picker("Ajuste de imagen", selection: $model.defaultSettings.audioVideoFit) {
                ForEach(ConverterImageFit.allCases) { Text($0.displayName).tag($0) }
            }
        }
    }

    private var pdfSection: some View {
        Section("PDF") {
            HStack {
                HelpLabel("Resolución al exportar páginas", topic: ZEUVEHelpTopics.converterPDFDPI)
                Spacer()
                Stepper("\(model.defaultSettings.pdfRasterDPI) ppp", value: $model.defaultSettings.pdfRasterDPI, in: 72...600, step: 25)
            }
        }
    }

    private var diagnosticsSection: some View {
        Section {
            LabeledContent("Resumen", value: model.engineSummary)
            if let report = model.diagnosticsReport {
                LabeledContent("Motores preparados", value: "\(report.readyEngineCount)")
                LabeledContent("Conversiones disponibles", value: "\(report.compatibilityEntries.count)")
                ForEach(report.checks) { check in
                    DisclosureGroup {
                        Text(check.detail).font(.caption).textSelection(.enabled)
                    } label: {
                        HStack {
                            Text(check.name)
                            Spacer()
                            Text(check.state)
                                .font(.caption)
                                .foregroundStyle(check.state == "Disponible" || check.state == "Correcta" ? .green : .secondary)
                        }
                    }
                }
                DisclosureGroup("Matriz de compatibilidad") {
                    ForEach(report.compatibilityEntries) { entry in
                        HStack(alignment: .firstTextBaseline) {
                            Text("\(entry.inputFormat.displayName) → \(entry.outputFormat.displayName)")
                            Spacer()
                            Text(entry.engine.displayName).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            Button("Actualizar y volver a comprobar") { model.refreshEngineSummary(forceRefresh: true) }
        } header: {
            HStack { Text("Diagnóstico"); ContextualHelpButton(topic: ZEUVEHelpTopics.converterDiagnostics) }
        } footer: {
            Text("Las autocomprobaciones son locales y sintéticas. Un motor ausente oculta automáticamente sus conversiones.")
        }
    }

    private var portabilitySection: some View {
        Section("Importar y exportar ajustes") {
            HStack {
                Button("Importar ajustes") { model.importSettings() }
                Button("Exportar ajustes") { model.exportSettings() }
            }
        }
    }

    private var currentOperationSection: some View {
        Section("Operación actual") {
            Button("Aplicar estos valores a la conversión actual") { model.applyDefaultsToCurrentOperation() }
                .disabled(model.isBusy)
        }
    }

    private var resetSection: some View {
        Section("Restablecer") {
            Button("Restaurar valores predeterminados", role: .destructive) { confirmRestore = true }
        }
    }

    @ViewBuilder
    private func numericField(_ title: String, value: Binding<Int>) -> some View {
        HStack {
            Text(title)
            Spacer()
            TextField(title, value: value, format: .number)
                .multilineTextAlignment(.trailing)
                .frame(width: 150)
        }
    }

    @ViewBuilder
    private func decimalField(_ title: String, value: Binding<Double>) -> some View {
        HStack {
            Text(title)
            Spacer()
            TextField(title, value: value, format: .number.precision(.fractionLength(0...2)))
                .multilineTextAlignment(.trailing)
                .frame(width: 150)
        }
    }

    @ViewBuilder
    private func byteField(_ title: String, value: Binding<Int64>) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(ByteCountFormatter.string(fromByteCount: value.wrappedValue, countStyle: .file))
                .foregroundStyle(.secondary)
            TextField(title, value: value, format: .number)
                .multilineTextAlignment(.trailing)
                .frame(width: 165)
        }
    }
}
