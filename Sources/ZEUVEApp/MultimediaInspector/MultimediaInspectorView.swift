import SwiftUI
import UniformTypeIdentifiers
import MultimediaInspectorModule
import ZEUVEEngines

struct MultimediaInspectorView: View {
    @EnvironmentObject private var model: MultimediaInspectorViewModel

    var body: some View {
        Group {
            if model.isBatchMode {
                MultimediaBatchView(
                    model: model.batch,
                    addFiles: model.chooseBatchFiles,
                    openSingle: model.openBatchItem,
                    close: model.closeBatch
                )
            } else {
                VStack(spacing: 0) {
                    header
                    Divider()
                    Group {
                        if model.isInspecting { ProgressView("Inspeccionando con FFprobe…").frame(maxWidth: .infinity, maxHeight: .infinity) }
                        else if let inspection = model.inspection { inspected(inspection) }
                        else {
                            MultimediaEmptyView(chooseSingle: model.chooseFile, chooseMultiple: model.chooseBatchFiles)
                                .padding(24)
                        }
                    }
                }
            }
        }
        .navigationTitle("Inspector multimedia")
        .dropDestination(for: URL.self) { urls, _ in
            model.handleDroppedURLs(urls)
            return !urls.isEmpty
        } isTargeted: { targeted in
            model.isDropTargeted = targeted
        }
        .alert("Descartar cambios", isPresented: $model.needsDiscardConfirmation) {
            Button("Conservar", role: .cancel) { model.keepCurrentDraft() }
            Button("Descartar", role: .destructive) { model.confirmDiscard() }
        } message: {
            Text("Hay cambios sin publicar en el borrador. El original no se ha modificado.")
        }
        .alert("Inspector multimedia", isPresented: Binding(get: { model.errorMessage != nil }, set: { if !$0 { model.errorMessage = nil } })) {
            Button("Aceptar", role: .cancel) { model.errorMessage = nil }
        } message: {
            Text(model.errorMessage ?? "")
        }
        .sheet(isPresented: Binding(get: { !model.pendingExternalCandidates.isEmpty }, set: { if !$0 { model.pendingExternalCandidates = [] } })) {
            candidatePicker
        }
        .sheet(isPresented: Binding(get: { model.ocrDraft != nil || model.isRunningBitmapSubtitleOCR }, set: { if !$0 { model.dismissOCRDraft() } })) {
            MultimediaSubtitleOCRView(model: model)
        }
        .onDisappear { model.stopPreview() }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "waveform.path.ecg").font(.title2)
            VStack(alignment: .leading) {
                HStack(spacing: 5) {
                    Text(model.selectedURL?.lastPathComponent ?? "Inspector multimedia").font(.headline)
                    ContextualHelpButton(topic: ZEUVEHelpTopics.multimediaInspectorOverview)
                }
                if let inspection = model.inspection {
                    Text(headerSummary(inspection)).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            Spacer()

            if model.isBusy {
                Button("Cancelar") { model.cancelCurrentOperation() }
            } else if model.inspection != nil {
                Button("Analizar otro archivo…") { model.chooseFile() }
                    .help("Selecciona otro archivo sin cerrar ZEUVE.")
                Button("Cerrar análisis") { model.requestCloseAnalysis() }
                    .help("Vuelve a la pantalla inicial del Inspector.")
            }

            if model.inspection != nil {
                if model.isEditing {
                    Button("Deshacer") { model.undo() }.disabled(!model.canUndo).keyboardShortcut("z", modifiers: [.command])
                    Button("Rehacer") { model.redo() }.disabled(!model.canRedo).keyboardShortcut("z", modifiers: [.command, .shift])
                    Button("Cancelar edición") { model.requestCancelEditing() }
                    Button("Revisar cambios") { model.preparePlan() }
                        .buttonStyle(.borderedProminent)
                        .disabled(!model.isDirty || model.isExecuting)
                } else {
                    Button("Editar") { model.beginEditing() }
                        .buttonStyle(.borderedProminent)
                        .help("Crea un borrador. El archivo original permanece en solo lectura.")
                }
            }
        }
        .padding(16)
    }

    @ViewBuilder private func inspected(_ inspection: MediaInspectionResult) -> some View {
        VStack(spacing: 12) {
            Picker("Vista", selection: $model.selectedTab) {
                ForEach(MultimediaInspectorTab.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 20)
            .padding(.top, 12)
            if model.isEditing {
                Label(model.isDirty ? "Editando un borrador con cambios pendientes" : "Modo edición: borrador limpio", systemImage: "pencil.and.outline")
                    .font(.caption)
                    .foregroundStyle(model.isDirty ? .orange : .secondary)
            } else {
                Label("Modo inspección · solo lectura", systemImage: "lock")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Group {
                switch model.selectedTab {
                case .summary: MultimediaSummaryView(model: model, inspection: inspection)
                case .tracks: MultimediaTracksView(model: model, inspection: inspection)
                case .spectrogram: MultimediaSpectrogramView(model: model, inspection: inspection)
                case .metadata: MultimediaMetadataView(model: model, inspection: inspection)
                }
            }
            .padding(.horizontal, 20)
            if model.previewState != .idle || !model.videoTracks.isEmpty {
                MultimediaPreviewPlayerView(model: model).padding(.horizontal, 20)
            }
            if let plan = model.editPlan {
                MultimediaEditPreview(plan: plan, inspection: inspection, execute: model.executePreparedPlan)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
            }
            if let warning = model.warningMessage {
                Label(warning, systemImage: "info.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)
            }
        }
    }

    private var candidatePicker: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Seleccionar pista").font(.title2.bold())
            Text("El archivo contiene varias pistas compatibles. Elige cuál añadir; ZEUVE no seleccionará una de forma silenciosa.").foregroundStyle(.secondary)
            List(model.pendingExternalCandidates) { c in
                Button { model.addExternalCandidate(c) } label: {
                    VStack(alignment: .leading) {
                        Text("Stream \(c.stream.index ?? -1) · \(c.stream.codec_name?.uppercased() ?? "")")
                        Text([c.stream.language, c.stream.title, c.stream.channel_layout].compactMap { $0 }.joined(separator: " · ")).foregroundStyle(.secondary)
                    }
                }
            }
            Button("Cancelar") { model.pendingExternalCandidates = [] }.frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(24)
        .frame(minWidth: 520, minHeight: 360)
    }

    private func headerSummary(_ i: MediaInspectionResult) -> String {
        let container = i.format?.format_long_name ?? i.format?.format_name?.uppercased() ?? "Multimedia"
        let video = i.videoStreams.first?.codec_name?.uppercased()
        let size = i.videoStreams.first.flatMap { s in s.width.flatMap { w in s.height.map { "\(w)×\($0)" } } }
        let fps = i.videoStreams.first?.frameRate.map { String(format: "%.3f FPS", $0) }
        let duration = i.durationSeconds.map { formatDuration($0) }
        return [container, video, size, fps, duration].compactMap { $0 }.joined(separator: " · ")
    }

    private func formatDuration(_ v: Double) -> String {
        let t = max(Int(v), 0)
        return String(format: "%02d:%02d:%02d", t / 3600, (t % 3600) / 60, t % 60)
    }
}
