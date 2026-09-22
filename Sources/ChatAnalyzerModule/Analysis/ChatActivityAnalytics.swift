import Foundation

extension ChatAnalytics {
    public static func timeSeries(
        _ messages: [NormalizedMessage],
        granularity: TimeGranularity,
        cancellation: @Sendable () -> Bool = { false }
    ) -> [TimeSeriesPoint] {
        let calendar = self.calendar
        func bucket(_ date: Date) -> Date {
            switch granularity {
            case .day: return calendar.startOfDay(for: date)
            case .week: return calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? calendar.startOfDay(for: date)
            case .month: return calendar.date(from: calendar.dateComponents([.year, .month], from: date)) ?? date
            case .year: return calendar.date(from: calendar.dateComponents([.year], from: date)) ?? date
            }
        }

        var counts: [Date: (total: Int, whatsapp: Int, instagram: Int)] = [:]
        counts.reserveCapacity(min(messages.count, 4_096))
        for (index, message) in messages.enumerated() {
            if index.isMultiple(of: 1_024), cancellation() { return [] }
            let date = bucket(message.timestamp)
            var value = counts[date] ?? (0, 0, 0)
            value.total += 1
            if message.platform == .whatsapp { value.whatsapp += 1 }
            else { value.instagram += 1 }
            counts[date] = value
        }

        var result: [TimeSeriesPoint] = []
        result.reserveCapacity(counts.count * 3)
        for (date, value) in counts {
            result.append(.init(date: date, platform: nil, count: value.total))
            if value.whatsapp > 0 { result.append(.init(date: date, platform: .whatsapp, count: value.whatsapp)) }
            if value.instagram > 0 { result.append(.init(date: date, platform: .instagram, count: value.instagram)) }
        }
        return result.sorted {
            if $0.date != $1.date { return $0.date < $1.date }
            return ($0.platform?.rawValue ?? "") < ($1.platform?.rawValue ?? "")
        }
    }

    public static func hourly(
        _ messages: [NormalizedMessage],
        cancellation: @Sendable () -> Bool = { false }
    ) -> [Int] {
        let calendar = self.calendar
        var values = Array(repeating: 0, count: 24)
        for (index, message) in messages.enumerated() {
            if index.isMultiple(of: 1_024), cancellation() { return Array(repeating: 0, count: 24) }
            values[calendar.component(.hour, from: message.timestamp)] += 1
        }
        return values
    }

    public static func weekdays(
        _ messages: [NormalizedMessage],
        cancellation: @Sendable () -> Bool = { false }
    ) -> [Int] {
        let calendar = self.calendar
        var values = Array(repeating: 0, count: 7)
        for (index, message) in messages.enumerated() {
            if index.isMultiple(of: 1_024), cancellation() { return Array(repeating: 0, count: 7) }
            values[calendar.component(.weekday, from: message.timestamp) - 1] += 1
        }
        return values
    }

    public static func heatmap(
        _ messages: [NormalizedMessage],
        cancellation: @Sendable () -> Bool = { false }
    ) -> [HeatmapCell] {
        let calendar = self.calendar
        var values = Array(repeating: 0, count: 7 * 24)
        for (index, message) in messages.enumerated() {
            if index.isMultiple(of: 1_024), cancellation() { return [] }
            let weekday = calendar.component(.weekday, from: message.timestamp)
            let hour = calendar.component(.hour, from: message.timestamp)
            values[(weekday - 1) * 24 + hour] += 1
        }
        return (1...7).flatMap { day in
            (0..<24).map { hour in
                .init(weekday: day, hour: hour, count: values[(day - 1) * 24 + hour])
            }
        }
    }

    public static func activitySnapshot(
        _ messages: [NormalizedMessage],
        granularity: TimeGranularity,
        cancellation: @Sendable () -> Bool = { false }
    ) -> ChatActivityAnalyticsSnapshot {
        let calendar = self.calendar
        func bucket(_ date: Date) -> Date {
            switch granularity {
            case .day: return calendar.startOfDay(for: date)
            case .week: return calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? calendar.startOfDay(for: date)
            case .month: return calendar.date(from: calendar.dateComponents([.year, .month], from: date)) ?? date
            case .year: return calendar.date(from: calendar.dateComponents([.year], from: date)) ?? date
            }
        }

        var temporal: [Date: (total: Int, whatsapp: Int, instagram: Int)] = [:]
        var hourlyValues = Array(repeating: 0, count: 24)
        var weekdayValues = Array(repeating: 0, count: 7)
        var heatmapValues = Array(repeating: 0, count: 7 * 24)
        temporal.reserveCapacity(min(messages.count, 4_096))

        for (index, message) in messages.enumerated() {
            if index.isMultiple(of: 1_024), cancellation() { return .empty }
            let date = bucket(message.timestamp)
            var counts = temporal[date] ?? (0, 0, 0)
            counts.total += 1
            if message.platform == .whatsapp { counts.whatsapp += 1 }
            else { counts.instagram += 1 }
            temporal[date] = counts

            let hour = calendar.component(.hour, from: message.timestamp)
            let weekdayIndex = calendar.component(.weekday, from: message.timestamp) - 1
            hourlyValues[hour] += 1
            weekdayValues[weekdayIndex] += 1
            heatmapValues[weekdayIndex * 24 + hour] += 1
        }

        var series: [TimeSeriesPoint] = []
        series.reserveCapacity(temporal.count * 3)
        for (date, counts) in temporal {
            series.append(.init(date: date, platform: nil, count: counts.total))
            if counts.whatsapp > 0 { series.append(.init(date: date, platform: .whatsapp, count: counts.whatsapp)) }
            if counts.instagram > 0 { series.append(.init(date: date, platform: .instagram, count: counts.instagram)) }
        }
        series.sort {
            if $0.date != $1.date { return $0.date < $1.date }
            return ($0.platform?.rawValue ?? "") < ($1.platform?.rawValue ?? "")
        }

        let heatmapCells = (1...7).flatMap { day in
            (0..<24).map { hour in
                HeatmapCell(weekday: day, hour: hour, count: heatmapValues[(day - 1) * 24 + hour])
            }
        }
        return ChatActivityAnalyticsSnapshot(
            series: series,
            hourly: hourlyValues,
            weekdays: weekdayValues,
            heatmap: heatmapCells
        )
    }
}
