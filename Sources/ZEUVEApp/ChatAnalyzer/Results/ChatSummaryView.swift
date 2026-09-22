import SwiftUI
import Charts
import ChatAnalyzerModule

struct ChatSummaryView: View {
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

