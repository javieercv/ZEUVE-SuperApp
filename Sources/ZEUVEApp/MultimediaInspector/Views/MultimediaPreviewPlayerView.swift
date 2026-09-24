import SwiftUI
import MultimediaInspectorModule

struct MultimediaPreviewPlayerView: View {
    @ObservedObject var model: MultimediaInspectorViewModel
    @StateObject private var owningWindow = MultimediaOwningWindowReference()

    var body: some View {
        VStack(spacing: 9) {
            HStack(spacing: 10) {
                Text(model.previewTitle ?? (model.videoTracks.isEmpty ? "Previsualización de audio" : "Previsualización de vídeo"))
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                Spacer()
                if let loudness = model.currentPreviewLoudness {
                    Text(loudnessSummary(loudness))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                Text("\(formatTime(model.previewPosition)) / \(formatTime(model.previewDuration ?? 0))")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            if !model.videoTracks.isEmpty {
                ZStack(alignment: .bottom) {
                    MultimediaVideoPreviewSurface(frame: model.videoPreviewFrame, scaleMode: model.defaultPreferences.videoPreviewScaleMode)
                        .frame(maxHeight: 430)
                    if let subtitle = model.currentSubtitlePreviewText, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.system(size: model.defaultPreferences.subtitlePreviewFontSize, weight: .medium))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(.black.opacity(model.defaultPreferences.subtitlePreviewBackgroundOpacity), in: RoundedRectangle(cornerRadius: 7))
                            .padding(.bottom, 14)
                            .padding(.horizontal, 24)
                    }
                }

                HStack(spacing: 8) {
                    Picker("Vídeo", selection: Binding(
                        get: { model.selectedVideoSourceID },
                        set: { model.selectVideoSource($0) }
                    )) {
                        ForEach(model.videoTracks) { track in
                            Text(track.title.isEmpty ? "Vídeo · \(track.codec.uppercased())" : track.title)
                                .tag(model.previewSourceID(for: track) as String?)
                        }
                    }
                    .frame(maxWidth: 260)

                    Picker("Subtítulos", selection: $model.selectedSubtitlePreviewStreamIndex) {
                        Text("Desactivados").tag(nil as Int?)
                        ForEach(model.textSubtitlePreviewStreams, id: \.id) { stream in
                            Text([stream.language, stream.title, stream.codec_name?.uppercased()].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · "))
                                .tag(stream.index as Int?)
                        }
                    }
                    .frame(maxWidth: 300)
                    .disabled(model.isLoadingSubtitlePreview)

                    if model.isLoadingSubtitlePreview { ProgressView().controlSize(.small) }
                    if !model.bitmapSubtitleStreams.isEmpty {
                        ContextualHelpButton(topic: ZEUVEHelpTopics.multimediaBitmapSubtitles)
                    }
                }
            }

            if !model.audioTracks.isEmpty {
                MultimediaWaveformView(model: model)
            }

            timelineControls

            HStack(spacing: 10) {
                Button(action: primaryAction) {
                    Image(systemName: primaryIcon).frame(width: 22)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityLabel(primaryLabel)

                Button { model.skipPreview(by: -Double(model.previewSkipSeconds)) } label: {
                    Label("-\(model.previewSkipSeconds) s", systemImage: "gobackward")
                }
                .disabled(model.previewSourceID == nil && model.videoPreviewSourceID == nil)
                .accessibilityLabel("Retroceder \(model.previewSkipSeconds) segundos")

                Button { model.skipPreview(by: Double(model.previewSkipSeconds)) } label: {
                    Label("+\(model.previewSkipSeconds) s", systemImage: "goforward")
                }
                .disabled(model.previewSourceID == nil && model.videoPreviewSourceID == nil)
                .accessibilityLabel("Avanzar \(model.previewSkipSeconds) segundos")

                if model.isAnalyzingLoudness, model.loudnessSourceID == model.previewSourceID {
                    ProgressView(value: model.loudnessProgress)
                        .frame(maxWidth: 150)
                    Text("Sonoridad…").font(.caption).foregroundStyle(.secondary)
                } else if model.previewSourceID != nil, model.currentPreviewLoudness == nil {
                    Button("Analizar sonoridad") { model.analyzeCurrentPreviewLoudness() }
                        .buttonStyle(.bordered)
                        .help("Calcula LUFS, LRA y picos localmente. Puede tardar porque recorre la pista completa.")
                }

                Spacer()

                if !model.videoTracks.isEmpty || model.previewSourceID != nil {
                    Picker("Velocidad", selection: $model.previewPlaybackRate) {
                        Text("0,5×").tag(0.5)
                        Text("0,75×").tag(0.75)
                        Text("1×").tag(1.0)
                        Text("1,25×").tag(1.25)
                        Text("1,5×").tag(1.5)
                        Text("2×").tag(2.0)
                    }
                    .frame(width: 95)
                    .accessibilityLabel("Velocidad de reproducción")

                    if !model.videoTracks.isEmpty {
                        Button { owningWindow.window?.toggleFullScreen(nil) } label: {
                            Image(systemName: "arrow.up.left.and.arrow.down.right")
                        }
                        .disabled(!owningWindow.isAvailable)
                        .help("Alterna la ventana en pantalla completa para ampliar la previsualización.")
                        .accessibilityLabel("Pantalla completa")
                    }
                }

                HStack(spacing: 6) {
                    Image(systemName: model.previewVolume == 0 ? "speaker.slash" : "speaker.wave.2")
                        .foregroundStyle(.secondary)
                    Slider(value: $model.previewVolume, in: 0 ... 1)
                        .frame(width: 110)
                        .accessibilityLabel("Volumen")
                }

                Button { model.stopPreview() } label: { Image(systemName: "stop.fill") }
                    .disabled(model.previewSourceID == nil && model.videoPreviewSourceID == nil)
                    .accessibilityLabel("Detener previsualización")
            }
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .background {
            MultimediaOwningWindowReader { [weak owningWindow] window in
                owningWindow?.update(window)
            }
            .frame(width: 0, height: 0)
        }
    }

    private var timelineControls: some View {
        HStack(spacing: 7) {
            Text("Zoom")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button { model.panAudioTimeline(-1) } label: { Image(systemName: "chevron.left") }
                .disabled(!model.isAudioTimelineZoomed)
                .accessibilityLabel("Desplazar forma de onda hacia atrás")
            Button { model.zoomAudioTimelineOut() } label: { Image(systemName: "minus.magnifyingglass") }
                .disabled(!model.isAudioTimelineZoomed)
                .accessibilityLabel("Reducir zoom de la forma de onda")
            Button { model.zoomAudioTimelineIn() } label: { Image(systemName: "plus.magnifyingglass") }
                .disabled(!model.canZoomAudioTimelineIn)
                .accessibilityLabel("Aumentar zoom de la forma de onda")
            Button { model.panAudioTimeline(1) } label: { Image(systemName: "chevron.right") }
                .disabled(!model.isAudioTimelineZoomed)
                .accessibilityLabel("Desplazar forma de onda hacia delante")
            Button("Vista completa") { model.resetAudioTimelineViewport() }
                .disabled(!model.isAudioTimelineZoomed)

            Spacer()

            if model.isAudioTimelineZoomed, let range = model.audioTimelineVisibleRange {
                Text("\(formatTimePrecise(range.start)) – \(formatTimePrecise(range.end))")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.borderless)
    }

    private var primaryIcon: String {
        switch model.previewState {
        case .playing, .loading: return "pause.fill"
        case .paused, .finished: return "play.fill"
        default: return "play.fill"
        }
    }

    private var primaryLabel: String {
        switch model.previewState {
        case .playing, .loading: return "Pausar"
        case .paused, .finished: return "Reanudar"
        default: return "Reproducir"
        }
    }

    private func primaryAction() {
        switch model.previewState {
        case .playing, .loading, .paused, .finished: model.togglePreviewPause()
        default:
            if !model.audioTracks.isEmpty { model.previewSelectedSpectrogram(at: 0) }
            else { model.previewSelectedVideo(at: 0) }
        }
    }

    private func loudnessSummary(_ result: AudioLoudnessResult) -> String {
        var parts: [String] = []
        if let value = result.integratedLUFS { parts.append(String(format: "%.1f LUFS", value)) }
        if let value = result.truePeakDBTP { parts.append(String(format: "TP %.1f dBTP", value)) }
        return parts.joined(separator: " · ")
    }

    private func formatTime(_ value: Double) -> String {
        let total = max(Int(value.rounded()), 0)
        if total >= 3600 { return String(format: "%02d:%02d:%02d", total / 3600, (total % 3600) / 60, total % 60) }
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
