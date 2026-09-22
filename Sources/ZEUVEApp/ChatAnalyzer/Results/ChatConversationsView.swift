import SwiftUI
import Charts
import ChatAnalyzerModule

struct ChatConversationsView: View {
    @ObservedObject var model: ChatAnalyzerViewModel
    private var stats: ConversationStatistics { model.conversations }

    private var usualStartHour: String {
        guard let hour = stats.startHourCounts.indices.max(by: { stats.startHourCounts[$0] < stats.startHourCounts[$1] }),
              stats.startHourCounts[hour] > 0 else { return "—" }
        return String(format: "%02d:00", hour)
    }

    private var usualStartWeekday: String {
        guard let index = stats.startWeekdayCounts.indices.max(by: { stats.startWeekdayCounts[$0] < stats.startWeekdayCounts[$1] }),
              stats.startWeekdayCounts[index] > 0 else { return "—" }
        return weekdayName(index + 1)
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
                    MetricCard(title: "Conversaciones", value: stats.totalCount.formatted(), detail: "grupos temporales", topic: ZEUVEHelpTopics.chatConversationCount)
                    MetricCard(title: "Duración media", value: duration(stats.averageDuration), detail: "mediana \(duration(stats.medianDuration))", topic: ZEUVEHelpTopics.chatConversationDuration)
                    MetricCard(title: "Mensajes medios", value: String(format: "%.1f", stats.averageMessages), detail: "por conversación", topic: ZEUVEHelpTopics.chatConversationMessages)
                    MetricCard(title: "Sin respuesta", value: stats.unansweredCount.formatted(), detail: "un solo participante", topic: ZEUVEHelpTopics.chatUnansweredConversations)
                    MetricCard(title: "Inicio habitual", value: usualStartHour, detail: usualStartWeekday, topic: ZEUVEHelpTopics.chatUsualConversationStart)
                    MetricCard(title: "Más mensajes", value: stats.maximumMessageCount > 0 ? stats.maximumMessageCount.formatted() : "—", detail: "en una conversación", topic: ZEUVEHelpTopics.chatLargestConversation)
                    MetricCard(title: "Mayor duración", value: duration(stats.maximumDuration), detail: "conversación más larga", topic: ZEUVEHelpTopics.chatLongestConversation)
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
                            let value = stats.participantStatistics[participant]
                            GridRow {
                                Text(participant)
                                Text((value?.initiated ?? 0).formatted())
                                Text((value?.finished ?? 0).formatted())
                                Text((value?.unanswered ?? 0).formatted())
                                Text(duration(value?.initiatedAverageDuration))
                                Text(value?.initiatedAverageMessages.map { String(format: "%.1f", $0) } ?? "—")
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
                                Text("\(conversation.messageCount) mensajes")
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
                            value: "\(duration(conversation.duration)) · \(conversation.messageCount) mensajes"
                        )
                    }
                }
            }
            .padding(26)
        }
    }
}

