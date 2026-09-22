import SwiftUI
import Charts
import ChatAnalyzerModule

struct ChatComparisonView: View {
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

