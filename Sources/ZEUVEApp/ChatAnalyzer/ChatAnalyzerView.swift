import SwiftUI
import AppKit
import UniformTypeIdentifiers
import Charts
import ChatAnalyzerModule

struct ChatAnalyzerView: View {
    @EnvironmentObject private var app: AppModel

    var body: some View {
        ChatAnalyzerObservedContent(model: app.chatAnalyzer)
    }
}

private struct ChatAnalyzerObservedContent: View {
    @ObservedObject var model: ChatAnalyzerViewModel

    var body: some View {
        Group {
            if model.session == nil {
                ChatAnalyzerImportView(model: model)
            } else {
                ChatAnalyzerResultsView(model: model)
            }
        }
        .navigationTitle("Analizador de chats")
        .alert("No se ha podido completar la acción", isPresented: Binding(
            get: { model.errorMessage != nil },
            set: { if !$0 { model.errorMessage = nil } }
        )) {
            Button("Aceptar", role: .cancel) { model.errorMessage = nil }
        } message: { Text(model.errorMessage ?? "Error desconocido") }
        .alert("Aviso", isPresented: Binding(
            get: { model.warningMessage != nil },
            set: { if !$0 { model.warningMessage = nil } }
        )) {
            Button("Aceptar", role: .cancel) { model.warningMessage = nil }
        } message: { Text(model.warningMessage ?? "") }
    }
}

private struct ChatAnalyzerImportView: View {
    @ObservedObject var model: ChatAnalyzerViewModel
    @State private var isTargeted = false
    @State private var instagramInputForSelection: ChatInput?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                privacyCard
                sourcePicker
                if !model.inputs.isEmpty { selectedInputs }
                operationOptions
                actionBar
            }
            .padding(30)
            .frame(maxWidth: 1_050, alignment: .leading)
        }
        .sheet(item: $instagramInputForSelection) { input in
            InstagramConversationSelectorSheet(model: model, input: input)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("Analizador de chats").font(.largeTitle.bold())
            Text("Importa conversaciones exportadas de WhatsApp e Instagram y explora su actividad sin enviar datos fuera del Mac.")
                .font(.title3).foregroundStyle(.secondary)
        }
    }

    private var privacyCard: some View {
        GroupBox {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "lock.shield.fill").font(.title).foregroundStyle(.green)
                VStack(alignment: .leading, spacing: 5) {
                    Text("Análisis privado y completamente local").font(.headline)
                    Text("Los originales se abren en lectura, los adjuntos no se decodifican, los enlaces no se abren y el análisis temporal se elimina al cerrarlo.")
                        .foregroundStyle(.secondary)
                }
            }.frame(maxWidth: .infinity, alignment: .leading).padding(4)
        }
    }

    private var sourcePicker: some View {
        VStack(spacing: 14) {
            Picker("Plataformas", selection: $model.importMode) {
                ForEach(ChatImportMode.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 520)
            .disabled(!model.inputs.isEmpty)
            Image(systemName: isTargeted ? "tray.and.arrow.down.fill" : "bubble.left.and.bubble.right")
                .font(.system(size: 42)).foregroundStyle(isTargeted ? Color.accentColor : .secondary)
            Text(dropTitle)
                .font(.headline)
            Text(dropSubtitle)
                .font(.subheadline).foregroundStyle(.secondary)
            HStack {
                Button("Seleccionar archivos…") { openPanel() }.buttonStyle(.borderedProminent)
                if model.isPreparingInput { ProgressView().controlSize(.small) }
            }
            Toggle("Modo avanzado", isOn: $model.advancedMode).toggleStyle(.switch).fixedSize()
            if !model.inputs.isEmpty {
                Text("Vacía la selección para cambiar el tipo de importación.").font(.caption).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 210)
        .background(Color.accentColor.opacity(isTargeted ? 0.12 : 0.045), in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(isTargeted ? Color.accentColor : Color.secondary.opacity(0.25), style: StrokeStyle(lineWidth: isTargeted ? 2 : 1, dash: [7])))
        .onDrop(of: [UTType.fileURL.identifier], isTargeted: $isTargeted) { providers in
            for provider in providers {
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                    let url: URL?
                    if let data = item as? Data { url = URL(dataRepresentation: data, relativeTo: nil) }
                    else { url = item as? URL }
                    if let url { Task { @MainActor in model.add(urls: [url]) } }
                }
            }
            return true
        }
    }

    private var selectedInputs: some View {
        GroupBox("Fuentes seleccionadas") {
            VStack(spacing: 0) {
                ForEach(model.inputs) { input in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 12) {
                            Image(systemName: input.estimatedPlatform == .instagram ? "camera" : "message.fill")
                                .frame(width: 28).foregroundStyle(input.estimatedPlatform == .instagram ? .pink : .green)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(input.url.lastPathComponent).fontWeight(.medium).lineLimit(1)
                                Text("\(input.estimatedPlatform?.displayName ?? "Desconocido") · \(ByteCountFormatter.string(fromByteCount: input.fingerprint.size, countStyle: .file))")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button(role: .destructive) { model.remove(input) } label: { Image(systemName: "trash") }
                                .buttonStyle(.borderless).help("Quitar de la selección")
                        }
                        if let conversations = model.instagramCatalogs[input.url] {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Conversación de Instagram").font(.caption).foregroundStyle(.secondary)
                                    if let selectedID = model.instagramSelections[input.url],
                                       let selected = conversations.first(where: { $0.id == selectedID }) {
                                        Text(conversationLabel(selected)).lineLimit(2)
                                    } else {
                                        Text("Todavía no has seleccionado una conversación").foregroundStyle(.orange)
                                    }
                                }
                                Spacer()
                                Button(model.instagramSelections[input.url] == nil ? "Elegir chat…" : "Cambiar…") {
                                    instagramInputForSelection = input
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                        if let candidates = model.whatsappCandidates[input.url], candidates.count > 1 {
                            Picker("Archivo de chat", selection: Binding(
                                get: { model.whatsappSelections[input.url] ?? "" },
                                set: { model.whatsappSelections[input.url] = $0 }
                            )) {
                                Text("Selecciona un TXT").tag("")
                                ForEach(candidates, id: \.self) { Text($0).tag($0) }
                            }
                        }
                    }
                    .padding(.vertical, 12)
                    if input.id != model.inputs.last?.id { Divider() }
                }
                HStack {
                    Spacer(); Button("Vaciar selección", role: .destructive) { model.clearInputs() }.buttonStyle(.borderless)
                }.padding(.top, 8)
            }.padding(6)
        }
    }

    private var operationOptions: some View {
        GroupBox("Opciones de este análisis") {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    HelpLabel("Zona horaria de Instagram", topic: ZEUVEHelpTopics.chatTimeZone)
                    Spacer()
                    Picker("", selection: $model.operationSettings.instagramTimeZone) {
                        ForEach(InstagramTimeZoneStrategy.allCases) { Text($0.displayName).tag($0) }
                    }.labelsHidden().frame(maxWidth: 280)
                }
                HStack {
                    HelpLabel("Fechas numéricas ambiguas", topic: ZEUVEHelpTopics.chatNumericDates)
                    Spacer()
                    Picker("", selection: $model.operationSettings.numericDateOrder) {
                        ForEach(AmbiguousNumericDateOrder.allCases) { Text($0.displayName).tag($0) }
                    }.labelsHidden().frame(maxWidth: 280)
                }
                Divider()
                Text("Estas opciones se copian al iniciar. Los valores predeterminados se administran en Ajustes > Analizador de chats.")
                    .font(.caption).foregroundStyle(.secondary)
            }.padding(6)
        }
    }

    private var actionBar: some View {
        HStack {
            Text(model.inputs.isEmpty ? "Añade al menos una fuente para continuar." : "\(model.inputs.count) fuente(s) preparada(s)")
                .foregroundStyle(.secondary)
            Spacer()
            if model.isAnalyzing {
                Button("Cancelar", role: .destructive) { model.cancel() }
                ProgressView().controlSize(.small)
            } else {
                Button("Iniciar análisis") { model.analyze() }
                    .buttonStyle(.borderedProminent).disabled(model.inputs.isEmpty || model.isPreparingInput)
            }
        }
    }

    private func conversationLabel(_ conversation: InstagramConversationDescriptor) -> String {
        let duplicate = conversation.duplicateDisplayName ? " · duplicado \(conversation.id.prefix(6))" : ""
        return "\(conversation.displayName) · \(conversation.category.displayName) · \(conversation.pages.count) pág.\(duplicate)"
    }

    private func openPanel() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseFiles = true
        panel.canChooseDirectories = model.advancedMode && model.importMode.allows(.instagram)
        panel.resolvesAliases = true
        panel.allowedContentTypes = allowedContentTypes
        panel.message = panelMessage
        if panel.runModal() == .OK { model.add(urls: panel.urls) }
    }

    private var allowedContentTypes: [UTType] {
        switch model.importMode {
        case .whatsapp:
            return [.zip, .plainText]
        case .instagram:
            return model.advancedMode ? [.zip, .html] : [.zip]
        case .both:
            return model.advancedMode ? [.zip, .plainText, .html] : [.zip, .plainText]
        }
    }

    private var dropTitle: String {
        switch model.importMode {
        case .whatsapp:
            return "Arrastra el ZIP original o el TXT de WhatsApp"
        case .instagram:
            return model.advancedMode
                ? "Arrastra el ZIP, los HTML o una carpeta de Instagram"
                : "Arrastra el ZIP de Instagram"
        case .both:
            return model.advancedMode
                ? "Arrastra exportaciones ZIP, TXT, HTML o carpetas"
                : "Arrastra exportaciones de WhatsApp o Instagram"
        }
    }

    private var dropSubtitle: String {
        switch model.importMode {
        case .whatsapp:
            return "Admite ZIP y TXT de WhatsApp. También puedes usar el diálogo de macOS."
        case .instagram:
            return model.advancedMode
                ? "Admite ZIP, páginas HTML y carpetas exportadas de Instagram."
                : "Admite el ZIP completo de Meta o un ZIP que contenga un único chat."
        case .both:
            return model.advancedMode
                ? "Admite todos los formatos compatibles de ambas plataformas."
                : "Admite ZIP de ambas plataformas y TXT de WhatsApp."
        }
    }

    private var panelMessage: String {
        switch model.importMode {
        case .whatsapp:
            return "Selecciona el ZIP original o el TXT exportado por WhatsApp."
        case .instagram:
            return model.advancedMode
                ? "Selecciona un ZIP, páginas HTML o una carpeta exportada de Instagram."
                : "Selecciona un ZIP exportado por Instagram."
        case .both:
            return model.advancedMode
                ? "Selecciona exportaciones compatibles de WhatsApp o Instagram."
                : "Selecciona ZIP de WhatsApp o Instagram, o un TXT de WhatsApp."
        }
    }
}

private struct InstagramConversationSelectorSheet: View {
    @ObservedObject var model: ChatAnalyzerViewModel
    let input: ChatInput
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var category: ChatCategory?

    private var conversations: [InstagramConversationDescriptor] {
        let source = model.instagramCatalogs[input.url] ?? []
        return source.filter { conversation in
            (category == nil || conversation.category == category) &&
            (searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || conversation.displayName.localizedCaseInsensitiveContains(searchText))
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack {
                    Picker("Categoría", selection: $category) {
                        Text("Todas").tag(ChatCategory?.none)
                        ForEach(ChatCategory.allCases.filter { $0 != .unknown }) { value in
                            Text(value.displayName).tag(Optional(value))
                        }
                    }
                    .frame(maxWidth: 280)
                    Spacer()
                    Text("\(conversations.count) conversaciones").foregroundStyle(.secondary)
                }
                .padding()
                Divider()
                if conversations.isEmpty {
                    ContentUnavailableView("No se han encontrado chats", systemImage: "bubble.left.and.exclamationmark.bubble.right", description: Text("Cambia la búsqueda o la categoría, o selecciona otro ZIP."))
                } else {
                    List(conversations) { conversation in
                        Button {
                            model.instagramSelections[input.url] = conversation.id
                            dismiss()
                        } label: {
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: conversation.category == .broadcast ? "megaphone" : "bubble.left.and.bubble.right")
                                    .frame(width: 28).foregroundStyle(.secondary)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(conversation.displayName).fontWeight(.medium).foregroundStyle(.primary)
                                    HStack(spacing: 8) {
                                        Text(conversation.category.displayName)
                                        Text("\(conversation.pages.count) página(s)")
                                        if conversation.duplicateDisplayName {
                                            Text("Nombre duplicado · \(conversation.id.prefix(6))").foregroundStyle(.orange)
                                        }
                                    }.font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                if model.instagramSelections[input.url] == conversation.id {
                                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.accentColor)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                Divider()
                HStack {
                    Label("Solo se leen los índices necesarios para mostrar este catálogo.", systemImage: "lock.shield")
                        .font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button("Cancelar") { dismiss() }
                }.padding()
            }
            .navigationTitle("Elegir conversación de Instagram")
            .searchable(text: $searchText, placement: .toolbar, prompt: "Buscar por nombre")
            .frame(minWidth: 720, minHeight: 560)
        }
    }
}
