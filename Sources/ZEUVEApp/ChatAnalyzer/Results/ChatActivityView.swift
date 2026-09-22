import SwiftUI
import Charts
import ChatAnalyzerModule

struct ChatActivityView: View {
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
                ChartCard(title: "Actividad por hora", topic: ZEUVEHelpTopics.chatHourlyActivity, empty: !model.hasFilteredMessages) {
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
                ChartCard(title: "Actividad por día de la semana", topic: ZEUVEHelpTopics.chatWeekdayActivity, empty: !model.hasFilteredMessages) {
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

struct HeatmapHoverValue: Equatable {
    let weekday: Int
    let hour: Int
    let count: Int
    var id: String { "\(weekday)-\(hour)" }
}

struct HeatmapView: View {
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

