import SwiftUI
import AppKit
import ZEUVECore
import ZEUVEStorage
import OrganizerModule
import YouTubeDownloaderModule
import ChatAnalyzerModule
import UniversalConverterModule

@MainActor
final class GlobalHistoryViewModel: ObservableObject {
    @Published var entries: [GlobalHistoryEntry] = []
    @Published var selectedModuleID: String?
    @Published var errorMessage: String?

    private let service: GlobalHistoryService?
    private let presenters: [any ModuleHistoryPresenter]
    private var loadTask: Task<Void, Never>?

    init(storage: StorageContainer?) {
        service = storage.map { GlobalHistoryService(repository: $0.history) }
        presenters = [OrganizerGlobalHistoryPresenter(), YouTubeHistoryPresenter(), ChatAnalyzerHistoryPresenter(), UniversalConverterHistoryPresenter()]
    }

    func load(manifests: [ModuleManifest]) {
        loadTask?.cancel()
        guard let service else { entries = []; return }
        let presenters = self.presenters
        let moduleID = selectedModuleID
        loadTask = Task { [weak self] in
            let result = await Task.detached(priority: .utility) {
                Result {
                    try service.entries(
                        manifests: manifests,
                        presenters: presenters,
                        moduleID: moduleID,
                        limit: 500
                    )
                }
            }.value
            guard let self, !Task.isCancelled, self.selectedModuleID == moduleID else { return }
            switch result {
            case .success(let entries):
                self.entries = entries
            case .failure(let error):
                self.errorMessage = error.localizedDescription
            }
        }
    }
}

struct GlobalHistoryView: View {
    @EnvironmentObject private var app: AppModel
    @EnvironmentObject private var model: GlobalHistoryViewModel

    var body: some View {
        VStack(spacing: 0) {
            filterBar
            Divider()
            if model.entries.isEmpty {
                ContentUnavailableView(
                    "Todavía no hay operaciones",
                    systemImage: "clock.arrow.circlepath",
                    description: Text("Las operaciones de los módulos aparecerán aquí.")
                )
            } else {
                List(model.entries) { entry in historyRow(entry) }.listStyle(.inset)
            }
        }
        .navigationTitle("Historial")
        .toolbar { Button("Actualizar") { model.load(manifests: app.modules) } }
        .task { model.load(manifests: app.modules) }
        .onChange(of: model.selectedModuleID) { _, _ in model.load(manifests: app.modules) }
        .alert("No se ha podido abrir el historial", isPresented: Binding(get: { model.errorMessage != nil }, set: { if !$0 { model.errorMessage = nil } })) {
            Button("Aceptar", role: .cancel) { model.errorMessage = nil }
        } message: { Text(model.errorMessage ?? "Error desconocido") }
    }

    private var filterBar: some View {
        HStack {
            Picker("Módulo", selection: $model.selectedModuleID) {
                Text("Todos los módulos").tag(String?.none)
                ForEach(app.modules) { module in
                    Label(module.name, systemImage: module.presentation.systemImage).tag(Optional(module.identifier))
                }
            }.frame(maxWidth: 340)
            Spacer()
            Text("\(model.entries.count) operaciones").font(.caption).foregroundStyle(.secondary)
        }.padding(14)
    }

    private func historyRow(_ entry: GlobalHistoryEntry) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: entry.moduleIcon).font(.title2).frame(width: 32).foregroundStyle(statusColor(entry.record.status))
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(entry.presentation.title).font(.headline)
                    Text(entry.moduleName).font(.caption.weight(.medium)).padding(.horizontal, 7).padding(.vertical, 2).background(.quaternary, in: Capsule())
                }
                Text(entry.presentation.subtitle).font(.caption).foregroundStyle(.secondary)
                ForEach(entry.presentation.details, id: \.self) { detail in Text(detail).font(.caption2).foregroundStyle(.secondary).lineLimit(2) }
            }
            Spacer()
            if let output = entry.presentation.outputFolder {
                Button("Abrir") { NSWorkspace.shared.open(output) }
            }
            if entry.record.moduleID == organizerModuleIdentifier,
               entry.record.undoAvailable,
               let organizerEntry = app.organizer.historyEntries.first(where: { $0.id == entry.record.id }) {
                Button("Deshacer") { app.organizer.undo(organizerEntry) }.disabled(app.organizer.state.isBusy)
            }
        }.padding(.vertical, 7)
    }

    private func statusColor(_ status: OperationStatus) -> Color {
        switch status {
        case .completed: return .green
        case .cancelled: return .orange
        case .failed, .undoUnavailable: return .red
        case .undone: return .blue
        case .partiallyUndone: return .orange
        default: return .secondary
        }
    }
}

private struct OrganizerGlobalHistoryPresenter: ModuleHistoryPresenter {
    let moduleID = organizerModuleIdentifier

    func presentation(for record: OperationHistoryRecord) -> ModuleHistoryPresentation {
        guard let payload = try? JSONDecoder().decode(OrganizerHistoryPayload.self, from: record.payload) else {
            return GenericModuleHistoryPresenter(moduleID: moduleID).presentation(for: record)
        }
        let execution = payload.execution
        return ModuleHistoryPresentation(
            title: execution.baseFolder.lastPathComponent,
            subtitle: "\(execution.moved) archivos organizados",
            details: payload.undoDetails,
            outputFolder: execution.baseFolder
        )
    }
}
