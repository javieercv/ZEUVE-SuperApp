import SwiftUI
import Charts
import ChatAnalyzerModule

struct ChatSearchView: View {
    @ObservedObject var model: ChatAnalyzerViewModel
    private var pageCount: Int {
        max(1, Int(ceil(Double(model.searchResult.totalMessages) / Double(max(model.searchOptions.pageSize, 1)))))
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                SectionTitle(
                    "Búsqueda avanzada",
                    subtitle: "La consulta no se guarda en el historial ni en los registros",
                    topic: ZEUVEHelpTopics.chatSearchOverview
                )
                HStack {
                    TextField("Texto que quieres buscar", text: $model.searchOptions.query)
                        .textFieldStyle(.roundedBorder)
                    HelpLabel("Modo", topic: ZEUVEHelpTopics.chatSearchMode)
                    Picker("", selection: $model.searchOptions.mode) {
                        ForEach(SearchMode.allCases) { Text($0.displayName).tag($0) }
                    }
                    .labelsHidden()
                    .frame(width: 210)
                    Button("Limpiar") { model.searchOptions = ChatSearchOptions() }
                }
                HStack {
                    HelpToggleRow("Ignorar mayúsculas", topic: ZEUVEHelpTopics.chatIgnoreCase, isOn: $model.searchOptions.ignoreCase)
                    HelpToggleRow("Palabras completas", topic: ZEUVEHelpTopics.chatWholeWords, isOn: $model.searchOptions.wholeWords)
                    HelpToggleRow("Ignorar tildes", topic: ZEUVEHelpTopics.chatIgnoreDiacritics, isOn: $model.searchOptions.ignoreDiacritics)
                    HelpLabel("Contexto", topic: ZEUVEHelpTopics.chatSearchContext)
                    Picker("", selection: $model.searchOptions.contextMessages) {
                        Text("1 mensaje").tag(1)
                        Text("3 mensajes").tag(3)
                        Text("5 mensajes").tag(5)
                    }
                    .labelsHidden()
                    .frame(width: 110)
                    HelpLabel("Por página", topic: ZEUVEHelpTopics.chatSearchPageSize)
                    Picker("", selection: $model.searchOptions.pageSize) {
                        Text("25").tag(25)
                        Text("50").tag(50)
                        Text("100").tag(100)
                    }
                    .labelsHidden()
                    .frame(width: 80)
                }
                .font(.subheadline)
                HStack {
                    Text("\(model.searchResult.totalMessages) mensajes · \(model.searchResult.totalOccurrences) apariciones")
                        .font(.headline)
                    ContextualHelpButton(topic: ZEUVEHelpTopics.chatSearchCounts)
                    Spacer()
                    Button {
                        model.searchOptions.page = max(0, model.searchOptions.page - 1)
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                    .disabled(model.searchOptions.page <= 0)
                    Text("Página \(min(model.searchOptions.page + 1, pageCount)) de \(pageCount)").monospacedDigit()
                    Button {
                        model.searchOptions.page = min(pageCount - 1, model.searchOptions.page + 1)
                    } label: {
                        Image(systemName: "chevron.right")
                    }
                    .disabled(model.searchOptions.page + 1 >= pageCount)
                }
                if !model.searchResult.participantCounts.isEmpty {
                    HStack(alignment: .top, spacing: 16) {
                        HelpGroupBox("Por participante", topic: ZEUVEHelpTopics.chatSearchParticipantCounts) {
                            ForEach(model.searchResult.participantCounts.sorted { $0.value > $1.value }, id: \.key) { item in
                                LabeledContent(item.key, value: item.value.formatted())
                            }
                        }
                        .frame(maxWidth: .infinity)
                        HelpGroupBox("Por plataforma", topic: ZEUVEHelpTopics.chatSearchPlatformCounts) {
                            ForEach(ChatPlatform.allCases) { platform in
                                LabeledContent(platform.displayName, value: model.searchResult.platformCounts[platform, default: 0].formatted())
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .padding(22)
            Divider()
            if model.searchOptions.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                EmptyState(icon: "magnifyingglass", title: "Escribe una búsqueda", message: "Los resultados respetarán todos los filtros globales activos.")
            } else if model.searchResult.matches.isEmpty {
                EmptyState(icon: "text.magnifyingglass", title: "Sin coincidencias", message: "Prueba a cambiar el modo o restablecer algún filtro.")
            } else {
                List(model.searchResult.matches) { match in
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(match.before) { context in ContextMessage(message: context) }
                        HStack {
                            Text(match.message.author).fontWeight(.semibold)
                            Text(match.message.platform.displayName).font(.caption).foregroundStyle(.secondary)
                            Spacer()
                            Text(match.message.timestamp.formatted(date: .abbreviated, time: .shortened)).font(.caption).foregroundStyle(.secondary)
                        }
                        Text(match.message.text.isEmpty ? "[\(match.message.contentType.displayName)]" : String(match.message.text.prefix(2_000)))
                            .textSelection(.enabled)
                        Text("\(match.occurrenceCount) coincidencia(s)").font(.caption).foregroundStyle(.secondary)
                        ForEach(match.after) { context in ContextMessage(message: context) }
                    }
                    .padding(.vertical, 8)
                }
            }
        }
        .onChange(of: model.searchOptions.query) { _, _ in model.searchOptions.page = 0 }
        .onChange(of: model.searchOptions.mode) { _, _ in model.searchOptions.page = 0 }
        .onChange(of: model.searchOptions.pageSize) { _, _ in model.searchOptions.page = 0 }
    }
}

struct ContextMessage: View {
    let message: NormalizedMessage
    var body: some View {
        HStack(alignment: .top) {
            Rectangle().fill(.quaternary).frame(width: 3)
            VStack(alignment: .leading) { Text("\(message.author) · \(message.timestamp.formatted(date: .omitted, time: .shortened))").font(.caption).foregroundStyle(.secondary); Text(String(message.text.prefix(300))).font(.caption).foregroundStyle(.secondary) }
        }
    }
}

