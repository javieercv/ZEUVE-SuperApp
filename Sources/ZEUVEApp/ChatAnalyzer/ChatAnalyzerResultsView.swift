import SwiftUI
import Charts
import ChatAnalyzerModule

struct ChatAnalyzerResultsView: View {
    @ObservedObject var model: ChatAnalyzerViewModel
    @State private var showFilters = false
    @State private var confirmClose = false
    @State private var confirmAnother = false

    var body: some View {
        VStack(spacing: 0) {
            resultToolbar
            Divider()
            HStack(spacing: 0) {
                List(ChatAnalyzerSection.allCases, selection: $model.selectedSection) { section in
                    Label(section.title, systemImage: section.icon).tag(section).padding(.vertical, 3)
                }
                .listStyle(.sidebar).frame(minWidth: 190, idealWidth: 215, maxWidth: 240)
                Divider()
                sectionContent.frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .confirmationDialog("¿Cerrar el análisis?", isPresented: $confirmClose, titleVisibility: .visible) {
            Button("Cerrar y eliminar datos temporales", role: .destructive) { model.closeAnalysis() }
            Button("Cancelar", role: .cancel) { }
        } message: { Text("Se eliminarán la base temporal y los datos cargados. Los ZIP y archivos originales no se modificarán.") }
        .confirmationDialog("¿Analizar otro chat?", isPresented: $confirmAnother, titleVisibility: .visible) {
            Button("Cerrar y seleccionar otras fuentes", role: .destructive) { model.analyzeAnother() }
            Button("Cancelar", role: .cancel) { }
        }
    }

    private var resultToolbar: some View {
        HStack(spacing: 12) {
            Button { showFilters.toggle() } label: {
                Label(model.filter.activeCount == 0 ? "Filtros" : "Filtros (\(model.filter.activeCount))", systemImage: "line.3.horizontal.decrease.circle")
            }
            .popover(isPresented: $showFilters, arrowEdge: .bottom) { ChatFilterPanel(model: model).frame(width: 430, height: 560) }
            Text("\(model.filteredMessageCount.formatted(.number.locale(Locale(identifier: "es_ES")))) de \(model.messageCount.formatted(.number.locale(Locale(identifier: "es_ES")))) mensajes")
                .font(.subheadline).foregroundStyle(.secondary)
            if model.isUpdatingStatistics {
                ProgressView().controlSize(.small)
                Text("Actualizando estadísticas…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if model.isSearching {
                ProgressView().controlSize(.small)
                Text("Buscando…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Analizar otro chat") { confirmAnother = true }
            Button("Cerrar análisis", role: .destructive) { confirmClose = true }
        }.padding(.horizontal, 18).padding(.vertical, 10)
    }

    @ViewBuilder private var sectionContent: some View {
        switch model.selectedSection {
        case .summary: ChatSummaryView(model: model)
        case .activity: ChatActivityView(model: model)
        case .participants: ChatParticipantsView(model: model)
        case .words: ChatWordsView(model: model)
        case .search: ChatSearchView(model: model)
        case .conversations: ChatConversationsView(model: model)
        case .responses: ChatResponsesView(model: model)
        case .comparison: ChatComparisonView(model: model)
        case .fusions: ChatFusionsView(model: model)
        }
    }
}

