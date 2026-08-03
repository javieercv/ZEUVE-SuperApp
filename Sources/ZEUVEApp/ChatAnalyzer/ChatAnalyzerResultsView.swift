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
            Text("\(model.filteredMessages.count.formatted(.number.locale(Locale(identifier: "es_ES")))) de \(model.messages.count.formatted(.number.locale(Locale(identifier: "es_ES")))) mensajes")
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

private struct ChatFilterPanel: View {
    @ObservedObject var model: ChatAnalyzerViewModel

    var body: some View {
        Form {
            Section("Fechas") {
                Toggle("Limitar fecha inicial", isOn: Binding(get: { model.filter.startDate != nil }, set: { model.filter.startDate = $0 ? startOfDay(model.messages.first?.timestamp ?? Date()) : nil }))
                if model.filter.startDate != nil { DatePicker("Desde", selection: Binding(get: { model.filter.startDate ?? Date() }, set: { model.filter.startDate = startOfDay($0) }), displayedComponents: .date) }
                Toggle("Limitar fecha final", isOn: Binding(get: { model.filter.endDate != nil }, set: { model.filter.endDate = $0 ? endOfDay(model.messages.last?.timestamp ?? Date()) : nil }))
                if model.filter.endDate != nil { DatePicker("Hasta", selection: Binding(get: { model.filter.endDate ?? Date() }, set: { model.filter.endDate = endOfDay($0) }), displayedComponents: .date) }
            }
            Section("Plataformas") {
                ForEach(ChatPlatform.allCases) { platform in
                    Toggle(platform.displayName, isOn: setBinding(platform, in: $model.filter.platforms))
                }
            }
            Section("Participantes") {
                ForEach(model.participantNames, id: \.self) { name in Toggle(name, isOn: setBinding(name, in: $model.filter.participants)) }
            }
            Section("Tipos de contenido") {
                ForEach(ChatContentType.allCases) { type in
                    Toggle(type.displayName, isOn: setBinding(type, in: $model.filter.contentTypes))
                }
            }
            Section("Días de la semana") {
                ForEach(1...7, id: \.self) { day in
                    Toggle(weekdayName(day), isOn: setBinding(day, in: $model.filter.weekdays))
                }
            }
            Section("Horario") {
                Picker("Desde", selection: optionalHour($model.filter.startHour)) { Text("Sin límite").tag(-1); ForEach(0..<24, id: \.self) { Text(String(format: "%02d:00", $0)).tag($0) } }
                Picker("Hasta", selection: optionalHour($model.filter.endHour)) { Text("Sin límite").tag(-1); ForEach(0..<24, id: \.self) { Text(String(format: "%02d:59", $0)).tag($0) } }
                Text("Si la hora inicial es posterior a la final, el intervalo atraviesa la medianoche.").font(.caption).foregroundStyle(.secondary)
            }
            Section { Button("Restablecer todos los filtros") { model.filter = ChatFilter() }.disabled(model.filter.activeCount == 0) }
        }.formStyle(.grouped).padding(8)
    }

    private func setBinding<T: Hashable>(_ value: T, in set: Binding<Set<T>>) -> Binding<Bool> {
        Binding(get: { set.wrappedValue.contains(value) }, set: { enabled in
            if enabled { set.wrappedValue.insert(value) } else { set.wrappedValue.remove(value) }
        })
    }

    private func optionalHour(_ value: Binding<Int?>) -> Binding<Int> {
        Binding(get: { value.wrappedValue ?? -1 }, set: { value.wrappedValue = $0 < 0 ? nil : $0 })
    }

    private func startOfDay(_ date: Date) -> Date { ChatAnalytics.calendar.startOfDay(for: date) }
    private func endOfDay(_ date: Date) -> Date {
        let start = ChatAnalytics.calendar.startOfDay(for: date)
        return ChatAnalytics.calendar.date(byAdding: .day, value: 1, to: start)?.addingTimeInterval(-0.001) ?? date
    }
}

private struct ChatSummaryView: View {
    @ObservedObject var model: ChatAnalyzerViewModel
    private var s: ChatSummaryStatistics { model.summary }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                SectionTitle(
                    "Resumen",
                    subtitle: "Visión general del periodo y los filtros activos",
                    topic: ZEUVEHelpTopics.chatSummaryOverview
                )
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 190), spacing: 14)], spacing: 14) {
                    MetricCard(title: "Mensajes incluidos", value: s.includedMessages.formatted(), detail: "de \(s.totalMessages.formatted())", topic: ZEUVEHelpTopics.chatIncludedMessages)
                    MetricCard(title: "Participantes", value: s.participants.formatted(), detail: "sin mensajes del sistema", topic: ZEUVEHelpTopics.chatParticipantCount)
                    MetricCard(title: "Días activos", value: s.activeDays.formatted(), detail: String(format: "%.1f mensajes/día", s.averagePerActiveDay), topic: ZEUVEHelpTopics.chatActiveDays)
                    MetricCard(title: "WhatsApp", value: s.whatsappMessages.formatted(), detail: percentage(s.whatsappMessages, total: s.includedMessages), topic: ZEUVEHelpTopics.chatPlatformMessages)
                    MetricCard(title: "Instagram", value: s.instagramMessages.formatted(), detail: percentage(s.instagramMessages, total: s.includedMessages), topic: ZEUVEHelpTopics.chatPlatformMessages)
                    MetricCard(title: "Hora más activa", value: s.mostActiveHour.map { String(format: "%02d:00", $0) } ?? "—", detail: weekdayName(s.mostActiveWeekday), topic: ZEUVEHelpTopics.chatMostActiveTime)
                }
                HelpGroupBox("Periodo", topic: ZEUVEHelpTopics.chatPeriod) {
                    HelpValueRow(title: "Primer mensaje", value: format(s.firstMessage), topic: ZEUVEHelpTopics.chatPeriod)
                    HelpValueRow(title: "Último mensaje", value: format(s.lastMessage), topic: ZEUVEHelpTopics.chatPeriod)
                    HelpValueRow(title: "Día con más mensajes", value: s.mostActiveDay?.formatted(date: .long, time: .omitted) ?? "—", topic: ZEUVEHelpTopics.chatMostActiveTime)
                }
                if let importSummary = model.session?.result.summary {
                    HelpGroupBox("Importación", topic: ZEUVEHelpTopics.chatImportSummary) {
                        HelpValueRow(title: "Archivos procesados", value: importSummary.processedFiles.formatted(), topic: ZEUVEHelpTopics.chatImportSummary)
                        HelpValueRow(title: "Páginas HTML", value: importSummary.processedHTMLPages.formatted(), topic: ZEUVEHelpTopics.chatImportSummary)
                        HelpValueRow(title: "Adjuntos referenciados", value: importSummary.referencedAttachments.formatted(), topic: ZEUVEHelpTopics.chatReferencedAttachments)
                        if let unverified = importSummary.unverifiedAttachments, unverified > 0 {
                            HelpValueRow(title: "Adjuntos no comprobados", value: unverified.formatted(), topic: ZEUVEHelpTopics.chatUnverifiedAttachments)
                        }
                        HelpValueRow(title: "Adjuntos faltantes", value: importSummary.missingAttachments.formatted(), topic: ZEUVEHelpTopics.chatMissingAttachments)
                        if !importSummary.warnings.isEmpty {
                            Divider()
                            ForEach(importSummary.warnings) { warning in
                                Label(warning.message, systemImage: "exclamationmark.triangle").foregroundStyle(.orange)
                            }
                        }
                    }
                }
            }
            .padding(26)
            .frame(maxWidth: 1_050, alignment: .leading)
        }
    }

    private func percentage(_ value: Int, total: Int) -> String {
        total == 0 ? "0 %" : String(format: "%.1f %%", Double(value) / Double(total) * 100)
    }

    private func format(_ date: Date?) -> String {
        date?.formatted(date: .long, time: .shortened) ?? "—"
    }
}

private struct ChatActivityView: View {
    @ObservedObject var model: ChatAnalyzerViewModel
    @State private var hoveredDate: Date?
    @State private var hoveredDateLocation: CGPoint?
    @State private var hoveredHour: Int?
    @State private var hoveredHourLocation: CGPoint?
    @State private var hoveredWeekday: Int?
    @State private var hoveredWeekdayLocation: CGPoint?

    private var allSeries: [TimeSeriesPoint] { model.activitySnapshot.series }
    private var totalSeries: [TimeSeriesPoint] { allSeries.filter { $0.platform == nil } }
    private var hourly: [Int] { model.activitySnapshot.hourly }
    private var weekdays: [Int] { model.activitySnapshot.weekdays }
    private var temporalDates: [Date] { totalSeries.map(\.date) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack {
                    SectionTitle(
                        "Actividad",
                        subtitle: "Distribución temporal de los mensajes incluidos",
                        topic: ZEUVEHelpTopics.chatActivityOverview
                    )
                    Spacer()
                    HelpLabel("Granularidad", topic: ZEUVEHelpTopics.chatGranularity)
                    Picker("", selection: $model.granularity) {
                        ForEach(TimeGranularity.allCases) { Text($0.displayName).tag($0) }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .frame(width: 320)
                }
                ChartCard(title: "Evolución temporal", topic: ZEUVEHelpTopics.chatTemporalEvolution, empty: totalSeries.isEmpty) {
                    Chart {
                        ForEach(allSeries) { point in
                            LineMark(x: .value("Fecha", point.date), y: .value("Mensajes", point.count))
                                .foregroundStyle(by: .value("Serie", point.platform?.displayName ?? "Total"))
                                .interpolationMethod(.monotone)
                        }
                        if let hoveredDate {
                            RuleMark(x: .value("Fecha seleccionada", hoveredDate))
                                .foregroundStyle(.secondary)
                                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                            ForEach(activityPoints(at: hoveredDate)) { point in
                                PointMark(x: .value("Fecha", point.date), y: .value("Mensajes", point.count))
                                    .foregroundStyle(by: .value("Serie", point.platform?.displayName ?? "Total"))
                                    .symbolSize(55)
                            }
                        }
                    }
                    .trackChartDateHover(
                        selection: $hoveredDate,
                        cursorLocation: $hoveredDateLocation,
                        dates: temporalDates
                    )
                    .chartCursorTooltip(at: hoveredDateLocation) {
                        if let hoveredDate {
                            ChartTooltipCard(
                                title: chartPeriodTitle(hoveredDate, granularity: model.granularity),
                                rows: activityTooltipRows(at: hoveredDate)
                            )
                        }
                    }
                    .accessibilityLabel("Evolución temporal total, de WhatsApp y de Instagram")
                } alternative: {
                    Text(allSeries.map { "\($0.platform?.displayName ?? "Total") · \($0.date.formatted(date: .abbreviated, time: .omitted)): \($0.count)" }.joined(separator: ", "))
                }
                ChartCard(title: "Actividad por hora", topic: ZEUVEHelpTopics.chatHourlyActivity, empty: model.filteredMessages.isEmpty) {
                    Chart {
                        ForEach(0..<24, id: \.self) { hour in
                            BarMark(x: .value("Hora", hour), y: .value("Mensajes", hourly[hour]))
                                .opacity(hoveredHour == nil || hoveredHour == hour ? 1 : 0.4)
                        }
                        if let hoveredHour {
                            RuleMark(x: .value("Hora seleccionada", hoveredHour))
                                .foregroundStyle(.secondary)
                                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        }
                    }
                    .trackChartCategoryHover(
                        selection: $hoveredHour,
                        cursorLocation: $hoveredHourLocation,
                        categoryCount: 24
                    )
                    .chartCursorTooltip(at: hoveredHourLocation) {
                        if let hoveredHour {
                            ChartTooltipCard(
                                title: chartHourTitle(hoveredHour),
                                rows: [ChartTooltipRow("Mensajes", value: hourly[hoveredHour].formatted(), emphasized: true)]
                            )
                        }
                    }
                } alternative: {
                    Text(hourly.enumerated().map { "\($0.offset) h: \($0.element)" }.joined(separator: ", "))
                }
                ChartCard(title: "Actividad por día de la semana", topic: ZEUVEHelpTopics.chatWeekdayActivity, empty: model.filteredMessages.isEmpty) {
                    Chart {
                        ForEach(0..<7, id: \.self) { index in
                            BarMark(x: .value("Día", weekdayName(index + 1)), y: .value("Mensajes", weekdays[index]))
                                .opacity(hoveredWeekday == nil || hoveredWeekday == index ? 1 : 0.4)
                        }
                        if let hoveredWeekday {
                            RuleMark(x: .value("Día seleccionado", weekdayName(hoveredWeekday + 1)))
                                .foregroundStyle(.secondary)
                                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        }
                    }
                    .trackChartCategoryHover(
                        selection: $hoveredWeekday,
                        cursorLocation: $hoveredWeekdayLocation,
                        categoryCount: 7
                    )
                    .chartCursorTooltip(at: hoveredWeekdayLocation) {
                        if let hoveredWeekday {
                            ChartTooltipCard(
                                title: weekdayName(hoveredWeekday + 1),
                                rows: [ChartTooltipRow("Mensajes", value: weekdays[hoveredWeekday].formatted(), emphasized: true)]
                            )
                        }
                    }
                } alternative: {
                    Text(weekdays.enumerated().map { "\(weekdayName($0.offset + 1)): \($0.element)" }.joined(separator: ", "))
                }
                HeatmapView(cells: model.activitySnapshot.heatmap)
            }
            .padding(26)
        }
        .onChange(of: model.granularity) { _, _ in
            hoveredDate = nil
            hoveredDateLocation = nil
        }
        .onDisappear {
            hoveredDate = nil
            hoveredDateLocation = nil
            hoveredHour = nil
            hoveredHourLocation = nil
            hoveredWeekday = nil
            hoveredWeekdayLocation = nil
        }
    }

    private func activityPoints(at date: Date) -> [TimeSeriesPoint] {
        allSeries.filter { $0.date == date }
    }

    private func activityTooltipRows(at date: Date) -> [ChartTooltipRow] {
        let points = activityPoints(at: date)
        let total = points.first(where: { $0.platform == nil })?.count ?? 0
        var rows = [ChartTooltipRow("Total", value: total.formatted(), emphasized: true)]
        for platform in ChatPlatform.allCases where allSeries.contains(where: { $0.platform == platform }) {
            let count = points.first(where: { $0.platform == platform })?.count ?? 0
            rows.append(ChartTooltipRow(platform.displayName, value: count.formatted()))
        }
        return rows
    }
}

private struct HeatmapHoverValue: Equatable {
    let weekday: Int
    let hour: Int
    let count: Int
    var id: String { "\(weekday)-\(hour)" }
}

private struct HeatmapView: View {
    let cells: [HeatmapCell]
    @State private var hoveredCell: HeatmapHoverValue?
    @State private var hoveredCellLocation: CGPoint?

    private let coordinateSpaceName = "ChatHeatmapSpace"

    private var maximum: Int { max(cells.map(\.count).max() ?? 0, 1) }

    var body: some View {
        HelpGroupBox("Mapa de calor · 7 días × 24 horas", topic: ZEUVEHelpTopics.chatHeatmap) {
            VStack(alignment: .leading, spacing: 5) {
                ForEach(1...7, id: \.self) { day in
                    HStack(spacing: 3) {
                        Text(shortWeekday(day)).font(.caption2).frame(width: 24, alignment: .trailing)
                        ForEach(0..<24, id: \.self) { hour in
                            let count = cells.first { $0.weekday == day && $0.hour == hour }?.count ?? 0
                            let cell = HeatmapHoverValue(weekday: day, hour: hour, count: count)
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.accentColor.opacity(cell.count == 0 ? 0.06 : 0.15 + 0.85 * Double(cell.count) / Double(maximum)))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 2)
                                        .stroke(hoveredCell?.id == cell.id ? Color.primary : Color.clear, lineWidth: 1.5)
                                }
                                .frame(height: 18)
                                .contentShape(Rectangle())
                                .overlay {
                                    GeometryReader { cellGeometry in
                                        Color.clear
                                            .contentShape(Rectangle())
                                            .onContinuousHover { phase in
                                                switch phase {
                                                case .active(let location):
                                                    let frame = cellGeometry.frame(in: .named(coordinateSpaceName))
                                                    hoveredCell = cell
                                                    hoveredCellLocation = CGPoint(
                                                        x: frame.minX + location.x,
                                                        y: frame.minY + location.y
                                                    )
                                                case .ended:
                                                    if hoveredCell?.id == cell.id {
                                                        hoveredCell = nil
                                                        hoveredCellLocation = nil
                                                    }
                                                }
                                            }
                                    }
                                }
                                .help("\(weekdayName(day)), \(hour):00: \(cell.count) mensajes")
                        }
                    }
                }
                HStack {
                    Spacer().frame(width: 28)
                    Text("0 h")
                    Spacer()
                    Text("12 h")
                    Spacer()
                    Text("23 h")
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
            .padding(8)
            .coordinateSpace(name: coordinateSpaceName)
            .chartCursorTooltip(at: hoveredCellLocation) {
                if let hoveredCell {
                    ChartTooltipCard(
                        title: weekdayName(hoveredCell.weekday),
                        rows: [
                            ChartTooltipRow("Franja", value: chartHourTitle(hoveredCell.hour)),
                            ChartTooltipRow("Mensajes", value: hoveredCell.count.formatted(), emphasized: true),
                        ]
                    )
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Mapa de calor de actividad por día y hora")
        .onDisappear {
            hoveredCell = nil
            hoveredCellLocation = nil
        }
    }
}

private struct ChatParticipantsView: View {
    @ObservedObject var model: ChatAnalyzerViewModel

    var body: some View {
        HStack(spacing: 0) {
            List(selection: $model.selectedParticipant) {
                Section {
                    ForEach(model.participants) { participant in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(participant.name).fontWeight(.medium)
                                Spacer()
                                Text(participant.messages.formatted()).monospacedDigit()
                            }
                            ProgressView(value: participant.percentage, total: 100)
                            Text(String(format: "%.1f %% · %d días activos · %@", participant.percentage, participant.activeDays, participant.platforms.map(\.displayName).sorted().joined(separator: " + ")))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .tag(participant.name)
                        .padding(.vertical, 5)
                    }
                } header: {
                    HStack(spacing: 5) {
                        Text("Participantes")
                        ContextualHelpButton(topic: ZEUVEHelpTopics.chatParticipantMessages)
                    }
                }
            }
            .frame(minWidth: 260, idealWidth: 310, maxWidth: 360)
            Divider()
            if let selected = model.selectedParticipant ?? model.participantNames.first,
               let stats = model.participants.first(where: { $0.name == selected }) {
                if let detail = model.participantsSnapshot.details[selected] {
                    ParticipantProfile(stats: stats, detail: detail)
                } else {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("Preparando el perfil…")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else if model.isUpdatingSection {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Calculando participantes…")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                EmptyState(icon: "person.2", title: "No hay participantes", message: "Ajusta los filtros o carga una conversación con mensajes personales.")
            }
        }
        .onAppear {
            if model.selectedParticipant == nil { model.selectedParticipant = model.participantNames.first }
        }
    }
}

private struct ParticipantProfile: View {
    let stats: ParticipantStatistics
    let detail: ParticipantDetailAnalyticsSnapshot
    @State private var hoveredMonth: Date?
    @State private var hoveredMonthLocation: CGPoint?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                SectionTitle(
                    stats.name,
                    subtitle: "Perfil estadístico dentro de los filtros activos",
                    topic: ZEUVEHelpTopics.chatParticipantOverview
                )
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 170), spacing: 12)], spacing: 12) {
                    MetricCard(title: "Mensajes", value: stats.messages.formatted(), detail: String(format: "%.1f %%", stats.percentage), topic: ZEUVEHelpTopics.chatParticipantMessages)
                    MetricCard(title: "Palabras", value: stats.words.formatted(), detail: String(format: "%.1f por mensaje", stats.averageWords), topic: ZEUVEHelpTopics.chatWordCount)
                    MetricCard(title: "Mediana", value: String(format: "%.1f", stats.medianWords), detail: "palabras por mensaje", topic: ZEUVEHelpTopics.chatMedianWords)
                    MetricCard(title: "Longitud media", value: String(format: "%.1f", stats.averageLength), detail: "caracteres por mensaje", topic: ZEUVEHelpTopics.chatAverageLength)
                    MetricCard(title: "Emojis", value: stats.emojis.formatted(), detail: "total", topic: ZEUVEHelpTopics.chatEmojiCount)
                    MetricCard(title: "Preguntas", value: stats.questions.formatted(), detail: ratio(stats.questions, stats.messages), topic: ZEUVEHelpTopics.chatQuestionCount)
                    MetricCard(title: "Multimedia", value: stats.multimedia.formatted(), detail: ratio(stats.multimedia, stats.messages), topic: ZEUVEHelpTopics.chatMultimedia)
                    MetricCard(title: "Hora habitual", value: usualHour, detail: "día habitual: \(usualWeekday)", topic: ZEUVEHelpTopics.chatUsualActivity)
                }
                HelpGroupBox("Contenido frecuente", topic: ZEUVEHelpTopics.chatFrequentContent) {
                    FrequencyRows(title: "Palabras", items: detail.words)
                    Divider()
                    FrequencyRows(title: "Frases de dos palabras", items: detail.bigrams)
                    Divider()
                    FrequencyRows(title: "Emojis", items: detail.emojis)
                }
                HelpGroupBox("Periodo", topic: ZEUVEHelpTopics.chatParticipantPeriod) {
                    HelpValueRow(title: "Primera aparición", value: stats.firstMessage?.formatted(date: .long, time: .shortened) ?? "—", topic: ZEUVEHelpTopics.chatParticipantPeriod)
                    HelpValueRow(title: "Última aparición", value: stats.lastMessage?.formatted(date: .long, time: .shortened) ?? "—", topic: ZEUVEHelpTopics.chatParticipantPeriod)
                    HelpValueRow(title: "Mensajes por día activo", value: String(format: "%.1f", stats.messagesPerActiveDay), topic: ZEUVEHelpTopics.chatMessagesPerActiveDay)
                    HelpValueRow(title: "Plataformas", value: stats.platforms.map(\.displayName).sorted().joined(separator: " + "), topic: ZEUVEHelpTopics.chatPlatformBreakdown)
                    HelpValueRow(title: "Enlaces", value: "\(stats.links) · \(ratio(stats.links, stats.messages))", topic: ZEUVEHelpTopics.chatLinks)
                    HelpValueRow(title: "Mayúsculas", value: "\(stats.uppercaseMessages) · \(ratio(stats.uppercaseMessages, stats.messages))", topic: ZEUVEHelpTopics.chatUppercase)
                }
                HelpGroupBox("Desglose por plataforma", topic: ZEUVEHelpTopics.chatPlatformBreakdown) {
                    ForEach(ChatPlatform.allCases) { platform in
                        LabeledContent(platform.displayName, value: detail.platformCounts[platform, default: 0].formatted())
                    }
                }
                HelpGroupBox("Tipos de contenido", topic: ZEUVEHelpTopics.chatContentTypes) {
                    ForEach(ChatContentType.allCases) { type in
                        if let count = stats.contentCounts[type], count > 0 {
                            LabeledContent(type.displayName, value: count.formatted())
                        }
                    }
                }
                ChartCard(title: "Evolución mensual", topic: ZEUVEHelpTopics.chatMonthlyEvolution, empty: detail.monthlySeries.isEmpty) {
                    Chart {
                        ForEach(detail.monthlySeries) { point in
                            LineMark(x: .value("Mes", point.date), y: .value("Mensajes", point.count))
                                .interpolationMethod(.monotone)
                        }
                        if let hoveredMonth,
                           let point = detail.monthlySeries.first(where: { $0.date == hoveredMonth }) {
                            RuleMark(x: .value("Mes seleccionado", hoveredMonth))
                                .foregroundStyle(.secondary)
                                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                            PointMark(x: .value("Mes", point.date), y: .value("Mensajes", point.count))
                                .symbolSize(55)
                        }
                    }
                    .trackChartDateHover(
                        selection: $hoveredMonth,
                        cursorLocation: $hoveredMonthLocation,
                        dates: detail.monthlySeries.map(\.date)
                    )
                    .chartCursorTooltip(at: hoveredMonthLocation) {
                        if let hoveredMonth,
                           let point = detail.monthlySeries.first(where: { $0.date == hoveredMonth }) {
                            ChartTooltipCard(
                                title: chartPeriodTitle(hoveredMonth, granularity: .month),
                                rows: [ChartTooltipRow("Mensajes", value: point.count.formatted(), emphasized: true)]
                            )
                        }
                    }
                } alternative: {
                    Text(detail.monthlySeries.map { "\($0.date.formatted(date: .abbreviated, time: .omitted)): \($0.count)" }.joined(separator: ", "))
                }
                if let longest = detail.longestMessage, !longest.text.isEmpty {
                    HelpGroupBox("Mensaje más largo", topic: ZEUVEHelpTopics.chatLongestMessage) {
                        Text(String(longest.text.prefix(500))).textSelection(.enabled)
                        Text(longest.timestamp.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(26)
        }
        .onDisappear {
            hoveredMonth = nil
            hoveredMonthLocation = nil
        }
    }

    private func ratio(_ value: Int, _ total: Int) -> String {
        total == 0 ? "0 %" : String(format: "%.1f %%", Double(value) / Double(total) * 100)
    }

    private var usualHour: String {
        let counts = detail.hourly
        guard let index = counts.indices.max(by: { counts[$0] < counts[$1] }), counts[index] > 0 else { return "—" }
        return String(format: "%02d:00", index)
    }

    private var usualWeekday: String {
        let counts = detail.weekdays
        guard let index = counts.indices.max(by: { counts[$0] < counts[$1] }), counts[index] > 0 else { return "—" }
        return weekdayName(index + 1)
    }
}

private struct ChatWordsView: View {
    @ObservedObject var model: ChatAnalyzerViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                SectionTitle(
                    "Palabras y emojis",
                    subtitle: "Frecuencias calculadas sobre los mensajes incluidos",
                    topic: ZEUVEHelpTopics.chatWordsOverview
                )
                HStack {
                    HelpToggleRow(
                        "Incluir palabras vacías",
                        topic: ZEUVEHelpTopics.chatStopWords,
                        isOn: $model.operationSettings.includeStopWords
                    )
                    Spacer()
                    HelpLabel("Multimedia", topic: ZEUVEHelpTopics.chatMultimedia)
                    Picker("", selection: $model.operationSettings.multimediaDefinition) {
                        ForEach(MultimediaDefinition.allCases) { Text($0.displayName).tag($0) }
                    }
                    .labelsHidden()
                    .frame(maxWidth: 280)
                }
                if model.operationSettings.multimediaDefinition == .configurable {
                    HelpGroupBox("Categorías consideradas multimedia", topic: ZEUVEHelpTopics.chatMultimedia) {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150))]) {
                            ForEach(ChatContentType.allCases.filter { $0 != .text && $0 != .system }) { type in
                                Toggle(type.displayName, isOn: Binding(
                                    get: { model.operationSettings.configurableMultimediaTypes.contains(type) },
                                    set: { enabled in
                                        if enabled { model.operationSettings.configurableMultimediaTypes.insert(type) }
                                        else { model.operationSettings.configurableMultimediaTypes.remove(type) }
                                    }
                                ))
                            }
                        }
                    }
                }
                HStack(alignment: .top, spacing: 16) {
                    HelpGroupBox("Palabras frecuentes", topic: ZEUVEHelpTopics.chatWordFrequency) {
                        FrequencyRows(title: nil, items: model.wordsSnapshot.words)
                    }
                    .frame(maxWidth: .infinity)
                    HelpGroupBox("Frases de dos palabras", topic: ZEUVEHelpTopics.chatBigrams) {
                        FrequencyRows(title: nil, items: model.wordsSnapshot.bigrams)
                    }
                    .frame(maxWidth: .infinity)
                    HelpGroupBox("Emojis", topic: ZEUVEHelpTopics.chatEmojiFrequency) {
                        FrequencyRows(title: nil, items: model.wordsSnapshot.emojis)
                    }
                    .frame(maxWidth: .infinity)
                }
                HelpGroupBox("Por participante", topic: ZEUVEHelpTopics.chatParticipantFrequency) {
                    ForEach(model.wordsSnapshot.participants) { participant in
                        VStack(alignment: .leading, spacing: 5) {
                            Text(participant.name).font(.headline)
                            Text("Palabras: " + participant.words.map { "\($0.value) (\($0.count))" }.joined(separator: ", "))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("Emojis: " + participant.emojis.map { "\($0.value) (\($0.count))" }.joined(separator: ", "))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
                HelpGroupBox("Tipos de contenido", topic: ZEUVEHelpTopics.chatContentTypes) {
                    ForEach(ChatContentType.allCases) { type in
                        if let count = model.wordsSnapshot.contentCounts[type], count > 0 {
                            LabeledContent(type.displayName, value: count.formatted())
                        }
                    }
                }
            }
            .padding(26)
        }
    }
}

private struct ChatSearchView: View {
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

private struct ContextMessage: View {
    let message: NormalizedMessage
    var body: some View {
        HStack(alignment: .top) {
            Rectangle().fill(.quaternary).frame(width: 3)
            VStack(alignment: .leading) { Text("\(message.author) · \(message.timestamp.formatted(date: .omitted, time: .shortened))").font(.caption).foregroundStyle(.secondary); Text(String(message.text.prefix(300))).font(.caption).foregroundStyle(.secondary) }
        }
    }
}

private struct ChatConversationsView: View {
    @ObservedObject var model: ChatAnalyzerViewModel
    private var stats: ConversationStatistics { model.conversations }

    private var usualStartHour: String {
        let grouped = Dictionary(grouping: stats.conversations, by: { ChatAnalytics.calendar.component(.hour, from: $0.start) })
        guard let hour = grouped.max(by: { $0.value.count < $1.value.count })?.key else { return "—" }
        return String(format: "%02d:00", hour)
    }

    private var usualStartWeekday: String {
        let grouped = Dictionary(grouping: stats.conversations, by: { ChatAnalytics.calendar.component(.weekday, from: $0.start) })
        return weekdayName(grouped.max(by: { $0.value.count < $1.value.count })?.key)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                SectionTitle(
                    "Conversaciones",
                    subtitle: "Agrupaciones temporales, no temáticas",
                    topic: ZEUVEHelpTopics.chatConversationsOverview
                )
                HStack {
                    HelpLabel("Pausa que separa conversaciones", topic: ZEUVEHelpTopics.chatConversationThreshold)
                    Picker("", selection: $model.operationSettings.conversationThresholdMinutes) {
                        Text("30 minutos").tag(30)
                        Text("1 hora").tag(60)
                        Text("3 horas").tag(180)
                        Text("6 horas").tag(360)
                        Text("12 horas").tag(720)
                        Text("24 horas").tag(1_440)
                    }
                    .labelsHidden()
                    .frame(width: 180)
                    Spacer()
                    HelpLabel("Cálculo", topic: ZEUVEHelpTopics.chatConversationFilters)
                    Picker("", selection: $model.operationSettings.conversationFilterStrategy) {
                        ForEach(ConversationFilterStrategy.allCases) { Text($0.displayName).tag($0) }
                    }
                    .labelsHidden()
                    .frame(width: 300)
                }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 12)], spacing: 12) {
                    MetricCard(title: "Conversaciones", value: stats.conversations.count.formatted(), detail: "grupos temporales", topic: ZEUVEHelpTopics.chatConversationCount)
                    MetricCard(title: "Duración media", value: duration(stats.averageDuration), detail: "mediana \(duration(stats.medianDuration))", topic: ZEUVEHelpTopics.chatConversationDuration)
                    MetricCard(title: "Mensajes medios", value: String(format: "%.1f", stats.averageMessages), detail: "por conversación", topic: ZEUVEHelpTopics.chatConversationMessages)
                    MetricCard(title: "Sin respuesta", value: stats.unansweredCount.formatted(), detail: "un solo participante", topic: ZEUVEHelpTopics.chatUnansweredConversations)
                    MetricCard(title: "Inicio habitual", value: usualStartHour, detail: usualStartWeekday, topic: ZEUVEHelpTopics.chatUsualConversationStart)
                    MetricCard(title: "Más mensajes", value: stats.conversations.max(by: { $0.messages.count < $1.messages.count })?.messages.count.formatted() ?? "—", detail: "en una conversación", topic: ZEUVEHelpTopics.chatLargestConversation)
                    MetricCard(title: "Mayor duración", value: duration(stats.conversations.max(by: { $0.duration < $1.duration })?.duration), detail: "conversación más larga", topic: ZEUVEHelpTopics.chatLongestConversation)
                }
                HelpGroupBox("Por participante", topic: ZEUVEHelpTopics.chatConversationsOverview) {
                    Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 7) {
                        GridRow {
                            HelpTableHeader("Participante")
                            HelpTableHeader("Iniciadas", topic: ZEUVEHelpTopics.chatInitiatedConversations)
                            HelpTableHeader("Finalizadas", topic: ZEUVEHelpTopics.chatFinishedConversations)
                            HelpTableHeader("Sin respuesta", topic: ZEUVEHelpTopics.chatUnansweredConversations)
                            HelpTableHeader("Duración media", topic: ZEUVEHelpTopics.chatConversationParticipantDuration)
                            HelpTableHeader("Mensajes medios", topic: ZEUVEHelpTopics.chatConversationParticipantMessages)
                        }
                        Divider().gridCellColumns(6)
                        ForEach(model.participantNames, id: \.self) { participant in
                            let initiated = stats.conversations.filter { $0.initiator == participant }
                            let finished = stats.conversations.filter { $0.lastParticipant == participant }
                            let unanswered = initiated.filter { $0.participants.count <= 1 }
                            GridRow {
                                Text(participant)
                                Text(initiated.count.formatted())
                                Text(finished.count.formatted())
                                Text(unanswered.count.formatted())
                                Text(duration(initiated.isEmpty ? nil : initiated.map(\.duration).reduce(0, +) / Double(initiated.count)))
                                Text(initiated.isEmpty ? "—" : String(format: "%.1f", Double(initiated.reduce(0) { $0 + $1.messages.count }) / Double(initiated.count)))
                            }
                        }
                    }
                    .padding(4)
                }
                HelpGroupBox("Diez con más mensajes", topic: ZEUVEHelpTopics.chatTopConversationsByMessages) {
                    ForEach(model.conversationSnapshot.topConversationsByMessages) { conversation in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(conversation.start.formatted(date: .abbreviated, time: .shortened)).fontWeight(.medium)
                                Spacer()
                                Text("\(conversation.messages.count) mensajes")
                            }
                            Text("\(conversation.initiator) → \(conversation.lastParticipant) · \(duration(conversation.duration)) · \(conversation.participants.count) participantes")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 5)
                    }
                }
                HelpGroupBox("Diez de mayor duración", topic: ZEUVEHelpTopics.chatTopConversationsByDuration) {
                    ForEach(model.conversationSnapshot.topConversationsByDuration) { conversation in
                        LabeledContent(
                            conversation.start.formatted(date: .abbreviated, time: .shortened),
                            value: "\(duration(conversation.duration)) · \(conversation.messages.count) mensajes"
                        )
                    }
                }
            }
            .padding(26)
        }
    }
}

private struct ResponseBucket: Identifiable {
    let label: String
    let count: Int
    var id: String { label }
}

private struct ChatResponsesView: View {
    @ObservedObject var model: ChatAnalyzerViewModel
    @State private var hoveredBucket: Int?
    @State private var hoveredBucketLocation: CGPoint?
    @State private var buckets: [ResponseBucket] = []

    private var stats: ResponseStatistics { model.responseStatistics }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                SectionTitle(
                    "Tiempos de respuesta",
                    subtitle: "Estimación entre turnos consecutivos de personas diferentes",
                    topic: ZEUVEHelpTopics.chatResponsesOverview
                )
                HStack {
                    HelpLabel("Ventana máxima", topic: ZEUVEHelpTopics.chatResponseWindow)
                    Picker("", selection: $model.operationSettings.responseWindowMinutes) {
                        Text("1 hora").tag(60)
                        Text("6 horas").tag(360)
                        Text("12 horas").tag(720)
                        Text("24 horas").tag(1_440)
                        Text("Sin límite dentro de la conversación").tag(0)
                    }
                    .labelsHidden()
                    .frame(width: 260)
                }
                GroupBox {
                    Label("Estas cifras no demuestran una respuesta directa. En grupos deben interpretarse con especial precaución.", systemImage: "info.circle")
                        .foregroundStyle(.secondary)
                }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 12)], spacing: 12) {
                    MetricCard(title: "Respuestas", value: stats.samples.count.formatted(), detail: "cambios de turno", topic: ZEUVEHelpTopics.chatResponseCount)
                    MetricCard(title: "Media", value: duration(stats.average), detail: "tiempo estimado", topic: ZEUVEHelpTopics.chatResponseAverage)
                    MetricCard(title: "Mediana", value: duration(stats.median), detail: "percentil central", topic: ZEUVEHelpTopics.chatResponseMedian)
                    MetricCard(title: "Más rápida", value: duration(stats.fastest), detail: "más lenta \(duration(stats.slowest))", topic: ZEUVEHelpTopics.chatResponseExtremes)
                    MetricCard(title: "Percentil 25", value: duration(stats.percentile25), detail: "percentil 75 \(duration(stats.percentile75))", topic: ZEUVEHelpTopics.chatResponsePercentiles)
                }
                let grouped = Dictionary(grouping: stats.samples, by: \.participant)
                HelpGroupBox("Por participante", topic: ZEUVEHelpTopics.chatResponsesOverview) {
                    Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 7) {
                        GridRow {
                            HelpTableHeader("Participante")
                            HelpTableHeader("Respuestas", topic: ZEUVEHelpTopics.chatResponseCount)
                            HelpTableHeader("Media", topic: ZEUVEHelpTopics.chatResponseAverage)
                            HelpTableHeader("Mediana", topic: ZEUVEHelpTopics.chatResponseMedian)
                            HelpTableHeader("Rápida", topic: ZEUVEHelpTopics.chatResponseExtremes)
                            HelpTableHeader("Lenta", topic: ZEUVEHelpTopics.chatResponseExtremes)
                            HelpTableHeader("<5 min", topic: ZEUVEHelpTopics.chatResponseThresholdCounts)
                            HelpTableHeader("<1 h", topic: ZEUVEHelpTopics.chatResponseThresholdCounts)
                            HelpTableHeader("<24 h", topic: ZEUVEHelpTopics.chatResponseThresholdCounts)
                        }
                        Divider().gridCellColumns(9)
                        ForEach(grouped.keys.sorted(), id: \.self) { participant in
                            let values = grouped[participant]?.map(\.delay).sorted() ?? []
                            GridRow {
                                Text(participant)
                                Text(values.count.formatted())
                                Text(duration(values.isEmpty ? nil : values.reduce(0, +) / Double(values.count)))
                                Text(duration(median(values)))
                                Text(duration(values.first))
                                Text(duration(values.last))
                                Text(values.filter { $0 < 300 }.count.formatted())
                                Text(values.filter { $0 < 3_600 }.count.formatted())
                                Text(values.filter { $0 < 86_400 }.count.formatted())
                            }
                        }
                    }
                    .padding(4)
                }
                ChartCard(title: "Distribución", topic: ZEUVEHelpTopics.chatResponseDistribution, empty: stats.samples.isEmpty) {
                    Chart {
                        ForEach(Array(buckets.enumerated()), id: \.element.id) { index, item in
                            BarMark(x: .value("Intervalo", item.label), y: .value("Respuestas", item.count))
                                .opacity(hoveredBucket == nil || hoveredBucket == index ? 1 : 0.4)
                        }
                        if let hoveredBucket, buckets.indices.contains(hoveredBucket) {
                            let item = buckets[hoveredBucket]
                            RuleMark(x: .value("Intervalo seleccionado", item.label))
                                .foregroundStyle(.secondary)
                                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        }
                    }
                    .trackChartCategoryHover(
                        selection: $hoveredBucket,
                        cursorLocation: $hoveredBucketLocation,
                        categoryCount: buckets.count
                    )
                    .chartCursorTooltip(at: hoveredBucketLocation) {
                        if let hoveredBucket, buckets.indices.contains(hoveredBucket) {
                            let item = buckets[hoveredBucket]
                            ChartTooltipCard(
                                title: item.label,
                                rows: [ChartTooltipRow("Respuestas", value: item.count.formatted(), emphasized: true)]
                            )
                        }
                    }
                } alternative: {
                    Text(buckets.map { "\($0.label): \($0.count)" }.joined(separator: ", "))
                }
            }
            .padding(26)
        }
        .onReceive(model.$conversationSnapshot) { snapshot in
            buckets = responseBuckets(snapshot.responses.samples)
            hoveredBucket = nil
            hoveredBucketLocation = nil
        }
        .onDisappear {
            hoveredBucket = nil
            hoveredBucketLocation = nil
        }
    }

    private func responseBuckets(_ samples: [ResponseSample]) -> [ResponseBucket] {
        let limits: [(String, TimeInterval)] = [
            ("<1 min", 60),
            ("<5 min", 300),
            ("<15 min", 900),
            ("<1 h", 3_600),
            ("<6 h", 21_600),
            ("<24 h", 86_400),
            ("≥24 h", .infinity),
        ]
        var counts = Array(repeating: 0, count: limits.count)
        for sample in samples {
            if let index = limits.firstIndex(where: { sample.delay < $0.1 }) {
                counts[index] += 1
            }
        }
        return limits.enumerated().map { index, item in
            ResponseBucket(label: item.0, count: counts[index])
        }
    }
}

private struct ChatComparisonView: View {
    @ObservedObject var model: ChatAnalyzerViewModel
    @State private var hoveredComparisonDate: Date?
    @State private var hoveredComparisonDateLocation: CGPoint?
    @State private var hoveredComparisonHour: Int?
    @State private var hoveredComparisonHourLocation: CGPoint?
    @State private var hoveredComparisonWeekday: Int?
    @State private var hoveredComparisonWeekdayLocation: CGPoint?
    private var first: ParticipantStatistics? {
        model.comparisonA.flatMap { model.comparisonSnapshot.participants[$0]?.statistics }
    }
    private var second: ParticipantStatistics? {
        model.comparisonB.flatMap { model.comparisonSnapshot.participants[$0]?.statistics }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                SectionTitle(
                    "Comparación",
                    subtitle: "Compara dos participantes dentro de los filtros activos",
                    topic: ZEUVEHelpTopics.chatComparisonOverview
                )
                HStack {
                    Picker("Primera persona", selection: $model.comparisonA) {
                        Text("Seleccionar").tag(String?.none)
                        ForEach(model.participantNames, id: \.self) { Text($0).tag(Optional($0)) }
                    }
                    Picker("Segunda persona", selection: $model.comparisonB) {
                        Text("Seleccionar").tag(String?.none)
                        ForEach(model.participantNames, id: \.self) { Text($0).tag(Optional($0)) }
                    }
                }
                if let first, let second, first.name != second.name {
                    if first.messages == 0 || second.messages == 0 {
                        Label("Uno de los participantes no tiene mensajes con los filtros actuales.", systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                    }
                    comparisonTable(first, second)
                    comparisonCharts(first.name, second.name)
                } else {
                    EmptyState(icon: "arrow.left.arrow.right", title: "Selecciona dos personas diferentes", message: "La selección se actualizará si cambian los filtros o las fusiones.")
                }
            }
            .padding(26)
        }
        .onAppear {
            if model.comparisonA == nil { model.comparisonA = model.participantNames.first }
            if model.comparisonB == nil { model.comparisonB = model.participantNames.dropFirst().first }
        }
        .onChange(of: model.comparisonA) { _, _ in resetHover() }
        .onChange(of: model.comparisonB) { _, _ in resetHover() }
        .onChange(of: model.granularity) { _, _ in
            hoveredComparisonDate = nil
            hoveredComparisonDateLocation = nil
        }
        .onDisappear { resetHover() }
    }

    private func comparisonTable(_ a: ParticipantStatistics, _ b: ParticipantStatistics) -> some View {
        HelpGroupBox("Indicadores", topic: ZEUVEHelpTopics.chatComparisonOverview) {
            Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 9) {
                GridRow {
                    HelpTableHeader("Indicador", topic: ZEUVEHelpTopics.chatComparisonOverview)
                    Text(a.name).bold()
                    Text(b.name).bold()
                }
                Divider().gridCellColumns(3)
                row("Mensajes", topic: ZEUVEHelpTopics.chatParticipantMessages, a.messages.formatted(), b.messages.formatted())
                row("Porcentaje", topic: ZEUVEHelpTopics.chatParticipantMessages, String(format: "%.1f %%", a.percentage), String(format: "%.1f %%", b.percentage))
                row("Palabras", topic: ZEUVEHelpTopics.chatWordCount, a.words.formatted(), b.words.formatted())
                row("Media de palabras", topic: ZEUVEHelpTopics.chatWordCount, String(format: "%.1f", a.averageWords), String(format: "%.1f", b.averageWords))
                row("Mediana", topic: ZEUVEHelpTopics.chatMedianWords, String(format: "%.1f", a.medianWords), String(format: "%.1f", b.medianWords))
                row("Longitud media", topic: ZEUVEHelpTopics.chatAverageLength, String(format: "%.1f", a.averageLength), String(format: "%.1f", b.averageLength))
                row("Días activos", topic: ZEUVEHelpTopics.chatActiveDays, a.activeDays.formatted(), b.activeDays.formatted())
                row("Mensajes por día", topic: ZEUVEHelpTopics.chatMessagesPerActiveDay, String(format: "%.1f", a.messagesPerActiveDay), String(format: "%.1f", b.messagesPerActiveDay))
                row("Preguntas", topic: ZEUVEHelpTopics.chatQuestionCount, countAndPercent(a.questions, a.messages), countAndPercent(b.questions, b.messages))
                row("Enlaces", topic: ZEUVEHelpTopics.chatLinks, countAndPercent(a.links, a.messages), countAndPercent(b.links, b.messages))
                row("Multimedia", topic: ZEUVEHelpTopics.chatMultimedia, countAndPercent(a.multimedia, a.messages), countAndPercent(b.multimedia, b.messages))
                row("Mayúsculas", topic: ZEUVEHelpTopics.chatUppercase, countAndPercent(a.uppercaseMessages, a.messages), countAndPercent(b.uppercaseMessages, b.messages))
                row("Emojis", topic: ZEUVEHelpTopics.chatEmojiCount, a.emojis.formatted(), b.emojis.formatted())
                row("Conversaciones iniciadas", topic: ZEUVEHelpTopics.chatInitiatedConversations, initiated(a.name).formatted(), initiated(b.name).formatted())
                row("Conversaciones sin respuesta", topic: ZEUVEHelpTopics.chatUnansweredConversations, unanswered(a.name).formatted(), unanswered(b.name).formatted())
                row("Conversaciones finalizadas", topic: ZEUVEHelpTopics.chatFinishedConversations, finished(a.name).formatted(), finished(b.name).formatted())
                row("Respuesta media", topic: ZEUVEHelpTopics.chatResponseAverage, duration(responseValues(a.name).average), duration(responseValues(b.name).average))
                row("Respuesta mediana", topic: ZEUVEHelpTopics.chatResponseMedian, duration(responseValues(a.name).median), duration(responseValues(b.name).median))
                row("WhatsApp", topic: ZEUVEHelpTopics.chatPlatformMessages, platformCount(a.name, .whatsapp).formatted(), platformCount(b.name, .whatsapp).formatted())
                row("Instagram", topic: ZEUVEHelpTopics.chatPlatformMessages, platformCount(a.name, .instagram).formatted(), platformCount(b.name, .instagram).formatted())
                row("Primero", topic: ZEUVEHelpTopics.chatParticipantPeriod, a.firstMessage?.formatted(date: .abbreviated, time: .shortened) ?? "—", b.firstMessage?.formatted(date: .abbreviated, time: .shortened) ?? "—")
                row("Último", topic: ZEUVEHelpTopics.chatParticipantPeriod, a.lastMessage?.formatted(date: .abbreviated, time: .shortened) ?? "—", b.lastMessage?.formatted(date: .abbreviated, time: .shortened) ?? "—")
            }
            .padding(6)
        }
    }

    @ViewBuilder private func comparisonCharts(_ a: String, _ b: String) -> some View {
        let names = [a, b]
        let first = model.comparisonSnapshot.participants[a]
        let second = model.comparisonSnapshot.participants[b]
        let hasMessages = (first?.statistics.messages ?? 0) + (second?.statistics.messages ?? 0) > 0
        let dates = comparisonDates(names)

        ChartCard(title: "Evolución temporal", topic: ZEUVEHelpTopics.chatTemporalEvolution, empty: !hasMessages) {
            Chart {
                ForEach(names, id: \.self) { name in
                    ForEach(model.comparisonSnapshot.participants[name]?.series ?? []) { point in
                        LineMark(x: .value("Fecha", point.date), y: .value("Mensajes", point.count))
                            .foregroundStyle(by: .value("Participante", name))
                            .interpolationMethod(.monotone)
                    }
                }
                if let hoveredComparisonDate {
                    RuleMark(x: .value("Fecha seleccionada", hoveredComparisonDate))
                        .foregroundStyle(.secondary)
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    ForEach(names, id: \.self) { name in
                        if let point = model.comparisonSnapshot.participants[name]?.series.first(where: { $0.date == hoveredComparisonDate }) {
                            PointMark(x: .value("Fecha", point.date), y: .value("Mensajes", point.count))
                                .foregroundStyle(by: .value("Participante", name))
                                .symbolSize(55)
                        }
                    }
                }
            }
            .trackChartDateHover(
                selection: $hoveredComparisonDate,
                cursorLocation: $hoveredComparisonDateLocation,
                dates: dates
            )
            .chartCursorTooltip(at: hoveredComparisonDateLocation) {
                if let hoveredComparisonDate {
                    ChartTooltipCard(
                        title: chartPeriodTitle(hoveredComparisonDate, granularity: model.granularity),
                        rows: comparisonTemporalRows(names, at: hoveredComparisonDate)
                    )
                }
            }
        } alternative: {
            Text("Comparación temporal de \(a) y \(b)")
        }
        ChartCard(title: "Actividad por hora", topic: ZEUVEHelpTopics.chatHourlyActivity, empty: !hasMessages) {
            Chart {
                ForEach(names, id: \.self) { name in
                    let values = model.comparisonSnapshot.participants[name]?.hourly ?? Array(repeating: 0, count: 24)
                    ForEach(0..<24, id: \.self) { hour in
                        BarMark(x: .value("Hora", hour), y: .value("Mensajes", values[hour]))
                            .foregroundStyle(by: .value("Participante", name))
                            .position(by: .value("Participante", name))
                            .opacity(hoveredComparisonHour == nil || hoveredComparisonHour == hour ? 1 : 0.4)
                    }
                }
                if let hoveredComparisonHour {
                    RuleMark(x: .value("Hora seleccionada", hoveredComparisonHour))
                        .foregroundStyle(.secondary)
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                }
            }
            .trackChartCategoryHover(
                selection: $hoveredComparisonHour,
                cursorLocation: $hoveredComparisonHourLocation,
                categoryCount: 24
            )
            .chartCursorTooltip(at: hoveredComparisonHourLocation) {
                if let hoveredComparisonHour {
                    ChartTooltipCard(
                        title: chartHourTitle(hoveredComparisonHour),
                        rows: comparisonCategoryRows(names) { name in
                            let values = model.comparisonSnapshot.participants[name]?.hourly ?? []
                            return values.indices.contains(hoveredComparisonHour) ? values[hoveredComparisonHour] : 0
                        }
                    )
                }
            }
        } alternative: {
            Text("Distribución horaria de \(a) y \(b)")
        }
        ChartCard(title: "Actividad por día", topic: ZEUVEHelpTopics.chatWeekdayActivity, empty: !hasMessages) {
            Chart {
                ForEach(names, id: \.self) { name in
                    let values = model.comparisonSnapshot.participants[name]?.weekdays ?? Array(repeating: 0, count: 7)
                    ForEach(0..<7, id: \.self) { index in
                        BarMark(x: .value("Día", weekdayName(index + 1)), y: .value("Mensajes", values[index]))
                            .foregroundStyle(by: .value("Participante", name))
                            .position(by: .value("Participante", name))
                            .opacity(hoveredComparisonWeekday == nil || hoveredComparisonWeekday == index ? 1 : 0.4)
                    }
                }
                if let hoveredComparisonWeekday {
                    RuleMark(x: .value("Día seleccionado", weekdayName(hoveredComparisonWeekday + 1)))
                        .foregroundStyle(.secondary)
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                }
            }
            .trackChartCategoryHover(
                selection: $hoveredComparisonWeekday,
                cursorLocation: $hoveredComparisonWeekdayLocation,
                categoryCount: 7
            )
            .chartCursorTooltip(at: hoveredComparisonWeekdayLocation) {
                if let hoveredComparisonWeekday {
                    ChartTooltipCard(
                        title: weekdayName(hoveredComparisonWeekday + 1),
                        rows: comparisonCategoryRows(names) { name in
                            let values = model.comparisonSnapshot.participants[name]?.weekdays ?? []
                            return values.indices.contains(hoveredComparisonWeekday) ? values[hoveredComparisonWeekday] : 0
                        }
                    )
                }
            }
        } alternative: {
            Text("Distribución semanal de \(a) y \(b)")
        }
    }

    private func comparisonDates(_ names: [String]) -> [Date] {
        Array(Set(names.flatMap { model.comparisonSnapshot.participants[$0]?.series.map(\.date) ?? [] })).sorted()
    }

    private func comparisonTemporalRows(_ names: [String], at date: Date) -> [ChartTooltipRow] {
        comparisonCategoryRows(names) { name in
            model.comparisonSnapshot.participants[name]?.series.first(where: { $0.date == date })?.count ?? 0
        }
    }

    private func comparisonCategoryRows(_ names: [String], value: (String) -> Int) -> [ChartTooltipRow] {
        let values = names.map { ($0, value($0)) }
        let total = values.reduce(0) { $0 + $1.1 }
        return [ChartTooltipRow("Total", value: total.formatted(), emphasized: true)]
            + values.map { ChartTooltipRow($0.0, value: $0.1.formatted()) }
    }

    private func resetHover() {
        hoveredComparisonDate = nil
        hoveredComparisonDateLocation = nil
        hoveredComparisonHour = nil
        hoveredComparisonHourLocation = nil
        hoveredComparisonWeekday = nil
        hoveredComparisonWeekdayLocation = nil
    }

    private func initiated(_ name: String) -> Int {
        model.comparisonSnapshot.participants[name]?.initiatedConversations ?? 0
    }

    private func unanswered(_ name: String) -> Int {
        model.comparisonSnapshot.participants[name]?.unansweredConversations ?? 0
    }

    private func finished(_ name: String) -> Int {
        model.comparisonSnapshot.participants[name]?.finishedConversations ?? 0
    }

    private func platformCount(_ name: String, _ platform: ChatPlatform) -> Int {
        model.comparisonSnapshot.participants[name]?.platformCounts[platform, default: 0] ?? 0
    }

    private func responseValues(_ name: String) -> (average: TimeInterval?, median: TimeInterval?) {
        let value = model.comparisonSnapshot.participants[name]
        return (value?.responseAverage, value?.responseMedian)
    }

    private func countAndPercent(_ value: Int, _ total: Int) -> String {
        total == 0 ? "0 · 0 %" : "\(value) · \(String(format: "%.1f %%", Double(value) / Double(total) * 100))"
    }

    private func row(_ label: String, topic: ContextualHelpTopic, _ a: String, _ b: String) -> some View {
        GridRow {
            HelpTableHeader(label, topic: topic)
            Text(a)
            Text(b)
        }
    }
}

private struct ChatFusionsView: View {
    @ObservedObject var model: ChatAnalyzerViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                SectionTitle(
                    "Fusión de identidades",
                    subtitle: "Une nombres que pertenecen a la misma persona solo durante este análisis",
                    topic: ZEUVEHelpTopics.chatFusionsOverview
                )
                GroupBox {
                    Label("La fusión no modifica los archivos ni elimina el autor original. Recalcula estadísticas, conversaciones, respuestas y búsquedas.", systemImage: "lock.shield")
                }
                HelpGroupBox("Participantes", topic: ZEUVEHelpTopics.chatFusionParticipants) {
                    ForEach(model.participantNames, id: \.self) { name in
                        Toggle(name, isOn: Binding(
                            get: { model.fusionSelection.contains(name) },
                            set: { enabled in
                                if enabled { model.fusionSelection.insert(name) }
                                else { model.fusionSelection.remove(name) }
                            }
                        ))
                    }
                }
                HStack {
                    HelpLabel("Nombre común", topic: ZEUVEHelpTopics.chatFusionName)
                    TextField("Nombre común", text: $model.fusionName).textFieldStyle(.roundedBorder)
                    Button("Fusionar seleccionados") { model.mergeSelectedIdentities() }
                        .buttonStyle(.borderedProminent)
                        .disabled(model.fusionSelection.count < 2 || model.fusionName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                HelpGroupBox("Fusiones activas", topic: ZEUVEHelpTopics.chatActiveFusions) {
                    if model.identityMap.isEmpty {
                        Text("No hay fusiones activas.").foregroundStyle(.secondary)
                    } else {
                        ForEach(Dictionary(grouping: model.identityMap.keys, by: { model.identityMap[$0] ?? $0 }).keys.sorted(), id: \.self) { merged in
                            LabeledContent(
                                merged,
                                value: Dictionary(grouping: model.identityMap.keys, by: { model.identityMap[$0] ?? $0 })[merged, default: []].sorted().joined(separator: ", ")
                            )
                        }
                    }
                }
                HStack {
                    HelpLabel("Deshacer", topic: ZEUVEHelpTopics.chatUndoFusions)
                    Button("Deshacer última fusión") { model.undoFusion() }
                        .disabled(model.fusionHistory.isEmpty)
                    Button("Restablecer todas", role: .destructive) { model.resetFusions() }
                        .disabled(model.identityMap.isEmpty)
                }
            }
            .padding(26)
            .frame(maxWidth: 900, alignment: .leading)
        }
    }
}

private struct SectionTitle: View {
    let title: String
    let subtitle: String
    let topic: ContextualHelpTopic?

    init(_ title: String, subtitle: String, topic: ContextualHelpTopic? = nil) {
        self.title = title
        self.subtitle = subtitle
        self.topic = topic
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text(title).font(.largeTitle.bold())
                if let topic { ContextualHelpButton(topic: topic) }
            }
            Text(subtitle).foregroundStyle(.secondary)
        }
    }
}

private struct MetricCard: View {
    let title: String
    let value: String
    let detail: String
    let topic: ContextualHelpTopic?

    init(title: String, value: String, detail: String, topic: ContextualHelpTopic? = nil) {
        self.title = title
        self.value = value
        self.detail = detail
        self.topic = topic
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Text(title).font(.caption).foregroundStyle(.secondary)
                if let topic { ContextualHelpButton(topic: topic).controlSize(.small) }
            }
            Text(value).font(.title2.bold()).minimumScaleFactor(0.75)
            Text(detail).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 86, alignment: .leading)
        .padding(14)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(.quaternary))
    }
}

private struct ChartCard<Content: View, Alternative: View>: View {
    let title: String
    let topic: ContextualHelpTopic?
    let empty: Bool
    @ViewBuilder let content: () -> Content
    @ViewBuilder let alternative: () -> Alternative

    init(
        title: String,
        topic: ContextualHelpTopic? = nil,
        empty: Bool,
        @ViewBuilder content: @escaping () -> Content,
        @ViewBuilder alternative: @escaping () -> Alternative
    ) {
        self.title = title
        self.topic = topic
        self.empty = empty
        self.content = content
        self.alternative = alternative
    }

    var body: some View {
        GroupBox {
            if empty {
                EmptyState(icon: "chart.bar", title: "Sin datos", message: "No hay mensajes para representar con los filtros actuales.").frame(height: 230)
            } else {
                content().frame(height: 260).accessibilityRepresentation { ScrollView { alternative().font(.caption) } }
            }
        } label: {
            HStack(spacing: 6) {
                Text(title)
                if let topic { ContextualHelpButton(topic: topic) }
            }
        }
    }
}

private struct HelpGroupBox<Content: View>: View {
    let title: String
    let topic: ContextualHelpTopic
    @ViewBuilder let content: () -> Content

    init(_ title: String, topic: ContextualHelpTopic, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.topic = topic
        self.content = content
    }

    var body: some View {
        GroupBox {
            content()
        } label: {
            HelpLabel(title, topic: topic)
        }
    }
}

private struct HelpValueRow: View {
    let title: String
    let value: String
    let topic: ContextualHelpTopic

    var body: some View {
        LabeledContent {
            Text(value)
        } label: {
            HelpLabel(title, topic: topic)
        }
    }
}

private struct HelpTableHeader: View {
    let title: String
    let topic: ContextualHelpTopic?

    init(_ title: String, topic: ContextualHelpTopic? = nil) {
        self.title = title
        self.topic = topic
    }

    var body: some View {
        HStack(spacing: 5) {
            Text(title).bold()
            if let topic { ContextualHelpButton(topic: topic).controlSize(.small) }
        }
    }
}

private struct FrequencyRows: View {
    let title: String?; let items: [FrequencyItem]
    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            if let title { Text(title).font(.headline) }
            if items.isEmpty { Text("Sin datos suficientes.").foregroundStyle(.secondary) }
            else { ForEach(items) { item in HStack { Text(item.value).lineLimit(1); Spacer(); Text(item.count.formatted()).monospacedDigit().foregroundStyle(.secondary) } } }
        }.padding(4)
    }
}

private struct EmptyState: View {
    let icon: String; let title: String; let message: String
    var body: some View { VStack(spacing: 10) { Image(systemName: icon).font(.system(size: 36)).foregroundStyle(.secondary); Text(title).font(.headline); Text(message).foregroundStyle(.secondary).multilineTextAlignment(.center).frame(maxWidth: 420) }.frame(maxWidth: .infinity, maxHeight: .infinity).padding(30) }
}

private func weekdayName(_ weekday: Int?) -> String {
    guard let weekday, (1...7).contains(weekday) else { return "—" }
    return Calendar.current.weekdaySymbols[weekday - 1].capitalized
}
private func shortWeekday(_ weekday: Int) -> String { Calendar.current.veryShortWeekdaySymbols[weekday - 1].capitalized }
private func duration(_ value: TimeInterval?) -> String {
    guard let value, value.isFinite else { return "—" }
    let seconds = Int(max(value, 0)); let days = seconds / 86_400; let hours = (seconds % 86_400) / 3_600; let minutes = (seconds % 3_600) / 60; let remaining = seconds % 60
    if days > 0 { return "\(days) d \(hours) h" }
    if hours > 0 { return "\(hours) h \(minutes) min" }
    if minutes > 0 { return "\(minutes) min \(remaining) s" }
    return "\(remaining) s"
}
private func median(_ values: [TimeInterval]) -> TimeInterval? {
    guard !values.isEmpty else { return nil }; let sorted = values.sorted(); let middle = sorted.count / 2
    return sorted.count.isMultiple(of: 2) ? (sorted[middle - 1] + sorted[middle]) / 2 : sorted[middle]
}
