import SwiftUI
import UniformTypeIdentifiers
import YouTubeDownloaderModule

struct YouTubeDownloaderView: View {
    @EnvironmentObject private var model: YouTubeDownloaderViewModel
    @State private var confirmReplacement = false

    var body: some View {
        ZStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 20) {
                    header
                    if let unavailable = model.unavailableMessage {
                        ContentUnavailableView("Descargador no disponible", systemImage: "wrench.and.screwdriver", description: Text(unavailable))
                    }
                    urlCard
                    validationSummary
                    analysisFailureSummary
                    if !model.analyses.isEmpty {
                        analysisCards
                        settingsCard
                        outputCard
                        summaryCard
                    }
                }
                .padding(28)
                .frame(maxWidth: 1_120, alignment: .leading)
            }
            if model.state.isBusy { progressOverlay }
        }
        .navigationTitle("Descargador de YouTube")
        .sheet(item: $model.completion) { result in YouTubeCompletionView(result: result).environmentObject(model) }
        .alert("No se ha podido completar la operación", isPresented: Binding(get: { model.errorMessage != nil }, set: { if !$0 { model.errorMessage = nil } })) {
            Button("Aceptar", role: .cancel) { model.errorMessage = nil }
        } message: { Text(model.errorMessage ?? "Error desconocido") }
        .confirmationDialog("¿Reemplazar los archivos existentes?", isPresented: $confirmReplacement, titleVisibility: .visible) {
            Button("Reemplazar archivos", role: .destructive) { model.downloadReplacingConfirmed() }
            Button("Cancelar", role: .cancel) { }
        } message: { Text("Los archivos existentes con el mismo nombre serán sustituidos. Esta acción no se puede deshacer.") }
        .onDrop(of: [.plainText, .url], isTargeted: nil) { providers in
            for provider in providers {
                _ = provider.loadObject(ofClass: NSString.self) { value, _ in
                    guard let text = value as? String else { return }
                    Task { @MainActor in model.addDroppedText(text) }
                }
            }
            return true
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Descargador de YouTube").font(.largeTitle.bold())
            Text("Analiza primero el contenido y decide después qué quieres guardar.").font(.title3).foregroundStyle(.secondary)
            Label("Internet solo se utiliza al analizar o descargar", systemImage: "network.badge.shield.half.filled")
                .font(.callout.weight(.medium)).foregroundStyle(.blue)
        }
    }

    private var urlCard: some View {
        GroupBox("Enlaces") {
            VStack(alignment: .leading, spacing: 12) {
                TextEditor(text: $model.inputText)
                    .font(.body.monospaced())
                    .frame(minHeight: 95)
                    .padding(6)
                    .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
                    .onChange(of: model.inputText) { _, _ in model.validateInput() }
                HStack {
                    Button("Pegar", systemImage: "doc.on.clipboard") { model.pasteFromClipboard() }
                    Button("Analizar", systemImage: "magnifyingglass") { model.analyse() }
                        .buttonStyle(.borderedProminent)
                        .disabled(model.acceptedURLs.isEmpty || model.state.isBusy || model.unavailableMessage != nil)
                    Spacer()
                    Text("También puedes arrastrar enlaces aquí").font(.caption).foregroundStyle(.secondary)
                }
            }.padding(8)
        }
    }

    @ViewBuilder private var validationSummary: some View {
        if !model.acceptedURLs.isEmpty || !model.rejected.isEmpty || !model.duplicates.isEmpty {
            GroupBox("Revisión de enlaces") {
                VStack(alignment: .leading, spacing: 8) {
                    Label("\(model.acceptedURLs.count) enlaces válidos", systemImage: "checkmark.circle").foregroundStyle(.green)
                    if !model.duplicates.isEmpty { Label("\(model.duplicates.count) duplicados eliminados", systemImage: "doc.on.doc").foregroundStyle(.orange) }
                    ForEach(model.rejected.keys.sorted(), id: \.self) { value in
                        Label("\(value): \(model.rejected[value] ?? "No compatible")", systemImage: "xmark.circle").foregroundStyle(.red)
                    }
                }.padding(8)
            }
        }
    }

    @ViewBuilder private var analysisFailureSummary: some View {
        if !model.analysisFailures.isEmpty {
            GroupBox("Enlaces que no se han podido analizar") {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(model.analysisFailures) { failure in
                        VStack(alignment: .leading, spacing: 3) {
                            Label(failure.canonicalID, systemImage: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                            Text(failure.userMessage).font(.caption).foregroundStyle(.secondary)
                            Text("Referencia: \(failure.technicalReference)").font(.caption2).foregroundStyle(.tertiary)
                        }
                    }
                }.padding(8)
            }
        }
    }

    private var analysisCards: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Contenido analizado").font(.title2.bold())
            ForEach(model.analyses) { analysis in
                GroupBox {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .top) {
                            if let thumbnail = analysis.thumbnailURL {
                                AsyncImage(url: thumbnail) { phase in
                                    if let image = phase.image {
                                        image.resizable().scaledToFill()
                                    } else {
                                        Image(systemName: "photo").font(.title).foregroundStyle(.secondary)
                                    }
                                }
                                .frame(width: 144, height: 81)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            } else {
                                Image(systemName: analysis.kind == .playlist ? "list.number" : "play.rectangle")
                                    .font(.title).frame(width: 44)
                            }
                            VStack(alignment: .leading, spacing: 3) {
                                Text(analysis.title).font(.headline)
                                if let uploader = analysis.uploader { Text(uploader).foregroundStyle(.secondary) }
                                HStack(spacing: 10) {
                                    if let duration = analysis.duration { Text(durationText(duration)) }
                                    if let date = analysis.publicationDate { Text(date.formatted(date: .abbreviated, time: .omitted)) }
                                    if analysis.kind == .video { Text("\(analysis.formats.count) formatos") }
                                    if !analysis.subtitles.isEmpty { Text("\(analysis.subtitles.count) pistas de subtítulos") }
                                }.font(.caption).foregroundStyle(.secondary)
                                Text(analysis.liveStatus.spanishDescription).font(.caption).foregroundStyle(analysis.liveStatus.canDownloadInVersion020 ? Color.secondary : Color.orange)
                            }
                            Spacer()
                            if analysis.kind == .video {
                                Toggle("Seleccionar", isOn: selectionBinding(analysis: analysis)).toggleStyle(.checkbox).disabled(!analysis.isDownloadable)
                            }
                        }
                        if analysis.kind == .playlist { playlistEntries(analysis) }
                    }.padding(8)
                }
            }
        }
    }

    private func playlistEntries(_ analysis: YouTubeMediaAnalysis) -> some View {
        YouTubePlaylistSelectionView(analysis: analysis)
            .environmentObject(model)
    }

    private var settingsCard: some View {
        GroupBox("Configuración") {
            VStack(alignment: .leading, spacing: 14) {
                if !model.presets.isEmpty {
                    HelpPickerRow(
                        "Aplicar preset",
                        topic: ZEUVEHelpTopics.quickPreset,
                        selection: quickPresetSelection
                    ) {
                        Text("Selecciona un preset").tag("")
                        ForEach(model.presets) { preset in
                            Text(preset.name).tag(preset.id.uuidString)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    HelpLabel("Modo", topic: ZEUVEHelpTopics.interfaceMode)
                    Picker("", selection: $model.advancedMode) {
                        Text("Simple").tag(false)
                        Text("Avanzado").tag(true)
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                }

                VStack(alignment: .leading, spacing: 6) {
                    HelpLabel("Contenido", topic: ZEUVEHelpTopics.downloadContent)
                    Picker("", selection: $model.settings.mode) {
                        Text("Vídeo").tag(YouTubeDownloadMode.video)
                        Text("Solo audio").tag(YouTubeDownloadMode.audio)
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                }

                if model.settings.mode == .video {
                    HelpPickerRow(
                        "Resolución máxima",
                        topic: ZEUVEHelpTopics.maximumResolution,
                        selection: $model.settings.maximumResolution
                    ) {
                        ForEach(YouTubeMaximumResolution.allCases) { resolution in
                            Text(resolution.spanishName).tag(resolution)
                        }
                    }

                    HelpPickerRow(
                        "Formato del archivo",
                        topic: ZEUVEHelpTopics.videoFormat,
                        selection: $model.settings.container
                    ) {
                        ForEach(YouTubeContainerPreference.allCases) { container in
                            Text(container.spanishName).tag(container)
                        }
                    }

                    if model.advancedMode {
                        HelpPickerRow(
                            "Rango dinámico",
                            topic: ZEUVEHelpTopics.dynamicRange,
                            selection: $model.settings.hdrPreference
                        ) {
                            Text("Automático").tag(YouTubeHDRPreference.automatic)
                            Text("Preferir SDR").tag(YouTubeHDRPreference.preferSDR)
                            Text("Preferir HDR").tag(YouTubeHDRPreference.preferHDR)
                        }
                    }
                } else {
                    HelpPickerRow(
                        "Formato de audio",
                        topic: ZEUVEHelpTopics.audioFormat,
                        selection: $model.settings.audioOutput
                    ) {
                        ForEach(YouTubeAudioOutput.allCases) { output in
                            Text(output.spanishName).tag(output)
                        }
                    }

                    if model.settings.audioOutput == .mp3 {
                        HelpPickerRow(
                            "Calidad MP3",
                            topic: ZEUVEHelpTopics.mp3Bitrate,
                            selection: $model.settings.mp3Bitrate
                        ) {
                            ForEach(YouTubeMP3Bitrate.allCases) { bitrate in
                                Text(bitrate.spanishName).tag(bitrate)
                            }
                        }
                    }

                    if model.settings.audioOutput.requiresTranscoding {
                        Label("La conversión puede ser con pérdida y no mejora la calidad de origen.", systemImage: "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }

                if model.advancedMode { advancedOptions }
            }
            .padding(8)
        }
    }

    private var advancedOptions: some View {
        DisclosureGroup("Opciones avanzadas") {
            VStack(alignment: .leading, spacing: 12) {
                if model.settings.mode == .video {
                    HelpPickerRow(
                        "Flujo de vídeo exacto",
                        topic: ZEUVEHelpTopics.exactVideoStream,
                        selection: exactVideoFormatBinding
                    ) {
                        Text("Selección automática").tag("")
                        ForEach(model.availableVideoFormats) { format in
                            Text(formatLabel(format)).tag(format.formatID)
                        }
                    }
                    HelpPickerRow(
                        "Flujo de audio exacto",
                        topic: ZEUVEHelpTopics.exactAudioStream,
                        selection: exactAudioFormatBinding
                    ) {
                        Text("Mejor audio automático").tag("")
                        ForEach(model.availableAudioFormats) { format in
                            Text(formatLabel(format)).tag(format.formatID)
                        }
                    }
                    if model.exactFormatAnalysis == nil {
                        Text("La selección exacta se habilita cuando hay un único vídeo seleccionado. Para lotes se utilizan reglas automáticas compatibles.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Divider()
                } else {
                    HelpPickerRow(
                        "Flujo de audio exacto",
                        topic: ZEUVEHelpTopics.exactAudioStream,
                        selection: exactAudioFormatBinding
                    ) {
                        Text("Selección automática").tag("")
                        ForEach(model.availableAudioFormats) { format in
                            Text(formatLabel(format)).tag(format.formatID)
                        }
                    }
                    Divider()
                }

                HelpToggleRow("Incrustar metadatos", topic: ZEUVEHelpTopics.embedMetadata, isOn: $model.settings.metadata.embedMetadata)
                HelpToggleRow("Incrustar miniatura", topic: ZEUVEHelpTopics.thumbnails, isOn: $model.settings.metadata.embedThumbnail)
                HelpToggleRow("Guardar miniatura por separado", topic: ZEUVEHelpTopics.thumbnails, isOn: $model.settings.metadata.saveThumbnail)
                HelpToggleRow("Añadir capítulos", topic: ZEUVEHelpTopics.chapters, isOn: $model.settings.metadata.addChapters)
                HelpToggleRow("Guardar descripción", topic: ZEUVEHelpTopics.descriptionAndJSON, isOn: $model.settings.metadata.saveDescription)
                HelpToggleRow("Guardar JSON informativo", topic: ZEUVEHelpTopics.descriptionAndJSON, isOn: $model.settings.metadata.saveInfoJSON)
                HelpToggleRow("Conservar la fecha de publicación cuando sea posible", topic: ZEUVEHelpTopics.publicationDate, isOn: $model.settings.metadata.preservePublicationDate)
                HelpToggleRow("Guardar metadatos de la lista seleccionada", topic: ZEUVEHelpTopics.descriptionAndJSON, isOn: $model.settings.metadata.savePlaylistMetadata)

                Divider()
                HStack(spacing: 6) {
                    TextField("Idiomas de subtítulos, separados por comas", text: subtitleLanguages)
                    ContextualHelpButton(topic: ZEUVEHelpTopics.subtitles)
                }
                if !model.availableSubtitleTracks.isEmpty {
                    ScrollView(.horizontal) {
                        HStack {
                            ForEach(model.availableSubtitleTracks) { track in
                                Button { toggleSubtitle(track.languageCode) } label: {
                                    Label(
                                        track.languageCode + (track.kind == .automatic ? " · automático" : " · manual"),
                                        systemImage: model.settings.subtitles.languages.contains(track.languageCode) ? "checkmark.circle.fill" : "circle"
                                    )
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    }
                    Text("Los subtítulos manuales los aporta el canal. Los automáticos los genera YouTube y pueden contener errores.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                HelpToggleRow("Incluir subtítulos automáticos", topic: ZEUVEHelpTopics.subtitles, isOn: $model.settings.subtitles.includeAutomatic)
                HelpToggleRow("Incrustar subtítulos", topic: ZEUVEHelpTopics.subtitles, isOn: $model.settings.subtitles.embed)
                HelpToggleRow("Convertir subtítulos a SRT", topic: ZEUVEHelpTopics.subtitles, isOn: $model.settings.subtitles.convertToSRT)

                Divider()
                HelpToggleRow("Usar proxy solo en esta operación", topic: ZEUVEHelpTopics.proxy, isOn: $model.proxyEnabled)
                if model.proxyEnabled {
                    TextField("https://proxy.ejemplo:8080", text: $model.proxyAddress)
                    TextField("Usuario opcional", text: $model.proxyUsername)
                    SecureField("Contraseña (no se guardará)", text: $model.proxyPassword)
                }
                HelpStepperRow(
                    "Reintentos: \(model.settings.network.retryCount)",
                    topic: ZEUVEHelpTopics.retries,
                    value: $model.settings.network.retryCount,
                    in: 0...100
                )
                HelpStepperRow(
                    "Fragmentos simultáneos: \(model.settings.network.concurrentFragments)",
                    topic: ZEUVEHelpTopics.concurrentFragments,
                    value: $model.settings.network.concurrentFragments,
                    in: 1...16
                )
                HStack {
                    HelpLabel("Cookies", topic: ZEUVEHelpTopics.cookies)
                    Text(model.cookiesFile?.lastPathComponent ?? "No se utilizan")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Seleccionar cookies.txt") { model.chooseCookiesFile() }
                    if model.cookiesFile != nil { Button("Quitar") { model.clearCookiesFile() } }
                }
            }
            .padding(.top, 8)
        }
    }

    private var outputCard: some View {
        GroupBox("Salida") {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label(model.outputFolder?.path(percentEncoded: false) ?? "No seleccionada", systemImage: "folder")
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                    Button("Elegir carpeta") { model.chooseOutputFolder() }
                }
                HelpPickerRow(
                    "Nombre de archivo",
                    topic: ZEUVEHelpTopics.filename,
                    selection: $model.settings.filenamePreset
                ) {
                    Text("Título").tag(YouTubeFilenamePreset.title)
                    Text("Título e ID").tag(YouTubeFilenamePreset.titleAndID)
                    Text("Fecha y título").tag(YouTubeFilenamePreset.dateAndTitle)
                    Text("Canal y título").tag(YouTubeFilenamePreset.channelAndTitle)
                    Text("Índice y título").tag(YouTubeFilenamePreset.playlistIndexAndTitle)
                    Text("Lista, índice y título").tag(YouTubeFilenamePreset.playlistAndIndexAndTitle)
                }
                HelpPickerRow(
                    "Conflictos",
                    topic: ZEUVEHelpTopics.fileConflicts,
                    selection: $model.settings.conflictPolicy
                ) {
                    Text("Renombrar automáticamente").tag(YouTubeConflictPolicy.renameAutomatically)
                    Text("Omitir").tag(YouTubeConflictPolicy.skip)
                    Text("Reemplazar con confirmación").tag(YouTubeConflictPolicy.replaceConfirmed)
                }
                HelpToggleRow("Crear una carpeta para la lista", topic: ZEUVEHelpTopics.playlistFolder, isOn: $model.settings.createPlaylistFolder)
                HelpToggleRow("Numerar elementos de listas", topic: ZEUVEHelpTopics.playlistNumbering, isOn: $model.settings.numberPlaylistItems)
            }
            .padding(8)
        }
    }

    private var summaryCard: some View {
        GroupBox("Resumen") {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text("\(model.selectedDownloadItems().count) elementos seleccionados").font(.headline)
                    if let estimate = estimatedSelectedBytes {
                        Text("Tamaño estimado: " + ByteCountFormatter.string(fromByteCount: estimate, countStyle: .file))
                            .font(.caption).foregroundStyle(.secondary)
                    } else {
                        Text("El tamaño total no está disponible para todos los elementos.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Text(model.formatExplanation).font(.caption).foregroundStyle(.secondary)
                    if let preview = model.expectedFilenamePreview() {
                        Text("Nombre previsto: " + preview).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                    }
                    if model.settings.metadata.saveThumbnail || model.settings.metadata.saveDescription || model.settings.metadata.saveInfoJSON || !model.settings.subtitles.languages.isEmpty {
                        Text("La operación también puede crear archivos auxiliares seleccionados.").font(.caption).foregroundStyle(.secondary)
                    }
                    Text(model.outputFolder?.path(percentEncoded: false) ?? "Selecciona una carpeta de salida").font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer()
                Button("Descargar", systemImage: "arrow.down.circle.fill") {
                    if model.settings.conflictPolicy == .replaceConfirmed { confirmReplacement = true } else { model.download() }
                }
                .buttonStyle(.borderedProminent)
                .disabled(model.selectedDownloadItems().isEmpty || model.outputFolder == nil || model.state.isBusy)
            }.padding(8)
        }
    }

    private var progressOverlay: some View {
        ZStack {
            Rectangle().fill(.black.opacity(0.18)).ignoresSafeArea()
            VStack(spacing: 14) {
                if let fraction = model.progress?.fraction { ProgressView(value: fraction) } else { ProgressView() }
                Text(progressTitle).font(.headline)
                if let current = model.progress?.currentItem { Text(current).font(.caption).foregroundStyle(.secondary).lineLimit(2) }
                if let progress = model.progress {
                    HStack(spacing: 14) {
                        if let speed = progress.speedBytesPerSecond { Text(ByteCountFormatter.string(fromByteCount: Int64(speed), countStyle: .file) + "/s") }
                        if let eta = progress.estimatedSecondsRemaining { Text("Quedan aprox. \(Int(eta)) s") }
                    }.font(.caption).foregroundStyle(.secondary)
                }
                Button("Cancelar", role: .destructive) { model.cancel() }.disabled(model.state == .cancelling)
            }
            .padding(24).frame(width: 420)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
    }

    private var progressTitle: String {
        switch model.state {
        case .analysing: return "Analizando enlaces"
        case .downloading: return "Descargando"
        case .cancelling: return "Cancelando de forma segura"
        default: return "Procesando"
        }
    }

    private func durationText(_ value: Double) -> String {
        let total = max(0, Int(value))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        return hours > 0 ? String(format: "%d:%02d:%02d", hours, minutes, seconds) : String(format: "%d:%02d", minutes, seconds)
    }

    private func selectionBinding(analysis: YouTubeMediaAnalysis, entry: YouTubePlaylistEntry? = nil) -> Binding<Bool> {
        let id = model.selectionID(analysis: analysis, entry: entry)
        return Binding(get: { model.selectedItemIDs.contains(id) }, set: { selected in if selected { model.selectedItemIDs.insert(id) } else { model.selectedItemIDs.remove(id) } })
    }

    private var quickPresetSelection: Binding<String> {
        Binding(
            get: { model.selectedPresetID?.uuidString ?? "" },
            set: { value in
                guard let id = UUID(uuidString: value), let preset = model.presets.first(where: { $0.id == id }) else {
                    model.selectedPresetID = nil
                    return
                }
                model.applyPreset(preset)
            }
        )
    }

    private var exactVideoFormatBinding: Binding<String> {
        Binding(
            get: { model.settings.exactVideoFormatID ?? "" },
            set: { model.settings.exactVideoFormatID = $0.isEmpty ? nil : $0 }
        )
    }

    private var exactAudioFormatBinding: Binding<String> {
        Binding(
            get: { model.settings.exactAudioFormatID ?? "" },
            set: { model.settings.exactAudioFormatID = $0.isEmpty ? nil : $0 }
        )
    }

    private var estimatedSelectedBytes: Int64? {
        let items = model.selectedDownloadItems()
        let estimates = items.compactMap(\.estimatedBytes)
        return estimates.count == items.count ? estimates.reduce(0, +) : nil
    }

    private func formatLabel(_ format: YouTubeFormat) -> String {
        var parts = [format.formatID]
        if let height = format.height { parts.append("\(height)p") }
        if let fps = format.fps { parts.append("\(Int(fps)) fps") }
        if let ext = format.extensionName { parts.append(ext.uppercased()) }
        if let vcodec = format.videoCodec, vcodec != "none" { parts.append(vcodec) }
        if let acodec = format.audioCodec, acodec != "none" { parts.append(acodec) }
        if let size = format.bestKnownSize { parts.append(ByteCountFormatter.string(fromByteCount: size, countStyle: .file)) }
        if format.dynamicRange == .hdr { parts.append("HDR") }
        return parts.joined(separator: " · ")
    }

    private func toggleSubtitle(_ language: String) {
        if let index = model.settings.subtitles.languages.firstIndex(of: language) {
            model.settings.subtitles.languages.remove(at: index)
        } else {
            model.settings.subtitles.languages.append(language)
        }
    }

    private var subtitleLanguages: Binding<String> {
        Binding(get: { model.settings.subtitles.languages.joined(separator: ",") }, set: { model.settings.subtitles.languages = $0.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty } })
    }
}

private struct YouTubePlaylistSelectionView: View {
    @EnvironmentObject private var model: YouTubeDownloaderViewModel
    let analysis: YouTubeMediaAnalysis
    @State private var rangeStart = 1
    @State private var rangeEnd = 1

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("\(analysis.playlistEntries.count) elementos")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Button("Seleccionar disponibles") { model.selectAll(in: analysis) }
                Button("Quitar selección") { model.clearSelection(in: analysis) }
            }
            HStack {
                Stepper("Desde \(rangeStart)", value: $rangeStart, in: validRange)
                Stepper("Hasta \(rangeEnd)", value: $rangeEnd, in: validRange)
                Button("Aplicar intervalo") { model.selectRange(in: analysis, start: rangeStart, end: rangeEnd) }
            }.font(.caption)
            LazyVStack(spacing: 0) {
                ForEach(analysis.playlistEntries) { entry in
                    HStack {
                        Toggle("", isOn: selectionBinding(entry)).labelsHidden().toggleStyle(.checkbox).disabled(!entry.isAvailable)
                        Text(entry.playlistIndex.map(String.init) ?? "–").font(.caption.monospacedDigit()).frame(width: 38, alignment: .trailing)
                        Text(entry.title).lineLimit(1)
                        Spacer()
                        if let duration = entry.duration { Text(durationText(duration)).font(.caption).foregroundStyle(.secondary) }
                        if !entry.isAvailable { Text("No disponible").font(.caption).foregroundStyle(.orange) }
                    }.padding(.vertical, 6)
                    Divider()
                }
            }
        }
        .onAppear { rangeEnd = max(1, analysis.playlistEntries.count) }
    }

    private var validRange: ClosedRange<Int> { 1...max(1, analysis.playlistEntries.count) }

    private func selectionBinding(_ entry: YouTubePlaylistEntry) -> Binding<Bool> {
        let id = model.selectionID(analysis: analysis, entry: entry)
        return Binding(
            get: { model.selectedItemIDs.contains(id) },
            set: { selected in
                if selected { model.selectedItemIDs.insert(id) } else { model.selectedItemIDs.remove(id) }
            }
        )
    }

    private func durationText(_ value: Double) -> String {
        let total = max(0, Int(value))
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

private struct YouTubeCompletionView: View {
    @EnvironmentObject private var model: YouTubeDownloaderViewModel
    let result: YouTubeOperationResult
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(result.wasCancelled ? "Descarga cancelada" : "Resumen final").font(.title.bold())
            HStack(spacing: 20) {
                Label("\(result.completedCount) correctos", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                Label("\(result.skippedCount) omitidos", systemImage: "minus.circle.fill").foregroundStyle(.orange)
                Label("\(result.failedCount) fallidos", systemImage: "xmark.circle.fill").foregroundStyle(.red)
            }
            if !result.warnings.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(result.warnings, id: \.self) { warning in
                        Label(warning, systemImage: "exclamationmark.triangle").foregroundStyle(.orange)
                    }
                }
            }
            List {
                ForEach(result.items) { item in
                    VStack(alignment: .leading) {
                        Text(item.title).font(.headline)
                        Text(item.userMessage ?? item.status.rawValue).font(.caption).foregroundStyle(.secondary)
                        if !item.outputFiles.isEmpty {
                            Text("\(item.outputFiles.count) archivo(s) publicado(s)").font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                }
                if !result.auxiliaryFiles.isEmpty {
                    Section("Archivos auxiliares") {
                        ForEach(result.auxiliaryFiles, id: \.self) { file in
                            Label(file.lastPathComponent, systemImage: "doc.text")
                        }
                    }
                }
            }
            HStack { Button("Abrir carpeta") { model.openOutputFolder() }; Spacer(); Button("Cerrar") { dismiss() }.keyboardShortcut(.defaultAction) }
        }.padding(24).frame(minWidth: 620, minHeight: 430)
    }
}
