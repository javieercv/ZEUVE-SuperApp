import SwiftUI
import Charts
import ChatAnalyzerModule

struct ChartTooltipRow {
    let label: String
    let value: String
    let emphasized: Bool

    init(_ label: String, value: String, emphasized: Bool = false) {
        self.label = label
        self.value = value
        self.emphasized = emphasized
    }
}

struct ChartTooltipCard: View {
    let title: String
    let rows: [ChartTooltipRow]

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(2)
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: 14) {
                    Text(row.label)
                        .fontWeight(row.emphasized ? .semibold : .regular)
                    Spacer(minLength: 12)
                    Text(row.value)
                        .fontWeight(row.emphasized ? .bold : .semibold)
                        .monospacedDigit()
                }
                .font(.callout)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(minWidth: 170, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(.quaternary)
        }
        .shadow(radius: 8, y: 3)
        .fixedSize(horizontal: true, vertical: true)
        .allowsHitTesting(false)
        .accessibilityElement(children: .combine)
    }
}

private struct ChartTooltipSizePreferenceKey: PreferenceKey {
    static let defaultValue: CGSize = .zero

    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        let candidate = nextValue()
        if candidate != .zero { value = candidate }
    }
}

private struct CursorFollowingTooltip<Content: View>: View {
    let location: CGPoint
    let content: Content

    @State private var tooltipSize: CGSize = .zero

    var body: some View {
        GeometryReader { geometry in
            content
                .background {
                    GeometryReader { tooltipGeometry in
                        Color.clear.preference(
                            key: ChartTooltipSizePreferenceKey.self,
                            value: tooltipGeometry.size
                        )
                    }
                }
                .onPreferenceChange(ChartTooltipSizePreferenceKey.self) { tooltipSize = $0 }
                .position(tooltipCenter(in: geometry.size))
                .transaction { transaction in
                    transaction.animation = nil
                }
        }
        .allowsHitTesting(false)
        .zIndex(100)
    }

    private func tooltipCenter(in containerSize: CGSize) -> CGPoint {
        let horizontalGap: CGFloat = 14
        let verticalGap: CGFloat = 12
        let margin: CGFloat = 8
        let halfWidth = tooltipSize.width / 2
        let halfHeight = tooltipSize.height / 2

        var x = location.x + horizontalGap + halfWidth
        if x + halfWidth > containerSize.width - margin {
            x = location.x - horizontalGap - halfWidth
        }

        var y = location.y - verticalGap - halfHeight
        if y - halfHeight < margin {
            y = location.y + verticalGap + halfHeight
        }

        let minimumX = margin + halfWidth
        let maximumX = max(minimumX, containerSize.width - margin - halfWidth)
        let minimumY = margin + halfHeight
        let maximumY = max(minimumY, containerSize.height - margin - halfHeight)

        return CGPoint(
            x: min(max(x, minimumX), maximumX),
            y: min(max(y, minimumY), maximumY)
        )
    }
}

private struct ChartDateHoverModifier: ViewModifier {
    @Binding var selection: Date?
    @Binding var cursorLocation: CGPoint?
    let dates: [Date]

    func body(content: Content) -> some View {
        content.chartOverlay { proxy in
            GeometryReader { geometry in
                Rectangle()
                    .fill(.clear)
                    .contentShape(Rectangle())
                    .onContinuousHover { phase in
                        switch phase {
                        case .active(let location):
                            guard let plotFrame = proxy.plotFrame else {
                                clearSelection()
                                return
                            }
                            let frame = geometry[plotFrame]
                            guard frame.contains(location), frame.width > 0 else {
                                clearSelection()
                                return
                            }
                            let xPosition = location.x - frame.minX
                            guard let rawDate = proxy.value(atX: xPosition, as: Date.self),
                                  let nearest = nearestDate(to: rawDate) else {
                                clearSelection()
                                return
                            }
                            if selection != nearest { selection = nearest }
                            if cursorLocation != location { cursorLocation = location }
                        case .ended:
                            clearSelection()
                        }
                    }
            }
        }
    }

    private func nearestDate(to target: Date) -> Date? {
        guard !dates.isEmpty else { return nil }
        var lower = 0
        var upper = dates.count
        while lower < upper {
            let middle = (lower + upper) / 2
            if dates[middle] < target { lower = middle + 1 }
            else { upper = middle }
        }
        if lower == 0 { return dates[0] }
        if lower == dates.count { return dates[dates.count - 1] }
        let before = dates[lower - 1]
        let after = dates[lower]
        return abs(before.timeIntervalSince(target)) <= abs(after.timeIntervalSince(target)) ? before : after
    }

    private func clearSelection() {
        if selection != nil { selection = nil }
        if cursorLocation != nil { cursorLocation = nil }
    }
}

private struct ChartCategoryHoverModifier: ViewModifier {
    @Binding var selection: Int?
    @Binding var cursorLocation: CGPoint?
    let categoryCount: Int

    func body(content: Content) -> some View {
        content.chartOverlay { proxy in
            GeometryReader { geometry in
                Rectangle()
                    .fill(.clear)
                    .contentShape(Rectangle())
                    .onContinuousHover { phase in
                        switch phase {
                        case .active(let location):
                            guard categoryCount > 0, let plotFrame = proxy.plotFrame else {
                                clearSelection()
                                return
                            }
                            let frame = geometry[plotFrame]
                            guard frame.contains(location), frame.width > 0 else {
                                clearSelection()
                                return
                            }
                            let relativeX = min(max(location.x - frame.minX, 0), max(frame.width - 0.001, 0))
                            let index = min(categoryCount - 1, max(0, Int(relativeX / frame.width * Double(categoryCount))))
                            if selection != index { selection = index }
                            if cursorLocation != location { cursorLocation = location }
                        case .ended:
                            clearSelection()
                        }
                    }
            }
        }
    }

    private func clearSelection() {
        if selection != nil { selection = nil }
        if cursorLocation != nil { cursorLocation = nil }
    }
}

extension View {
    func trackChartDateHover(
        selection: Binding<Date?>,
        cursorLocation: Binding<CGPoint?>,
        dates: [Date]
    ) -> some View {
        modifier(
            ChartDateHoverModifier(
                selection: selection,
                cursorLocation: cursorLocation,
                dates: dates.sorted()
            )
        )
    }

    func trackChartCategoryHover(
        selection: Binding<Int?>,
        cursorLocation: Binding<CGPoint?>,
        categoryCount: Int
    ) -> some View {
        modifier(
            ChartCategoryHoverModifier(
                selection: selection,
                cursorLocation: cursorLocation,
                categoryCount: categoryCount
            )
        )
    }

    func chartCursorTooltip<Tooltip: View>(
        at location: CGPoint?,
        @ViewBuilder tooltip: () -> Tooltip
    ) -> some View {
        overlay {
            if let location {
                CursorFollowingTooltip(location: location, content: tooltip())
            }
        }
    }
}

func chartPeriodTitle(_ date: Date, granularity: TimeGranularity) -> String {
    switch granularity {
    case .day:
        return chartLongDateTitle(date)
    case .week:
        let calendar = ChatAnalytics.calendar
        let end = calendar.date(byAdding: .day, value: 6, to: date) ?? date
        let startText = chartDayMonthFormatter.string(from: date)
        let endText = chartLongDateFormatter.string(from: end)
        return "Semana del \(startText) al \(endText)"
    case .month:
        return chartMonthFormatter.string(from: date).capitalized
    case .year:
        return chartYearFormatter.string(from: date)
    }
}

func chartLongDateTitle(_ date: Date) -> String {
    chartLongDateFormatter.string(from: date).capitalized
}

func chartHourTitle(_ hour: Int) -> String {
    String(format: "%02d:00–%02d:59", hour, hour)
}

private let chartLongDateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "es_ES")
    formatter.calendar = ChatAnalytics.calendar
    formatter.dateFormat = "EEEE, d 'de' MMMM 'de' yyyy"
    return formatter
}()

private let chartDayMonthFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "es_ES")
    formatter.calendar = ChatAnalytics.calendar
    formatter.dateFormat = "d 'de' MMMM"
    return formatter
}()

private let chartMonthFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "es_ES")
    formatter.calendar = ChatAnalytics.calendar
    formatter.dateFormat = "MMMM 'de' yyyy"
    return formatter
}()

private let chartYearFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "es_ES")
    formatter.calendar = ChatAnalytics.calendar
    formatter.dateFormat = "yyyy"
    return formatter
}()
