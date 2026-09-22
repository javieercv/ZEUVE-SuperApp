import SwiftUI
import AppKit
import ZEUVECore
import OrganizerModule
import UniversalDownloaderModule
import ZEUVEEngines
import ChatAnalyzerModule
import UniversalConverterModule

private enum SettingsArea: Identifiable, Hashable {
    case general
    case module(BuiltInModuleID)

    var id: String {
        switch self {
        case .general: return "general"
        case .module(let moduleID): return "module.\(moduleID.rawValue)"
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject private var app: AppModel
    @State private var selectedArea: SettingsArea? = .general

    var body: some View {
        HStack(spacing: 0) {
            List(selection: $selectedArea) {
                Label("General", systemImage: "gearshape")
                    .tag(SettingsArea.general)
                    .padding(.vertical, 3)
                ForEach(app.settingsModules) { module in
                    Label(
                        module.descriptor.settingsTitle ?? module.manifest.name,
                        systemImage: module.manifest.presentation.systemImage
                    )
                    .tag(SettingsArea.module(module.id))
                    .padding(.vertical, 3)
                }
            }
            .listStyle(.sidebar)
            .frame(minWidth: 210, idealWidth: 230, maxWidth: 260)

            Divider()

            Group {
                switch selectedArea ?? .general {
                case .general:
                    GeneralSettingsContent(app: app)
                case .module(let moduleID):
                    BuiltInModuleSettingsRouter(moduleID: moduleID)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationTitle("Ajustes")
        .alert("No se ha podido guardar el ajuste", isPresented: Binding(
            get: { app.settingsError != nil },
            set: { if !$0 { app.settingsError = nil } }
        )) {
            Button("Aceptar", role: .cancel) { app.settingsError = nil }
        } message: {
            Text(app.settingsError ?? "Error desconocido")
        }
    }
}

private struct GeneralSettingsContent: View {
    @ObservedObject var app: AppModel
    @State private var confirmRestoreAll = false

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

            Section {
                ForEach(app.navigationPreferences.moduleOrder, id: \.self) { targetID in
                    if let descriptor = BuiltInModuleCatalog.descriptor(forIdentifier: targetID) {
                        HStack(spacing: 12) {
                            Image(systemName: "line.3.horizontal").foregroundStyle(.tertiary)
                            Text(descriptor.registrationName)
                            Spacer()
                            ShortcutRecorderView(shortcut: app.shortcut(for: descriptor.id)) { shortcut in
                                app.setShortcut(shortcut, forTargetID: descriptor.primaryIdentifier)
                            }
                        }
                        .contentShape(Rectangle())
                        .draggable(targetID)
                        .dropDestination(for: String.self) { values, _ in
                            guard let dragged = values.first else { return false }
                            app.moveNavigationModule(dragged, before: targetID)
                            return true
                        }
                    }
                }
                HStack {
                    Image(systemName: "clock.arrow.circlepath").foregroundStyle(.secondary)
                    Text("Historial")
                    Spacer()
                    ShortcutRecorderView(shortcut: app.historyShortcut) { shortcut in
                        app.setShortcut(shortcut, forTargetID: BuiltInModuleCatalog.historyTargetID)
                    }
                }
                Button("Restaurar orden y atajos predeterminados") { app.restoreNavigationDefaults() }
            } header: {
                Text("Herramientas y atajos")
            } footer: {
                Text("Arrastra los módulos para cambiar el orden compartido de la barra lateral, Inicio y el menú ZEUVE. Inicio y Ajustes conservan sus accesos estándar.")
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

            Section {
                Button("Restaurar todos los ajustes predeterminados", role: .destructive) {
                    confirmRestoreAll = true
                }
                .disabled(!app.canRestoreAllSettings)
            } header: {
                Text("Restablecer")
            } footer: {
                Text("Restaura las preferencias generales y de todos los módulos. Conserva el historial, los preajustes, las favoritas, los perfiles personalizados, las carpetas recientes, los motores y tus archivos. También olvida la sesión de Instagram recordada y las carpetas de salida recordadas.")
            }

            Section("Versión") {
                LabeledContent("ZEUVE", value: ZEUVEProductInfo.displayVersion)
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
        .confirmationDialog(
            "¿Restaurar todos los ajustes de ZEUVE?",
            isPresented: $confirmRestoreAll,
            titleVisibility: .visible
        ) {
            Button("Restaurar todos los ajustes", role: .destructive) {
                app.restoreAllSettingsToDefaults()
            }
            Button("Cancelar", role: .cancel) { }
        } message: {
            Text("Se recuperarán los valores de fábrica de la aplicación y de todos los módulos. No se borrarán el historial, los preajustes, las favoritas, los perfiles personalizados, las carpetas recientes, los motores ni tus archivos.")
        }
    }
}

struct OrganizerModuleSettingsView: View {
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
        .alert("No se ha podido guardar el ajuste", isPresented: Binding(
            get: { model.errorMessage != nil },
            set: { if !$0 { model.errorMessage = nil } }
        )) {
            Button("Aceptar", role: .cancel) { model.errorMessage = nil }
        } message: {
            Text(model.errorMessage ?? "Error desconocido")
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


struct ChatAnalyzerModuleSettingsView: View {
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
