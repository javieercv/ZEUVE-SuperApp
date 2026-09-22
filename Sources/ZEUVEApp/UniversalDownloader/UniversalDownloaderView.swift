import SwiftUI
import AppKit
import UniformTypeIdentifiers
import UniversalDownloaderModule

struct UniversalDownloaderView: View {
    @EnvironmentObject private var model: UniversalDownloaderViewModel
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
                        UniversalDownloaderSettingsCard(model: model)
                        if model.hasPageDiscoveredSelection { pageSourceCard }
                        outputCard
                        summaryCard
                    }
                }
                .padding(28)
                .frame(maxWidth: 1_120, alignment: .leading)
            }
            if model.state.isBusy { progressOverlay }
        }
        .navigationTitle("Descargador universal")
        .sheet(item: $model.completion) { result in UniversalDownloaderCompletionView(result: result).environmentObject(model) }
        .alert("No se ha podido completar la operación", isPresented: Binding(get: { model.errorMessage != nil }, set: { if !$0 { model.errorMessage = nil } })) {
            if model.errorMessage?.contains("Permitir contenido para adultos") == true {
                Button("Abrir Ajustes") {
                    NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                    model.errorMessage = nil
                }
            }
            Button("Aceptar", role: .cancel) { model.errorMessage = nil }
        } message: { Text(model.errorMessage ?? "Error desconocido") }
        .alert("Aviso", isPresented: Binding(
            get: { model.warningMessage != nil },
            set: { if !$0 { model.warningMessage = nil } }
        )) {
            Button("Aceptar", role: .cancel) { model.warningMessage = nil }
        } message: { Text(model.warningMessage ?? "") }
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
            Text("Descargador universal").font(.largeTitle.bold())
            Text("Descarga fotos, vídeos, audio, publicaciones, stories, galerías y contenido multimedia de redes sociales o páginas web.").font(.title3).foregroundStyle(.secondary)
            Label("Internet solo se utiliza al analizar o descargar", systemImage: "network.badge.shield.half.filled")
                .font(.callout.weight(.medium)).foregroundStyle(.blue)
        }
    }

    private var urlCard: some View {
        GroupBox("Enlaces o páginas") {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center, spacing: 10) {
                    Text("Plataforma").font(.subheadline.weight(.semibold))
                    Picker("Plataforma", selection: $model.selectedPlatform) {
                        ForEach(UniversalDownloadPlatform.allCases) { platform in
                            Text(platform.spanishName).tag(platform)
                        }
                    }
                    .labelsHidden()
                    .frame(maxWidth: 220)
                    .onChange(of: model.selectedPlatform) { _, _ in model.validateInput() }
                    Spacer()
                    if model.universalPreferences.allowAdultContent {
                        Label("Contenido adulto permitido", systemImage: "18.circle")
                            .font(.caption).foregroundStyle(.orange)
                    }
                }
                Text(model.selectedPlatform == .instagram
                     ? "Pega un nombre de usuario de Instagram, un perfil o un enlace concreto."
                     : "Pega el enlace concreto del contenido. En Automático también puedes pegar una página web.")
                    .font(.caption).foregroundStyle(.secondary)
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
                        .disabled(model.acceptedURLs.isEmpty || model.state.isBusy || model.importingInstagramSession || model.unavailableMessage != nil)
                    Spacer()
                    Text("También puedes arrastrar enlaces o páginas aquí").font(.caption).foregroundStyle(.secondary)
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
                            Group {
                                if let thumbnail = analysis.thumbnailURL {
                                    AsyncImage(url: thumbnail) { phase in
                                        if let image = phase.image { image.resizable().scaledToFill() }
                                        else { Image(systemName: analysis.mediaKind?.systemImage ?? "rectangle.stack").font(.title) }
                                    }
                                } else {
                                    Image(systemName: analysis.mediaKind?.systemImage ?? (analysis.kind == .video ? "play.rectangle" : "rectangle.stack"))
                                        .font(.title)
                                }
                            }
                            .frame(width: 72, height: 58)
                            .clipped()
                            .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
                            .foregroundStyle(.secondary)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(analysis.title).font(.headline)
                                if let uploader = analysis.uploader { Text(uploader).foregroundStyle(.secondary) }
                                if let service = analysis.serviceName { Text(service).font(.caption).foregroundStyle(.secondary) }
                                HStack(spacing: 6) {
                                    if let platform = analysis.platform { Label(platform.spanishName, systemImage: "network") }
                                    if let kind = analysis.mediaKind { Label(kind.spanishName, systemImage: kind.systemImage) }
                                    if let engine = analysis.engineKind { Text("Motor: \(engine.spanishName)") }
                                }
                                .font(.caption2).foregroundStyle(.secondary)
                                if analysis.downloadSource == .pageDiscovered {
                                    HStack(spacing: 6) {
                                        Label("Descarga original", systemImage: "arrow.down.doc")
                                        ContextualHelpButton(topic: ZEUVEHelpTopics.pageOriginalDownload)
                                    }
                                    .font(.caption)
                                    .foregroundStyle(.blue)
                                }
                                if analysis.duplicateCount > 0 {
                                    Label("\(analysis.duplicateCount) referencias duplicadas omitidas antes de descargar", systemImage: "doc.on.doc")
                                        .font(.caption).foregroundStyle(.orange)
                                }
                                if model.isPreviouslyDownloaded(analysis.canonicalID), analysis.kind == .video {
                                    Label("Ya descargado anteriormente", systemImage: "clock.arrow.circlepath")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                if model.isPossibleDuplicate(analysis.canonicalID), analysis.kind == .video {
                                    Label("Posible duplicado", systemImage: "exclamationmark.triangle")
                                        .font(.caption).foregroundStyle(.orange)
                                }
                                HStack(spacing: 10) {
                                    if let duration = analysis.duration { Text(durationText(duration)) }
                                    if let date = analysis.publicationDate { Text(date.formatted(date: .abbreviated, time: .omitted)) }
                                    if analysis.kind == .video { Text("\(analysis.formats.count) formatos") }
                                    if !analysis.subtitles.isEmpty { Text("\(analysis.subtitles.count) pistas de subtítulos") }
                                }.font(.caption).foregroundStyle(.secondary)
                                if analysis.mediaKind?.mediaClass == .video || analysis.kind == .video {
                                    Text(analysis.liveStatus.spanishDescription).font(.caption).foregroundStyle(analysis.liveStatus.canDownloadInVersion020 ? Color.secondary : Color.orange)
                                }
                            }
                            Spacer()
                            if analysis.kind == .video {
                                Toggle("Seleccionar", isOn: selectionBinding(analysis: analysis)).toggleStyle(.checkbox).disabled(!analysis.isDownloadable)
                            }
                        }
                        if analysis.requiresAuthentication, analysis.platform == .instagram {
                            instagramSessionCard(analysis)
                        }
                        if analysis.kind == .profile,
                           analysis.platform == .instagram,
                           let restricted = analysis.authenticationRestrictedSections,
                           !restricted.isEmpty {
                            instagramRestrictedSectionsCard(restricted)
                        }
                        if analysis.kind == .profile, analysis.platform == .instagram {
                            HStack {
                                Button("Buscar fotos de perfil anteriores", systemImage: "clock.arrow.circlepath") {
                                    model.searchArchivedProfilePictures(for: analysis)
                                }
                                .disabled(model.archiveSearchInProgress)
                                if model.archiveSearchInProgress { ProgressView().controlSize(.small) }
                                Spacer()
                                Text("Búsqueda opcional; no garantiza resultados")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            if let message = model.archiveSearchMessage {
                                Text(message).font(.caption).foregroundStyle(.secondary)
                            }
                            if !model.archivedProfilePictures.isEmpty {
                                archiveCandidates(username: analysis.profileUsername ?? analysis.uploader ?? "instagram")
                            }
                        }
                        if analysis.kind != .video { playlistEntries(analysis) }
                        if analysis.hasMoreEntries {
                            Button("Cargar más", systemImage: "arrow.down.circle") { model.loadMore(in: analysis) }
                                .disabled(model.state.isBusy)
                        }
                    }.padding(8)
                }
            }
        }
    }

    private func instagramRestrictedSectionsCard(_ sections: [UniversalCatalogSection]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Perfil público analizado sin sesión", systemImage: "person.crop.circle.badge.checkmark")
                .font(.headline)
            Text("El contenido público disponible puede seleccionarse y descargarse normalmente.")
                .font(.caption)
                .foregroundStyle(.secondary)
            ForEach(sections) { section in
                Label("\(section.spanishName): no disponibles sin sesión", systemImage: "lock")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .background(.quaternary.opacity(0.25), in: RoundedRectangle(cornerRadius: 8))
    }

    private func instagramSessionCard(_ analysis: DownloadAnalysis) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(
                analysis.kind == .profile
                    ? "Instagram no ha permitido comprobar este perfil"
                    : "Instagram exige una sesión para este contenido",
                systemImage: "lock.shield"
            )
            .font(.headline).foregroundStyle(.orange)
            if let detail = analysis.description, !detail.isEmpty {
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
            Text("Pega una cabecera Cookie o el contenido de cookies.txt de una sesión autorizada. ZEUVE no solicita tu contraseña ni intenta saltar la privacidad.")
                .font(.caption).foregroundStyle(.secondary)
            TextEditor(text: $model.instagramSessionText)
                .font(.caption.monospaced())
                .frame(minHeight: 70)
                .padding(5)
                .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 7))
            HStack(spacing: 8) {
                Picker("Navegador", selection: $model.instagramCookieBrowser) {
                    Text("Safari").tag("safari")
                    Text("Chrome").tag("chrome")
                    Text("Firefox").tag("firefox")
                    Text("Brave").tag("brave")
                    Text("Edge").tag("edge")
                    Text("Arc").tag("arc")
                    Text("Chromium").tag("chromium")
                    Text("Opera").tag("opera")
                    Text("Vivaldi").tag("vivaldi")
                }
                .frame(maxWidth: 190)
                Button("Importar sesión", systemImage: "safari") { model.importInstagramSessionFromBrowser() }
                    .disabled(model.importingInstagramSession || model.state.isBusy)
                if model.importingInstagramSession { ProgressView().controlSize(.small) }
                Spacer()
            }
            if let status = model.instagramSessionStatus {
                HStack {
                    Label(status, systemImage: "checkmark.shield")
                        .font(.caption).foregroundStyle(.green)
                    Spacer()
                    Button("Quitar sesión") { model.clearTemporaryInstagramSession() }
                        .buttonStyle(.link)
                        .disabled(model.state.isBusy)
                }
            }
            HStack {
                Toggle("Recordar en el Llavero", isOn: $model.rememberInstagramSession)
                Spacer()
                Button("Volver a analizar", systemImage: "arrow.clockwise") { model.analyse() }
                    .buttonStyle(.borderedProminent)
            }
            Text("La sesión es temporal por defecto. También puedes importarla expresamente desde un navegador. macOS puede pedir permiso para leer sus cookies. Si eliges recordarla, se guarda cifrada en el Llavero y nunca aparece en registros o historial.")
                .font(.caption2).foregroundStyle(.secondary)
        }
        .padding(10)
        .background(.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
    }

    private func archiveCandidates(username: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(model.archivedProfilePictures) { candidate in
                HStack(spacing: 10) {
                    AsyncImage(url: candidate.imageURL) { phase in
                        if let image = phase.image { image.resizable().scaledToFill() }
                        else { Image(systemName: "person.crop.circle") }
                    }
                    .frame(width: 54, height: 54).clipShape(RoundedRectangle(cornerRadius: 7))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(candidate.capturedAt?.formatted(date: .abbreviated, time: .omitted) ?? "Fecha no disponible")
                        Text(candidate.sourceName).font(.caption).foregroundStyle(.secondary)
                        Text(candidate.confidence).font(.caption2).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Añadir") { model.addArchivedProfilePicture(candidate, username: username) }
                }
            }
        }
        .padding(8)
        .background(.quaternary.opacity(0.2), in: RoundedRectangle(cornerRadius: 8))
    }

    private func playlistEntries(_ analysis: DownloadAnalysis) -> some View {
        UniversalDownloaderCatalogView(analysis: analysis)
            .environmentObject(model)
    }

    private var pageSourceCard: some View {
        GroupBox("Procedencia") {
            VStack(alignment: .leading, spacing: 12) {
                HelpToggleRow(
                    "Guardar procedencia en los metadatos del archivo",
                    topic: ZEUVEHelpTopics.pageSourceMetadata,
                    isOn: $model.settings.pageSource.embedSourceMetadata
                )
                HelpToggleRow(
                    "Añadir la fecha de descarga",
                    topic: ZEUVEHelpTopics.pageSourceDownloadDate,
                    isOn: $model.settings.pageSource.includeDownloadDate
                )
                .disabled(!model.settings.pageSource.embedSourceMetadata)
                HelpToggleRow(
                    "Añadir «De dónde» de macOS",
                    topic: ZEUVEHelpTopics.macOSWhereFrom,
                    isOn: $model.settings.pageSource.applyMacOSWhereFrom
                )
                Text("La procedencia está desactivada por defecto. Se guarda la URL limpia de la página, nunca la URL temporal del vídeo, cookies, tokens ni cabeceras privadas.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(8)
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
                if model.onlyPageDiscoveredSelection {
                    HStack(spacing: 6) {
                        Text("Nombre limpio y numeración automática")
                        ContextualHelpButton(topic: ZEUVEHelpTopics.pageDiscoveredFilename)
                    }
                    Text("Se eliminarán los identificadores técnicos. Si varios vídeos comparten título, se nombrarán (1), (2), (3)… incluyendo el primero.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    HelpPickerRow(
                        "Nombre de archivo",
                        topic: ZEUVEHelpTopics.filename,
                        selection: $model.settings.filenamePreset
                    ) {
                        Text("Título").tag(DownloadFilenamePreset.title)
                        Text("Título e ID").tag(DownloadFilenamePreset.titleAndID)
                        Text("Fecha y título").tag(DownloadFilenamePreset.dateAndTitle)
                        Text("Canal y título").tag(DownloadFilenamePreset.channelAndTitle)
                        Text("Índice y título").tag(DownloadFilenamePreset.playlistIndexAndTitle)
                        Text("Lista, índice y título").tag(DownloadFilenamePreset.playlistAndIndexAndTitle)
                    }
                    if model.hasPageDiscoveredSelection {
                        Text("Esta opción solo afecta a los enlaces directos. Los vídeos encontrados en páginas usan nombres limpios y numeración automática.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                HelpPickerRow(
                    "Conflictos",
                    topic: ZEUVEHelpTopics.fileConflicts,
                    selection: $model.settings.conflictPolicy
                ) {
                    Text("Renombrar automáticamente").tag(DownloadConflictPolicy.renameAutomatically)
                    Text("Omitir").tag(DownloadConflictPolicy.skip)
                    Text("Reemplazar con confirmación").tag(DownloadConflictPolicy.replaceConfirmed)
                }
                HelpToggleRow("Crear una carpeta para la lista", topic: ZEUVEHelpTopics.playlistFolder, isOn: $model.settings.createPlaylistFolder)
                if !model.onlyPageDiscoveredSelection {
                    HelpToggleRow("Numerar elementos de listas", topic: ZEUVEHelpTopics.playlistNumbering, isOn: $model.settings.numberPlaylistItems)
                }
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
                    if model.hasDirectSelection && (model.settings.metadata.saveThumbnail || model.settings.metadata.saveDescription || model.settings.metadata.saveInfoJSON || !model.settings.subtitles.languages.isEmpty) {
                        Text("La operación también puede crear archivos auxiliares seleccionados.").font(.caption).foregroundStyle(.secondary)
                    }
                    Text(model.outputFolder?.path(percentEncoded: false) ?? "Selecciona una carpeta de salida").font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer()
                Button("Descargar", systemImage: "arrow.down.circle.fill") {
                    if model.requiresReplacementConfirmation { confirmReplacement = true } else { model.download() }
                }
                .buttonStyle(.borderedProminent)
                .disabled(model.selectedDownloadItems().isEmpty || model.outputFolder == nil || model.state.isBusy || model.importingInstagramSession)
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

    private func selectionBinding(analysis: DownloadAnalysis, entry: DownloadCatalogItem? = nil) -> Binding<Bool> {
        let id = model.selectionID(analysis: analysis, entry: entry)
        return Binding(get: { model.selectedItemIDs.contains(id) }, set: { selected in if selected { model.selectedItemIDs.insert(id) } else { model.selectedItemIDs.remove(id) } })
    }

    private var estimatedSelectedBytes: Int64? {
        let items = model.selectedDownloadItems()
        let estimates = items.compactMap(\.estimatedBytes)
        return estimates.count == items.count ? estimates.reduce(0, +) : nil
    }

}
