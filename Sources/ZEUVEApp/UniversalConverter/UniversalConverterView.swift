import SwiftUI
import AppKit
import UniversalConverterModule

struct UniversalConverterView: View {
    @EnvironmentObject private var model: UniversalConverterViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                if model.state == .result, let result = model.result { resultView(result) }
                else {
                    inputSection
                    if !model.inputs.isEmpty { recipeSection; outputSection; previewSection }
                    if model.state == .running { runningSection }
                }
            }
            .padding(28)
            .frame(maxWidth: 1_080, alignment: .leading)
        }
        .navigationTitle("Conversor universal")
        .alert("No se ha podido completar la operación", isPresented: Binding(
            get: { model.errorMessage != nil }, set: { if !$0 { model.errorMessage = nil } }
        )) {
            Button("Aceptar", role: .cancel) { model.errorMessage = nil }
        } message: { Text(model.errorMessage ?? "Error desconocido") }
        .alert("Aviso", isPresented: Binding(
            get: { model.warningMessage != nil }, set: { if !$0 { model.warningMessage = nil } }
        )) {
            Button("Aceptar", role: .cancel) { model.warningMessage = nil }
        } message: { Text(model.warningMessage ?? "") }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 34)).frame(width: 64, height: 64)
                .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
            VStack(alignment: .leading, spacing: 5) {
                Text("Conversor universal").font(.largeTitle.bold())
                Text("Convierte imágenes, audio, vídeo, PDF y documentos sin modificar los originales.")
                    .foregroundStyle(.secondary)
                Text(model.engineSummary).font(.caption).foregroundStyle(.tertiary)
            }
            Spacer()
        }
    }

    private var inputSection: some View {
        GroupBox {
            VStack(spacing: 12) {
                VStack(spacing: 8) {
                    Image(systemName: model.isDropTargeted ? "arrow.down.doc.fill" : "doc.on.doc")
                        .font(.system(size: 30)).foregroundStyle(model.isDropTargeted ? Color.accentColor : .secondary)
                    Text(model.state == .scanning ? "Inspeccionando entradas…" : "Arrastra archivos, carpetas o un ZIP")
                        .font(.headline)
                    Text("Elige un archivo, varios archivos o un ZIP. Las carpetas y el arrastrar y soltar siguen disponibles como métodos complementarios.")
                        .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    HStack {
                        Button("Un archivo") { model.chooseSingleInput() }
                        Button("Varios archivos") { model.chooseMultipleInputs() }
                        Button("Un ZIP") { model.chooseZIPInput() }
                    }
                    .disabled(model.isBusy)
                    Button("Seleccionar carpeta…") { model.chooseFolderInput() }
                        .buttonStyle(.link)
                        .disabled(model.isBusy)
                }
                .frame(maxWidth: .infinity, minHeight: 120)
                .background(model.isDropTargeted ? Color.accentColor.opacity(0.08) : Color.secondary.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(model.isDropTargeted ? Color.accentColor : Color.secondary.opacity(0.25), style: StrokeStyle(lineWidth: 1, dash: [6])))
                .onDrop(of: [.fileURL], isTargeted: $model.isDropTargeted, perform: model.handleDrop)

                HStack {
                    HelpLabel("Contraseña del archivo", topic: ZEUVEHelpTopics.converterZIPPassword)
                    Spacer()
                    Group {
                        if model.isArchivePasswordVisible {
                            TextField("Solo si el ZIP o PDF está protegido", text: $model.archivePassword)
                        } else {
                            SecureField("Solo si el ZIP o PDF está protegido", text: $model.archivePassword)
                        }
                    }
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 280)
                    .disabled(model.state == .running)
                    .onChange(of: model.archivePassword) { _, _ in model.archivePasswordChanged() }
                    Button { model.isArchivePasswordVisible.toggle() } label: {
                        Image(systemName: model.isArchivePasswordVisible ? "eye.slash" : "eye")
                    }
                    .buttonStyle(.plain)
                    .help(model.isArchivePasswordVisible ? "Ocultar contraseña" : "Mostrar contraseña")
                    .disabled(model.state == .running)
                }

                if model.state == .scanning { ProgressView().controlSize(.small) }
                if !model.inputs.isEmpty {
                    HStack {
                        Text("\(model.inputs.count) entradas compatibles").font(.subheadline.weight(.semibold))
                        Spacer(); Button("Quitar todas", role: .destructive) { model.clearInputs() }.disabled(model.isBusy)
                    }
                    LazyVStack(spacing: 6) {
                        ForEach(model.inputs.prefix(200)) { item in
                            HStack {
                                Image(systemName: icon(for: item.category)).foregroundStyle(.secondary).frame(width: 22)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.relativePath).lineLimit(1).truncationMode(.middle)
                                    Text("\(item.format.displayName) · \(ByteCountFormatter.string(fromByteCount: item.size, countStyle: .file))")
                                        .font(.caption2).foregroundStyle(.secondary)
                                }
                                Spacer(); Button { model.removeInput(item) } label: { Image(systemName: "xmark.circle.fill") }.buttonStyle(.plain).foregroundStyle(.secondary)
                            }.padding(.vertical, 3)
                        }
                        if model.inputs.count > 200 { Text("Se muestran las primeras 200 entradas.").font(.caption).foregroundStyle(.secondary) }
                    }
                }
                notices(model.scanWarnings, color: .orange)
                notices(model.rejectedInputs.prefix(10).map { $0 }, color: .red, systemImage: "xmark.octagon")
            }.padding(4)
        } label: { HelpLabel("Entradas", topic: ZEUVEHelpTopics.converterInputs) }
    }

    private var recipeSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 14) {
                if !model.favorites.isEmpty {
                    HStack {
                        Label("Favorita", systemImage: "star")
                        Spacer()
                        Picker("", selection: Binding(
                            get: { model.selectedFavoriteID },
                            set: { model.applyFavorite($0) }
                        )) {
                            Text("Ninguna").tag(UUID?.none)
                            ForEach(model.favorites.sorted { lhs, rhs in
                                if lhs.isPinned != rhs.isPinned { return lhs.isPinned && !rhs.isPinned }
                                return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
                            }) { favorite in
                                Text((favorite.isPinned ? "★ " : "") + favorite.name).tag(Optional(favorite.id))
                            }
                        }
                        .labelsHidden()
                        .frame(maxWidth: 360)
                    }
                }
                HStack {
                    HelpLabel("Preajuste", topic: ZEUVEHelpTopics.converterPresets)
                    Spacer()
                    Picker("", selection: Binding(
                        get: { model.selectedPresetID },
                        set: { model.applyPreset($0) }
                    )) {
                        Text("Configuración actual").tag(UUID?.none)
                        ForEach(model.presets) { preset in
                            Text(preset.name).tag(Optional(preset.id))
                        }
                    }
                    .labelsHidden()
                    .frame(maxWidth: 360)
                }

                Picker("Modo", selection: $model.options.advancedMode) {
                    Text("Simple").tag(false); Text("Avanzado").tag(true)
                }.pickerStyle(.segmented).onChange(of: model.options.advancedMode) { _, _ in model.optionsChanged() }

                HStack {
                    HelpLabel("Operación", topic: ZEUVEHelpTopics.converterOperation)
                    Spacer()
                    Picker("", selection: $model.options.operation) {
                        ForEach(model.availableOperations) { Text($0.displayName).tag($0) }
                    }.labelsHidden().frame(maxWidth: 360)
                }.onChange(of: model.options.operation) { _, _ in model.operationChanged() }

                if !model.availableTargetFormats.isEmpty {
                    HStack {
                        Text("Formato de salida")
                        Spacer()
                        Picker("", selection: Binding(get: { model.options.targetFormat ?? model.availableTargetFormats.first ?? .unknown }, set: { model.options.targetFormat = $0; model.optionsChanged() })) {
                            ForEach(model.availableTargetFormats) { Text($0.displayName).tag($0) }
                        }.labelsHidden().frame(maxWidth: 300)
                    }
                }

                HStack {
                    HelpLabel("Calidad", topic: ZEUVEHelpTopics.converterQuality)
                    Spacer()
                    Picker("", selection: $model.options.quality) {
                        ForEach(ConverterQualityProfile.allCases) { Text($0.displayName).tag($0) }
                    }.labelsHidden().frame(maxWidth: 300)
                }.onChange(of: model.options.quality) { _, _ in model.qualityChanged() }

                if model.options.operation == .audioToVideo { audioVideoOptions }
                if model.options.operation == .extractFrames { frameOptions }
                if model.options.operation == .pdfToImages { pdfOptions }

                if model.options.advancedMode {
                    if model.options.operation == .convert, model.inputs.allSatisfy({ $0.category == .image }) { imageAdvancedOptions }
                    if model.options.operation == .extractAudio || model.options.operation == .audioToVideo || (model.options.operation == .convert && model.inputs.allSatisfy({ $0.category == .audio })) { audioAdvancedOptions }
                    if model.options.operation == .convert, model.inputs.allSatisfy({ $0.category == .video }) { videoAdvancedOptions }
                    Divider()
                    HStack {
                        HelpLabel("Metadatos", topic: ZEUVEHelpTopics.converterMetadata)
                        Spacer()
                        Picker("", selection: $model.options.metadataPolicy) {
                            ForEach(ConverterMetadataPolicy.allCases) { Text($0.displayName).tag($0) }
                        }
                        .labelsHidden()
                        .frame(maxWidth: 340)
                    }
                    .onChange(of: model.options.metadataPolicy) { _, _ in model.optionsChanged(markQualityAsCustom: false) }
                    Toggle("Conservar fechas de los archivos", isOn: $model.options.preserveDates).onChange(of: model.options.preserveDates) { _, _ in model.optionsChanged() }
                    HStack { Toggle("Evitar ampliar resolución", isOn: $model.options.avoidUpscaling); ContextualHelpButton(topic: ZEUVEHelpTopics.converterQuality) }
                        .onChange(of: model.options.avoidUpscaling) { _, _ in model.optionsChanged() }
                    HStack {
                        Toggle(
                            model.inputs.allSatisfy({ $0.category == .video })
                                ? "Copia rápida sin recodificar el vídeo"
                                : "Copia rápida sin recodificar pistas compatibles",
                            isOn: $model.options.preferRemuxWhenPossible
                        )
                        ContextualHelpButton(topic: ZEUVEHelpTopics.converterRemux)
                    }
                    .onChange(of: model.options.preferRemuxWhenPossible) { _, _ in model.optionsChanged() }
                    Toggle("Volver a comprimir en ZIP los resultados de una entrada ZIP", isOn: $model.options.recompressZIPResults)
                        .onChange(of: model.options.recompressZIPResults) { _, _ in model.optionsChanged() }
                }
            }.padding(4)
        } label: { Text("Conversión") }
    }

    private var imageAdvancedOptions: some View {
        VStack(alignment: .leading, spacing: 10) {
            Divider()
            Text("Imagen").font(.headline)
            Picker("Tamaño", selection: $model.options.imageResizeMode) {
                ForEach(ConverterImageResizeMode.allCases) { Text($0.displayName).tag($0) }
            }.onChange(of: model.options.imageResizeMode) { _, _ in model.optionsChanged() }
            if model.options.imageResizeMode == .percentage {
                Stepper("Escala: \(model.options.imageResizePercentage)%", value: $model.options.imageResizePercentage, in: 1...400)
                    .onChange(of: model.options.imageResizePercentage) { _, _ in model.optionsChanged() }
            } else if model.options.imageResizeMode == .dimensions {
                HStack {
                    Stepper("Ancho máximo: \(model.options.imageMaximumWidth)", value: $model.options.imageMaximumWidth, in: 1...32768)
                    Stepper("Alto máximo: \(model.options.imageMaximumHeight)", value: $model.options.imageMaximumHeight, in: 1...32768)
                }
                .onChange(of: model.options.imageMaximumWidth) { _, _ in model.optionsChanged() }
                .onChange(of: model.options.imageMaximumHeight) { _, _ in model.optionsChanged() }
                Toggle("Mantener proporción", isOn: $model.options.imageMaintainAspectRatio)
                    .onChange(of: model.options.imageMaintainAspectRatio) { _, _ in model.optionsChanged() }
            }
        }
    }

    private var audioAdvancedOptions: some View {
        VStack(alignment: .leading, spacing: 10) {
            Divider()
            Text("Audio").font(.headline)
            Picker("Bitrate", selection: $model.options.audioBitrate) {
                ForEach(ConverterAudioBitrate.allCases) { Text($0.displayName).tag($0) }
            }.onChange(of: model.options.audioBitrate) { _, _ in model.optionsChanged() }
            Picker("Frecuencia de muestreo", selection: $model.options.audioSampleRate) {
                ForEach(ConverterAudioSampleRate.allCases) { Text($0.displayName).tag($0) }
            }.onChange(of: model.options.audioSampleRate) { _, _ in model.optionsChanged() }
            Picker("Canales", selection: $model.options.audioChannels) {
                ForEach(ConverterAudioChannels.allCases) { Text($0.displayName).tag($0) }
            }.onChange(of: model.options.audioChannels) { _, _ in model.optionsChanged() }
            Toggle("Normalizar volumen", isOn: $model.options.normalizeAudio)
                .onChange(of: model.options.normalizeAudio) { _, _ in model.optionsChanged() }
            if model.options.operation == .convert, model.inputs.allSatisfy({ $0.category == .audio }) {
                HStack {
                    Toggle("Conservar portada integrada", isOn: $model.options.preserveCoverArt)
                    ContextualHelpButton(topic: ZEUVEHelpTopics.converterCoverArt)
                }
                .onChange(of: model.options.preserveCoverArt) { _, _ in model.optionsChanged() }
            }
        }
    }

    private var videoAdvancedOptions: some View {
        VStack(alignment: .leading, spacing: 10) {
            Divider()
            Text("Vídeo").font(.headline)
            Picker("Códec", selection: $model.options.videoCodec) {
                ForEach(ConverterVideoCodec.allCases) { Text($0.displayName).tag($0) }
            }.onChange(of: model.options.videoCodec) { _, _ in model.optionsChanged() }
            Picker("Resolución", selection: $model.options.videoResolution) {
                ForEach(ConverterVideoResolution.allCases) { Text($0.displayName).tag($0) }
            }.onChange(of: model.options.videoResolution) { _, _ in model.optionsChanged() }
            if model.options.videoResolution == .custom {
                HStack {
                    Stepper("Ancho: \(model.options.videoWidth)", value: $model.options.videoWidth, in: 16...8192)
                    Stepper("Alto: \(model.options.videoHeight)", value: $model.options.videoHeight, in: 16...8192)
                }
                .onChange(of: model.options.videoWidth) { _, _ in model.optionsChanged() }
                .onChange(of: model.options.videoHeight) { _, _ in model.optionsChanged() }
            }
            Picker("Fotogramas por segundo", selection: $model.options.videoFrameRate) {
                ForEach(ConverterVideoFrameRate.allCases) { Text($0.displayName).tag($0) }
            }.onChange(of: model.options.videoFrameRate) { _, _ in model.optionsChanged() }
            Picker("Audio", selection: $model.options.videoAudioMode) {
                ForEach(ConverterVideoAudioMode.allCases) { Text($0.displayName).tag($0) }
            }.onChange(of: model.options.videoAudioMode) { _, _ in model.optionsChanged() }
            Toggle("Conservar subtítulos", isOn: $model.options.preserveSubtitles)
                .onChange(of: model.options.preserveSubtitles) { _, _ in model.optionsChanged() }
            Toggle("Conservar capítulos", isOn: $model.options.preserveChapters)
                .onChange(of: model.options.preserveChapters) { _, _ in model.optionsChanged() }
        }
    }

    private var audioVideoOptions: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("Fondo", selection: $model.options.audioVideoBackground) {
                ForEach(ConverterAudioVideoBackground.allCases) { Text($0.displayName).tag($0) }
            }.pickerStyle(.segmented).onChange(of: model.options.audioVideoBackground) { _, _ in model.optionsChanged() }
            if model.options.audioVideoBackground == .image {
                HStack {
                    Text(model.options.audioVideoImageURL?.lastPathComponent ?? "Ninguna imagen seleccionada").lineLimit(1)
                    Spacer(); Button("Elegir imagen") { model.chooseAudioVideoImage() }
                }
            }
            Picker("Lienzo", selection: $model.options.audioVideoCanvas) {
                ForEach(ConverterVideoCanvas.allCases) { Text($0.displayName).tag($0) }
            }.onChange(of: model.options.audioVideoCanvas) { _, _ in model.optionsChanged() }
            if model.options.audioVideoCanvas == .custom {
                HStack {
                    Stepper("Ancho: \(model.options.audioVideoWidth)", value: $model.options.audioVideoWidth, in: 16...8192)
                    Stepper("Alto: \(model.options.audioVideoHeight)", value: $model.options.audioVideoHeight, in: 16...8192)
                }.onChange(of: model.options.audioVideoWidth) { _, _ in model.optionsChanged() }
                 .onChange(of: model.options.audioVideoHeight) { _, _ in model.optionsChanged() }
            }
            Picker("Ajuste de imagen", selection: $model.options.audioVideoFit) {
                ForEach(ConverterImageFit.allCases) { Text($0.displayName).tag($0) }
            }.onChange(of: model.options.audioVideoFit) { _, _ in model.optionsChanged() }
        }
    }

    private var frameOptions: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack { HelpLabel("Formato de fotogramas", topic: ZEUVEHelpTopics.converterFrames); Spacer(); Picker("", selection: $model.options.frameFormat) { ForEach(ConverterFrameFormat.allCases) { Text($0.displayName).tag($0) } }.labelsHidden() }
                .onChange(of: model.options.frameFormat) { _, _ in model.optionsChanged() }
            Toggle("Usar 16 bits automáticamente cuando la fuente lo requiera", isOn: $model.options.automaticHighBitDepthFrames).onChange(of: model.options.automaticHighBitDepthFrames) { _, _ in model.optionsChanged() }
            Toggle("Crear tiempos.csv", isOn: $model.options.createFrameTimingCSV).onChange(of: model.options.createFrameTimingCSV) { _, _ in model.optionsChanged() }
        }
    }

    private var pdfOptions: some View {
        HStack {
            HelpLabel("Resolución", topic: ZEUVEHelpTopics.converterPDFDPI)
            Spacer(); Stepper("\(model.options.pdfRasterDPI) ppp", value: $model.options.pdfRasterDPI, in: 72...600, step: 25)
        }.onChange(of: model.options.pdfRasterDPI) { _, _ in model.optionsChanged() }
    }

    private var outputSection: some View {
        GroupBox("Salida") {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label(model.outputFolder?.path ?? "Selecciona una carpeta", systemImage: "folder")
                        .lineLimit(1).truncationMode(.middle)
                    Spacer()
                    Button("Elegir carpeta") { model.chooseOutputFolder() }.disabled(model.isBusy)
                }
                Picker("Ubicación", selection: $model.options.outputFolderMode) {
                    ForEach(ConverterOutputFolderMode.allCases) { Text($0.displayName).tag($0) }
                }
                .onChange(of: model.options.outputFolderMode) { _, _ in model.optionsChanged(markQualityAsCustom: false) }
                if model.options.outputFolderMode == .subfolder {
                    TextField("Nombre de la subcarpeta", text: $model.options.outputSubfolderName)
                        .onChange(of: model.options.outputSubfolderName) { _, _ in model.optionsChanged(markQualityAsCustom: false) }
                }
                if model.inputs.contains(where: \.isFromArchive) {
                    Picker("Estructura del ZIP", selection: $model.options.zipStructureMode) {
                        ForEach(ConverterZIPStructureMode.allCases) { Text($0.displayName).tag($0) }
                    }
                    .onChange(of: model.options.zipStructureMode) { _, _ in model.optionsChanged(markQualityAsCustom: false) }
                }
                HStack {
                    HelpLabel("Si ya existe el nombre", topic: ZEUVEHelpTopics.converterConflict)
                    Spacer()
                    Picker("", selection: $model.options.conflictPolicy) {
                        ForEach(ConverterConflictPolicy.allCases) { Text($0.displayName).tag($0) }
                    }
                    .labelsHidden().frame(maxWidth: 300)
                }
                .onChange(of: model.options.conflictPolicy) { _, _ in model.optionsChanged(markQualityAsCustom: false) }
                HStack {
                    Text("Estilo de nombre")
                    Spacer()
                    Picker("", selection: $model.options.filenameStyle) {
                        ForEach(ConverterFilenameStyle.allCases) { Text($0.displayName).tag($0) }
                    }
                    .labelsHidden().frame(maxWidth: 300)
                }
                .onChange(of: model.options.filenameStyle) { _, _ in model.optionsChanged(markQualityAsCustom: false) }
                if model.options.advancedMode {
                    TextField("Prefijo", text: $model.options.filenamePrefix)
                        .onChange(of: model.options.filenamePrefix) { _, _ in model.optionsChanged(markQualityAsCustom: false) }
                    TextField("Sufijo", text: $model.options.filenameSuffix)
                        .onChange(of: model.options.filenameSuffix) { _, _ in model.optionsChanged(markQualityAsCustom: false) }
                    TextField("Separador", text: $model.options.filenameSeparator)
                        .onChange(of: model.options.filenameSeparator) { _, _ in model.optionsChanged(markQualityAsCustom: false) }
                }
            }
            .padding(4)
        }
    }

    private var previewSection: some View {
        GroupBox("Vista previa") {
            VStack(alignment: .leading, spacing: 12) {
                if let plan = model.plan {
                    HStack {
                        Text("\(plan.items.count) operaciones preparadas").font(.headline)
                        Spacer()
                        if let bytes = plan.estimatedOutputBytes {
                            Text("Estimación: \(ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file))")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 4) {
                        GridRow { Text("Destino").foregroundStyle(.secondary); Text(plan.outputFolder.path).lineLimit(1).truncationMode(.middle) }
                        GridRow { Text("Preajuste").foregroundStyle(.secondary); Text(plan.options.quality.displayName) }
                        GridRow { Text("Metadatos").foregroundStyle(.secondary); Text(plan.options.metadataPolicy.displayName) }
                        GridRow { Text("ZIP").foregroundStyle(.secondary); Text(plan.options.zipStructureMode.displayName) }
                        if let available = plan.availableOutputBytes {
                            GridRow { Text("Espacio disponible").foregroundStyle(.secondary); Text(ByteCountFormatter.string(fromByteCount: available, countStyle: .file)) }
                        }
                        if let margin = plan.safetyMarginBytes {
                            GridRow { Text("Margen de seguridad").foregroundStyle(.secondary); Text(ByteCountFormatter.string(fromByteCount: margin, countStyle: .file)) }
                        }
                    }
                    .font(.caption)
                    if plan.mayHaveInsufficientSpace {
                        Label("El espacio disponible puede ser insuficiente.", systemImage: "externaldrive.badge.exclamationmark")
                            .font(.caption).foregroundStyle(.red)
                    }
                    ForEach(plan.items.prefix(100)) { item in
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.sources.map(\.displayName).joined(separator: ", ")).lineLimit(1)
                                Text(item.destinationRelativePath).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                                ForEach(item.warnings, id: \.self) { Text($0).font(.caption2).foregroundStyle(.orange) }
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(item.targetFormat.displayName).font(.caption.weight(.medium))
                                Text(item.executionKind.rawValue).font(.caption2).foregroundStyle(.secondary)
                            }
                        }.padding(.vertical, 4)
                    }
                    notices(plan.warnings, color: .orange)
                    HStack {
                        Spacer()
                        Button("Convertir") { model.executePlan() }.buttonStyle(.borderedProminent).disabled(!model.canExecute)
                    }
                } else if model.outputFolder == nil {
                    Text("Selecciona la carpeta de salida para preparar la vista previa.").foregroundStyle(.secondary)
                } else {
                    ProgressView("Preparando vista previa…").controlSize(.small)
                }
            }.padding(4)
        }
    }

    private var runningSection: some View {
        GroupBox("Conversión en curso") {
            VStack(alignment: .leading, spacing: 10) {
                if let progress = model.progress {
                    if let fraction = progress.overallFraction { ProgressView(value: fraction) } else { ProgressView() }
                    if let currentItem = progress.currentItem {
                        Text(currentItem).font(.caption).foregroundStyle(.secondary)
                        Text(progress.phase).font(.caption2).foregroundStyle(.tertiary)
                    } else {
                        Text(progress.phase).font(.caption).foregroundStyle(.secondary)
                    }
                    Text("\(progress.completedItems) correctos · \(progress.failedItems) fallidos · \(progress.skippedItems) omitidos · \(progress.cancelledItems) cancelados")
                        .font(.caption2).foregroundStyle(.tertiary)
                    HStack {
                        Text("Transcurrido: \(durationText(progress.elapsed))")
                        if let remaining = progress.estimatedRemaining { Text("Restante aprox.: \(durationText(remaining))") }
                    }
                    .font(.caption2).foregroundStyle(.tertiary)
                    ForEach(progress.itemStates.prefix(8)) { item in
                        HStack {
                            Image(systemName: progressIcon(item.status)).frame(width: 16)
                            Text(item.sourceNames.joined(separator: ", ")).lineLimit(1)
                            Spacer()
                            if let fraction = item.fraction { Text(fraction.formatted(.percent.precision(.fractionLength(0)))) }
                        }
                        .font(.caption2)
                    }
                } else { ProgressView("Iniciando…") }
                HStack { Spacer(); Button("Cancelar", role: .destructive) { model.cancel() } }
            }.padding(4)
        }
    }

    private func resultView(_ result: UniversalConverterResult) -> some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 14) {
                Label("Conversión terminada", systemImage: result.failedCount == 0 ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .font(.title2.bold()).foregroundStyle(result.failedCount == 0 ? Color.green : Color.orange)
                HStack(spacing: 18) {
                    summary("Correctos", result.completedCount, .green)
                    summary("Omitidos", result.skippedCount, .orange)
                    summary("Fallidos", result.failedCount, .red)
                    summary("Cancelados", result.cancelledCount, .secondary)
                }
                ForEach(result.items) { item in
                    HStack(alignment: .top) {
                        Image(systemName: statusIcon(item.status)).foregroundStyle(statusColor(item.status))
                        VStack(alignment: .leading) {
                            Text(item.sourceNames.joined(separator: ", ")).lineLimit(1)
                            if let message = item.message { Text(message).font(.caption).foregroundStyle(.secondary) }
                        }
                    }
                }
                Text("Duración total: \(durationText(result.duration))").font(.caption).foregroundStyle(.secondary)
                if let first = result.generatedFiles.first {
                    Button("Abrir primer resultado") { NSWorkspace.shared.open(first) }
                }
                HStack {
                    Button("Abrir carpeta de resultados") { NSWorkspace.shared.open(result.outputFolder) }
                    if let archive = result.archiveURL { Button("Abrir ZIP final") { NSWorkspace.shared.open(archive) } }
                    Button("Guardar como favorita") { model.createFavorite(name: "Conversión desde resultado") }
                    Spacer()
                    Button("Cerrar resultado") { model.closeResultKeepingInputs() }
                    Button("Otra conversión") { model.newConversion() }.buttonStyle(.borderedProminent)
                }
            }.padding(6)
        }
    }

    private func notices(_ values: [String], color: Color, systemImage: String = "exclamationmark.triangle") -> some View {
        ForEach(values, id: \.self) { value in
            Label(value, systemImage: systemImage).font(.caption).foregroundStyle(color)
        }
    }

    private func summary(_ title: String, _ value: Int, _ color: Color) -> some View {
        VStack(alignment: .leading) { Text(value.formatted()).font(.title2.bold()).foregroundStyle(color); Text(title).font(.caption).foregroundStyle(.secondary) }
    }
    private func icon(for category: ConverterCategory) -> String {
        switch category {
        case .image: return "photo"
        case .vectorImage: return "scribble.variable"
        case .animation: return "photo.stack"
        case .audio: return "waveform"
        case .video: return "film"
        case .pdf: return "doc.richtext"
        case .text, .markup, .data: return "text.alignleft"
        case .ebook: return "book.closed"
        case .archive: return "archivebox"
        case .unknown: return "questionmark.square"
        }
    }

    private func progressIcon(_ status: ConverterProgressItemStatus) -> String {
        switch status {
        case .pending: return "circle"
        case .running: return "arrow.triangle.2.circlepath"
        case .completed: return "checkmark.circle"
        case .skipped: return "minus.circle"
        case .failed: return "xmark.circle"
        case .cancelled: return "stop.circle"
        }
    }

    private func durationText(_ seconds: TimeInterval) -> String {
        let total = max(Int(seconds.rounded()), 0)
        if total < 60 { return "\(total) s" }
        let minutes = total / 60
        let remainder = total % 60
        if minutes < 60 { return "\(minutes) min \(remainder) s" }
        return "\(minutes / 60) h \(minutes % 60) min"
    }
    private func statusIcon(_ status: ConverterItemResultStatus) -> String {
        switch status { case .completed: return "checkmark.circle"; case .skipped: return "minus.circle"; case .failed: return "xmark.circle"; case .cancelled: return "stop.circle" }
    }
    private func statusColor(_ status: ConverterItemResultStatus) -> Color {
        switch status { case .completed: return .green; case .skipped: return .orange; case .failed: return .red; case .cancelled: return .secondary }
    }
}
