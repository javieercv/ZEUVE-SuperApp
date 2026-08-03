import SwiftUI
import AppKit
import ZEUVECore
import OrganizerModule
import YouTubeDownloaderModule
import ChatAnalyzerModule
import UniversalConverterModule

private enum SettingsArea: String, CaseIterable, Identifiable {
    case general
    case organizer
    case youtubeDownloader
    case chatAnalyzer
    case universalConverter

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: return "General"
        case .organizer: return "Organizador de archivos"
        case .youtubeDownloader: return "Descargador de YouTube"
        case .chatAnalyzer: return "Analizador de chats"
        case .universalConverter: return "Conversor universal"
        }
    }

    var systemImage: String {
        switch self {
        case .general: return "gearshape"
        case .organizer: return "folder.badge.gearshape"
        case .youtubeDownloader: return "arrow.down.circle"
        case .chatAnalyzer: return "bubble.left.and.bubble.right"
        case .universalConverter: return "arrow.triangle.2.circlepath"
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject private var app: AppModel
    @State private var selectedArea: SettingsArea? = .general

    var body: some View {
        HStack(spacing: 0) {
            List(SettingsArea.allCases, selection: $selectedArea) { area in
                Label(area.title, systemImage: area.systemImage)
                    .tag(area)
                    .padding(.vertical, 3)
            }
            .listStyle(.sidebar)
            .frame(minWidth: 210, idealWidth: 230, maxWidth: 260)

            Divider()

            Group {
                switch selectedArea ?? .general {
                case .general:
                    GeneralSettingsContent(app: app)
                case .organizer:
                    OrganizerModuleSettingsView(model: app.organizer)
                case .youtubeDownloader:
                    YouTubeModuleSettingsView(model: app.youtubeDownloader)
                case .chatAnalyzer:
                    ChatAnalyzerModuleSettingsView(model: app.chatAnalyzer)
                case .universalConverter:
                    UniversalConverterSettingsView(model: app.universalConverter)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationTitle("Ajustes")
    }
}

private struct GeneralSettingsContent: View {
    @ObservedObject var app: AppModel

    var body: some View {
        Form {
            Section {
                LabeledContent {
                    Text("General y por módulo")
                } label: {
                    HelpLabel("Organización de los ajustes", topic: ZEUVEHelpTopics.centralizedSettings)
                }
            } header: {
                Text("Ajustes")
            } footer: {
                Text("Las opciones de una descarga u organización concreta permanecen dentro de la herramienta. Los valores permanentes se administran únicamente aquí.")
            }

            Section("Apariencia") {
                Picker("Tema", selection: Binding(get: { app.theme }, set: { app.saveTheme($0) })) {
                    ForEach(ThemePreference.allCases) { Text($0.name).tag($0) }
                }
                .pickerStyle(.segmented)
            }

            Section("Privacidad") {
                LabeledContent {
                    Text("Desactivada")
                } label: {
                    HelpLabel("Telemetría", topic: ZEUVEHelpTopics.telemetry)
                }
                LabeledContent {
                    Text("Desactivadas")
                } label: {
                    HelpLabel("Actualizaciones automáticas", topic: ZEUVEHelpTopics.automaticUpdates)
                }
                LabeledContent {
                    Text("Activado")
                } label: {
                    HelpLabel("Procesamiento local", topic: ZEUVEHelpTopics.localProcessing)
                }
                LabeledContent {
                    Text("Solo por acción del usuario")
                } label: {
                    HelpLabel("Red", topic: ZEUVEHelpTopics.networkUse)
                }
            }

            Section("Registros") {
                HStack {
                    Button("Abrir carpeta de registros") {
                        if let url = try? AppPaths.logs() { NSWorkspace.shared.open(url) }
                    }
                    ContextualHelpButton(topic: ZEUVEHelpTopics.logs)
                }
            }

            Section("Versión") {
                LabeledContent("ZEUVE", value: "0.7.1 (22)")
                LabeledContent {
                    Text("1.0")
                } label: {
                    HelpLabel("API de módulos", topic: ZEUVEHelpTopics.moduleAPI)
                }
                LabeledContent {
                    Text("Pendiente de prueba técnica")
                } label: {
                    HelpLabel("App Sandbox", topic: ZEUVEHelpTopics.appSandbox)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

private struct OrganizerModuleSettingsView: View {
    @ObservedObject var model: OrganizerViewModel
    @State private var confirmRestore = false
    @State private var confirmForgetFolders = false

    var body: some View {
        Form {
            Section {
                HelpPickerRow(
                    "Nivel de organización",
                    topic: ZEUVEHelpTopics.organizationLevel,
                    selection: $model.defaultOptions.organizationLevel
                ) {
                    ForEach(OrganizationLevel.allCases, id: \.self) { level in
                        Text(level.displayName).tag(level)
                    }
                }
                HelpToggleRow(
                    "Agrupar archivos con el mismo nombre",
                    topic: ZEUVEHelpTopics.relatedFiles,
                    isOn: $model.defaultOptions.keepRelated
                )
                HelpToggleRow(
                    "Incluir subcarpetas",
                    topic: ZEUVEHelpTopics.recursiveFolders,
                    isOn: $model.defaultOptions.recursive
                )
                HelpPickerRow(
                    "Cuando exista el mismo nombre",
                    topic: ZEUVEHelpTopics.organizerConflict,
                    selection: $model.defaultOptions.conflictPolicy
                ) {
                    ForEach(ConflictPolicy.allCases, id: \.self) { policy in
                        Text(policy.displayName).tag(policy)
                    }
                }
                HelpToggleRow(
                    "Incluir archivos y carpetas ocultos",
                    topic: ZEUVEHelpTopics.hiddenFiles,
                    isOn: $model.defaultOptions.includeHidden
                )
            } header: {
                HStack {
                    Text("Valores predeterminados")
                    ContextualHelpButton(topic: ZEUVEHelpTopics.moduleDefaults)
                }
            } footer: {
                Text("Se aplicarán al comenzar nuevas operaciones. No cambian automáticamente una vista previa o una operación ya preparada.")
            }

            Section("Operación actual") {
                Button("Aplicar estos valores a la operación actual") {
                    model.applyDefaultOptionsToCurrentOperation()
                }
                .disabled(model.state.isBusy)
            }

            Section {
                if model.recentFolders.isEmpty {
                    Text("No hay carpetas recientes guardadas.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(model.recentFolders, id: \.path) { folder in
                        Label(folder.path, systemImage: "folder")
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    Button("Olvidar carpetas recientes", role: .destructive) {
                        confirmForgetFolders = true
                    }
                }
            } header: {
                HStack {
                    Text("Carpetas recientes")
                    ContextualHelpButton(topic: ZEUVEHelpTopics.recentFolders)
                }
            }

            Section("Restablecer") {
                Button("Restaurar valores predeterminados", role: .destructive) {
                    confirmRestore = true
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .onChange(of: model.defaultOptions) { _, _ in
            model.persistDefaultOptions()
        }
        .confirmationDialog(
            "¿Restaurar los ajustes del Organizador?",
            isPresented: $confirmRestore,
            titleVisibility: .visible
        ) {
            Button("Restaurar", role: .destructive) { model.restoreDefaultOptions() }
            Button("Cancelar", role: .cancel) { }
        } message: {
            Text("Se recuperarán los valores predeterminados del módulo. Los archivos y las operaciones ya realizadas no se modificarán.")
        }
        .confirmationDialog(
            "¿Olvidar las carpetas recientes?",
            isPresented: $confirmForgetFolders,
            titleVisibility: .visible
        ) {
            Button("Olvidar", role: .destructive) { model.clearRecentFolders() }
            Button("Cancelar", role: .cancel) { }
        } message: {
            Text("Solo se borrará la lista local de accesos recientes. No se eliminará ni modificará ninguna carpeta.")
        }
    }
}


private struct ChatAnalyzerModuleSettingsView: View {
    @ObservedObject var model: ChatAnalyzerViewModel
    @State private var confirmRestore = false

    private let megabyte: Int64 = 1_024 * 1_024

    private var conversationFileLimitEnabled: Binding<Bool> {
        Binding(
            get: { model.defaultSettings.conversationFileMaximumBytes != nil },
            set: { enabled in
                model.defaultSettings.conversationFileMaximumBytes = enabled ? 1_024 * megabyte : nil
            }
        )
    }

    private var conversationFileLimitMB: Binding<Int> {
        Binding(
            get: {
                max(1, Int((model.defaultSettings.conversationFileMaximumBytes ?? megabyte) / megabyte))
            },
            set: { value in
                let safe = max(1, value)
                let maximumMB = Int(Int64.max / megabyte)
                model.defaultSettings.conversationFileMaximumBytes = Int64(min(safe, maximumMB)) * megabyte
            }
        )
    }

    var body: some View {
        Form {
            Section {
                HelpPickerRow("Zona horaria de Instagram", topic: ZEUVEHelpTopics.chatTimeZone, selection: $model.defaultSettings.instagramTimeZone) {
                    ForEach(InstagramTimeZoneStrategy.allCases) { Text($0.displayName).tag($0) }
                }
                HelpPickerRow("Orden de fechas numéricas", topic: ZEUVEHelpTopics.chatNumericDates, selection: $model.defaultSettings.numericDateOrder) {
                    ForEach(AmbiguousNumericDateOrder.allCases) { Text($0.displayName).tag($0) }
                }
                HelpPickerRow("Definición de multimedia", topic: ZEUVEHelpTopics.chatMultimedia, selection: $model.defaultSettings.multimediaDefinition) {
                    ForEach(MultimediaDefinition.allCases) { Text($0.displayName).tag($0) }
                }
                if model.defaultSettings.multimediaDefinition == .configurable {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Categorías consideradas multimedia")
                            .font(.subheadline.weight(.medium))
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 145), alignment: .leading)], alignment: .leading, spacing: 8) {
                            ForEach(ChatContentType.allCases.filter { $0 != .text && $0 != .system }) { type in
                                Toggle(type.displayName, isOn: Binding(
                                    get: { model.defaultSettings.configurableMultimediaTypes.contains(type) },
                                    set: { enabled in
                                        if enabled { model.defaultSettings.configurableMultimediaTypes.insert(type) }
                                        else { model.defaultSettings.configurableMultimediaTypes.remove(type) }
                                    }
                                ))
                            }
                        }
                    }
                }
                HelpToggleRow("Incluir palabras vacías", topic: ZEUVEHelpTopics.chatStopWords, isOn: $model.defaultSettings.includeStopWords)
                HelpPickerRow("Granularidad temporal", topic: ZEUVEHelpTopics.chatGranularity, selection: $model.defaultSettings.granularity) {
                    ForEach(TimeGranularity.allCases) { Text($0.displayName).tag($0) }
                }
            } header: {
                HStack { Text("Análisis predeterminado"); ContextualHelpButton(topic: ZEUVEHelpTopics.moduleDefaults) }
            } footer: {
                Text("Se copiarán al preparar un análisis nuevo. No modifican un análisis ya cargado ni una operación en curso.")
            }

            Section("Conversaciones y respuestas") {
                HelpPickerRow("Pausa entre conversaciones", topic: ZEUVEHelpTopics.chatConversationThreshold, selection: $model.defaultSettings.conversationThresholdMinutes) {
                    Text("30 minutos").tag(30); Text("1 hora").tag(60); Text("3 horas").tag(180); Text("6 horas").tag(360); Text("12 horas").tag(720); Text("24 horas").tag(1_440)
                }
                HelpPickerRow("Ventana máxima de respuesta", topic: ZEUVEHelpTopics.chatResponseWindow, selection: $model.defaultSettings.responseWindowMinutes) {
                    Text("1 hora").tag(60); Text("6 horas").tag(360); Text("12 horas").tag(720); Text("24 horas").tag(1_440); Text("Sin límite dentro de la conversación").tag(0)
                }
                HelpPickerRow("Conversaciones y filtros", topic: ZEUVEHelpTopics.chatConversationFilters, selection: $model.defaultSettings.conversationFilterStrategy) {
                    ForEach(ConversationFilterStrategy.allCases) { Text($0.displayName).tag($0) }
                }
            }

            Section("Listas") {
                Picker("Resultados por página", selection: $model.defaultSettings.listLimit) {
                    Text("25").tag(25); Text("50").tag(50); Text("100").tag(100)
                }
            }

            Section {
                HelpToggleRow(
                    "Limitar el tamaño de cada archivo de conversación",
                    topic: ZEUVEHelpTopics.chatConversationFileLimit,
                    isOn: conversationFileLimitEnabled
                )
                if model.defaultSettings.conversationFileMaximumBytes != nil {
                    HStack(spacing: 12) {
                        HelpLabel("Tamaño máximo", topic: ZEUVEHelpTopics.chatConversationFileLimit)
                        Spacer(minLength: 12)
                        TextField("Máximo", value: conversationFileLimitMB, format: .number)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 120)
                        Text("MB").foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("Archivos de conversación")
            } footer: {
                Text("Por defecto no hay límite. Si se activa, el TXT de WhatsApp o cada página HTML de Instagram que supere el valor se rechazará sin analizarse parcialmente.")
            }

            Section {
                LabeledContent("Tamaño ZIP con advertencia", value: ByteCountFormatter.string(fromByteCount: model.defaultSettings.archiveLimits.compressedWarningBytes, countStyle: .file))
                LabeledContent("Tamaño ZIP máximo", value: ByteCountFormatter.string(fromByteCount: model.defaultSettings.archiveLimits.compressedMaximumBytes, countStyle: .file))
                LabeledContent("Mensajes con advertencia", value: model.defaultSettings.archiveLimits.messageWarningCount.formatted())
                LabeledContent("Mensajes máximos", value: model.defaultSettings.archiveLimits.messageMaximumCount.formatted())
            } header: {
                HStack { Text("Límites de seguridad"); ContextualHelpButton(topic: ZEUVEHelpTopics.chatArchiveLimits) }
            } footer: {
                Text("Los límites absolutos protegen frente a ZIP hostiles y no pueden desactivarse desde la operación.")
            }

            Section("Operación actual") {
                Button("Aplicar estos valores a la operación actual") { model.applyDefaultSettingsToCurrentAnalysis() }
                    .disabled(model.isAnalyzing)
            }

            Section("Restablecer") {
                Button("Restaurar valores predeterminados", role: .destructive) { confirmRestore = true }
            }
        }
        .formStyle(.grouped)
        .padding()
        .onChange(of: model.defaultSettings) { _, _ in model.persistSettings() }
        .confirmationDialog("¿Restaurar los ajustes del Analizador de chats?", isPresented: $confirmRestore, titleVisibility: .visible) {
            Button("Restaurar", role: .destructive) { model.restoreSettings() }
            Button("Cancelar", role: .cancel) { }
        } message: {
            Text("Se recuperarán los valores predeterminados. Los originales y los análisis anteriores no se modificarán.")
        }
    }
}

private enum YouTubeSettingsSection: String, CaseIterable, Identifiable {
    case defaults
    case presets
    case diagnostics

    var id: String { rawValue }

    var title: String {
        switch self {
        case .defaults: return "Predeterminados"
        case .presets: return "Presets"
        case .diagnostics: return "Diagnóstico"
        }
    }
}

private struct YouTubeModuleSettingsView: View {
    @ObservedObject var model: YouTubeDownloaderViewModel
    @State private var section: YouTubeSettingsSection = .defaults

    var body: some View {
        VStack(spacing: 0) {
            Picker("Sección", selection: $section) {
                ForEach(YouTubeSettingsSection.allCases) { item in
                    Text(item.title).tag(item)
                }
            }
            .pickerStyle(.segmented)
            .padding([.top, .horizontal])

            Group {
                switch section {
                case .defaults:
                    YouTubeDefaultsSettingsView(model: model)
                case .presets:
                    YouTubePresetsSettingsView(model: model)
                case .diagnostics:
                    YouTubeDiagnosticsSettingsView(model: model)
                }
            }
        }
        .alert("No se ha podido guardar el ajuste", isPresented: Binding(
            get: { model.errorMessage != nil },
            set: { if !$0 { model.errorMessage = nil } }
        )) {
            Button("Aceptar", role: .cancel) { model.errorMessage = nil }
        } message: {
            Text(model.errorMessage ?? "Error desconocido")
        }
    }
}

private struct YouTubeDefaultsSettingsView: View {
    @ObservedObject var model: YouTubeDownloaderViewModel
    @State private var confirmRestore = false

    var body: some View {
        Form {
            Section {
                HelpToggleRow(
                    "Abrir nuevas operaciones en modo avanzado",
                    topic: ZEUVEHelpTopics.interfaceMode,
                    isOn: $model.defaultAdvancedMode
                )
                HelpPickerRow(
                    "Contenido",
                    topic: ZEUVEHelpTopics.downloadContent,
                    selection: $model.defaultSettings.mode
                ) {
                    Text("Vídeo").tag(YouTubeDownloadMode.video)
                    Text("Solo audio").tag(YouTubeDownloadMode.audio)
                }

                if model.defaultSettings.mode == .video {
                    HelpPickerRow(
                        "Resolución máxima",
                        topic: ZEUVEHelpTopics.maximumResolution,
                        selection: $model.defaultSettings.maximumResolution
                    ) {
                        ForEach(YouTubeMaximumResolution.allCases) { resolution in
                            Text(resolution.spanishName).tag(resolution)
                        }
                    }
                    HelpPickerRow(
                        "Formato del archivo",
                        topic: ZEUVEHelpTopics.videoFormat,
                        selection: $model.defaultSettings.container
                    ) {
                        ForEach(YouTubeContainerPreference.allCases) { container in
                            Text(container.spanishName).tag(container)
                        }
                    }
                    HelpPickerRow(
                        "Rango dinámico",
                        topic: ZEUVEHelpTopics.dynamicRange,
                        selection: $model.defaultSettings.hdrPreference
                    ) {
                        Text("Automático").tag(YouTubeHDRPreference.automatic)
                        Text("Preferir SDR").tag(YouTubeHDRPreference.preferSDR)
                        Text("Preferir HDR").tag(YouTubeHDRPreference.preferHDR)
                    }
                } else {
                    HelpPickerRow(
                        "Formato de audio",
                        topic: ZEUVEHelpTopics.audioFormat,
                        selection: $model.defaultSettings.audioOutput
                    ) {
                        ForEach(YouTubeAudioOutput.allCases) { output in
                            Text(output.spanishName).tag(output)
                        }
                    }
                    if model.defaultSettings.audioOutput == .mp3 {
                        HelpPickerRow(
                            "Calidad MP3",
                            topic: ZEUVEHelpTopics.mp3Bitrate,
                            selection: $model.defaultSettings.mp3Bitrate
                        ) {
                            ForEach(YouTubeMP3Bitrate.allCases) { bitrate in
                                Text(bitrate.spanishName).tag(bitrate)
                            }
                        }
                    }
                }
            } header: {
                HStack {
                    Text("Valores predeterminados")
                    ContextualHelpButton(topic: ZEUVEHelpTopics.moduleDefaults)
                }
            } footer: {
                Text("Las selecciones exactas de pistas, el proxy y las cookies siguen siendo decisiones de cada operación y no se guardan como valores generales.")
            }

            Section("Nombre y listas") {
                HelpPickerRow(
                    "Nombre de archivo",
                    topic: ZEUVEHelpTopics.filename,
                    selection: $model.defaultSettings.filenamePreset
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
                    selection: $model.defaultSettings.conflictPolicy
                ) {
                    Text("Renombrar automáticamente").tag(YouTubeConflictPolicy.renameAutomatically)
                    Text("Omitir").tag(YouTubeConflictPolicy.skip)
                    Text("Reemplazar con confirmación").tag(YouTubeConflictPolicy.replaceConfirmed)
                }
                HelpToggleRow(
                    "Crear una carpeta para la lista",
                    topic: ZEUVEHelpTopics.playlistFolder,
                    isOn: $model.defaultSettings.createPlaylistFolder
                )
                HelpToggleRow(
                    "Numerar elementos de listas",
                    topic: ZEUVEHelpTopics.playlistNumbering,
                    isOn: $model.defaultSettings.numberPlaylistItems
                )
            }

            Section("Metadatos y archivos auxiliares") {
                HelpToggleRow("Incrustar metadatos", topic: ZEUVEHelpTopics.embedMetadata, isOn: $model.defaultSettings.metadata.embedMetadata)
                HelpToggleRow("Incrustar miniatura", topic: ZEUVEHelpTopics.thumbnails, isOn: $model.defaultSettings.metadata.embedThumbnail)
                HelpToggleRow("Guardar miniatura por separado", topic: ZEUVEHelpTopics.thumbnails, isOn: $model.defaultSettings.metadata.saveThumbnail)
                HelpToggleRow("Añadir capítulos", topic: ZEUVEHelpTopics.chapters, isOn: $model.defaultSettings.metadata.addChapters)
                HelpToggleRow("Guardar descripción", topic: ZEUVEHelpTopics.descriptionAndJSON, isOn: $model.defaultSettings.metadata.saveDescription)
                HelpToggleRow("Guardar JSON informativo", topic: ZEUVEHelpTopics.descriptionAndJSON, isOn: $model.defaultSettings.metadata.saveInfoJSON)
                HelpToggleRow("Conservar la fecha de publicación", topic: ZEUVEHelpTopics.publicationDate, isOn: $model.defaultSettings.metadata.preservePublicationDate)
                HelpToggleRow("Guardar metadatos de la lista", topic: ZEUVEHelpTopics.descriptionAndJSON, isOn: $model.defaultSettings.metadata.savePlaylistMetadata)
            }

            Section("Subtítulos") {
                HStack(spacing: 6) {
                    TextField("Idiomas separados por comas", text: subtitleLanguages)
                    ContextualHelpButton(topic: ZEUVEHelpTopics.subtitles)
                }
                HelpToggleRow("Incluir subtítulos automáticos", topic: ZEUVEHelpTopics.subtitles, isOn: $model.defaultSettings.subtitles.includeAutomatic)
                HelpToggleRow("Incrustar subtítulos", topic: ZEUVEHelpTopics.subtitles, isOn: $model.defaultSettings.subtitles.embed)
                HelpToggleRow("Convertir subtítulos a SRT", topic: ZEUVEHelpTopics.subtitles, isOn: $model.defaultSettings.subtitles.convertToSRT)
            }

            Section("Red") {
                HelpStepperRow(
                    "Reintentos: \(model.defaultSettings.network.retryCount)",
                    topic: ZEUVEHelpTopics.retries,
                    value: $model.defaultSettings.network.retryCount,
                    in: 0...100
                )
                HelpStepperRow(
                    "Reintentos de fragmentos: \(model.defaultSettings.network.fragmentRetryCount)",
                    topic: ZEUVEHelpTopics.retries,
                    value: $model.defaultSettings.network.fragmentRetryCount,
                    in: 0...100
                )
                HelpStepperRow(
                    "Tiempo de espera: \(model.defaultSettings.network.connectionTimeoutSeconds) s",
                    topic: ZEUVEHelpTopics.retries,
                    value: $model.defaultSettings.network.connectionTimeoutSeconds,
                    in: 5...120
                )
                HelpStepperRow(
                    "Fragmentos simultáneos: \(model.defaultSettings.network.concurrentFragments)",
                    topic: ZEUVEHelpTopics.concurrentFragments,
                    value: $model.defaultSettings.network.concurrentFragments,
                    in: 1...16
                )
                TextField("Límite de velocidad opcional, por ejemplo 5M", text: speedLimit)
            }

            Section("Operación actual") {
                Button("Aplicar estos valores a la operación actual") {
                    model.applyDefaultSettingsToCurrentOperation()
                }
                .disabled(model.state.isBusy)
            }

            Section("Restablecer") {
                Button("Restaurar valores predeterminados", role: .destructive) {
                    confirmRestore = true
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .onChange(of: model.defaultSettings) { _, _ in model.persistDefaultSettings() }
        .onChange(of: model.defaultAdvancedMode) { _, _ in model.persistDefaultSettings() }
        .confirmationDialog(
            "¿Restaurar los ajustes del Descargador?",
            isPresented: $confirmRestore,
            titleVisibility: .visible
        ) {
            Button("Restaurar", role: .destructive) { model.restoreDefaultSettings() }
            Button("Cancelar", role: .cancel) { }
        } message: {
            Text("Se recuperarán MP4, MP3 a 320 kbps, Título y el resto de valores iniciales. Los presets guardados no se eliminarán.")
        }
    }

    private var subtitleLanguages: Binding<String> {
        Binding(
            get: { model.defaultSettings.subtitles.languages.joined(separator: ", ") },
            set: { value in
                model.defaultSettings.subtitles.languages = value
                    .split(separator: ",")
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
            }
        )
    }

    private var speedLimit: Binding<String> {
        Binding(
            get: { model.defaultSettings.network.speedLimit ?? "" },
            set: { value in
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                model.defaultSettings.network.speedLimit = trimmed.isEmpty ? nil : trimmed
            }
        )
    }
}

private struct YouTubePresetsSettingsView: View {
    @ObservedObject var model: YouTubeDownloaderViewModel
    @State private var newPresetName = ""
    @State private var renameID: UUID?
    @State private var renameText = ""
    @State private var confirmRestore = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Presets de descarga")
                        .font(.title2.bold())
                    Text("Crea y administra configuraciones reutilizables. Dentro del Descargador solo se muestra el selector rápido para aplicarlas.")
                        .foregroundStyle(.secondary)
                }

                GroupBox("Crear preset") {
                    HStack {
                        TextField("Nombre del nuevo preset", text: $newPresetName)
                        Button("Guardar valores predeterminados actuales") {
                            model.saveDefaultSettingsAsPreset(named: newPresetName)
                            newPresetName = ""
                        }
                        .disabled(newPresetName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    .padding(8)
                }

                if model.presets.isEmpty {
                    ContentUnavailableView(
                        "No hay presets",
                        systemImage: "slider.horizontal.3",
                        description: Text("Crea uno a partir de los valores predeterminados actuales o restaura los presets incluidos.")
                    )
                } else {
                    VStack(spacing: 10) {
                        ForEach(model.presets) { preset in
                            HStack(spacing: 12) {
                                Button { model.toggleFavorite(preset) } label: {
                                    Image(systemName: preset.isFavorite ? "star.fill" : "star")
                                }
                                .buttonStyle(.plain)
                                .help(preset.isFavorite ? "Quitar de favoritos" : "Marcar como favorito")

                                VStack(alignment: .leading, spacing: 4) {
                                    if renameID == preset.id {
                                        TextField("Nombre", text: $renameText)
                                            .onSubmit {
                                                model.renamePreset(preset, to: renameText)
                                                renameID = nil
                                            }
                                    } else {
                                        Text(preset.name).font(.headline)
                                    }
                                    Text(presetSummary(preset))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Menu {
                                    Button("Aplicar a la operación actual") { model.applyPreset(preset) }
                                    Button("Usar como valores predeterminados") { model.usePresetAsDefaults(preset) }
                                    Button("Actualizar con los valores predeterminados") { model.updatePresetFromDefaultSettings(preset) }
                                    Button("Renombrar") {
                                        renameID = preset.id
                                        renameText = preset.name
                                    }
                                    Button("Duplicar") { model.duplicatePreset(preset) }
                                    Divider()
                                    Button("Eliminar", role: .destructive) { model.deletePreset(preset) }
                                } label: {
                                    Image(systemName: "ellipsis.circle")
                                }
                            }
                            .padding(12)
                            .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 10))
                        }
                    }
                }

                HStack {
                    Button("Restaurar presets incluidos", role: .destructive) { confirmRestore = true }
                    Spacer()
                }
            }
            .padding(24)
            .frame(maxWidth: 900, alignment: .leading)
        }
        .confirmationDialog(
            "¿Restaurar los presets incluidos?",
            isPresented: $confirmRestore,
            titleVisibility: .visible
        ) {
            Button("Restaurar", role: .destructive) { model.restoreDefaultPresets() }
            Button("Cancelar", role: .cancel) { }
        } message: {
            Text("Se sustituirá la lista actual de presets. Esta acción no modifica los archivos descargados.")
        }
    }

    private func presetSummary(_ preset: YouTubePreset) -> String {
        if preset.settings.mode == .video {
            return "Vídeo · \(preset.settings.maximumResolution.spanishName) · \(preset.settings.container.spanishName)"
        }
        let quality = preset.settings.audioOutput == .mp3 ? " · \(preset.settings.mp3Bitrate.spanishName)" : ""
        return "Audio · \(preset.settings.audioOutput.spanishName)\(quality)"
    }
}

private struct YouTubeDiagnosticsSettingsView: View {
    @ObservedObject var model: YouTubeDownloaderViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Diagnóstico de motores")
                        .font(.title2.bold())
                    Text("Comprueba los componentes incluidos que utiliza el Descargador.")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Comprobar de nuevo") {
                    Task { await model.refreshDiagnostics() }
                }
                .disabled(model.state.isBusy)
            }

            if model.diagnostics.isEmpty {
                ContentUnavailableView(
                    "Motores no disponibles",
                    systemImage: "wrench.and.screwdriver",
                    description: Text(model.unavailableMessage ?? "No se ha podido leer el registro compartido de motores incluidos.")
                )
            } else {
                List(model.diagnostics) { diagnostic in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: diagnostic.isReady ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                            .foregroundStyle(diagnostic.isReady ? .green : .orange)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(diagnostic.descriptor.name) \(diagnostic.descriptor.version)")
                                .font(.headline)
                            Text(diagnostic.message)
                                .foregroundStyle(.secondary)
                            Text(diagnostic.descriptor.architecture.spanishName)
                                .font(.caption)
                            if !diagnostic.technicalDetails.isEmpty {
                                DisclosureGroup("Detalles técnicos") {
                                    ForEach(diagnostic.technicalDetails.indices, id: \.self) { index in
                                        Text(diagnostic.technicalDetails[index])
                                            .font(.caption.monospaced())
                                            .textSelection(.enabled)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                            }
                            if !diagnostic.dynamicDependencies.isEmpty {
                                DisclosureGroup("Dependencias dinámicas") {
                                    ForEach(diagnostic.dynamicDependencies, id: \.self) { dependency in
                                        Text(dependency)
                                            .font(.caption.monospaced())
                                            .textSelection(.enabled)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding(24)
    }
}
