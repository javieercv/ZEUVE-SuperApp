import SwiftUI
import MultimediaInspectorModule

struct MultimediaWaveformView: View {
    @ObservedObject var model: MultimediaInspectorViewModel
    @State private var dragPosition: Double?
    @State private var hoverLocation: CGPoint?

    var body: some View {
        GeometryReader { proxy in
            let width = max(proxy.size.width, 1)
            let position = dragPosition ?? model.previewPosition
            let duration = max(model.previewDuration ?? model.waveform?.duration ?? 0, 0)
            let visibleRange = model.audioTimelineVisibleRange(totalDuration: duration)
            let samples = renderedSamples(width: width, visibleRange: visibleRange)
            let playedFraction = visibleRange.duration > 0
                ? min(max((position - visibleRange.start) / visibleRange.duration, 0), 1)
                : 0
            let chapters = visibleChapterMarkers(in: visibleRange)
            let silences = visibleSilenceSegments(in: visibleRange)
            let clippings = visibleClippingEvents(in: visibleRange)
            let anomalies = visibleSpectralAnomalies(in: visibleRange)

            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(.quaternary.opacity(0.35))

                if model.waveformShowsCenterGuide {
                    Rectangle()
                        .fill(.secondary.opacity(0.18))
                        .frame(height: 1)
                }

                if samples.isEmpty {
                    if model.isGeneratingWaveform {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Text("Forma de onda disponible al reproducir")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Canvas { context, size in
                        drawSilenceSegments(silences, visibleRange: visibleRange, context: &context, size: size)
                        drawSpectralAnomalies(anomalies, visibleRange: visibleRange, context: &context, size: size)
                        drawWaveform(samples, context: &context, size: size, playedFraction: playedFraction)
                        drawChapterMarkers(chapters, visibleRange: visibleRange, context: &context, size: size)
                        drawClippingEvents(clippings, visibleRange: visibleRange, context: &context, size: size)
                    }
                }

                if visibleRange.duration > 0, visibleRange.contains(position) {
                    let fraction = (position - visibleRange.start) / visibleRange.duration
                    Rectangle()
                        .fill(.primary.opacity(0.75))
                        .frame(width: 1)
                        .offset(x: (fraction - 0.5) * width)
                        .allowsHitTesting(false)
                }

                hoverOverlay(
                    width: width,
                    visibleRange: visibleRange,
                    chapters: chapters,
                    silences: silences,
                    clippings: clippings,
                    anomalies: anomalies
                )
            }
            .contentShape(Rectangle())
            .onContinuousHover { phase in
                switch phase {
                case .active(let location): hoverLocation = location
                case .ended: hoverLocation = nil
                }
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard visibleRange.duration > 0 else { return }
                        dragPosition = timeAtX(value.location.x, width: width, visibleRange: visibleRange)
                    }
                    .onEnded { value in
                        guard visibleRange.duration > 0 else { dragPosition = nil; return }
                        let target = timeAtX(value.location.x, width: width, visibleRange: visibleRange)
                        // El ViewModel adopta el destino de forma síncrona antes de soltar
                        // el estado local del drag, evitando un frame con la posición anterior.
                        model.seekPreview(to: target)
                        dragPosition = nil
                    }
            )
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Posición de reproducción")
            .accessibilityValue("\(formatTime(position)) de \(formatTime(duration))")
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment: model.skipPreview(by: Double(model.previewSkipSeconds))
                case .decrement: model.skipPreview(by: -Double(model.previewSkipSeconds))
                @unknown default: break
                }
            }
        }
        .frame(height: waveformHeight)
    }

    private var waveformHeight: CGFloat {
        switch model.waveformStyle {
        case .compact: return 44
        case .balanced: return 58
        case .detailed: return 72
        }
    }

    private func renderedSamples(
        width: CGFloat,
        visibleRange: AudioTimelineVisibleRange
    ) -> [MultimediaWaveformBucket] {
        guard let waveform = model.waveform, !waveform.buckets.isEmpty else { return [] }
        let pointsPerBar: CGFloat
        switch model.waveformStyle {
        case .compact: pointsPerBar = 7
        case .balanced: pointsPerBar = 4.5
        case .detailed: pointsPerBar = 2.8
        }
        let target = max(16, min(Int(width / pointsPerBar), 1600))
        return MultimediaWaveformRenderSampler.samples(
            from: waveform,
            visibleRange: visibleRange,
            targetCount: target
        )
    }

    private func visibleChapterMarkers(in range: AudioTimelineVisibleRange) -> [AudioTimelineChapterMarker] {
        guard model.showChapterMarkersOnWaveform else { return [] }
        return model.audioTimelineChapterMarkers.filter { range.contains($0.time) }
    }

    private func visibleSilenceSegments(in range: AudioTimelineVisibleRange) -> [AudioSilenceSegment] {
        guard model.showSignalOverlaysOnWaveform else { return [] }
        return model.currentWaveformSignalAnalysis?.silenceSegments.filter {
            $0.endTime >= range.start && $0.startTime <= range.end
        } ?? []
    }

    private func visibleClippingEvents(in range: AudioTimelineVisibleRange) -> [AudioClippingEvent] {
        guard model.showSignalOverlaysOnWaveform else { return [] }
        return model.currentWaveformSignalAnalysis?.clippingEvents.filter {
            $0.endTime >= range.start && $0.startTime <= range.end
        } ?? []
    }

    private func visibleSpectralAnomalies(in range: AudioTimelineVisibleRange) -> [SpectralAnomaly] {
        guard model.showAdvancedAudioOverlays else { return [] }
        return model.currentWaveformAdvancedAudio?.anomalies.filter {
            $0.end >= range.start && $0.start <= range.end
        } ?? []
    }

    @ViewBuilder
    private func hoverOverlay(
        width: CGFloat,
        visibleRange: AudioTimelineVisibleRange,
        chapters: [AudioTimelineChapterMarker],
        silences: [AudioSilenceSegment],
        clippings: [AudioClippingEvent],
        anomalies: [SpectralAnomaly]
    ) -> some View {
        if let hoverLocation, visibleRange.duration > 0 {
            let time = timeAtX(hoverLocation.x, width: width, visibleRange: visibleRange)
            let tolerance = visibleRange.duration * Double(8 / max(width, 1))
            let clipping = clippings.min(by: {
                abs(($0.startTime + $0.endTime) / 2 - time) < abs(($1.startTime + $1.endTime) / 2 - time)
            }).flatMap {
                abs(($0.startTime + $0.endTime) / 2 - time) <= tolerance ? $0 : nil
            }
            let silence = silences.first { time >= $0.startTime && time <= $0.endTime }
            let anomaly = anomalies.first { time >= $0.start && time <= $0.end }
            let chapter = chapters.min(by: { abs($0.time - time) < abs($1.time - time) })
                .flatMap { abs($0.time - time) <= tolerance ? $0 : nil }
            let label = hoverLabel(
                time: time,
                clipping: clipping,
                silence: silence,
                anomaly: anomaly,
                chapter: chapter
            )

            Text(label)
                .font(.caption2.monospacedDigit())
                .lineLimit(1)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 5))
                .position(
                    x: min(max(hoverLocation.x, 62), max(width - 62, 62)),
                    y: 12
                )
                .allowsHitTesting(false)
        }
    }

    private func hoverLabel(
        time: TimeInterval,
        clipping: AudioClippingEvent?,
        silence: AudioSilenceSegment?,
        anomaly: SpectralAnomaly?,
        chapter: AudioTimelineChapterMarker?
    ) -> String {
        if let clipping {
            return "Posible clipping · \(formatTimePrecise(clipping.startTime)) · canal \(clipping.channelIndex + 1) · \(String(format: "%.2f dBFS", clipping.peakDBFS))"
        }
        if let silence {
            return "Silencio · \(formatTimePrecise(silence.startTime))–\(formatTimePrecise(silence.endTime)) · \(String(format: "%.2f s", silence.duration))"
        }
        if let anomaly {
            return "\(anomaly.title) · \(formatTimePrecise(anomaly.start))–\(formatTimePrecise(anomaly.end))"
        }
        if let chapter {
            return "\(chapter.title) · \(formatTimePrecise(chapter.time))"
        }
        return formatTimePrecise(time)
    }

    private func drawSilenceSegments(
        _ segments: [AudioSilenceSegment],
        visibleRange: AudioTimelineVisibleRange,
        context: inout GraphicsContext,
        size: CGSize
    ) {
        guard visibleRange.duration > 0 else { return }
        for segment in segments {
            let start = min(max((segment.startTime - visibleRange.start) / visibleRange.duration, 0), 1)
            let end = min(max((segment.endTime - visibleRange.start) / visibleRange.duration, start), 1)
            let rect = CGRect(
                x: CGFloat(start) * size.width,
                y: 0,
                width: max(CGFloat(end - start) * size.width, 1),
                height: size.height
            )
            context.fill(Path(rect), with: .color(.secondary.opacity(0.11)))
        }
    }

    private func drawSpectralAnomalies(
        _ anomalies: [SpectralAnomaly],
        visibleRange: AudioTimelineVisibleRange,
        context: inout GraphicsContext,
        size: CGSize
    ) {
        guard visibleRange.duration > 0 else { return }
        for anomaly in anomalies {
            let start = min(max((anomaly.start - visibleRange.start) / visibleRange.duration, 0), 1)
            let end = min(max((anomaly.end - visibleRange.start) / visibleRange.duration, start), 1)
            let rect = CGRect(
                x: CGFloat(start) * size.width,
                y: 0,
                width: max(CGFloat(end - start) * size.width, 2),
                height: size.height
            )
            context.fill(Path(rect), with: .color(.purple.opacity(0.10 + 0.12 * anomaly.severity)))
        }
    }

    private func drawClippingEvents(
        _ events: [AudioClippingEvent],
        visibleRange: AudioTimelineVisibleRange,
        context: inout GraphicsContext,
        size: CGSize
    ) {
        guard visibleRange.duration > 0 else { return }
        for event in events {
            let time = (event.startTime + event.endTime) / 2
            let fraction = min(max((time - visibleRange.start) / visibleRange.duration, 0), 1)
            let x = CGFloat(fraction) * size.width
            var line = Path()
            line.move(to: CGPoint(x: x, y: 0))
            line.addLine(to: CGPoint(x: x, y: size.height))
            context.stroke(line, with: .color(.orange.opacity(0.8)), style: StrokeStyle(lineWidth: 1.2))
            var marker = Path()
            marker.move(to: CGPoint(x: x, y: 1))
            marker.addLine(to: CGPoint(x: x - 4, y: 7))
            marker.addLine(to: CGPoint(x: x + 4, y: 7))
            marker.closeSubpath()
            context.fill(marker, with: .color(.orange.opacity(0.9)))
        }
    }

    private func drawWaveform(
        _ samples: [MultimediaWaveformBucket],
        context: inout GraphicsContext,
        size: CGSize,
        playedFraction: Double
    ) {
        guard !samples.isEmpty else { return }
        let centerY = size.height / 2
        let verticalPadding: CGFloat = 4
        let halfHeight = max(centerY - verticalPadding, 1)
        let slot = size.width / CGFloat(samples.count)
        let gap: CGFloat
        switch model.waveformStyle {
        case .compact: gap = min(2.2, slot * 0.38)
        case .balanced: gap = min(1.8, slot * 0.32)
        case .detailed: gap = min(1.2, slot * 0.25)
        }
        let barWidth = max(slot - gap, 1)
        let playedX = size.width * playedFraction

        for (index, bucket) in samples.enumerated() {
            let x = CGFloat(index) * slot + (slot - barWidth) / 2
            let centerX = x + barWidth / 2
            let positive = CGFloat(max(bucket.maximum, 0)) * halfHeight
            let negative = CGFloat(max(-bucket.minimum, 0)) * halfHeight
            let upper = positive > 0 ? max(positive, 1.5) : 0
            let lower = negative > 0 ? max(negative, 1.5) : 0
            guard upper > 0 || lower > 0 else { continue }
            let top = centerY - upper
            let bottom = centerY + lower
            let rect = CGRect(x: x, y: top, width: barWidth, height: max(bottom - top, 1))
            let path = Path(roundedRect: rect, cornerRadius: min(barWidth / 2, 3))
            let color: Color = centerX <= playedX ? .accentColor : .secondary.opacity(0.48)
            context.fill(path, with: .color(color))

            if model.waveformRepresentation == .peaksAndEnergy, bucket.rms > 0 {
                let energy = min(CGFloat(bucket.rms) * halfHeight, halfHeight)
                let innerWidth = max(barWidth * 0.45, 0.8)
                let inner = CGRect(
                    x: centerX - innerWidth / 2,
                    y: centerY - energy,
                    width: innerWidth,
                    height: max(energy * 2, 1)
                )
                let energyPath = Path(roundedRect: inner, cornerRadius: innerWidth / 2)
                context.fill(energyPath, with: .color(.primary.opacity(centerX <= playedX ? 0.34 : 0.2)))
            }
        }
    }

    private func drawChapterMarkers(
        _ chapters: [AudioTimelineChapterMarker],
        visibleRange: AudioTimelineVisibleRange,
        context: inout GraphicsContext,
        size: CGSize
    ) {
        guard visibleRange.duration > 0 else { return }
        for chapter in chapters {
            let fraction = min(max((chapter.time - visibleRange.start) / visibleRange.duration, 0), 1)
            let x = CGFloat(fraction) * size.width
            var line = Path()
            line.move(to: CGPoint(x: x, y: 0))
            line.addLine(to: CGPoint(x: x, y: size.height))
            context.stroke(line, with: .color(.secondary.opacity(0.48)), style: StrokeStyle(lineWidth: 0.8, dash: [2, 3]))
            let marker = Path(ellipseIn: CGRect(x: x - 2.5, y: 2, width: 5, height: 5))
            context.fill(marker, with: .color(.primary.opacity(0.7)))
        }
    }

    private func timeAtX(
        _ x: CGFloat,
        width: CGFloat,
        visibleRange: AudioTimelineVisibleRange
    ) -> TimeInterval {
        let fraction = min(max(Double(x / max(width, 1)), 0), 1)
        return visibleRange.start + fraction * visibleRange.duration
    }

    private func formatTime(_ value: Double) -> String {
        let total = max(Int(value.rounded()), 0)
        if total >= 3600 {
            return String(format: "%02d:%02d:%02d", total / 3600, (total % 3600) / 60, total % 60)
        }
        return String(format: "%02d:%02d", total / 60, total % 60)
    }

    private func formatTimePrecise(_ value: Double) -> String {
        let clamped = max(value, 0)
        let hours = Int(clamped) / 3600
        let minutes = (Int(clamped) % 3600) / 60
        let seconds = clamped.truncatingRemainder(dividingBy: 60)
        if hours > 0 { return String(format: "%02d:%02d:%06.3f", hours, minutes, seconds) }
        return String(format: "%02d:%06.3f", minutes, seconds)
    }
}
