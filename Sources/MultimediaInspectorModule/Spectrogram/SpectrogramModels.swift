import Foundation

public enum SpectrogramChannelSelection: Sendable, Equatable, Hashable {
    case mix
    case channel(Int)
    public var displayName: String { switch self { case .mix: return "Mezcla"; case .channel(let i): return "Canal \(i + 1)" } }
}

public struct SpectrogramDynamicRange: Sendable, Equatable {
    public var minimumDB: Float
    public var maximumDB: Float
    public init(minimumDB: Float = -120, maximumDB: Float = 0) { self.minimumDB = minimumDB; self.maximumDB = maximumDB }
}

public struct SpectrogramAnalysisRequest: Sendable, Equatable {
    public let url: URL
    public let streamIndex: Int
    public let sampleRate: Double
    public let channels: Int
    public var channelSelection: SpectrogramChannelSelection
    public var window: SpectrogramWindowFunction
    public var fftSize: Int
    public var dynamicRange: SpectrogramDynamicRange
    public var startTime: TimeInterval
    public var duration: TimeInterval?
    public var maximumColumns: Int
    public init(url: URL, streamIndex: Int, sampleRate: Double, channels: Int, channelSelection: SpectrogramChannelSelection = .mix, window: SpectrogramWindowFunction = .hann, fftSize: Int = 4096, dynamicRange: SpectrogramDynamicRange = .init(), startTime: TimeInterval = 0, duration: TimeInterval? = nil, maximumColumns: Int = 1800) {
        self.url=url; self.streamIndex=streamIndex; self.sampleRate=sampleRate; self.channels=channels; self.channelSelection=channelSelection; self.window=window; self.fftSize=fftSize; self.dynamicRange=dynamicRange; self.startTime=startTime; self.duration=duration; self.maximumColumns=maximumColumns
    }
}

public struct SpectrogramColumn: Sendable, Equatable { public let time: TimeInterval; public let decibels: [Float]; public init(time: TimeInterval, decibels: [Float]) { self.time=time; self.decibels=decibels } }

public struct SpectrogramResult: Sendable, Equatable {
    public let renderID = UUID()
    public let sampleRate: Double
    public let fftSize: Int
    public let startTime: TimeInterval
    public let endTime: TimeInterval
    public let dynamicRange: SpectrogramDynamicRange
    public let columns: [SpectrogramColumn]
    public var nyquist: Double { sampleRate / 2 }
    public var binWidth: Double { sampleRate / Double(fftSize) }
    public func frequency(forBin bin: Int) -> Double { min(Double(max(bin, 0)) * binWidth, nyquist) }
}

/// Contadores locales sin rutas ni persistencia; disponibles para QA y desarrollo.
public struct SpectrogramDiagnostics: Sendable, Equatable {
    public let fftExecutions: Int
    public let pcmFrames: Int64
    public let columns: Int
    public let processedChannels: Int
    public let decodedDuration: Double
}

extension SpectrogramResult {
    public func displaying(dynamicRange: SpectrogramDynamicRange) -> Self {
        .init(sampleRate: sampleRate, fftSize: fftSize, startTime: startTime, endTime: endTime,
              dynamicRange: dynamicRange, columns: columns)
    }

    public func cropped(start: TimeInterval, duration: TimeInterval?) -> Self {
        let lower = min(max(start, startTime), endTime)
        let upper = min(lower + (duration ?? (endTime - lower)), endTime)
        let first = max((columns.firstIndex { $0.time >= lower } ?? columns.count) - 1, 0)
        let last = min((columns.firstIndex { $0.time > upper } ?? columns.count) + 1, columns.count)
        return .init(sampleRate: sampleRate, fftSize: fftSize, startTime: lower, endTime: upper,
                     dynamicRange: dynamicRange, columns: Array(columns[first..<max(first, last)]))
    }
}
