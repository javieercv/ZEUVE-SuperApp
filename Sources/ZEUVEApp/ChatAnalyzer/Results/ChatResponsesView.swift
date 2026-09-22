import SwiftUI
import Charts
import ChatAnalyzerModule

struct ResponseBucket: Identifiable {
    let label: String
    let count: Int
    var id: String { label }
}

struct ChatResponsesView: View {
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
                    MetricCard(title: "Respuestas", value: stats.sampleCount.formatted(), detail: "cambios de turno", topic: ZEUVEHelpTopics.chatResponseCount)
                    MetricCard(title: "Media", value: duration(stats.average), detail: "tiempo estimado", topic: ZEUVEHelpTopics.chatResponseAverage)
                    MetricCard(title: "Mediana", value: duration(stats.median), detail: "percentil central", topic: ZEUVEHelpTopics.chatResponseMedian)
                    MetricCard(title: "Más rápida", value: duration(stats.fastest), detail: "más lenta \(duration(stats.slowest))", topic: ZEUVEHelpTopics.chatResponseExtremes)
                    MetricCard(title: "Percentil 25", value: duration(stats.percentile25), detail: "percentil 75 \(duration(stats.percentile75))", topic: ZEUVEHelpTopics.chatResponsePercentiles)
                }
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
                        ForEach(stats.participants.keys.sorted(), id: \.self) { participant in
                            let values = stats.participants[participant]
                            GridRow {
                                Text(participant)
                                Text((values?.count ?? 0).formatted())
                                Text(duration(values?.average))
                                Text(duration(values?.median))
                                Text(duration(values?.fastest))
                                Text(duration(values?.slowest))
                                Text((values?.underFiveMinutes ?? 0).formatted())
                                Text((values?.underOneHour ?? 0).formatted())
                                Text((values?.underTwentyFourHours ?? 0).formatted())
                            }
                        }
                    }
                    .padding(4)
                }
                ChartCard(title: "Distribución", topic: ZEUVEHelpTopics.chatResponseDistribution, empty: stats.sampleCount == 0) {
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
            buckets = snapshot.responses.distribution.map { ResponseBucket(label: $0.label, count: $0.count) }
            hoveredBucket = nil
            hoveredBucketLocation = nil
        }
        .onDisappear {
            hoveredBucket = nil
            hoveredBucketLocation = nil
        }
    }

}

