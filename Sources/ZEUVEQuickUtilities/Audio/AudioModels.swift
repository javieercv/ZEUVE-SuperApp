import Foundation

public struct AudioApplicationSource: Identifiable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let processIDs: [UInt32]
    public let supportsRouting: Bool
    public let limitation: String?
    public init(id: String, name: String, processIDs: [UInt32], supportsRouting: Bool = true, limitation: String? = nil) {
        self.id = id; self.name = name; self.processIDs = processIDs
        self.supportsRouting = supportsRouting; self.limitation = limitation
    }
}

public struct AudioApplicationLevel: Codable, Equatable, Sendable {
    public var gain: Float
    public var muted: Bool
    public init(gain: Float = 1, muted: Bool = false) { self.gain = gain; self.muted = muted }
    public func validate() throws {
        guard gain.isFinite, (0...1).contains(gain) else { throw QuickUtilityError.failure("El volumen debe estar entre 0 y 100 %. ") }
    }
    public var effectiveGain: Float { muted ? 0 : gain }
}

public struct AudioMixerPreferences: Codable, Equatable, Sendable {
    public var schemaVersion = 1
    public var levels: [String: AudioApplicationLevel] = [:]
    public init() {}
    public func validate() throws {
        guard schemaVersion == 1, levels.count <= 128 else { throw QuickUtilityError.failure("Configuración del mezclador incompatible.") }
        for (key, level) in levels {
            guard !key.isEmpty, key.count <= 255 else { throw QuickUtilityError.failure("Identidad de aplicación no válida.") }
            try level.validate()
        }
    }
}

public enum AudioRoutingPolicy {
    /// Source identity is never inferred from a visible window title or an arbitrary helper PID.
    public static func exclusionReason(bundleID: String, ownBundleID: String, runningInput: Bool) -> String? {
        let id = bundleID.lowercased()
        if id == ownBundleID.lowercased() { return "ZEUVE se excluye para evitar realimentación." }
        if runningInput { return "La aplicación utiliza entrada de audio; su salida no se captura." }
        let callIDs = ["com.apple.facetime", "com.apple.avconferenced", "com.apple.callservicesd", "us.zoom.xos", "com.microsoft.teams", "com.microsoft.teams2", "com.skype.skype", "com.hnc.discord", "com.cisco.webexmeetingsapp"]
        if callIDs.contains(id) { return "Las aplicaciones de llamada se excluyen para proteger las conversaciones." }
        return nil
    }
}

public enum AudioGainProcessor {
    public static func apply(_ samples: [Float], level: AudioApplicationLevel) throws -> [Float] {
        try level.validate()
        var result = [Float](repeating: 0, count: samples.count)
        samples.withUnsafeBufferPointer { source in
            result.withUnsafeMutableBufferPointer { destination in
                guard let input = source.baseAddress, let output = destination.baseAddress else { return }
                render(input: input, output: output, count: samples.count, channels: 1, from: level.effectiveGain, to: level.effectiveGain)
            }
        }
        return result
    }
    /// Stereo channel layout conversion shares the same gain ramp for both channels.
    public static func renderStereo(inputLeft: UnsafePointer<Float>, inputRight: UnsafePointer<Float>, inputStride: Int, outputLeft: UnsafeMutablePointer<Float>, outputRight: UnsafeMutablePointer<Float>, outputStride: Int, frames: Int, from start: Float, to target: Float) {
        guard frames > 0, inputStride > 0, outputStride > 0 else { return }
        for frame in 0..<frames {
            let gain = start + (target - start) * Float(frame + 1) / Float(frames)
            outputLeft[frame * outputStride] = inputLeft[frame * inputStride] * gain
            outputRight[frame * outputStride] = inputRight[frame * inputStride] * gain
        }
    }
    /// Shared with the HAL callback: bounded arithmetic only, without allocation or locks.
    public static func render(input: UnsafePointer<Float>, output: UnsafeMutablePointer<Float>, count: Int, channels: Int, from start: Float, to target: Float) {
        guard count > 0, channels > 0 else { return }
        let frames = max(1, count / channels)
        for index in 0..<count {
            let gain = start + (target - start) * Float(index / channels + 1) / Float(frames)
            output[index] = input[index] * gain
        }
    }
}

public protocol AudioRouteBackend: Sendable {
    func discoverSources() async throws -> [AudioApplicationSource]
    func startRoute(source: AudioApplicationSource, gain: Float) async throws
    func setGain(sourceID: String, gain: Float) async throws
    func stopRoute(sourceID: String) async throws
    func stopAll() async throws
    func setMeteringEnabled(sourceID: String, enabled: Bool) async throws
    func readMeters() async throws -> [AudioRouteMeter]
    func observeChanges(_ handler: (@MainActor @Sendable (String?) -> Void)?) async throws
}

/// Last callback's aggregate amplitude only. Not Codable and never sent to logs/history/storage.
public struct AudioRouteMeter: Identifiable, Equatable, Sendable {
    public let id: String
    public let inputRMS: Float
    public let outputRMS: Float
    public let callbackCount: UInt32
    public init(id: String, inputRMS: Float, outputRMS: Float, callbackCount: UInt32) {
        self.id = id; self.inputRMS = inputRMS; self.outputRMS = outputRMS; self.callbackCount = callbackCount
    }
    public static func decibels(_ amplitude: Float) -> Double? {
        guard amplitude.isFinite, amplitude > 0 else { return nil }
        return 20 * log10(Double(amplitude))
    }
}

public struct AudioStereoRMS: Equatable, Sendable {
    public let input: Float
    public let output: Float
    public init(input: Float, output: Float) { self.input = input; self.output = output }
}

extension AudioGainProcessor {
    public static func measureStereo(inputLeft: UnsafePointer<Float>, inputRight: UnsafePointer<Float>, inputStride: Int, outputLeft: UnsafePointer<Float>, outputRight: UnsafePointer<Float>, outputStride: Int, frames: Int) -> AudioStereoRMS {
        guard frames > 0, inputStride > 0, outputStride > 0 else { return .init(input: 0, output: 0) }
        var inputPower: Double = 0, outputPower: Double = 0
        for frame in 0..<frames {
            let left = Double(inputLeft[frame * inputStride]), right = Double(inputRight[frame * inputStride])
            let renderedLeft = Double(outputLeft[frame * outputStride]), renderedRight = Double(outputRight[frame * outputStride])
            inputPower += left * left + right * right
            outputPower += renderedLeft * renderedLeft + renderedRight * renderedRight
        }
        return .init(input: Float(sqrt(inputPower / Double(frames * 2))), output: Float(sqrt(outputPower / Double(frames * 2))))
    }
}
