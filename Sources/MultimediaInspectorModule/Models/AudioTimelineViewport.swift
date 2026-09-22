import Foundation

public struct AudioTimelineVisibleRange: Sendable, Equatable {
    public let start: TimeInterval
    public let end: TimeInterval

    public init(start: TimeInterval, end: TimeInterval) {
        let safeStart = start.isFinite ? max(start, 0) : 0
        let safeEnd = end.isFinite ? max(end, safeStart) : safeStart
        self.start = safeStart
        self.end = safeEnd
    }

    public var duration: TimeInterval { max(end - start, 0) }

    public func contains(_ time: TimeInterval) -> Bool {
        time.isFinite && time >= start && time <= end
    }
}

public struct AudioTimelineViewport: Sendable, Equatable {
    public let start: TimeInterval
    public let duration: TimeInterval?

    public static let full = AudioTimelineViewport()

    public init(start: TimeInterval = 0, duration: TimeInterval? = nil) {
        if let duration, duration.isFinite, duration > 0 {
            self.start = start.isFinite ? max(start, 0) : 0
            self.duration = duration
        } else {
            self.start = 0
            self.duration = nil
        }
    }

    public var isFull: Bool { duration == nil }

    public func visibleRange(totalDuration: TimeInterval) -> AudioTimelineVisibleRange {
        guard totalDuration.isFinite, totalDuration > 0 else {
            return AudioTimelineVisibleRange(start: 0, end: 0)
        }
        guard let duration else {
            return AudioTimelineVisibleRange(start: 0, end: totalDuration)
        }
        let width = min(max(duration, .leastNonzeroMagnitude), totalDuration)
        let lower = min(max(start, 0), max(totalDuration - width, 0))
        return AudioTimelineVisibleRange(start: lower, end: min(lower + width, totalDuration))
    }

    public func zoomed(
        by factor: Double,
        around anchor: TimeInterval?,
        totalDuration: TimeInterval,
        minimumDuration: TimeInterval = 1
    ) -> AudioTimelineViewport {
        guard factor.isFinite, factor > 0, totalDuration.isFinite, totalDuration > 0 else { return .full }
        let current = visibleRange(totalDuration: totalDuration)
        let minimum = min(max(minimumDuration.isFinite ? minimumDuration : 1, 0.05), totalDuration)
        let nextDuration = min(max(current.duration * factor, minimum), totalDuration)
        if nextDuration >= totalDuration - 0.000_001 { return .full }

        let fallbackAnchor = current.start + current.duration / 2
        let safeAnchor = min(max((anchor?.isFinite == true ? anchor! : fallbackAnchor), current.start), current.end)
        let nextStart = min(max(safeAnchor - nextDuration / 2, 0), max(totalDuration - nextDuration, 0))
        return AudioTimelineViewport(start: nextStart, duration: nextDuration)
    }

    public func panned(byFraction fraction: Double, totalDuration: TimeInterval) -> AudioTimelineViewport {
        guard fraction.isFinite, !isFull, totalDuration.isFinite, totalDuration > 0 else { return self }
        let current = visibleRange(totalDuration: totalDuration)
        guard current.duration < totalDuration else { return .full }
        let nextStart = min(
            max(current.start + current.duration * fraction, 0),
            max(totalDuration - current.duration, 0)
        )
        return AudioTimelineViewport(start: nextStart, duration: current.duration)
    }
}

public struct AudioTimelineChapterMarker: Sendable, Equatable, Identifiable {
    public let id: Int
    public let time: TimeInterval
    public let title: String

    public init(id: Int, time: TimeInterval, title: String) {
        self.id = id
        self.time = max(time.isFinite ? time : 0, 0)
        self.title = title
    }
}
