import SwiftUI
import ZEUVEEngines
import MultimediaInspectorModule

struct MultimediaSummaryView: View {
    @ObservedObject var model: MultimediaInspectorViewModel
    let inspection: MediaInspectionResult

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    HelpLabel("Resumen técnico", topic: ZEUVEHelpTopics.multimediaSummaryTab)
                        .font(.title3.weight(.semibold))
                    Spacer()
                    Button("Copiar resumen") { MultimediaClipboard.copy(MediaInspectionTextFormatter().summary(inspection)) }
                    Button("Exportar informe") {
                        model.exportTechnicalReport(model.defaultPreferences.defaultReportFormat)
                    }
                    Menu {
                        ForEach(MultimediaTechnicalReportFormat.allCases) { format in
                            Button(format.displayName) { model.exportTechnicalReport(format) }
                        }
                    } label: {
                        Image(systemName: "chevron.down.circle")
                    }
                    .help("Elegir otro formato de informe")
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: 14)], alignment: .leading, spacing: 14) {
                    if !inspection.videoStreams.isEmpty { videoCard }
                    fileCard
                    audioCard
                    subtitleCard
                    if let loudness = model.selectedAudioLoudness { loudnessCard(loudness) }
                    if let timing = model.audioTimingAnalysis, timing.availableOffsetCount > 0 { timingCard(timing) }
                }

                if hasAdditionalStructure {
                    GroupBox("Estructura adicional · solo lectura") {
                        MultimediaTechnicalStructureView(model: model, inspection: inspection, timing: model.audioTimingAnalysis)
                            .padding(.top, 5)
                    }
                }

                DisclosureGroup(isExpanded: $model.isTechnicalDetailExpanded) {
                    VStack(alignment: .leading, spacing: 14) {
                        technicalFormat
                        ForEach(inspection.streams, id: \.id) { stream in technicalStream(stream) }
                    }
                    .padding(.top, 10)
                } label: {
                    HelpLabel("Detalle técnico", topic: ZEUVEHelpTopics.multimediaTechnicalDetail)
                }
                .padding(16)
                .background(.background.secondary, in: RoundedRectangle(cornerRadius: 12))
            }
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var videoCard: some View {
        summaryCard("VÍDEO", systemImage: "film") {
            ForEach(Array(inspection.videoStreams.enumerated()), id: \.element.id) { offset, stream in
                VStack(alignment: .leading, spacing: 3) {
                    Text(inspection.videoStreams.count > 1 ? "Stream \(stream.index ?? offset)" : (stream.codec_long_name ?? stream.codec_name?.uppercased() ?? "Códec desconocido"))
                        .font(.headline)
                    if inspection.videoStreams.count > 1 { Text(stream.codec_long_name ?? stream.codec_name?.uppercased() ?? "Códec desconocido") }
                    Text(videoDetails(stream)).foregroundStyle(.secondary)
                }
                if offset < inspection.videoStreams.count - 1 { Divider() }
            }
        }
    }

    private var fileCard: some View {
        summaryCard("ARCHIVO", systemImage: "doc") {
            Text(inspection.format?.format_long_name ?? inspection.format?.format_name?.uppercased() ?? "Formato desconocido").font(.headline)
            if let duration = inspection.durationSeconds { Text(formatDuration(duration)) }
            if let size = inspection.format?.sizeBytes { Text(ByteCountFormatter.string(fromByteCount: size, countStyle: .file)) }
            if inspection.isPartial {
                HStack(spacing: 5) {
                    Label("Análisis parcial", systemImage: "exclamationmark.triangle").foregroundStyle(.orange)
                    ContextualHelpButton(topic: ZEUVEHelpTopics.multimediaPartialInspection)
                }
            }
        }
    }

    private var audioCard: some View {
        summaryCard("AUDIO · \(inspection.audioStreams.count)", systemImage: "speaker.wave.2") {
            if inspection.audioStreams.isEmpty { Text("Sin audio").foregroundStyle(.secondary) }
            ForEach(inspection.audioStreams, id: \.id) { stream in
                VStack(alignment: .leading, spacing: 2) {
                    Text(stream.language ?? "Idioma sin indicar").font(.headline)
                    Text(audioLine(stream)).foregroundStyle(.secondary)
                }
            }
        }
    }

    private var subtitleCard: some View {
        summaryCard("SUBTÍTULOS · \(inspection.subtitleStreams.count)", systemImage: "captions.bubble") {
            if inspection.subtitleStreams.isEmpty { Text("Sin subtítulos").foregroundStyle(.secondary) }
            ForEach(inspection.subtitleStreams.prefix(5), id: \.id) { stream in
                Text([stream.language ?? "Idioma sin indicar", stream.codec_name?.uppercased(), stream.subtitleRepresentation.map { $0 == .text ? "Texto" : "Bitmap" }, stream.isForced ? "Forced" : nil].compactMap { $0 }.joined(separator: " · "))
            }
            if inspection.subtitleStreams.count > 5 { Text("+ \(inspection.subtitleStreams.count - 5) pistas más").foregroundStyle(.secondary) }
        }
    }


    private func loudnessCard(_ result: AudioLoudnessResult) -> some View {
        summaryCard("SONORIDAD", systemImage: "waveform.badge.magnifyingglass") {
            if let value = result.integratedLUFS {
                HStack(spacing: 5) {
                    Text(String(format: "%.1f LUFS", value)).font(.headline)
                    ContextualHelpButton(topic: ZEUVEHelpTopics.multimediaIntegratedLUFS)
                }
            }
            if let lra = result.loudnessRangeLU {
                HStack(spacing: 5) { Text(String(format: "LRA %.1f LU", lra)); ContextualHelpButton(topic: ZEUVEHelpTopics.multimediaLRA) }
                    .foregroundStyle(.secondary)
            }
            if let peak = result.truePeakDBTP {
                HStack(spacing: 5) { Text(String(format: "True Peak %.1f dBTP", peak)); ContextualHelpButton(topic: ZEUVEHelpTopics.multimediaTruePeak) }
                    .foregroundStyle(.secondary)
            }
            if let peak = result.samplePeakDBFS {
                HStack(spacing: 5) { Text(String(format: "Sample Peak %.1f dBFS", peak)); ContextualHelpButton(topic: ZEUVEHelpTopics.multimediaSamplePeak) }
                    .foregroundStyle(.secondary)
            }
            if let timeline = result.timeline {
                HStack(spacing: 5) {
                    Text([
                        timeline.shortTermMinimumLUFS.map { String(format: "S mín %.1f", $0) },
                        timeline.shortTermMaximumLUFS.map { String(format: "S máx %.1f", $0) },
                        timeline.shortTermAverageLUFS.map { String(format: "S media %.1f LUFS", $0) },
                    ].compactMap { $0 }.joined(separator: " · "))
                    ContextualHelpButton(topic: ZEUVEHelpTopics.multimediaShortTermStats)
                }
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
            }
        }
    }

    private func timingCard(_ timing: AudioTimingAnalysis) -> some View {
        summaryCard("SINCRONIZACIÓN", systemImage: "clock.arrow.2.circlepath") {
            HStack(spacing: 5) {
                Text("Referencia: \(timing.referenceLabel)").font(.headline)
                ContextualHelpButton(topic: ZEUVEHelpTopics.multimediaAudioTiming)
            }
            Text("\(timing.availableOffsetCount) pistas con offset calculable")
                .foregroundStyle(.secondary)
            if let largest = timing.entries.compactMap(\.offsetFromReference).max(by: { abs($0) < abs($1) }) {
                Text(String(format: "Mayor diferencia declarada: %+.3f s", largest)).foregroundStyle(.secondary)
            }
        }
    }

    private func summaryCard<Content: View>(_ title: String, systemImage: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: systemImage).font(.caption.weight(.bold)).foregroundStyle(.secondary)
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 12))
    }

    private var technicalFormat: some View {
        let format = inspection.format
        return VStack(alignment: .leading, spacing: 4) {
            HStack { Text("Contenedor").font(.headline); Spacer(); Button("Copiar") { MultimediaClipboard.copy(MediaInspectionTextFormatter().summary(inspection)) }.buttonStyle(.link) }
            technicalLine("Formato", format?.format_long_name ?? format?.format_name)
            technicalLine("Inicio", format?.start_time)
            technicalLine("Bitrate", format?.bitRateValue.map { "\($0) bit/s" })
            technicalLine("Streams", format?.nb_streams.map(String.init))
            technicalLine("Programas", format?.nb_programs.map(String.init))
        }
    }

    private func technicalStream(_ stream: MediaInspectionStream) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Stream \(stream.index ?? -1) · \(stream.codec_type ?? "desconocido")").font(.headline)
                Spacer()
                Button("Copiar stream") { MultimediaClipboard.copy(MediaInspectionTextFormatter().stream(stream)) }.buttonStyle(.link)
            }
            technicalLine("Códec", [stream.codec_long_name, stream.codec_name].compactMap { $0 }.joined(separator: " · "))
            technicalLine("Perfil", stream.profile)
            technicalLine("Nivel", stream.level.map(String.init))
            technicalLine("Resolución", stream.width.flatMap { w in stream.height.map { "\(w) × \($0)" } })
            technicalLine("Resolución codificada", stream.coded_width.flatMap { w in stream.coded_height.map { "\(w) × \($0)" } })
            technicalLine("SAR / DAR", [stream.sample_aspect_ratio, stream.display_aspect_ratio].compactMap { $0 }.joined(separator: " / "))
            technicalLine("Pixel format", stream.pix_fmt)
            technicalLine("Bits raw", stream.bits_per_raw_sample)
            technicalLine("Sample format", stream.sample_fmt)
            technicalLine("Sample rate", stream.sample_rate)
            technicalLine("Canales", stream.channels.map(String.init))
            technicalLine("Layout", stream.channel_layout)
            if let count = stream.channels {
                let channels = AudioChannelLayoutResolver.channels(layout: stream.channel_layout, count: count)
                if channels.contains(where: { !$0.shortName.hasPrefix("C") }) { technicalLine("Posiciones", channels.map(\.shortName).joined(separator: " · ")) }
            }
            technicalLine("Bitrate", stream.bit_rate)
            technicalLine("FPS", stream.avg_frame_rate)
            technicalLine("Time base", stream.time_base)
            technicalLine("Duración", stream.duration)
            technicalLine("Frames declarados", stream.nb_frames)
            technicalLine("Tipo de subtítulo", stream.subtitleRepresentation.map { $0 == .text ? "Texto" : "Bitmap" })
            technicalLine("Field order", stream.field_order)
            technicalLine("Color", [stream.color_range, stream.color_space, stream.color_transfer, stream.color_primaries].compactMap { $0 }.joined(separator: " · "))
            technicalLine("HDR", stream.inferredHDRDescription)
            technicalLine("Rotación", stream.rotationDegrees.map { "\($0)°" })
            technicalLine("Side data", stream.side_data_list?.compactMap(\.side_data_type).joined(separator: " · "))
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder private func technicalLine(_ key: String, _ value: String?) -> some View {
        if let value, !value.isEmpty, value.uppercased() != "N/A" {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(key).foregroundStyle(.secondary).frame(width: 150, alignment: .leading)
                Text(value).textSelection(.enabled)
                Spacer()
                Button { MultimediaClipboard.copy(value) } label: { Image(systemName: "doc.on.doc") }
                    .buttonStyle(.borderless).accessibilityLabel("Copiar \(key)")
            }.font(.caption)
        }
    }

    private var hasAdditionalStructure: Bool {
        !inspection.attachmentStreams.isEmpty || !inspection.dataStreams.isEmpty || !inspection.unknownStreams.isEmpty || !(inspection.chapters ?? []).isEmpty || !(inspection.programs ?? []).isEmpty || inspection.streams.contains(where: { $0.codec_type == "video" && $0.isAttachedPicture }) || (model.audioTimingAnalysis?.entries.isEmpty == false)
    }

    private func videoDetails(_ stream: MediaInspectionStream) -> String {
        [
            stream.width.flatMap { width in stream.height.map { "\(width)×\($0)" } },
            stream.frameRate.map { String(format: "%.3f FPS", $0) },
            stream.bits_per_raw_sample.flatMap { $0.uppercased() == "N/A" ? nil : "\($0) bit" },
            stream.inferredHDRDescription,
        ].compactMap { $0 }.joined(separator: " · ")
    }

    private func audioLine(_ stream: MediaInspectionStream) -> String {
        [stream.codec_name?.uppercased(), stream.channel_layout, stream.sampleRateValue.map { String(format: "%.1f kHz", $0 / 1000) }, stream.isDefault ? "Default" : nil].compactMap { $0 }.joined(separator: " · ")
    }

    private func formatDuration(_ value: Double) -> String {
        let total = max(Int(value.rounded()), 0)
        return String(format: "%d h %02d min %02d s", total / 3600, (total % 3600) / 60, total % 60)
    }
}
