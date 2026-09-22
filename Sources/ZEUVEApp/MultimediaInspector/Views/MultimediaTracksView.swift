import SwiftUI
import ZEUVEEngines
import MultimediaInspectorModule

struct MultimediaTracksView: View {
    @ObservedObject var model: MultimediaInspectorViewModel
    let inspection: MediaInspectionResult

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HelpLabel("Pistas", topic: ZEUVEHelpTopics.multimediaTracksTab)
                    .font(.title3.weight(.semibold))
                trackSection(title: "VÍDEO", kind: .video, tracks: model.videoTracks)
                if model.audioTracks.count >= 2 { comparisonSection }
                trackSection(title: "AUDIO", kind: .audio, tracks: model.audioTracks)
                trackSection(title: "SUBTÍTULOS", kind: .subtitle, tracks: model.subtitleTracks)

                if !inspection.attachmentStreams.isEmpty || !inspection.dataStreams.isEmpty || !inspection.unknownStreams.isEmpty {
                    GroupBox("OTROS STREAMS · SOLO LECTURA") {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(inspection.streams.filter { !["video", "audio", "subtitle"].contains($0.codec_type ?? "") }, id: \.id) { stream in
                                Text("Stream \(stream.index ?? -1) · \(stream.codec_type ?? "desconocido") · \(stream.codec_name ?? "sin códec")")
                            }
                        }
                    }
                }
            }
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var comparisonSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    comparisonPicker(.a)
                    comparisonPicker(.b)
                }

                HStack(spacing: 10) {
                    Picker("Pista activa", selection: Binding(
                        get: { model.activeComparisonSlot },
                        set: { model.selectComparisonSlot($0) }
                    )) {
                        Text("A").tag(AudioComparisonSlot.a)
                        Text("B").tag(AudioComparisonSlot.b)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 120)

                    let state = model.comparisonPlaybackState
                    Button { model.toggleComparisonPreview() } label: {
                        if state == .loading {
                            Label("Cargando…", systemImage: "hourglass")
                        } else {
                            Label(state == .playing ? "Pausar" : "Escuchar", systemImage: state == .playing ? "pause.fill" : "play.fill")
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(!model.comparisonHasTwoTracks || state == .loading)
                    .help("Alterna A/B usando el mismo reproductor y conserva el instante y el estado Play/Pausa.")

                    Spacer()

                    if comparisonHasMissingAnalysis {
                        Button(model.isCompletingComparisonAnalysis ? "Completando análisis…" : "Completar análisis A/B") {
                            model.completeComparisonAnalysis()
                        }
                        .buttonStyle(.bordered)
                        .disabled(model.isCompletingComparisonAnalysis || !model.comparisonHasTwoTracks)
                    }
                }

                if model.isCompletingComparisonAnalysis {
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small)
                        Text(comparisonProgressLabel).font(.caption).foregroundStyle(.secondary)
                    }
                }

                comparisonTable

                Text("A/B conserva el mismo instante y el estado de reproducción. La pista seleccionada para el espectrograma no cambia al alternar A/B.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 4)
        } label: {
            HStack(spacing: 6) {
                Text("COMPARAR A/B")
                ContextualHelpButton(topic: ZEUVEHelpTopics.multimediaABComparison)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func comparisonPicker(_ slot: AudioComparisonSlot) -> some View {
        Picker(slot.displayName, selection: Binding<UUID?>(
            get: { slot == .a ? model.comparisonTrackAID : model.comparisonTrackBID },
            set: { model.setComparisonTrack(slot, id: $0) }
        )) {
            ForEach(model.comparisonAvailableTracks) { track in
                Text(model.comparisonLabel(for: track)).tag(track.id as UUID?)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var comparisonHasMissingAnalysis: Bool {
        [AudioComparisonSlot.a, .b].compactMap { model.comparisonTrack(for: $0) }.contains { model.comparisonNeedsAnalysis(for: $0) }
    }

    private var comparisonProgressLabel: String {
        guard let id = model.comparisonAnalysisCurrentTrackID, let track = model.audioTracks.first(where: { $0.id == id }) else {
            return "Completando análisis secuencial…"
        }
        return "Analizando \(model.comparisonLabel(for: track))…"
    }

    private var comparisonTable: some View {
        let a = model.comparisonMetrics(for: .a)
        let b = model.comparisonMetrics(for: .b)
        return Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 6) {
            GridRow {
                Text("Dato").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                Text("A").font(.caption.weight(.semibold))
                Text("B").font(.caption.weight(.semibold))
            }
            comparisonRow("Códec", a: a?.codec, b: b?.codec)
            comparisonRow("Bitrate", a: formatBitRate(a?.bitRate), b: formatBitRate(b?.bitRate))
            comparisonRow("Sample rate", a: formatSampleRate(a?.sampleRate), b: formatSampleRate(b?.sampleRate))
            comparisonRow("Canales", a: a?.channels.map(String.init), b: b?.channels.map(String.init))
            comparisonRow("Layout", a: a?.channelLayout, b: b?.channelLayout)
            comparisonRow("Duración", a: formatDuration(a?.duration), b: formatDuration(b?.duration))
            comparisonRow("Integrated", a: formatValue(a?.integratedLUFS, suffix: " LUFS"), b: formatValue(b?.integratedLUFS, suffix: " LUFS"), topic: ZEUVEHelpTopics.multimediaIntegratedLUFS)
            comparisonRow("LRA", a: formatValue(a?.loudnessRangeLU, suffix: " LU"), b: formatValue(b?.loudnessRangeLU, suffix: " LU"), topic: ZEUVEHelpTopics.multimediaLRA)
            comparisonRow("True Peak", a: formatValue(a?.truePeakDBTP, suffix: " dBTP"), b: formatValue(b?.truePeakDBTP, suffix: " dBTP"), topic: ZEUVEHelpTopics.multimediaTruePeak)
            comparisonRow("Sample Peak", a: formatValue(a?.samplePeakDBFS, suffix: " dBFS"), b: formatValue(b?.samplePeakDBFS, suffix: " dBFS"), topic: ZEUVEHelpTopics.multimediaSamplePeak)
            comparisonRow("Silencios", a: formatCount(a?.silenceSegmentCount), b: formatCount(b?.silenceSegmentCount), topic: ZEUVEHelpTopics.multimediaSignalAnalysis)
            comparisonRow("Tiempo silencio", a: formatDuration(a?.totalSilenceDuration), b: formatDuration(b?.totalSilenceDuration), topic: ZEUVEHelpTopics.multimediaSilenceDuration)
            comparisonRow("Posible clipping", a: formatCount(a?.clippingEventCount), b: formatCount(b?.clippingEventCount), topic: ZEUVEHelpTopics.multimediaClippingThreshold)
        }
        .font(.caption.monospacedDigit())
    }

    private func comparisonRow(_ title: String, a: String?, b: String?, topic: ContextualHelpTopic? = nil) -> some View {
        GridRow {
            HStack(spacing: 4) {
                Text(title).foregroundStyle(.secondary)
                if let topic { ContextualHelpButton(topic: topic) }
            }
            Text(a ?? "n/d")
            Text(b ?? "n/d")
        }
    }

    private func formatValue(_ value: Double?, suffix: String) -> String? {
        value.map { String(format: "%.1f%@", $0, suffix) }
    }

    private func formatCount(_ value: Int?) -> String? { value.map(String.init) }

    private func formatBitRate(_ value: Int64?) -> String? {
        guard let value else { return nil }
        return value >= 1_000_000 ? String(format: "%.2f Mb/s", Double(value) / 1_000_000) : String(format: "%.0f kb/s", Double(value) / 1_000)
    }

    private func formatSampleRate(_ value: Double?) -> String? {
        value.map { String(format: "%.1f kHz", $0 / 1_000) }
    }

    private func formatDuration(_ value: TimeInterval?) -> String? {
        guard let value, value.isFinite else { return nil }
        return String(format: "%.3f s", value)
    }

    @ViewBuilder
    private func trackSection(title: String, kind: MediaTrackKind, tracks: [MediaEditableTrack]) -> some View {
        GroupBox {
            VStack(spacing: 10) {
                if tracks.isEmpty {
                    Text("Sin pistas").foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading)
                }

                ForEach(Array(tracks.enumerated()), id: \.element.id) { index, track in
                    trackRow(track, index: index, total: tracks.count)
                        .modifier(TrackReorderModifier(enabled: model.isEditing, track: track) { movingID in
                            model.reorderTrack(kind: kind, movingID: movingID, before: track.id)
                        })
                }

                if model.isEditing {
                    HStack {
                        switch kind {
                        case .video:
                            Button("Añadir vídeo…") { model.chooseExternalTrack(kind: .video) }.buttonStyle(.bordered)
                        case .audio:
                            Button("Añadir audio…") { model.chooseExternalTrack(kind: .audio) }.buttonStyle(.bordered)
                        case .subtitle:
                            Button("Añadir subtítulo…") { model.chooseExternalTrack(kind: .subtitle) }.buttonStyle(.bordered)
                        }
                        Label(
                            kind == .video ? "También puedes soltar aquí un archivo de vídeo" : (kind == .audio ? "También puedes soltar aquí un archivo de audio" : "También puedes soltar aquí un archivo de subtítulos"),
                            systemImage: "square.and.arrow.down"
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .dropDestination(for: URL.self) { urls, _ in
                guard model.isEditing, let url = urls.first else { return false }
                model.addDroppedExternalTrack(url, kind: kind)
                return true
            }
        } label: { Text(title) }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func trackRow(_ track: MediaEditableTrack, index: Int, total: Int) -> some View {
        if model.isEditing {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "line.3.horizontal")
                        .foregroundStyle(.tertiary)
                        .help("Arrastra para reordenar")
                    VStack(alignment: .leading, spacing: 2) {
                        Text(track.codec.uppercased()).font(.headline)
                        if let detail = technicalTrackDetail(track), !detail.isEmpty { Text(detail).font(.caption).foregroundStyle(.secondary) }
                    }
                    Spacer()
                    if track.kind == .video { videoPreviewButton(track) }
                    if track.kind == .audio {
                        previewButton(track)
                        signalAnalysisButton(track)
                        loudnessButton(track)
                        advancedAudioButton(track)
                    }
                    if track.kind == .subtitle, isBitmapSubtitle(track) {
                        bitmapOCRButton(track)
                    }
                    Button { move(track, from: index, to: index - 1) } label: { Image(systemName: "arrow.up") }
                        .disabled(index == 0).accessibilityLabel("Mover pista arriba").help("Mover pista arriba")
                    Button { move(track, from: index, to: index + 2) } label: { Image(systemName: "arrow.down") }
                        .disabled(index == total - 1).accessibilityLabel("Mover pista abajo").help("Mover pista abajo")
                    Button(role: .destructive) { model.removeTrack(track.id, kind: track.kind) } label: { Image(systemName: "trash") }
                        .accessibilityLabel("Eliminar pista").help("Eliminar pista del borrador")
                }

                HStack {
                    TextField("Idioma", text: binding(track, \.language)).frame(maxWidth: 140).accessibilityLabel("Idioma de la pista")
                    TextField("Título", text: binding(track, \.title)).accessibilityLabel("Título de la pista")
                    HStack(spacing: 4) {
                        Toggle("Default", isOn: Binding(
                            get: { (model.videoTracks + model.audioTracks + model.subtitleTracks).first(where: { $0.id == track.id })?.isDefault ?? false },
                            set: { model.setDefault(track.id, kind: track.kind, value: $0) }
                        )).toggleStyle(.checkbox)
                        ContextualHelpButton(topic: ZEUVEHelpTopics.multimediaDefaultFlag)
                    }
                    if track.kind == .subtitle {
                        HStack(spacing: 4) {
                            Toggle("Forced", isOn: Binding(
                                get: { model.subtitleTracks.first(where: { $0.id == track.id })?.isForced ?? false },
                                set: { model.setForced(track.id, value: $0) }
                            )).toggleStyle(.checkbox)
                            ContextualHelpButton(topic: ZEUVEHelpTopics.multimediaForcedFlag)
                        }
                    }
                }

                if track.kind == .audio {
                    audioAnalysisDetail(track)
                }

                if track.kind == .subtitle, let draft = model.currentDraft {
                    let decision = MediaContainerCompatibilityRegistry().decision(kind: .subtitle, codec: track.codec, container: draft.targetContainer)
                    if case .convertSubtitle(let destinationCodec) = decision {
                        HStack(spacing: 5) {
                            Toggle("Autorizar \(track.codec) → \(destinationCodec)", isOn: Binding(
                                get: { draft.authorizedSubtitleConversions.contains(track.id) },
                                set: { model.authorizeSubtitleConversion(track.id, allowed: $0) }
                            ))
                            ContextualHelpButton(topic: ZEUVEHelpTopics.multimediaSubtitleConversion)
                        }
                    }
                }
            }
            .padding(10)
            .background(.background.secondary, in: RoundedRectangle(cornerRadius: 10))
        } else {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading) {
                        Text(track.language.isEmpty ? "Idioma sin indicar" : track.language).font(.headline)
                        Text([
                            track.codec.uppercased(), technicalTrackDetail(track), track.title.isEmpty ? nil : track.title,
                            track.isDefault ? "Default" : nil, track.isForced ? "Forced" : nil,
                        ].compactMap { $0 }.joined(separator: " · ")).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if track.kind == .video { videoPreviewButton(track) }
                    if track.kind == .audio {
                        previewButton(track)
                        signalAnalysisButton(track)
                        loudnessButton(track)
                        advancedAudioButton(track)
                    }
                    if track.kind == .subtitle, isBitmapSubtitle(track) {
                        bitmapOCRButton(track)
                    }
                }
                if track.kind == .audio { audioAnalysisDetail(track) }
            }
            .padding(.vertical, 4)
        }
    }


    private func videoPreviewButton(_ track: MediaEditableTrack) -> some View {
        let selected = model.selectedVideoStreamIndex == track.source.streamIndex
        return Button {
            model.selectedVideoStreamIndex = track.source.streamIndex
            model.previewSelectedVideo(at: model.previewPosition)
        } label: {
            Label(selected && model.videoPreviewState == .playing ? "Pausar" : "Ver", systemImage: selected && model.videoPreviewState == .playing ? "pause.fill" : "play.rectangle")
        }
        .buttonStyle(.bordered)
        .accessibilityHint("Previsualiza esta pista de vídeo localmente y conserva el playhead compartido.")
    }

    private func loudnessButton(_ track: MediaEditableTrack) -> some View {
        let active = model.isLoudnessAnalysisActive(for: track)
        let hasResult = model.loudnessResult(for: track) != nil
        return Button {
            model.analyzeLoudness(track)
        } label: {
            if active {
                Label("Analizando…", systemImage: "waveform.badge.magnifyingglass")
            } else {
                Label(hasResult ? "Reanalizar" : "Sonoridad", systemImage: "gauge.with.dots.needle.50percent")
            }
        }
        .buttonStyle(.bordered)
        .disabled(model.isAnalyzingLoudness && !active)
        .help("Calcula LUFS, LRA y picos de esta pista localmente.")
    }

    private func signalAnalysisButton(_ track: MediaEditableTrack) -> some View {
        let active = model.isSignalAnalysisActive(for: track)
        let hasResult = model.signalAnalysisResult(for: track) != nil
        return Button {
            model.analyzeSignal(track)
        } label: {
            if active {
                Label("Analizando…", systemImage: "waveform.path.ecg")
            } else {
                Label(hasResult ? "Reanalizar señal" : "Señal", systemImage: "waveform.path.ecg")
            }
        }
        .buttonStyle(.bordered)
        .disabled(model.isAnalyzingSignal && !active)
        .help("Detecta silencios y posible clipping recorriendo la pista completa a resolución PCM.")
    }

    private func advancedAudioButton(_ track: MediaEditableTrack) -> some View {
        let active = model.isAdvancedAudioAnalysisActive(for: track)
        let hasResult = model.advancedAudioResult(for: track) != nil
        return Button {
            model.analyzeAdvancedAudio(track)
        } label: {
            if active {
                Label("Analizando…", systemImage: "waveform.and.magnifyingglass")
            } else {
                Label(hasResult ? "Reanalizar espectro" : "Análisis avanzado", systemImage: "waveform.and.magnifyingglass")
            }
        }
        .buttonStyle(.bordered)
        .disabled(model.isAnalyzingAdvancedAudio && !active)
        .help("Busca indicios espectrales explicables y anomalías temporales. No afirma de forma absoluta el origen del archivo.")
    }

    private func bitmapOCRButton(_ track: MediaEditableTrack) -> some View {
        let active = model.isRunningBitmapSubtitleOCR && model.ocrSourceStreamIndex == track.source.streamIndex
        return Button {
            model.runBitmapSubtitleOCR(streamIndex: track.source.streamIndex)
        } label: {
            Label(active ? "OCR…" : "OCR local", systemImage: "text.viewfinder")
        }
        .buttonStyle(.bordered)
        .disabled(model.isRunningBitmapSubtitleOCR)
        .help("Reconoce localmente subtítulos bitmap mediante Vision y crea un borrador revisable; no sustituye la pista original.")
    }

    private func isBitmapSubtitle(_ track: MediaEditableTrack) -> Bool {
        guard track.kind == .subtitle,
              case .original(let streamIndex) = track.source,
              let stream = inspection.subtitleStreams.first(where: { $0.index == streamIndex }) else { return false }
        return stream.subtitleRepresentation == .bitmap
    }

    @ViewBuilder
    private func audioAnalysisDetail(_ track: MediaEditableTrack) -> some View {
        if model.isSignalAnalysisActive(for: track) {
            HStack(spacing: 8) {
                ProgressView(value: model.signalAnalysisProgress).frame(maxWidth: 180)
                Text("Analizando señal…").font(.caption).foregroundStyle(.secondary)
            }
        } else if let result = model.signalAnalysisResult(for: track) {
            HStack(spacing: 5) {
                Text(signalAnalysisLine(result)).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                ContextualHelpButton(topic: ZEUVEHelpTopics.multimediaSignalAnalysis)
            }
        }
        if model.isLoudnessAnalysisActive(for: track) {
            HStack(spacing: 8) {
                ProgressView(value: model.loudnessProgress).frame(maxWidth: 180)
                Text("Analizando sonoridad…").font(.caption).foregroundStyle(.secondary)
            }
        } else if let result = model.loudnessResult(for: track) {
            HStack(spacing: 5) {
                Text(loudnessLine(result)).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                ContextualHelpButton(topic: ZEUVEHelpTopics.multimediaLoudness)
            }
        }
        if model.isAdvancedAudioAnalysisActive(for: track) {
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text("Analizando indicios y anomalías espectrales…").font(.caption).foregroundStyle(.secondary)
                ContextualHelpButton(topic: ZEUVEHelpTopics.multimediaAdvancedAudioAnalysis)
            }
        } else if let result = model.advancedAudioResult(for: track) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    Text("\(result.indication.displayName) · confianza descriptiva \(Int(result.confidence * 100)) %")
                        .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                    ContextualHelpButton(topic: ZEUVEHelpTopics.multimediaAdvancedAudioAnalysis)
                }
                ForEach(result.evidence.prefix(3)) { evidence in
                    Text("• \(evidence.title): \(evidence.detail)").font(.caption2).foregroundStyle(.secondary)
                }
                if !result.anomalies.isEmpty {
                    Text("\(result.anomalies.count) anomalías temporales señaladas en la timeline.")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
        if let timing = model.timingEntry(for: track) {
            let values = [
                timing.offsetFromReference.map { String(format: "offset %+.3f s", $0) },
                timing.durationDifference.map { String(format: "Δ duración %+.3f s", $0) },
            ].compactMap { $0 }
            if !values.isEmpty {
                HStack(spacing: 5) {
                    Text(values.joined(separator: " · ")).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                    ContextualHelpButton(topic: ZEUVEHelpTopics.multimediaAudioTiming)
                }
            }
        }
    }

    private func signalAnalysisLine(_ result: AudioSignalAnalysisResult) -> String {
        let silenceText: String
        if result.silenceSegmentCount == 0 {
            silenceText = "Sin silencios detectados"
        } else {
            silenceText = String(
                format: "%d silencios · %.1f s",
                result.silenceSegmentCount,
                result.totalSilenceDuration
            )
        }
        let clippingText = result.clippingEventCount == 0
            ? "Sin posible clipping"
            : "\(result.clippingEventCount) posibles clippings"
        return "\(silenceText) · \(clippingText)"
    }

    private func loudnessLine(_ result: AudioLoudnessResult) -> String {
        [
            result.integratedLUFS.map { String(format: "%.1f LUFS", $0) },
            result.loudnessRangeLU.map { String(format: "LRA %.1f LU", $0) },
            result.truePeakDBTP.map { String(format: "TP %.1f dBTP", $0) },
            result.samplePeakDBFS.map { String(format: "Peak %.1f dBFS", $0) },
        ].compactMap { $0 }.joined(separator: " · ")
    }

    private func previewButton(_ track: MediaEditableTrack) -> some View {
        let sourceID = model.previewSourceID(for: track)
        let playbackState = model.previewPlaybackState(for: sourceID)
        let isLoading = playbackState == .loading
        let isPlaying = playbackState == .playing
        return Button { model.previewTrack(track) } label: {
            if isLoading {
                Label("Cargando…", systemImage: "hourglass")
            } else {
                Label(isPlaying ? "Pausar" : "Escuchar", systemImage: isPlaying ? "pause.fill" : "play.fill")
            }
        }
        .buttonStyle(.bordered)
        .disabled(isLoading)
        .accessibilityHint("Previsualiza esta pista localmente sin modificar el archivo.")
    }

    private func technicalTrackDetail(_ track: MediaEditableTrack) -> String? {
        guard case .original(let streamIndex) = track.source,
              let stream = inspection.streams.first(where: { $0.index == streamIndex }) else {
            if case .external = track.source { return "Archivo externo" }
            return nil
        }
        if track.kind == .video {
            return [
                stream.width.flatMap { width in stream.height.map { "\(width)×\($0)" } },
                stream.frameRate.map { String(format: "%.3f FPS", $0) }
            ].compactMap { $0 }.joined(separator: " · ")
        }
        if track.kind == .audio {
            let channelNames: String? = stream.channels.flatMap { count in
                let resolved = AudioChannelLayoutResolver.channels(layout: stream.channel_layout, count: count)
                guard resolved.contains(where: { !$0.shortName.hasPrefix("C") }) else { return nil }
                return resolved.map(\.shortName).joined(separator: "/")
            }
            return [
                stream.channel_layout, channelNames,
                stream.sampleRateValue.map { String(format: "%.1f kHz", $0 / 1000) },
                stream.bits_per_raw_sample.flatMap { $0.uppercased() == "N/A" ? nil : "\($0) bit" },
            ].compactMap { $0 }.joined(separator: " · ")
        }
        return stream.subtitleRepresentation.map { $0 == .text ? "Texto" : "Bitmap" }
    }

    private func binding(_ track: MediaEditableTrack, _ keyPath: WritableKeyPath<MediaEditableTrack, String>) -> Binding<String> {
        Binding(
            get: {
                let all: [MediaEditableTrack]
                switch track.kind { case .video: all = model.videoTracks; case .audio: all = model.audioTracks; case .subtitle: all = model.subtitleTracks }
                return all.first(where: { $0.id == track.id })?[keyPath: keyPath] ?? ""
            },
            set: { value in
                var copy = track; copy[keyPath: keyPath] = value; model.updateTrack(copy)
            }
        )
    }

    private func move(_ track: MediaEditableTrack, from: Int, to: Int) {
        let count: Int
        switch track.kind { case .video: count = model.videoTracks.count; case .audio: count = model.audioTracks.count; case .subtitle: count = model.subtitleTracks.count }
        model.moveTrack(kind: track.kind, from: IndexSet(integer: from), to: max(0, min(to, count)))
    }
}

private struct TrackReorderModifier: ViewModifier {
    let enabled: Bool
    let track: MediaEditableTrack
    let reorder: (UUID) -> Void

    @ViewBuilder
    func body(content: Content) -> some View {
        if enabled {
            content
                .draggable(track.id.uuidString)
                .dropDestination(for: String.self) { values, _ in
                    guard let raw = values.first, let id = UUID(uuidString: raw), id != track.id else { return false }
                    reorder(id); return true
                }
        } else { content }
    }
}
