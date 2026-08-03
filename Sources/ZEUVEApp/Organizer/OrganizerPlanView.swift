import SwiftUI
import OrganizerModule

struct OrganizerPlanView: View {
    @EnvironmentObject private var model: OrganizerViewModel
    let plan: OrganizerPlan
    @Binding var confirmExecution: Bool
    @State private var searchText = ""
    @State private var selectionGroupsExpanded = true

    private var summary: OrganizerPlanSummary {
        plan.summary(selectedIDs: model.selectedIDs)
    }

    private var filteredOperations: [OrganizerMoveOperation] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return plan.operations }
        return plan.operations.filter {
            $0.source.lastPathComponent.lowercased().contains(query)
                || relativeDestination($0.destination).lowercased().contains(query)
                || $0.category.lowercased().contains(query)
                || $0.formatFolder.lowercased().contains(query)
        }
    }

    private var categoryNames: [String] {
        Set(plan.operations.map(\.category)).sorted()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            summaryGrid
            groupSelection

            HStack {
                Text("Movimientos")
                    .font(.title2.bold())
                Text("\(model.selectedCount) de \(plan.operations.count) seleccionados")
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Todos") { model.selectAll() }
                Button("Ninguno") { model.selectNone() }
            }

            TextField("Buscar por nombre, destino, categoría o formato", text: $searchText)
                .textFieldStyle(.roundedBorder)

            if plan.operations.isEmpty {
                ContentUnavailableView(
                    "No hay archivos para organizar",
                    systemImage: "checkmark.circle",
                    description: Text("La carpeta está vacía o todos sus elementos han sido omitidos por seguridad.")
                )
                .frame(minHeight: 180)
            } else if filteredOperations.isEmpty {
                ContentUnavailableView.search(text: searchText)
                    .frame(minHeight: 180)
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(filteredOperations) { operation in
                        operationRow(operation)
                        Divider()
                    }
                }
                .background(.background, in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(.quaternary))
            }

            if !plan.ignored.isEmpty {
                DisclosureGroup("Elementos omitidos (\(plan.ignored.count))") {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(plan.ignored) { item in
                            HStack {
                                Image(systemName: "minus.circle")
                                    .foregroundStyle(.secondary)
                                Text(item.url.lastPathComponent)
                                Spacer()
                                Text(item.reason)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.top, 8)
                }
            }

            HStack {
                Button("Exportar plan…") { model.exportPlan() }
                Spacer()
                Button {
                    confirmExecution = true
                } label: {
                    Label("Organizar seleccionados", systemImage: "folder.badge.checkmark")
                }
                .buttonStyle(.borderedProminent)
                .disabled(!model.canExecute)
            }
        }
    }

    private var groupSelection: some View {
        HStack(alignment: .top, spacing: 8) {
            DisclosureGroup("Selección por categoría y formato", isExpanded: $selectionGroupsExpanded) {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(categoryNames, id: \.self) { category in
                        let categoryOperations = plan.operations.filter { $0.category == category }
                        let categoryIDs = Set(categoryOperations.map(\.id))
                        VStack(alignment: .leading, spacing: 7) {
                            Toggle(isOn: groupBinding(ids: categoryIDs)) {
                                HStack {
                                    Label(category, systemImage: icon(for: category))
                                        .font(.body.weight(.semibold))
                                    Spacer()
                                    Text("\(categoryOperations.count)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            let formatNames = Set(categoryOperations.map(\.formatFolder)).sorted()
                            FlowLayout(spacing: 7) {
                                ForEach(formatNames, id: \.self) { format in
                                    let formatIDs = Set(categoryOperations.filter { $0.formatFolder == format }.map(\.id))
                                    Toggle(format, isOn: groupBinding(ids: formatIDs))
                                        .toggleStyle(.button)
                                        .controlSize(.small)
                                }
                            }
                        }
                        if category != categoryNames.last { Divider() }
                    }
                }
                .padding(.top, 10)
            }
            ContextualHelpButton(topic: ZEUVEHelpTopics.groupSelection)
        }
        .padding(14)
        .background(.background, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(.quaternary))
    }

    private var summaryGrid: some View {
        HStack(spacing: 12) {
            SummaryTile(title: "Archivos", value: "\(summary.files)", image: "doc.on.doc")
            SummaryTile(title: "Carpetas nuevas", value: "\(summary.foldersToCreate)", image: "folder.badge.plus")
            SummaryTile(title: "Relacionados", value: "\(summary.relatedGroups)", image: "link")
            SummaryTile(title: "Conflictos", value: "\(summary.conflicts)", image: "exclamationmark.triangle")
            SummaryTile(title: "Omitidos", value: "\(summary.ignored)", image: "minus.circle")
        }
    }

    private func operationRow(_ operation: OrganizerMoveOperation) -> some View {
        HStack(spacing: 12) {
            Toggle("", isOn: Binding(
                get: { model.selectedIDs.contains(operation.id) },
                set: { model.setSelected([operation.id], selected: $0) }
            ))
            .labelsHidden()
            Image(systemName: icon(for: operation.category))
                .frame(width: 26)
                .foregroundStyle(operation.conflict ? Color.orange : Color.accentColor)
            VStack(alignment: .leading, spacing: 3) {
                Text(operation.source.lastPathComponent)
                    .font(.body.weight(.medium))
                Text(relativeDestination(operation.destination))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            if operation.conflict {
                Label("Renombrado", systemImage: "arrow.triangle.2.circlepath")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
            Text(operation.formatFolder)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private func groupBinding(ids: Set<UUID>) -> Binding<Bool> {
        Binding(
            get: { !ids.isEmpty && ids.isSubset(of: model.selectedIDs) },
            set: { model.setSelected(ids, selected: $0) }
        )
    }

    private func relativeDestination(_ url: URL) -> String {
        String(url.path.dropFirst(plan.baseFolder.path.count + 1))
    }

    private func icon(for category: String) -> String {
        switch category {
        case "Imágenes": return "photo"
        case "Vídeos": return "film"
        case "Audio": return "waveform"
        case "Documentos": return "doc.text"
        case "Código": return "chevron.left.forwardslash.chevron.right"
        case "Comprimidos": return "archivebox"
        case "Relacionados": return "link"
        default: return "doc"
        }
    }
}

private struct SummaryTile: View {
    let title: String
    let value: String
    let image: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: image)
                .foregroundStyle(Color.accentColor)
            VStack(alignment: .leading, spacing: 1) {
                Text(value).font(.title3.bold())
                Text(title).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(.background, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(.quaternary))
    }
}
