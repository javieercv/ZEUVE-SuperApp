import SwiftUI
import MultimediaInspectorModule
import ZEUVEEngines

struct MultimediaSpectrogramView: View {
    @ObservedObject var model: MultimediaInspectorViewModel
    let inspection: MediaInspectionResult
    @State private var cursor: CGPoint?

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                HelpLabel("Espectrograma", topic: ZEUVEHelpTopics.multimediaSpectrogramTab)
                    .font(.title3.weight(.semibold))
                Spacer()
            }
            if inspection.audioStreams.isEmpty {
                noAudioState
            } else {
                controls

                Group {
                    if model.isGeneratingSpectrogram {
                        generatingState
                    } else if let result = model.spectrogram {
                        spectrum(result)
                    } else {
                        emptyState
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var noAudioState: some View {
        ContentUnavailableView(
            "Sin pistas de audio",
            systemImage: "speaker.slash",
            description: Text("Este archivo puede inspeccionarse en Resumen, Pistas y Metadatos.")
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .padding(.vertical, 36)
    }

    private var controls: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 12) {
                analysisControls.frame(maxWidth: .infinity)
                displayControls.frame(maxWidth: .infinity)
                actionControls
            }
            VStack(alignment: .leading, spacing: 10) {
                analysisControls
                displayControls
                actionControls.frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
    }

    private var analysisControls: some View {
        GroupBox("Análisis") {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 10)], alignment: .leading, spacing: 8) {
                HStack(spacing: 5) {
                    Picker("Pista", selection: $model.selectedAudioStreamIndex) {
                        ForEach(inspection.audioStreams, id: \.id) { stream in
                            Text("#\(stream.index ?? 0) · \(stream.language ?? "Audio") · \(stream.codec_name?.uppercased() ?? "")")
                                .tag(stream.index as Int?)
                        }
                    }
                    ContextualHelpButton(topic: ZEUVEHelpTopics.multimediaSpectrogramTrack)
                }

                HStack(spacing: 5) {
                    Picker("Canal", selection: $model.spectrogramChannel) {
                        Text("Mezcla").tag(SpectrogramChannelSelection.mix)
                        ForEach(selectedChannelDescriptors) { channel in
                            Text(channel.label).tag(SpectrogramChannelSelection.channel(channel.index))
                        }
                    }
                    ContextualHelpButton(topic: ZEUVEHelpTopics.multimediaSpectrogramChannel)
                }

                HStack(spacing: 5) {
                    Picker("Ventana", selection: $model.spectrogramWindow) {
                        ForEach(SpectrogramWindowFunction.allCases) { Text($0.displayName).tag($0) }
                    }
                    ContextualHelpButton(topic: ZEUVEHelpTopics.multimediaWindow)
                }

                HStack(spacing: 5) {
                    Picker("FFT", selection: $model.spectrogramFFTSize) {
                        ForEach(model.defaultPreferences.allowedFFTSizes, id: \.self) { Text(String($0)).tag($0) }
                    }
                    ContextualHelpButton(topic: ZEUVEHelpTopics.multimediaFFTSize)
                }
            }
            .padding(.top, 4)
        }
    }

    private var displayControls: some View {
        GroupBox("Visualización") {
            VStack(alignment: .leading, spacing: 9) {
                HStack(spacing: 8) {
                    HStack(spacing: 5) {
                        Text("Rango: \(Int(model.spectrogramDynamicMinimum))…0 dB")
                            .frame(minWidth: 110, alignment: .leading)
                        ContextualHelpButton(topic: ZEUVEHelpTopics.multimediaDynamicRange)
                    }
                    Slider(value: $model.spectrogramDynamicMinimum, in: -160 ... -40, step: 5)
                }
                HStack(spacing: 8) {
                    HStack(spacing: 5) {
                        Picker("Frecuencia", selection: $model.spectrogramFrequencyScale) {
                            ForEach(SpectrogramFrequencyScale.allCases) { Text($0.displayName).tag($0) }
                        }
                        ContextualHelpButton(topic: ZEUVEHelpTopics.multimediaFrequencyScale)
                    }
                    Spacer()
                    HStack(spacing: 5) {
                        Text(selectedStream?.sampleRateValue.map { "Nyquist: \(formatFrequency($0 / 2))" } ?? "Nyquist desconocido")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        ContextualHelpButton(topic: ZEUVEHelpTopics.multimediaNyquist)
                    }
                }
                HStack(spacing: 6) {
                    Text("Zoom")
                    Button { model.panAudioTimeline(-1) } label: { Image(systemName: "chevron.left") }
                        .disabled(!model.isAudioTimelineZoomed)
                        .accessibilityLabel("Desplazar vista temporal hacia atrás")
                    Button { model.zoomAudioTimelineOut() } label: { Image(systemName: "minus.magnifyingglass") }
                        .disabled(!model.isAudioTimelineZoomed)
                        .accessibilityLabel("Reducir zoom temporal")
                    Button { model.zoomAudioTimelineIn() } label: { Image(systemName: "plus.magnifyingglass") }
                        .disabled(!model.canZoomAudioTimelineIn)
                        .accessibilityLabel("Aumentar zoom temporal")
                    Button { model.panAudioTimeline(1) } label: { Image(systemName: "chevron.right") }
                        .disabled(!model.isAudioTimelineZoomed)
                        .accessibilityLabel("Desplazar vista temporal hacia delante")
                    Button("Vista completa") { model.resetAudioTimelineViewport() }
                        .disabled(!model.isAudioTimelineZoomed)
                    Spacer()
                    if model.isAudioTimelineZoomed, let range = model.audioTimelineVisibleRange {
                        Text("\(formatTimePrecise(range.start)) – \(formatTimePrecise(range.end))")
                            .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.borderless)
            }
            .padding(.top, 4)
        }
    }

    private var actionControls: some View {
        VStack(alignment: .trailing, spacing: 8) {
            HStack {
                Button {
                    model.previewSelectedSpectrogram(preservePlaybackState: true)
                } label: {
                    if selectedSpectrogramSourceIsLoading {
                        Label("Cargando…", systemImage: "hourglass")
                    } else {
                        Label(selectedSpectrogramSourceIsPlaying ? "Pausar" : "Escuchar", systemImage: selectedSpectrogramSourceIsPlaying ? "pause.fill" : "play.fill")
                    }
                }
                .disabled(selectedSpectrogramSourceID == nil || selectedSpectrogramSourceIsLoading)
                .help("Previsualiza localmente la pista seleccionada sin modificar el archivo.")

                if model.isGeneratingSpectrogram {
                    Button("Cancelar") { model.cancelCurrentOperation() }
                } else {
                    Button("Actualizar") { model.generateSpectrogram() }.buttonStyle(.borderedProminent)
                }
            }
            Button {
                if let track = selectedEditableTrack { model.analyzeAdvancedAudio(track) }
            } label: {
                if selectedEditableTrackIsAnalyzing {
                    Label("Analizando…", systemImage: "hourglass")
                } else {
                    Label("Análisis avanzado", systemImage: "waveform.badge.magnifyingglass")
                }
            }
            .disabled(selectedEditableTrack == nil || selectedEditableTrackIsAnalyzing)
            .help("Analiza localmente indicios espectrales y anomalías. Las conclusiones son indicios técnicos, no una certificación del origen del archivo.")

            Button("Exportar PNG") { model.exportSpectrogramPNG() }
                .disabled(model.spectrogram == nil)
        }
        .padding(.top, 4)
    }

    private var emptyState: some View {
        VStack(spacing: 18) {
            ContentUnavailableView(
                "Espectrograma sin generar",
                systemImage: "waveform",
                description: Text("Selecciona pista, canal y resolución. El análisis es local y cancelable.")
            )
            Button("Generar espectrograma") { model.generateSpectrogram() }
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .padding(.vertical, 36)
    }

    private var generatingState: some View {
        VStack(spacing: 14) {
            ProgressView(value: model.spectrogramProgress, total: 1)
                .frame(maxWidth: 380)
            Text("Decodificando y analizando…")
                .font(.headline)
            Text("\(Int(model.spectrogramProgress * 100)) %")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
            Button("Cancelar") { model.cancelCurrentOperation() }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .padding(.vertical, 36)
    }

    private func spectrum(_ result: SpectrogramResult) -> some View {
        HStack(alignment: .top, spacing: 7) {
            SpectrogramFrequencyAxis(result: result, scale: model.spectrogramFrequencyScale)
                .frame(maxHeight: .infinity)

            VStack(spacing: 3) {
                GeometryReader { geometry in
                    ZStack {
                        SpectrogramRasterView(result: result, scale: model.spectrogramFrequencyScale)
                        if model.showSignalOverlaysOnSpectrogram {
                            signalAnalysisOverlay(result: result, size: geometry.size)
                        }
                        if model.showAdvancedAudioOverlays {
                            advancedAudioOverlay(result: result, size: geometry.size)
                        }
                        SpectrogramGridOverlay(result: result, scale: model.spectrogramFrequencyScale)
                        playheadOverlay(result: result, size: geometry.size)
                        cursorOverlay(result: result, size: geometry.size)
                    }
                    .contentShape(Rectangle())
                    .onContinuousHover { phase in
                        switch phase {
                        case .active(let location): cursor = location
                        case .ended: cursor = nil
                        }
                    }
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onEnded { value in
                                let time = timeAtX(value.location.x, width: geometry.size.width, result: result)
                                model.previewSelectedSpectrogram(at: time)
                            }
                    )
                    .help("Haz clic para escuchar desde ese instante.")
                }
                .frame(maxHeight: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 8))

                if model.showLoudnessTimeline {
                    MultimediaLoudnessTimelineView(model: model, result: result)
                        .frame(height: 112)
                }

                if let advanced = model.selectedSpectrogramAdvancedAudio {
                    advancedAnalysisSummary(advanced)
                }

                SpectrogramTimeAxis(result: result)
            }

            SpectrogramDBLegend(range: result.dynamicRange)
                .frame(maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func signalAnalysisOverlay(result: SpectrogramResult, size: CGSize) -> some View {
        if let signal = model.selectedSpectrogramSignalAnalysis, result.endTime > result.startTime {
            Canvas { context, canvasSize in
                let duration = result.endTime - result.startTime
                for segment in signal.silenceSegments where segment.endTime >= result.startTime && segment.startTime <= result.endTime {
                    let start = min(max((segment.startTime - result.startTime) / duration, 0), 1)
                    let end = min(max((segment.endTime - result.startTime) / duration, start), 1)
                    let rect = CGRect(
                        x: CGFloat(start) * canvasSize.width,
                        y: 0,
                        width: max(CGFloat(end - start) * canvasSize.width, 1),
                        height: canvasSize.height
                    )
                    context.fill(Path(rect), with: .color(.secondary.opacity(0.10)))
                }
                for event in signal.clippingEvents where event.endTime >= result.startTime && event.startTime <= result.endTime {
                    let time = (event.startTime + event.endTime) / 2
                    let fraction = min(max((time - result.startTime) / duration, 0), 1)
                    let x = CGFloat(fraction) * canvasSize.width
                    var line = Path()
                    line.move(to: CGPoint(x: x, y: 0))
                    line.addLine(to: CGPoint(x: x, y: canvasSize.height))
                    context.stroke(line, with: .color(.orange.opacity(0.82)), style: StrokeStyle(lineWidth: 1.2))
                }
            }
            .frame(width: size.width, height: size.height)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }


    @ViewBuilder
    private func advancedAudioOverlay(result: SpectrogramResult, size: CGSize) -> some View {
        if let analysis = model.selectedSpectrogramAdvancedAudio, result.endTime > result.startTime {
            Canvas { context, canvasSize in
                let duration = result.endTime - result.startTime
                for anomaly in analysis.anomalies where anomaly.end >= result.startTime && anomaly.start <= result.endTime {
                    let start = min(max((anomaly.start - result.startTime) / duration, 0), 1)
                    let end = min(max((anomaly.end - result.startTime) / duration, start), 1)
                    let rect = CGRect(
                        x: CGFloat(start) * canvasSize.width,
                        y: 0,
                        width: max(CGFloat(end - start) * canvasSize.width, 1),
                        height: canvasSize.height
                    )
                    let opacity = 0.07 + min(max(anomaly.severity, 0), 1) * 0.13
                    context.fill(Path(rect), with: .color(.purple.opacity(opacity)))
                }
            }
            .frame(width: size.width, height: size.height)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }

    private func advancedAnalysisSummary(_ analysis: AudioSourceQualityAnalysis) -> some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(analysis.indication.displayName).font(.subheadline.weight(.semibold))
                    Spacer()
                    Text("Confianza técnica: \(Int((analysis.confidence * 100).rounded())) %")
                        .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                }
                if let rolloff = analysis.spectralRolloffHz {
                    Text("Rolloff espectral (99,5 %): \(formatFrequency(rolloff))")
                        .font(.caption).foregroundStyle(.secondary)
                }
                if let bandwidth = analysis.effectiveBandwidthHz {
                    Text("Banda efectiva estimada: \(formatFrequency(bandwidth))")
                        .font(.caption).foregroundStyle(.secondary)
                }
                if let cutoff = analysis.persistentCutoffCandidateHz {
                    Text("Caída persistente candidata: \(formatFrequency(cutoff))")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Text("Ventanas útiles: \(analysis.activeWindowCount) · descartadas: \(analysis.discardedWindowCount)")
                    .font(.caption2).foregroundStyle(.secondary)
                ForEach(analysis.evidence.prefix(3)) { item in
                    Text("• \(item.title): \(item.detail)")
                        .font(.caption).foregroundStyle(.secondary)
                }
                if analysis.totalAnomalyCount > 0 {
                    Text(analysis.anomaliesWereTruncated
                         ? "\(analysis.anomalies.count) eventos representativos de \(analysis.totalAnomalyCount); se alcanzó el límite de visualización."
                         : "\(analysis.totalAnomalyCount) anomalía(s) espectral(es) localizada(s) en la timeline.")
                        .font(.caption).foregroundStyle(.purple)
                }
                Text("El resultado expresa indicios y puede verse afectado por el contenido, masterización o filtrado legítimo.")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            .padding(.top, 2)
        } label: {
            HelpLabel("Análisis espectral avanzado", topic: ZEUVEHelpTopics.multimediaAdvancedAudioAnalysis)
        }
    }

    @ViewBuilder
    private func cursorOverlay(result: SpectrogramResult, size: CGSize) -> some View {
        if let cursor {
            Path { path in
                path.move(to: CGPoint(x: cursor.x, y: 0)); path.addLine(to: CGPoint(x: cursor.x, y: size.height))
                path.move(to: CGPoint(x: 0, y: cursor.y)); path.addLine(to: CGPoint(x: size.width, y: cursor.y))
            }
            .stroke(.white.opacity(0.75), style: StrokeStyle(lineWidth: 0.8, dash: [3, 3]))
            .allowsHitTesting(false)

            let info = cursorInfo(result: result, size: size, point: cursor)
            Text(info)
                .font(.caption.monospaced())
                .padding(6)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6))
                .position(
                    x: min(max(cursor.x + 95, 95), max(size.width - 95, 95)),
                    y: min(max(cursor.y + 22, 22), max(size.height - 22, 22))
                )
                .allowsHitTesting(false)
        }
    }

    @ViewBuilder
    private func playheadOverlay(result: SpectrogramResult, size: CGSize) -> some View {
        if selectedSpectrogramSourceMatchesPreview,
           model.previewPosition >= result.startTime,
           model.previewPosition <= result.endTime {
            let fraction = (model.previewPosition - result.startTime) / max(result.endTime - result.startTime, .leastNonzeroMagnitude)
            Rectangle()
                .fill(.white.opacity(0.9))
                .frame(width: 1.5, height: size.height)
                .position(x: fraction * size.width, y: size.height / 2)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }

    private func cursorInfo(result: SpectrogramResult, size: CGSize, point: CGPoint) -> String {
        let time = timeAtX(point.x, width: size.width, result: result)
        let normalized = max(Double(size.height - point.y), 0) / Double(max(size.height, 1))
        let hz = SpectrogramRenderMapping.frequency(normalizedFromBottom: normalized, nyquist: result.nyquist, scale: model.spectrogramFrequencyScale)
        let db = result.approximateDecibels(time: time, frequency: hz)
        let dbText = db.map { String(format: " · ~%.1f dB", $0) } ?? ""
        let signalText: String = {
            guard let signal = model.selectedSpectrogramSignalAnalysis else { return "" }
            let tolerance = max((result.endTime - result.startTime) * 0.006, 0.002)
            if let event = signal.clippingEvents.min(by: {
                abs(($0.startTime + $0.endTime) / 2 - time) < abs(($1.startTime + $1.endTime) / 2 - time)
            }), abs((event.startTime + event.endTime) / 2 - time) <= tolerance {
                return " · Posible clipping (canal \(event.channelIndex + 1))"
            }
            if signal.silenceSegments.contains(where: { time >= $0.startTime && time <= $0.endTime }) {
                return " · Silencio"
            }
            return ""
        }()
        let advancedText: String = {
            guard model.showAdvancedAudioOverlays, let analysis = model.selectedSpectrogramAdvancedAudio else { return "" }
            if let anomaly = analysis.anomalies.first(where: { time >= $0.start && time <= $0.end }) {
                return " · \(anomaly.title)"
            }
            return ""
        }()
        return "\(formatTimePrecise(time)) · ~\(formatFrequency(hz))\(dbText)\(signalText)\(advancedText)"
    }

    private func timeAtX(_ x: CGFloat, width: CGFloat, result: SpectrogramResult) -> TimeInterval {
        let fraction = min(max(Double(x / max(width, 1)), 0), 1)
        return result.startTime + fraction * (result.endTime - result.startTime)
    }

    private var selectedStream: MediaInspectionStream? {
        inspection.audioStreams.first(where: { $0.index == model.selectedAudioStreamIndex }) ?? inspection.audioStreams.first
    }

    private var selectedEditableTrack: MediaEditableTrack? {
        model.audioTracks.first(where: { $0.source.streamIndex == selectedStream?.index })
    }

    private var selectedEditableTrackIsAnalyzing: Bool {
        guard let selectedEditableTrack else { return false }
        return model.isAdvancedAudioAnalysisActive(for: selectedEditableTrack)
    }

    private var selectedChannelDescriptors: [AudioChannelDescriptor] {
        AudioChannelLayoutResolver.channels(layout: selectedStream?.channel_layout, count: max(selectedStream?.channels ?? 1, 1))
    }

    private var selectedSpectrogramSourceID: String? {
        guard let url = model.selectedURL, let fingerprint = model.fingerprint, let index = selectedStream?.index else { return nil }
        return MultimediaAudioPreviewSource.identity(url: url, fingerprint: fingerprint, streamIndex: index)
    }

    private var selectedSpectrogramPlaybackState: MultimediaPreviewPlaybackState {
        model.previewPlaybackState(for: selectedSpectrogramSourceID)
    }
    private var selectedSpectrogramSourceMatchesPreview: Bool { selectedSpectrogramPlaybackState != .idle }
    private var selectedSpectrogramSourceIsLoading: Bool { selectedSpectrogramPlaybackState == .loading }
    private var selectedSpectrogramSourceIsPlaying: Bool { selectedSpectrogramPlaybackState == .playing }

    private func formatFrequency(_ hz: Double) -> String {
        hz >= 1000 ? String(format: "%.1f kHz", hz / 1000) : String(format: "%.0f Hz", hz)
    }

    private func formatTime(_ value: Double) -> String {
        let total = max(Int(value), 0)
        return total >= 3600 ? String(format: "%02d:%02d:%02d", total / 3600, (total % 3600) / 60, total % 60) : String(format: "%02d:%02d", total / 60, total % 60)
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
