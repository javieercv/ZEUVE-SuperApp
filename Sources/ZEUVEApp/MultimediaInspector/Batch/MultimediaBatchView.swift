import SwiftUI
import MultimediaInspectorModule

struct MultimediaBatchView: View {
    @ObservedObject var model: MultimediaBatchViewModel
    let addFiles: () -> Void
    let openSingle: (URL) -> Void
    let close: () -> Void
    @State private var ruleKind: MediaTrackKind = .audio
    @State private var ruleField: MultimediaBatchRuleField = .language
    @State private var ruleMatch: MultimediaBatchRuleMatch = .equals
    @State private var ruleValue = ""
    @State private var ruleAction = "remove"
    @State private var ruleActionValue = ""
    @State private var confirmStructuralExecution = false
    @State private var ruleSetName = ""

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    configurationCard
                    structuralEditingCard
                    queueCard
                    if let summary = model.runSummary { summaryCard(summary) }
                    if let warning = model.warningMessage {
                        Label(warning, systemImage: "info.circle")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if let error = model.errorMessage {
                        Label(error, systemImage: "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
                .padding(20)
            }
        }
        .confirmationDialog("¿Ejecutar la edición estructural por lotes?", isPresented: $confirmStructuralExecution, titleVisibility: .visible) {
            Button("Ejecutar", role: .destructive) { model.executeStructuralBatch() }
            Button("Cancelar", role: .cancel) { }
        } message: {
            Text("Se generará un archivo nuevo por cada plan aplicable. Los originales permanecerán intactos y cada resultado se validará con FFprobe.")
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "square.stack.3d.up").font(.title2)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text("Inspector multimedia · Lote").font(.headline)
                    ContextualHelpButton(topic: ZEUVEHelpTopics.multimediaBatchMode)
                }
                Text("\(model.items.count) archivos · procesamiento secuencial")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if model.isRunning {
                Button("Cancelar lote") { model.cancel() }
            } else {
                Button("Añadir archivos…", action: addFiles)
                Button("Añadir carpeta…") { model.chooseInputFolder() }
                    .help("Enumera archivos sin seguir enlaces simbólicos y aplica los filtros configurados en Ajustes.")
                Button("Cerrar lote", action: close)
            }
        }
        .padding(16)
    }

    private var configurationCard: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    HStack(spacing: 5) {
                    Picker("Preset", selection: Binding(
                        get: { model.selectedPresetID },
                        set: { id in
                            guard let id, let preset = model.presets.first(where: { $0.id == id }) else { return }
                            model.applyPreset(preset)
                        }
                    )) {
                        ForEach(model.presets) { preset in Text(preset.name).tag(Optional(preset.id)) }
                    }
                    .frame(maxWidth: 360)
                    ContextualHelpButton(topic: ZEUVEHelpTopics.multimediaBatchPreset)
                    if let id = model.selectedPresetID, let preset = model.presets.first(where: { $0.id == id }) {
                        Button { model.toggleFavoritePreset(preset) } label: {
                            Image(systemName: model.isFavoritePreset(id) ? "star.fill" : "star")
                        }
                        .buttonStyle(.borderless)
                        .help(model.isFavoritePreset(id) ? "Quitar preset de favoritos" : "Añadir preset a favoritos")
                        .accessibilityLabel(model.isFavoritePreset(id) ? "Quitar preset de favoritos" : "Añadir preset a favoritos")
                    }
                    }
                    Text("Los presets se administran en Ajustes. Los favoritos guardan solo configuraciones, nunca rutas multimedia.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 18) {
                    HelpToggleRow("Analizar señal", topic: ZEUVEHelpTopics.multimediaBatchOperations, isOn: $model.configuration.analyzeSignal)
                    HelpToggleRow("Analizar sonoridad", topic: ZEUVEHelpTopics.multimediaBatchOperations, isOn: $model.configuration.analyzeLoudness)
                    HelpToggleRow("Exportar espectrograma", topic: ZEUVEHelpTopics.multimediaBatchOperations, isOn: $model.configuration.exportSpectrogram)
                }
                .disabled(model.isRunning)

                HStack {
                    HStack(spacing: 5) {
                    Picker("Informe", selection: $model.configuration.reportFormat) {
                        Text("Ninguno").tag(MultimediaTechnicalReportFormat?.none)
                        ForEach(MultimediaTechnicalReportFormat.allCases) { format in
                            Text(format.displayName).tag(Optional(format))
                        }
                    }
                    .frame(maxWidth: 260)
                    ContextualHelpButton(topic: ZEUVEHelpTopics.multimediaReportFormat)
                    }
                    Spacer()
                    if model.needsOutputFolder {
                        ContextualHelpButton(topic: ZEUVEHelpTopics.multimediaBatchOutputFolder)
                        if let folder = model.outputDirectory {
                            Text(folder.lastPathComponent)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                            Button("Cambiar…") { model.chooseOutputFolder() }
                            Button("Quitar") { model.clearOutputFolder() }
                        } else {
                            Button("Seleccionar carpeta de resultados…") { model.chooseOutputFolder() }
                                .buttonStyle(.borderedProminent)
                        }
                    }
                }
                .disabled(model.isRunning)

                if model.isRunning {
                    ProgressView(value: model.overallProgress, total: 1)
                    if let index = model.currentIndex, model.items.indices.contains(index) {
                        let item = model.items[index]
                        HStack {
                            Text("\(index + 1) / \(model.items.count) · \(item.url.lastPathComponent)")
                                .font(.caption.weight(.semibold))
                            Spacer()
                            if let fraction = model.currentFraction {
                                Text("\(Int((fraction * 100).rounded())) %")
                                    .font(.caption.monospacedDigit())
                            }
                        }
                    }
                } else {
                    HStack {
                        Spacer()
                        Button("Iniciar lote") { model.start() }
                            .buttonStyle(.borderedProminent)
                            .disabled(!model.canStart)
                    }
                }
            }
            .padding(8)
        } label: {
            HelpLabel("Configuración del lote", topic: ZEUVEHelpTopics.multimediaBatchMode)
        }
    }

    private var structuralEditingCard: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Picker("Conjunto guardado", selection: Binding<UUID?>(
                        get: { model.savedRuleSets.contains(where: { $0.id == model.structuralRuleSet.id }) ? model.structuralRuleSet.id : nil },
                        set: { id in
                            guard let id, let value = model.savedRuleSets.first(where: { $0.id == id }) else { return }
                            model.applyRuleSet(value)
                            ruleSetName = value.name
                        }
                    )) {
                        Text("Sin seleccionar").tag(UUID?.none)
                        ForEach(model.savedRuleSets) { ruleSet in
                            Text((model.isFavoriteRuleSet(ruleSet.id) ? "★ " : "") + ruleSet.name).tag(Optional(ruleSet.id))
                        }
                    }
                    .frame(maxWidth: 320)
                    ContextualHelpButton(topic: ZEUVEHelpTopics.multimediaStructuralRules)
                    if model.savedRuleSets.contains(where: { $0.id == model.structuralRuleSet.id }) {
                        Button { model.toggleFavoriteRuleSet(model.structuralRuleSet) } label: {
                            Image(systemName: model.isFavoriteRuleSet(model.structuralRuleSet.id) ? "star.fill" : "star")
                        }.buttonStyle(.borderless)
                        Button("Actualizar") { model.updateCurrentRuleSet() }.buttonStyle(.borderless)
                        Button(role: .destructive) { model.deleteRuleSet(model.structuralRuleSet) } label: { Image(systemName: "trash") }.buttonStyle(.borderless)
                    }
                    Spacer()
                    TextField("Nombre para guardar", text: $ruleSetName).frame(maxWidth: 220)
                    Button("Guardar conjunto") { model.saveCurrentRuleSet(named: ruleSetName) }
                        .disabled(model.structuralRuleSet.rules.isEmpty)
                }
                .disabled(model.isPreflighting || model.isExecutingStructural)

                HStack(spacing: 8) {
                    Picker("Tipo", selection: $ruleKind) { ForEach(MediaTrackKind.allCases) { Text($0.displayName).tag($0) } }.frame(width: 120)
                    Picker("Campo", selection: $ruleField) { ForEach(MultimediaBatchRuleField.allCases) { Text($0.displayName).tag($0) } }.frame(width: 130)
                    Picker("Condición", selection: $ruleMatch) { ForEach(MultimediaBatchRuleMatch.allCases) { Text($0.displayName).tag($0) } }.frame(width: 150)
                    TextField("Valor", text: $ruleValue).frame(minWidth: 120)
                    Picker("Acción", selection: $ruleAction) {
                        Text("Eliminar").tag("remove")
                        Text("Cambiar idioma").tag("language")
                        Text("Cambiar título").tag("title")
                        Text("Default sí").tag("defaultOn")
                        Text("Default no").tag("defaultOff")
                        Text("Forced sí").tag("forcedOn")
                        Text("Forced no").tag("forcedOff")
                    }.frame(width: 150)
                    if ruleAction == "language" || ruleAction == "title" { TextField("Nuevo valor", text: $ruleActionValue).frame(minWidth: 120) }
                    Button("Añadir regla") { addStructuralRule() }.buttonStyle(.bordered)
                }
                .disabled(model.isPreflighting || model.isExecutingStructural)

                if model.structuralRuleSet.rules.isEmpty {
                    Text("Sin reglas estructurales. El lote normal de análisis sigue funcionando independientemente.").font(.caption).foregroundStyle(.secondary)
                } else {
                    ForEach(model.structuralRuleSet.rules) { rule in
                        HStack {
                            Text(rule.name).font(.caption.weight(.semibold))
                            Text(ruleSummary(rule)).font(.caption).foregroundStyle(.secondary)
                            Spacer()
                            Button(role: .destructive) { model.removeStructuralRule(rule.id) } label: { Image(systemName: "trash") }.buttonStyle(.borderless)
                        }
                    }
                    HStack {
                        Button(model.isPreflighting ? "Preparando…" : "Generar preflight") { model.prepareStructuralPreflight() }
                            .disabled(model.isPreflighting || model.isExecutingStructural)
                        ContextualHelpButton(topic: ZEUVEHelpTopics.multimediaStructuralRules)
                        if model.isPreflighting { ProgressView().controlSize(.small) }
                        Spacer()
                        if let folder = model.structuralOutputDirectory {
                            Text(folder.lastPathComponent).font(.caption).foregroundStyle(.secondary)
                            Button("Cambiar salida…") { model.chooseStructuralOutputFolder() }
                        } else {
                            Button("Carpeta de salidas…") { model.chooseStructuralOutputFolder() }
                        }
                    }
                }

                if !model.preflightItems.isEmpty {
                    Divider()
                    let applicable = model.preflightItems.filter { $0.classification == .applicable }.count
                    let warnings = model.preflightItems.filter { $0.classification == .applicableWithWarnings }.count
                    let incompatible = model.preflightItems.filter { $0.classification == .incompatible }.count
                    let unchanged = model.preflightItems.filter { $0.classification == .noChanges }.count
                    Text("Preflight · \(applicable) aplicables · \(warnings) con avisos · \(incompatible) incompatibles · \(unchanged) sin cambios")
                        .font(.caption.weight(.semibold))
                    ForEach(model.preflightItems) { item in
                        HStack {
                            Image(systemName: preflightIcon(item.classification))
                            Text(item.url.lastPathComponent).lineLimit(1)
                            Spacer()
                            Text(preflightLabel(item.classification)).font(.caption).foregroundStyle(.secondary)
                            if !item.warnings.isEmpty { Text("\(item.warnings.count) avisos").font(.caption).foregroundStyle(.orange) }
                        }
                    }
                    HStack {
                        if model.isExecutingStructural {
                            ProgressView()
                            Text("Editando secuencialmente · \(model.structuralCompleted) correctos · \(model.structuralFailed) fallidos").font(.caption)
                            Button("Cancelar") { model.cancelStructural() }
                        } else {
                            Spacer()
                            Button("Ejecutar planes aplicables") { confirmStructuralExecution = true }
                                .buttonStyle(.borderedProminent)
                                .disabled(!model.canExecuteStructural)
                        }
                    }
                }
            }.padding(8)
        } label: {
            HelpLabel("Edición estructural por lotes", topic: ZEUVEHelpTopics.multimediaStructuralRules)
        }
    }

    private func addStructuralRule() {
        let action: MultimediaBatchRuleAction
        switch ruleAction {
        case "language": action = .setLanguage(ruleActionValue)
        case "title": action = .setTitle(ruleActionValue)
        case "defaultOn": action = .setDefault(true)
        case "defaultOff": action = .setDefault(false)
        case "forcedOn": action = .setForced(true)
        case "forcedOff": action = .setForced(false)
        default: action = .remove
        }
        let name = "\(ruleKind.displayName) · \(ruleField.displayName) · \(ruleMatch.displayName)"
        model.addStructuralRule(kind: ruleKind, field: ruleField, match: ruleMatch, value: ruleValue, action: action, name: name)
    }

    private func ruleSummary(_ rule: MultimediaBatchStructuralRule) -> String {
        guard let condition = rule.conditions.first else { return "sin condición" }
        return "\(condition.kind.displayName) · \(condition.field.displayName) \(condition.match.displayName.lowercased()) \(condition.value)"
    }

    private func preflightLabel(_ value: MultimediaBatchPreflightClassification) -> String {
        switch value { case .applicable: return "Aplicable"; case .applicableWithWarnings: return "Aplicable con avisos"; case .incompatible: return "Incompatible"; case .noChanges: return "Sin cambios" }
    }
    private func preflightIcon(_ value: MultimediaBatchPreflightClassification) -> String {
        switch value { case .applicable: return "checkmark.circle"; case .applicableWithWarnings: return "exclamationmark.circle"; case .incompatible: return "xmark.circle"; case .noChanges: return "minus.circle" }
    }

    private var queueCard: some View {
        GroupBox {
            LazyVStack(spacing: 0) {
                ForEach(model.items) { item in
                    HStack(spacing: 10) {
                        Image(systemName: icon(for: item.status))
                            .frame(width: 20)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.url.lastPathComponent)
                                .lineLimit(1)
                            Text(item.phase ?? item.status.displayName)
                                .font(.caption)
                                .foregroundStyle(item.status == .failed ? .red : .secondary)
                                .lineLimit(2)
                        }
                        Spacer()
                        if let summary = item.summary {
                            Text(summaryText(summary))
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        if !model.isRunning, item.status.isTerminal {
                            Button("Abrir en Inspector") { openSingle(item.url) }
                                .buttonStyle(.borderless)
                        }
                        if !model.isRunning, !item.status.isTerminal {
                            Button(role: .destructive) { model.remove(item) } label: {
                                Image(systemName: "minus.circle")
                            }
                            .buttonStyle(.borderless)
                            .help("Quitar del lote")
                        }
                    }
                    .padding(.vertical, 8)
                    if item.id != model.items.last?.id { Divider() }
                }
            }
            .padding(.horizontal, 8)
        } label: {
            HelpLabel("Archivos", topic: ZEUVEHelpTopics.multimediaBatchStatuses)
        }
    }

    private func summaryCard(_ summary: MultimediaBatchRunSummary) -> some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                Text("\(summary.total) archivos · \(summary.completed) correctos · \(summary.warnings) con avisos · \(summary.skipped) omitidos · \(summary.failed) fallidos · \(summary.cancelled) cancelados")
                Text("\(summary.reportsGenerated) informes · \(summary.spectrogramsGenerated) espectrogramas · \(formatDuration(summary.durationSeconds))")
                    .foregroundStyle(.secondary)
                HStack {
                    if model.outputDirectory != nil {
                        Button("Abrir carpeta de resultados") { model.openResultsFolder() }
                    }
                    Button("Reintentar fallidos") { model.retryFailures() }
                        .disabled(!model.canRetryFailures)
                    Spacer()
                    Button("Nuevo lote") { model.clear() }
                }
            }
            .padding(8)
        } label: {
            HelpLabel("Lote completado", topic: ZEUVEHelpTopics.multimediaBatchStatuses)
        }
    }

    private func icon(for status: MultimediaBatchItemStatus) -> String {
        switch status {
        case .queued: return "circle"
        case .waiting: return "clock"
        case .inspecting, .analyzingSignal, .analyzingLoudness, .generatingSpectrogram, .exporting: return "arrow.triangle.2.circlepath"
        case .completed: return "checkmark.circle.fill"
        case .completedWithWarning: return "exclamationmark.circle.fill"
        case .skipped: return "minus.circle"
        case .failed: return "xmark.circle.fill"
        case .cancelled: return "stop.circle"
        }
    }

    private func summaryText(_ summary: MultimediaBatchInspectionSummary) -> String {
        "V \(summary.videoStreams) · A \(summary.audioStreams) · S \(summary.subtitleStreams)"
    }

    private func formatDuration(_ value: TimeInterval) -> String {
        let total = max(Int(value.rounded()), 0)
        if total >= 3600 { return String(format: "%d h %02d min %02d s", total / 3600, (total % 3600) / 60, total % 60) }
        return String(format: "%d min %02d s", total / 60, total % 60)
    }
}
