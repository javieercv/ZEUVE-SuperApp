import SwiftUI
import MultimediaInspectorModule

struct MultimediaLoudnessTimelineView: View {
    @ObservedObject var model: MultimediaInspectorViewModel
    let result: SpectrogramResult
    @State private var cursor: CGPoint?

    var body: some View {
        GroupBox {
            if model.isAnalyzingLoudness, model.loudnessSourceID == model.selectedSpectrogramSourceID {
                HStack(spacing: 10) {
                    ProgressView(value: model.loudnessProgress).frame(maxWidth: 220)
                    Text("Analizando sonoridad…").font(.caption).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            } else if let timeline = model.selectedSpectrogramLoudness?.timeline, !timeline.samples.isEmpty {
                timelineCanvas(timeline)
            } else {
                HStack(spacing: 10) {
                    Text("Analiza la sonoridad de esta pista para mostrar su evolución temporal.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    if let track = model.selectedAudioTrack {
                        Button("Analizar sonoridad") { model.analyzeLoudness(track) }
                            .buttonStyle(.bordered)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        } label: {
            HStack(spacing: 6) {
                Text("Sonoridad temporal · Short-term LUFS")
                ContextualHelpButton(topic: ZEUVEHelpTopics.multimediaLoudnessTimeline)
            }
        }
    }

    private func timelineCanvas(_ timeline: AudioLoudnessTimeline) -> some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                Canvas { context, size in
                    drawGrid(context: &context, size: size, timeline: timeline)
                    drawCurve(context: &context, size: size, timeline: timeline)
                    drawPlayhead(context: &context, size: size)
                }
                .contentShape(Rectangle())
                .onContinuousHover { phase in
                    switch phase {
                    case .active(let point): cursor = point
                    case .ended: cursor = nil
                    }
                }
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onEnded { value in model.seekPreview(to: timeAtX(value.location.x, width: geometry.size.width)) }
                )
                .help("Haz clic para mover el reproductor a ese instante.")

                if let cursor, let sample = sampleAtCursor(cursor, width: geometry.size.width, timeline: timeline) {
                    Text(tooltip(sample))
                        .font(.caption2.monospacedDigit())
                        .padding(5)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6))
                        .position(
                            x: min(max(cursor.x + 105, 105), max(geometry.size.width - 105, 105)),
                            y: min(max(cursor.y + 18, 18), max(geometry.size.height - 18, 18))
                        )
                        .allowsHitTesting(false)
                }
            }
        }
        .frame(minHeight: 72)
    }

    private func drawGrid(context: inout GraphicsContext, size: CGSize, timeline: AudioLoudnessTimeline) {
        let bounds = loudnessBounds(timeline)
        for fraction in [0.0, 0.5, 1.0] {
            let y = CGFloat(fraction) * size.height
            var line = Path()
            line.move(to: CGPoint(x: 0, y: y))
            line.addLine(to: CGPoint(x: size.width, y: y))
            context.stroke(line, with: .color(.secondary.opacity(0.18)), style: StrokeStyle(lineWidth: 0.6, dash: [3, 3]))
        }
        let top = Text(String(format: "%.0f", bounds.max)).font(.caption2).foregroundStyle(.secondary)
        let bottom = Text(String(format: "%.0f", bounds.min)).font(.caption2).foregroundStyle(.secondary)
        context.draw(top, at: CGPoint(x: 18, y: 8), anchor: .center)
        context.draw(bottom, at: CGPoint(x: 18, y: max(size.height - 8, 8)), anchor: .center)
    }

    private func drawCurve(context: inout GraphicsContext, size: CGSize, timeline: AudioLoudnessTimeline) {
        let samples = visibleSamples(timeline)
        guard samples.count >= 2 else { return }
        let bounds = loudnessBounds(timeline)
        var path = Path()
        var started = false
        for sample in samples {
            guard let value = sample.shortTermLUFS else { continue }
            let point = CGPoint(x: xForTime(sample.time, width: size.width), y: yForLoudness(value, height: size.height, bounds: bounds))
            if started { path.addLine(to: point) } else { path.move(to: point); started = true }
        }
        if started { context.stroke(path, with: .foreground, style: StrokeStyle(lineWidth: 1.6, lineJoin: .round)) }
    }

    private func drawPlayhead(context: inout GraphicsContext, size: CGSize) {
        guard model.previewPosition >= result.startTime, model.previewPosition <= result.endTime else { return }
        let x = xForTime(model.previewPosition, width: size.width)
        var line = Path()
        line.move(to: CGPoint(x: x, y: 0))
        line.addLine(to: CGPoint(x: x, y: size.height))
        context.stroke(line, with: .color(.primary.opacity(0.75)), style: StrokeStyle(lineWidth: 1))
    }

    private func visibleSamples(_ timeline: AudioLoudnessTimeline) -> [AudioLoudnessTimelineSample] {
        let samples = timeline.samples
        guard !samples.isEmpty else { return [] }
        var visible = samples.filter { $0.time >= result.startTime && $0.time <= result.endTime }
        if let before = samples.last(where: { $0.time < result.startTime }) { visible.insert(before, at: 0) }
        if let after = samples.first(where: { $0.time > result.endTime }) { visible.append(after) }
        return visible
    }

    private func loudnessBounds(_ timeline: AudioLoudnessTimeline) -> (min: Double, max: Double) {
        let minimum = min(timeline.shortTermMinimumLUFS ?? -60, -6)
        let maximum = max(timeline.shortTermMaximumLUFS ?? 0, minimum + 6)
        return (floor(minimum / 6) * 6, min(ceil(maximum / 6) * 6, 6))
    }

    private func xForTime(_ time: TimeInterval, width: CGFloat) -> CGFloat {
        let duration = max(result.endTime - result.startTime, .leastNonzeroMagnitude)
        let fraction = min(max((time - result.startTime) / duration, 0), 1)
        return CGFloat(fraction) * width
    }

    private func timeAtX(_ x: CGFloat, width: CGFloat) -> TimeInterval {
        let fraction = min(max(Double(x / max(width, 1)), 0), 1)
        return result.startTime + fraction * (result.endTime - result.startTime)
    }

    private func yForLoudness(_ loudness: Double, height: CGFloat, bounds: (min: Double, max: Double)) -> CGFloat {
        let fraction = min(max((loudness - bounds.min) / max(bounds.max - bounds.min, .leastNonzeroMagnitude), 0), 1)
        return height - CGFloat(fraction) * height
    }

    private func sampleAtCursor(_ point: CGPoint, width: CGFloat, timeline: AudioLoudnessTimeline) -> AudioLoudnessTimelineSample? {
        timeline.nearestSample(to: timeAtX(point.x, width: width))
    }

    private func tooltip(_ sample: AudioLoudnessTimelineSample) -> String {
        let m = sample.momentaryLUFS.map { String(format: "M %.1f", $0) } ?? "M n/d"
        let s = sample.shortTermLUFS.map { String(format: "S %.1f", $0) } ?? "S n/d"
        let i = sample.integratedLUFS.map { String(format: "I %.1f", $0) } ?? "I n/d"
        return "\(formatTime(sample.time)) · \(m) · \(s) · \(i) LUFS"
    }

    private func formatTime(_ value: TimeInterval) -> String {
        let clamped = max(value, 0)
        let hours = Int(clamped) / 3600
        let minutes = (Int(clamped) % 3600) / 60
        let seconds = clamped.truncatingRemainder(dividingBy: 60)
        return hours > 0 ? String(format: "%02d:%02d:%06.3f", hours, minutes, seconds) : String(format: "%02d:%06.3f", minutes, seconds)
    }
}
