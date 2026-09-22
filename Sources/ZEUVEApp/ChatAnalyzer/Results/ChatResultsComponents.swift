import SwiftUI
import Charts
import ChatAnalyzerModule

struct SectionTitle: View {
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

struct MetricCard: View {
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

struct ChartCard<Content: View, Alternative: View>: View {
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

struct HelpGroupBox<Content: View>: View {
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

struct HelpValueRow: View {
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

struct HelpTableHeader: View {
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

struct FrequencyRows: View {
    let title: String?; let items: [FrequencyItem]
    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            if let title { Text(title).font(.headline) }
            if items.isEmpty { Text("Sin datos suficientes.").foregroundStyle(.secondary) }
            else { ForEach(items) { item in HStack { Text(item.value).lineLimit(1); Spacer(); Text(item.count.formatted()).monospacedDigit().foregroundStyle(.secondary) } } }
        }.padding(4)
    }
}

struct EmptyState: View {
    let icon: String; let title: String; let message: String
    var body: some View { VStack(spacing: 10) { Image(systemName: icon).font(.system(size: 36)).foregroundStyle(.secondary); Text(title).font(.headline); Text(message).foregroundStyle(.secondary).multilineTextAlignment(.center).frame(maxWidth: 420) }.frame(maxWidth: .infinity, maxHeight: .infinity).padding(30) }
}

func weekdayName(_ weekday: Int?) -> String {
    guard let weekday, (1...7).contains(weekday) else { return "—" }
    return Calendar.current.weekdaySymbols[weekday - 1].capitalized
}
func shortWeekday(_ weekday: Int) -> String { Calendar.current.veryShortWeekdaySymbols[weekday - 1].capitalized }
func duration(_ value: TimeInterval?) -> String {
    guard let value, value.isFinite else { return "—" }
    let seconds = Int(max(value, 0)); let days = seconds / 86_400; let hours = (seconds % 86_400) / 3_600; let minutes = (seconds % 3_600) / 60; let remaining = seconds % 60
    if days > 0 { return "\(days) d \(hours) h" }
    if hours > 0 { return "\(hours) h \(minutes) min" }
    if minutes > 0 { return "\(minutes) min \(remaining) s" }
    return "\(remaining) s"
}
func median(_ values: [TimeInterval]) -> TimeInterval? {
    guard !values.isEmpty else { return nil }; let sorted = values.sorted(); let middle = sorted.count / 2
    return sorted.count.isMultiple(of: 2) ? (sorted[middle - 1] + sorted[middle]) / 2 : sorted[middle]
}
