import SwiftUI
import MultimediaInspectorModule

struct SpectrogramFrequencyAxis: View {
    let result: SpectrogramResult
    let scale: SpectrogramFrequencyScale

    var body: some View {
        GeometryReader { geometry in
            let ticks = SpectrogramAxisTicks.frequencies(nyquist: result.nyquist, scale: scale)
            ZStack(alignment: .topTrailing) {
                ForEach(ticks, id: \.self) { frequency in
                    let normalized = SpectrogramRenderMapping.normalizedFromBottom(frequency: frequency, nyquist: result.nyquist, scale: scale)
                    Text(formatFrequency(frequency))
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .position(x: geometry.size.width / 2, y: (1 - normalized) * geometry.size.height)
                }
            }
        }
        .frame(width: 58)
        .accessibilityLabel("Eje de frecuencia")
    }

    private func formatFrequency(_ hz: Double) -> String {
        if hz >= 10_000 { return String(format: "%.0f k", hz / 1_000) }
        if hz >= 1_000 { return String(format: "%.1f k", hz / 1_000) }
        return String(format: "%.0f", hz)
    }
}

struct SpectrogramTimeAxis: View {
    let result: SpectrogramResult

    var body: some View {
        GeometryReader { geometry in
            let ticks = SpectrogramAxisTicks.times(start: result.startTime, end: result.endTime)
            ZStack(alignment: .leading) {
                ForEach(ticks, id: \.self) { time in
                    let fraction = (time - result.startTime) / max(result.endTime - result.startTime, .leastNonzeroMagnitude)
                    Text(formatTime(time))
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .position(x: fraction * geometry.size.width, y: geometry.size.height / 2)
                }
            }
        }
        .frame(height: 20)
        .accessibilityLabel("Eje temporal")
    }

    private func formatTime(_ value: Double) -> String {
        let total = max(Int(value.rounded()), 0)
        if total >= 3600 { return String(format: "%02d:%02d:%02d", total / 3600, (total % 3600) / 60, total % 60) }
        return String(format: "%02d:%02d", total / 60, total % 60)
    }
}

struct SpectrogramGridOverlay: View {
    let result: SpectrogramResult
    let scale: SpectrogramFrequencyScale

    var body: some View {
        Canvas { context, size in
            var path = Path()
            for time in SpectrogramAxisTicks.times(start: result.startTime, end: result.endTime) {
                let fraction = (time - result.startTime) / max(result.endTime - result.startTime, .leastNonzeroMagnitude)
                let x = fraction * size.width
                path.move(to: CGPoint(x: x, y: 0)); path.addLine(to: CGPoint(x: x, y: size.height))
            }
            for frequency in SpectrogramAxisTicks.frequencies(nyquist: result.nyquist, scale: scale) {
                let normalized = SpectrogramRenderMapping.normalizedFromBottom(frequency: frequency, nyquist: result.nyquist, scale: scale)
                let y = (1 - normalized) * size.height
                path.move(to: CGPoint(x: 0, y: y)); path.addLine(to: CGPoint(x: size.width, y: y))
            }
            context.stroke(path, with: .color(.white.opacity(0.14)), lineWidth: 0.5)
        }
        .allowsHitTesting(false)
    }
}

struct SpectrogramDBLegend: View {
    let range: SpectrogramDynamicRange

    var body: some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 3)
                .fill(LinearGradient(colors: [.yellow, .red, .purple, .blue], startPoint: .top, endPoint: .bottom))
                .frame(width: 10)
            VStack(alignment: .leading) {
                Text("0"); Spacer(); Text(String(format: "%.0f", (range.minimumDB + range.maximumDB) / 2)); Spacer(); Text(String(format: "%.0f", range.minimumDB))
            }
            .font(.caption2.monospacedDigit())
            .foregroundStyle(.secondary)
        }
        .frame(width: 42)
        .accessibilityLabel("Leyenda de intensidad en decibelios")
    }
}
