import SwiftUI
import OrganizerModule
import ZEUVECore

struct OrganizerHistoryView: View {
    @EnvironmentObject private var model: OrganizerViewModel

    var body: some View {
        Group {
            if model.historyEntries.isEmpty {
                ContentUnavailableView(
                    "Todavía no hay operaciones",
                    systemImage: "clock.arrow.circlepath",
                    description: Text("Las organizaciones completadas aparecerán aquí.")
                )
            } else {
                List(model.historyEntries) { entry in
                    historyRow(entry)
                }
                .listStyle(.inset)
            }
        }
        .navigationTitle("Historial")
        .toolbar {
            Button("Actualizar") { Task { await model.loadHistory() } }
        }
        .task { await model.loadHistory() }
    }

    private func historyRow(_ entry: OrganizerHistoryEntry) -> some View {
        HStack(spacing: 14) {
            Image(systemName: statusIcon(entry.record.status))
                .font(.title2)
                .foregroundStyle(statusColor(entry.record.status))
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.payload.execution.baseFolder.lastPathComponent)
                    .font(.headline)
                Text("\(entry.payload.execution.moved) archivos · \(entry.record.createdAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if !entry.payload.undoDetails.isEmpty {
                    Text(entry.payload.undoDetails.joined(separator: " · "))
                        .font(.caption2)
                        .foregroundStyle(.orange)
                        .lineLimit(2)
                }
            }
            Spacer()
            Button("Abrir") { model.openFolder(entry.payload.execution.baseFolder) }
            if entry.record.undoAvailable {
                Button("Deshacer") { model.undo(entry) }
                    .disabled(model.state.isBusy)
            }
        }
        .padding(.vertical, 6)
    }

    private func statusIcon(_ status: OperationStatus) -> String {
        switch status {
        case .completed: return "checkmark.circle.fill"
        case .undone: return "arrow.uturn.backward.circle.fill"
        case .partiallyUndone: return "exclamationmark.circle.fill"
        case .undoUnavailable, .failed: return "xmark.circle.fill"
        default: return "clock.fill"
        }
    }

    private func statusColor(_ status: OperationStatus) -> Color {
        switch status {
        case .completed: return .green
        case .undone: return .blue
        case .partiallyUndone: return .orange
        case .undoUnavailable, .failed: return .red
        default: return .secondary
        }
    }
}
