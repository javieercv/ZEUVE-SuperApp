import SwiftUI
import UniformTypeIdentifiers
import OrganizerModule

struct OrganizerView: View {
    @EnvironmentObject private var model: OrganizerViewModel
    @State private var confirmExecution = false
    @State private var advancedOptionsVisible = false

    var body: some View {
        ZStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    if let unavailable = model.unavailableMessage {
                        ContentUnavailableView(
                            "Organizador no disponible",
                            systemImage: "exclamationmark.triangle",
                            description: Text(unavailable)
                        )
                    } else {
                        folderSelection
                        optionsCard
                        actionBar
                        if let plan = model.plan {
                            OrganizerPlanView(plan: plan, confirmExecution: $confirmExecution)
                                .environmentObject(model)
                        }
                    }
                }
                .padding(28)
                .frame(maxWidth: 1_080, alignment: .leading)
            }

            if model.state.isBusy {
                busyOverlay
            }
        }
        .navigationTitle("Organizador")
        .alert("No se ha podido completar la operación", isPresented: Binding(
            get: { model.errorMessage != nil },
            set: { if !$0 { model.errorMessage = nil } }
        )) {
            Button("Aceptar", role: .cancel) { model.errorMessage = nil }
        } message: {
            Text(model.errorMessage ?? "Error desconocido")
        }
        .sheet(item: $model.completion) { completion in
            OrganizerCompletionView(
                completion: completion,
                openFolder: { folder in model.openFolder(folder) },
                undo: { recordID in model.undoCompletion(recordID: recordID) },
                close: { model.completion = nil }
            )
        }
        .confirmationDialog(
            "¿Organizar los archivos seleccionados?",
            isPresented: $confirmExecution,
            titleVisibility: .visible
        ) {
            Button("Organizar \(model.selectedCount) archivos") { model.execute() }
            Button("Cancelar", role: .cancel) { }
        } message: {
            Text("Los archivos se moverán según la vista previa. No se sobrescribirá ningún archivo existente y la operación podrá deshacerse desde el historial mientras los resultados no hayan cambiado.")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Organizador de archivos")
                .font(.largeTitle.bold())
            Text("Revisa exactamente qué ocurrirá antes de mover ningún archivo.")
                .font(.title3)
                .foregroundStyle(.secondary)
            Label("Los originales no se eliminan ni se sobrescriben", systemImage: "lock.shield")
                .font(.callout.weight(.medium))
                .foregroundStyle(.green)
        }
    }

    private var folderSelection: some View {
        GroupBox {
            VStack(spacing: 14) {
                HStack(spacing: 14) {
                    Image(systemName: "folder")
                        .font(.system(size: 28))
                        .foregroundStyle(Color.accentColor)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(model.folderURL?.lastPathComponent ?? "Selecciona una carpeta")
                            .font(.headline)
                        Text(model.folderURL?.path ?? "También puedes arrastrarla a esta zona")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    Spacer()
                    Button("Seleccionar…") { model.chooseFolder() }
                }
                .padding(8)

                if !model.recentFolders.isEmpty {
                    Divider()
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Carpetas recientes")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        FlowLayout(spacing: 8) {
                            ForEach(model.recentFolders, id: \.path) { folder in
                                Button {
                                    model.setFolder(folder)
                                } label: {
                                    Label(folder.lastPathComponent, systemImage: "clock")
                                        .lineLimit(1)
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 8)
                    .padding(.bottom, 6)
                }
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .dropDestination(for: URL.self) { urls, _ in
                guard let first = urls.first else { return false }
                var isDirectory: ObjCBool = false
                guard FileManager.default.fileExists(atPath: first.path, isDirectory: &isDirectory), isDirectory.boolValue else {
                    return false
                }
                model.setFolder(first)
                return true
            } isTargeted: { _ in }
        }
    }

    private var optionsCard: some View {
        GroupBox("Configuración") {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    HelpLabel("Nivel", topic: ZEUVEHelpTopics.organizationLevel)
                    Picker("", selection: $model.options.organizationLevel) {
                        ForEach(OrganizationLevel.allCases, id: \.self) { level in
                            Text(level.displayName).tag(level)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                }

                HelpToggleRow("Agrupar archivos con el mismo nombre", topic: ZEUVEHelpTopics.relatedFiles, isOn: $model.options.keepRelated)
                HelpToggleRow("Incluir subcarpetas", topic: ZEUVEHelpTopics.recursiveFolders, isOn: $model.options.recursive)

                DisclosureGroup("Opciones avanzadas", isExpanded: $advancedOptionsVisible) {
                    VStack(alignment: .leading, spacing: 12) {
                        HelpPickerRow(
                            "Cuando exista el mismo nombre",
                            topic: ZEUVEHelpTopics.organizerConflict,
                            selection: $model.options.conflictPolicy
                        ) {
                            ForEach(ConflictPolicy.allCases, id: \.self) { policy in
                                Text(policy.displayName).tag(policy)
                            }
                        }
                        HelpToggleRow("Incluir archivos y carpetas ocultos", topic: ZEUVEHelpTopics.hiddenFiles, isOn: $model.options.includeHidden)
                        Text("Los enlaces simbólicos y los paquetes de macOS nunca se recorren.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 8)
                }
            }
            .padding(6)
        }
        .disabled(model.state.isBusy)
    }

    private var actionBar: some View {
        HStack {
            if model.plan != nil {
                Button("Descartar vista previa") { model.clearPlan() }
            }
            Spacer()
            Button {
                model.analyze()
            } label: {
                Label(model.plan == nil ? "Analizar carpeta" : "Actualizar vista previa", systemImage: "magnifyingglass")
            }
            .buttonStyle(.borderedProminent)
            .disabled(!model.canPlan)
        }
    }

    private var busyOverlay: some View {
        ZStack {
            Color.black.opacity(0.12).ignoresSafeArea()
            VStack(spacing: 14) {
                if let fraction = model.progress?.fraction {
                    ProgressView(value: fraction)
                        .frame(width: 260)
                } else {
                    ProgressView()
                        .controlSize(.large)
                }
                Text(model.progress?.phase ?? "Procesando")
                    .font(.headline)
                if let current = model.progress?.currentItem {
                    Text(current)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .frame(maxWidth: 320)
                }
                Button("Cancelar", role: .cancel) { model.cancel() }
                    .disabled(model.state == .cancelling)
            }
            .padding(26)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
            .shadow(radius: 18)
        }
    }
}


private struct OrganizerCompletionView: View {
    let completion: OrganizerCompletion
    let openFolder: (URL) -> Void
    let undo: (UUID) -> Void
    let close: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 52))
                .foregroundStyle(.green)
            VStack(spacing: 6) {
                Text(completion.title).font(.title2.bold())
                Text(completion.message)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            if completion.moved != nil || completion.foldersCreated != nil || completion.renamed != nil {
                HStack(spacing: 12) {
                    CompletionMetric(value: completion.moved ?? 0, title: "Archivos")
                    CompletionMetric(value: completion.foldersCreated ?? 0, title: "Carpetas")
                    CompletionMetric(value: completion.renamed ?? 0, title: "Renombrados")
                }
            }
            HStack {
                Button("Cerrar", action: close)
                Spacer()
                if let recordID = completion.undoRecordID {
                    Button("Deshacer") { undo(recordID) }
                }
                if let folder = completion.folder {
                    Button("Abrir carpeta") { openFolder(folder) }
                        .buttonStyle(.borderedProminent)
                }
            }
        }
        .padding(28)
        .frame(width: 520)
    }
}

private struct CompletionMetric: View {
    let value: Int
    let title: String

    var body: some View {
        VStack(spacing: 3) {
            Text("\(value)").font(.title2.bold())
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
    }
}

struct FlowLayout: Layout {
    let spacing: CGFloat

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > width {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: width.isFinite ? width : x, height: y + rowHeight)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
