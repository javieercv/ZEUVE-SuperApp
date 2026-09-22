import SwiftUI
import Charts
import ChatAnalyzerModule

struct ChatParticipantsView: View {
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

struct ParticipantProfile: View {
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

