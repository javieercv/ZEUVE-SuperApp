import Foundation
#if canImport(Accelerate)
import Accelerate
#endif

public struct SpectrogramFFTProcessor: Sendable {
    public init() {}

    public func analyze(
        samples: [Float],
        sampleRate: Double,
        window: SpectrogramWindowFunction,
        dynamicRange: SpectrogramDynamicRange
    ) throws -> [Float] {
        _ = sampleRate
        let analyzer = try SpectrogramFFTAnalyzer(
            fftSize: samples.count,
            window: window,
            dynamicRange: dynamicRange
        )
        return analyzer.analyze(samples)
    }

    public func windowValues(count: Int, function: SpectrogramWindowFunction) -> [Float] {
        SpectrogramFFTAnalyzer.windowValues(count: count, function: function)
    }
}

/// Plan FFT reutilizable para una petición de espectrograma.
///
/// El acumulador lo crea una sola vez y lo utiliza de forma serializada bajo su propio lock,
/// evitando reconstruir la ventana y el setup de Accelerate para cada columna.
final class SpectrogramFFTAnalyzer {
    private let fftSize: Int
    private let dynamicRange: SpectrogramDynamicRange
    private let weights: [Float]
    private let coherentGain: Float
    #if canImport(Accelerate)
    private let setup: vDSP_DFT_Setup
    #endif

    init(
        fftSize: Int,
        window: SpectrogramWindowFunction,
        dynamicRange: SpectrogramDynamicRange
    ) throws {
        guard fftSize >= 2, fftSize.nonzeroBitCount == 1 else {
            throw MultimediaInspectorError.invalidInput
        }
        self.windowed = [Float](repeating: 0, count: fftSize)
        self.imaginaryInput = [Float](repeating: 0, count: fftSize)
        self.realOutput = [Float](repeating: 0, count: fftSize)
        self.imaginaryOutput = [Float](repeating: 0, count: fftSize)
        self.power = [Float](repeating: 0, count: fftSize / 2 + 1)
        self.fftSize = fftSize
        self.dynamicRange = dynamicRange
        self.weights = Self.windowValues(count: fftSize, function: window)
        self.coherentGain = max(self.weights.reduce(0, +), Float.leastNonzeroMagnitude)
        #if canImport(Accelerate)
        guard let setup = vDSP_DFT_zop_CreateSetup(nil, vDSP_Length(fftSize), .FORWARD) else {
            throw MultimediaInspectorError.invalidInput
        }
        self.setup = setup
        #endif
    }

    deinit {
        #if canImport(Accelerate)
        vDSP_DFT_DestroySetup(setup)
        #endif
    }

    private var windowed: [Float] = []
    private var imaginaryInput: [Float] = []
    private var realOutput: [Float] = []
    private var imaginaryOutput: [Float] = []
    private var power: [Float] = []

    func analyze(_ samples: [Float]) -> [Float] {
        analyzePower(samples).map { value in
            min(max(10 * log10f(max(value, Float.leastNonzeroMagnitude)), dynamicRange.minimumDB), dynamicRange.maximumDB)
        }
    }

    /// El resultado prestado se consume sin retenerlo antes de la siguiente FFT.
    func analyzePower(_ samples: [Float]) -> [Float] {
        precondition(samples.count == fftSize)
        #if canImport(Accelerate)
        vDSP_vmul(samples, 1, weights, 1, &windowed, 1, vDSP_Length(fftSize))
        vDSP_DFT_Execute(setup, windowed, imaginaryInput, &realOutput, &imaginaryOutput)
        #else
        for index in samples.indices { windowed[index] = samples[index] * weights[index] }
        let bins = fallbackDFT(windowed)
        for index in bins.indices { realOutput[index] = bins[index].0; imaginaryOutput[index] = bins[index].1 }
        #endif
        let normalization = 1 / (coherentGain * coherentGain)
        for index in power.indices {
            let scale: Float = index == 0 || index == fftSize / 2 ? normalization : 4 * normalization
            let value = (realOutput[index] * realOutput[index] + imaginaryOutput[index] * imaginaryOutput[index]) * scale
            power[index] = value.isFinite ? value : 0
        }
        return power
    }

    static func windowValues(count: Int, function: SpectrogramWindowFunction) -> [Float] {
        guard count > 1 else {
            return [Float](repeating: 1, count: max(0, count))
        }
        let denominator = Float(count - 1)
        return (0..<count).map { index in
            let angle = 2 * Float.pi * Float(index) / denominator
            switch function {
            case .hann:
                return 0.5 - 0.5 * cosf(angle)
            case .hamming:
                return 0.53836 - 0.46164 * cosf(angle)
            case .blackmanHarris:
                return 0.35875
                    - 0.48829 * cosf(angle)
                    + 0.14128 * cosf(2 * angle)
                    - 0.01168 * cosf(3 * angle)
            }
        }
    }

    private func fallbackDFT(_ input: [Float]) -> [(Float, Float)] {
        let count = input.count
        return (0...(count / 2)).map { bin in
            var real: Double = 0
            var imaginary: Double = 0
            for sample in 0..<count {
                let angle = -2 * Double.pi * Double(bin * sample) / Double(count)
                let value = Double(input[sample])
                real += value * cos(angle)
                imaginary += value * sin(angle)
            }
            return (Float(real), Float(imaginary))
        }
    }
}
