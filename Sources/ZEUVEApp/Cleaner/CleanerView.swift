import SwiftUI
import AppKit
import CleanerModule

private enum CleanerArea: String, CaseIterable, Identifiable {
    case summary = "Resumen"
    case applications = "Aplicaciones"
    case residues = "Residuos"
    case cleaning = "Limpieza"
    case space = "Espacio"
    var id: String { rawValue }
}

struct CleanerView: View {
    @EnvironmentObject private var model: CleanerViewModel
    @State private var area: CleanerArea = .summary
    @State private var search = ""
    @State private var confirmExecution = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            Group {
                switch area {
                case .summary: summary
                case .applications: applications
                case .residues: residues
                case .cleaning: cleaning
                case .space: space
                }
            }
        }
        .navigationTitle("Limpiador")
        .alert("Limpiador", isPresented: Binding(get: { model.errorMessage != nil }, set: { if !$0 { model.errorMessage = nil } })) {
            Button("Aceptar", role: .cancel) { model.errorMessage = nil }
        } message: { Text(model.errorMessage ?? "Error desconocido") }
        .sheet(isPresented: $confirmExecution) { executionReview }
        .dropDestination(for: URL.self) { urls, _ in
            guard let app = urls.first(where: { $0.pathExtension.lowercased() == "app" }) else { return false }
            model.analyzeDroppedApplication(app); area = .applications; return true
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Limpiador").font(.title.bold())
                    Text("Análisis local, revisión explícita y eliminación segura.").foregroundStyle(.secondary)
                }
                Spacer()
                if model.isBusy { ProgressView().controlSize(.small) }
                Button(model.isBusy ? "Cancelar" : "Analizar") {
                    if model.isBusy { model.cancel() } else { Task { await model.analyze() } }
                }
                .keyboardShortcut(.return, modifiers: [.command])
            }
            Picker("Área", selection: $area) {
                ForEach(CleanerArea.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            if let message = model.resultMessage { Text(message).font(.callout).foregroundStyle(.secondary) }
        }
        .padding(20)
    }

    private var summary: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if let result = model.analysis {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 190))], spacing: 12) {
                        metric("Cobertura", coverageName(result.summary.coverage), "shield.lefthalf.filled")
                        metric("Aplicaciones", "\(result.summary.appCount)", "app.dashed")
                        metric("Candidatos", "\(result.summary.candidateCount)", "doc.text.magnifyingglass")
                        metric("Analizado", bytes(result.summary.scannedLogicalBytes), "externaldrive")
                        metric("Selección segura potencial", bytes(result.summary.potentialRecoverableBytes), "sparkles")
                        metric("Sin acceso", "\(result.summary.inaccessibleLocations)", "lock.trianglebadge.exclamationmark")
                    }
                    Text("Selección segura potencial: espacio asignado a elementos regenerables que cumplen las guardas del análisis. No implica que se vayan a eliminar.")
                        .font(.caption).foregroundStyle(.secondary)
                    if let issue = discoveryIssue(result.discoveryStatus) {
                        Label(issue, systemImage: "exclamationmark.triangle")
                            .font(.callout).foregroundStyle(.orange)
                    }
                    GroupBox("Principales candidatos") {
                        VStack(spacing: 0) {
                            ForEach(Array(result.candidates.prefix(8))) { candidate in
                                compactCandidate(candidate)
                                if candidate.id != result.candidates.prefix(8).last?.id { Divider() }
                            }
                        }
                    }
                } else {
                    ContentUnavailableView("Aún no hay análisis", systemImage: "sparkles.rectangle.stack", description: Text("Pulsa Analizar para inventariar aplicaciones, residuos, cachés, logs y elementos regenerables."))
                }
            }
            .padding(24)
        }
    }

    private var applications: some View {
        VStack(spacing: 0) {
            HStack {
                TextField("Buscar aplicación", text: $search).textFieldStyle(.roundedBorder)
                Spacer()
                Text("También puedes arrastrar una .app aquí").font(.caption).foregroundStyle(.secondary)
            }.padding(16)
            Divider()
            if let uninstall = model.uninstallAnalysis {
                uninstallBanner(uninstall)
                Divider()
            }
            List(filteredApplications) { app in
                HStack(spacing: 12) {
                    Image(systemName: app.availability == .externalVolumeUnavailable ? "externaldrive.badge.questionmark" : "app")
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(app.identity.name).fontWeight(.medium)
                        Text(app.identity.path).font(.caption).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                        HStack(spacing: 10) {
                            if let version = app.identity.version { Text("v\(version)") }
                            if let size = app.logicalSize { Text(bytes(size)) }
                            Text(availabilityName(app.availability))
                        }.font(.caption2).foregroundStyle(.tertiary)
                    }
                    Spacer()
                    Button("Mostrar en Finder") { NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: app.identity.path)]) }
                    Button("Analizar desinstalación") { model.analyzeUninstall(app) }
                }
                .padding(.vertical, 4)
            }
        }
    }

    private var residues: some View {
        candidateList(candidates: model.plan.candidates.filter { candidate in
            [.probableResidue, .possibleResidue, .uncertainAssociation, .applicationUnavailable, .keptByUser].contains(candidate.status)
        })
    }

    private var cleaning: some View {
        VStack(spacing: 0) {
            HStack {
                Button("Seleccionar elementos seguros") { model.selectSafeItems() }
                Button("Deseleccionar todo") { model.deselectAll() }
                Spacer()
                Text("\(model.selectedCount) seleccionados · \(bytes(model.selectedBytes))").foregroundStyle(.secondary)
                Button(model.preferences.deletionMode == .trash ? "Mover a Papelera…" : "Eliminar…", role: .destructive) { confirmExecution = true }
                    .disabled(model.selectedCount == 0 || model.isBusy)
                if model.canUndoLast {
                    Button("Deshacer") { Task { await model.undoLast() } }.disabled(model.isBusy)
                }
            }.padding(16)
            if let result = model.executionSummary {
                DisclosureGroup("Resultado: \(result.removedCount) eliminados · \(result.skippedCount) omitidos · \(result.failedCount) fallidos") {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(result.results) { item in
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\(executionStatusName(item.status)): \(item.sourcePath)")
                                        .font(.caption).textSelection(.enabled)
                                    if let message = item.message { Text(message).font(.caption2).foregroundStyle(.secondary) }
                                }
                            }
                        }.frame(maxWidth: .infinity, alignment: .leading)
                    }.frame(maxHeight: 150)
                }.padding(.horizontal, 16).padding(.bottom, 8)
            }
            Divider()
            candidateList(candidates: model.plan.candidates)
        }
    }

    private var space: some View {
        VStack(spacing: 0) {
            HStack {
                Button("Elegir carpeta…") { chooseSpaceFolder() }
                Text(model.spaceRoot.path).font(.caption).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                Spacer()
                Stepper("Mín. \(model.spaceMinimumMB) MB", value: $model.spaceMinimumMB, in: 0...100_000, step: 100)
                Button("Analizar espacio") { Task { await model.scanSpace() } }.disabled(model.isBusy)
            }.padding(16)
            Divider()
            if let tree = model.spaceTree {
                ScrollView { SpaceNodeView(node: tree).padding(16) }
            } else {
                ContentUnavailableView("Explorador de espacio", systemImage: "externaldrive.fill", description: Text("Elige una carpeta o analiza tu carpeta de usuario. Los enlaces simbólicos no se siguen."))
            }
        }
    }

    @ViewBuilder
    private func candidateList(candidates: [CleanerCandidate]) -> some View {
        if candidates.isEmpty {
            ContentUnavailableView("Sin elementos", systemImage: "checkmark.circle", description: Text("No hay candidatos de esta categoría en el análisis actual."))
        } else {
            List(candidates) { candidate in candidateRow(candidate) }
        }
    }

    private func candidateRow(_ candidate: CleanerCandidate) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Toggle("", isOn: Binding(get: { model.plan.candidates.first(where: { $0.id == candidate.id })?.selected ?? false }, set: { model.setSelected($0, candidateID: candidate.id) }))
                .labelsHidden()
                .disabled(!model.canSelect(candidate))
            VStack(alignment: .leading, spacing: 4) {
                Text(candidate.url.lastPathComponent).fontWeight(.medium)
                Text(candidate.url.path).font(.caption).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                HStack(spacing: 10) {
                    Text(categoryName(candidate.category)); Text(statusName(candidate.status)); Text("Riesgo \(riskName(candidate.risk))")
                    if let size = candidate.logicalSize { Text(bytes(size)) }
                }.font(.caption2).foregroundStyle(.tertiary)
                Text(candidate.consequence).font(.caption).foregroundStyle(candidate.containsPotentialUserData ? .orange : .secondary)
                if model.uninstallAnalysis != nil && candidate.category != .application && !model.canSelect(candidate) && CleanerPlanner.canSelect(candidate) {
                    Text("Selecciona primero la aplicación para retirar este elemento.").font(.caption2).foregroundStyle(.orange)
                }
                if let evidence = candidate.evidences.first { Text("Motivo: \(evidence.explanation)").font(.caption2).foregroundStyle(.secondary) }
            }
            Spacer()
            Menu {
                Button("Mostrar en Finder") { NSWorkspace.shared.activateFileViewerSelecting([candidate.url]) }
                Button("Conservar") { model.conserve(candidate) }
                if candidate.associatedBundleID != nil { Button("Indicar dónde está la aplicación…") { chooseApplication(for: candidate) } }
            } label: { Image(systemName: "ellipsis.circle") }
        }.padding(.vertical, 4)
    }

    private func compactCandidate(_ candidate: CleanerCandidate) -> some View {
        HStack { VStack(alignment: .leading) { Text(candidate.url.lastPathComponent); Text(categoryName(candidate.category)).font(.caption).foregroundStyle(.secondary) }; Spacer(); if let size=candidate.logicalSize { Text(bytes(size)).foregroundStyle(.secondary) } }.padding(.vertical, 7)
    }

    private func uninstallBanner(_ uninstall: CleanerUninstallAnalysis) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack { Text("Desinstalación: \(uninstall.application.identity.name)").font(.headline); Spacer(); Text("\(uninstall.plan.candidates.count) elementos revisables").foregroundStyle(.secondary) }
            if uninstall.isRunning { Button("Cerrar aplicación y continuar") { model.closeApplicationAndReanalyze() } }
            if let official = uninstall.officialUninstaller {
                HStack {
                    Text("Se ha detectado un desinstalador oficial relacionado.")
                    Button("Abrir desinstalador oficial") { NSWorkspace.shared.open(official.url) }
                    Button("Reanalizar residuos") { Task { await model.analyze() } }
                }
            }
            Text("La aplicación y cada dato asociado se muestran en Limpieza antes de ejecutar nada.").font(.caption).foregroundStyle(.secondary)
            Button("Revisar plan en Limpieza") { area = .cleaning }
        }.padding(14).background(.quaternary.opacity(0.5))
    }

    private var filteredApplications: [CleanerAppInventoryItem] {
        guard let apps = model.analysis?.applications else { return [] }
        if search.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return apps }
        let q=search.lowercased(); return apps.filter { $0.identity.name.lowercased().contains(q) || ($0.identity.bundleID?.lowercased().contains(q) ?? false) || $0.identity.path.lowercased().contains(q) }
    }

    private var executionTitle: String { model.preferences.deletionMode == .trash ? "¿Mover los elementos seleccionados a Papelera?" : "¿Eliminar permanentemente los elementos seleccionados?" }
    private var executionReview: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(executionTitle).font(.title2.bold())
            Text("\(model.selectedCount) elementos · \(bytes(model.selectedBytes)) de tamaño conocido")
                .font(.headline)
            if model.plan.selectedCandidates.contains(where: { $0.logicalSize == nil }) {
                Text("Algunos elementos no tienen un tamaño disponible; la cifra anterior no los incluye.")
                    .font(.caption).foregroundStyle(.orange)
            }
            Text(model.preferences.deletionMode == .trash
                 ? "Se moverán a la Papelera los elementos de esta lista. Podrás deshacer los movimientos completados."
                 : "El borrado permanente no se puede deshacer. Revisa cada ruta antes de continuar.")
                .foregroundStyle(model.preferences.deletionMode == .trash ? Color.secondary : Color.red)
            List(model.plan.selectedCandidates) { candidate in
                VStack(alignment: .leading, spacing: 4) {
                    Text(candidate.url.lastPathComponent).fontWeight(.medium)
                    Text(candidate.url.path).font(.caption).textSelection(.enabled)
                    Text("\(categoryName(candidate.category)) · \(candidate.logicalSize.map(bytes) ?? "Tamaño no disponible") · Riesgo \(riskName(candidate.risk))")
                        .font(.caption2).foregroundStyle(.secondary)
                    Text(candidate.consequence).font(.caption2).foregroundStyle(.secondary)
                }.padding(.vertical, 3)
            }
            Text("ZEUVE revalidará cada elemento antes de actuar. Los que hayan cambiado se omitirán.")
                .font(.caption).foregroundStyle(.secondary)
            HStack {
                Spacer()
                Button("Cancelar") { confirmExecution = false }
                Button(model.preferences.deletionMode == .trash ? "Mover a Papelera" : "Eliminar permanentemente", role: .destructive) {
                    confirmExecution = false
                    Task { await model.executeCurrentPlan() }
                }.disabled(model.selectedCount == 0 || model.isBusy)
            }
        }
        .padding(20)
        .frame(width: 650, height: 480)
    }
    private func discoveryIssue(_ status: CleanerApplicationDiscoveryStatus) -> String? {
        switch status {
        case .complete: return nil
        case .unavailable: return "Spotlight no pudo completar el inventario. La cobertura es parcial; no se han marcado aplicaciones históricas como desaparecidas por esta causa."
        case .timedOut: return "Spotlight tardó demasiado. La cobertura es parcial; puedes repetir el análisis más tarde."
        case .cancelled: return "El descubrimiento de aplicaciones se canceló."
        }
    }
    private func executionStatusName(_ status: CleanerItemExecutionStatus) -> String {
        switch status {
        case .removed: return "Eliminado"
        case .skippedChanged, .permissionDenied, .unavailable: return "Omitido"
        case .failed: return "Fallido"
        case .restored: return "Restaurado"
        case .restoreConflict: return "Conflicto al restaurar"
        }
    }
    private func metric(_ title:String,_ value:String,_ icon:String)->some View { VStack(alignment:.leading,spacing:8){Image(systemName:icon).font(.title2);Text(value).font(.title2.bold());Text(title).font(.caption).foregroundStyle(.secondary)}.frame(maxWidth:.infinity,alignment:.leading).padding(14).background(.quaternary.opacity(0.45),in:RoundedRectangle(cornerRadius:12)) }
    private func bytes(_ value:Int64)->String{ByteCountFormatter.string(fromByteCount:value,countStyle:.file)}
    private func coverageName(_ c: CleanerCoverage) -> String { switch c { case .complete: return "Completa"; case .partial: return "Parcial"; case .noAccess: return "Sin acceso"; case .notAnalyzed: return "No analizada" } }
    private func availabilityName(_ a: CleanerApplicationAvailability) -> String { switch a { case .installed: return "Instalada"; case .missing: return "No encontrada"; case .externalVolumeUnavailable: return "Volumen no disponible" } }
    private func riskName(_ r: CleanerRemovalRisk) -> String { switch r { case .low: return "bajo"; case .medium: return "medio"; case .high: return "alto" } }
    private func statusName(_ s: CleanerResidueStatus) -> String { switch s { case .probableResidue: return "Residuo probable"; case .possibleResidue: return "Posible residuo"; case .uncertainAssociation: return "Asociación incierta"; case .notResidue: return "No residuo"; case .applicationUnavailable: return "Aplicación no disponible"; case .keptByUser: return "Conservado"; case .regenerable: return "Regenerable" } }
    private func categoryName(_ c: CleanerCandidateCategory) -> String { switch c { case .cache: return "Caché"; case .log: return "Log"; case .preference: return "Preferencias"; case .applicationSupport: return "Application Support"; case .container: return "Container"; case .groupContainer: return "Group Container"; case .savedState: return "Estado guardado"; case .applicationScript: return "Scripts"; case .launchItem: return "Inicio"; case .xcodeDerivedData: return "Xcode DerivedData"; case .xcodeIndex: return "Índice Xcode"; case .installer: return "Instalador"; case .application: return "Aplicación"; case .other: return "Otro" } }

    private func chooseSpaceFolder(){let panel=NSOpenPanel();panel.canChooseDirectories=true;panel.canChooseFiles=false;panel.allowsMultipleSelection=false;if panel.runModal() == .OK,let url=panel.url{model.spaceRoot=url;Task{await model.scanSpace(root:url)}}}
    private func chooseApplication(for candidate:CleanerCandidate){let panel=NSOpenPanel();panel.canChooseDirectories=false;panel.canChooseFiles=true;panel.allowedFileTypes=["app"];panel.allowsMultipleSelection=false;if panel.runModal() == .OK,let url=panel.url{Task{await model.locateApplication(for:candidate,at:url)}}}
}

private struct SpaceNodeView: View {
    let node: CleanerStorageNode
    var body: some View {
        if node.children.isEmpty {
            row
        } else {
            DisclosureGroup { ForEach(node.children) { SpaceNodeView(node: $0).padding(.leading, 12) } } label: { row }
        }
    }
    private var row: some View { HStack { Image(systemName: node.isDirectory ? "folder" : "doc"); Text(node.url.lastPathComponent.isEmpty ? node.url.path : node.url.lastPathComponent); Spacer(); Text(ByteCountFormatter.string(fromByteCount: node.logicalSize, countStyle: .file)).foregroundStyle(.secondary); Button { NSWorkspace.shared.activateFileViewerSelecting([node.url]) } label: { Image(systemName:"arrow.right.circle") }.buttonStyle(.borderless) }.padding(.vertical,3) }
}
