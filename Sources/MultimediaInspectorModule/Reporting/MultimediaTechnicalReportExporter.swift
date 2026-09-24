import Foundation
import ZEUVEEngines

public enum MultimediaTechnicalReportFormat: String, Codable, CaseIterable, Sendable, Identifiable {
    case text = "txt"
    case markdown = "md"
    case json = "json"

    public var id: String { rawValue }
    public var displayName: String {
        switch self { case .text: return "Texto"; case .markdown: return "Markdown"; case .json: return "JSON" }
    }
}

public struct AudioLoudnessReportItem: Sendable {
    public let label: String
    public let result: AudioLoudnessResult

    public init(label: String, result: AudioLoudnessResult) {
        self.label = label
        self.result = result
    }
}

public struct AudioSignalReportItem: Sendable {
    public let label: String
    public let result: AudioSignalAnalysisResult

    public init(label: String, result: AudioSignalAnalysisResult) {
        self.label = label
        self.result = result
    }
}

public struct AudioAdvancedReportItem: Sendable {
    public let label: String
    public let result: AudioSourceQualityAnalysis

    public init(label: String, result: AudioSourceQualityAnalysis) {
        self.label = label
        self.result = result
    }
}

public struct BitmapSubtitleOCRReportSummary: Sendable, Codable, Equatable {
    public let streamIndex: Int
    public let codec: String
    public let language: String?
    public let eventCount: Int
    public let needsReviewCount: Int

    public init(streamIndex: Int, codec: String, language: String?, eventCount: Int, needsReviewCount: Int) {
        self.streamIndex = streamIndex
        self.codec = codec
        self.language = language
        self.eventCount = max(0, eventCount)
        self.needsReviewCount = max(0, needsReviewCount)
    }
}

public struct MultimediaStructuralEditReportSummary: Sendable, Codable, Equatable {
    public let targetContainer: String
    public let videoStreams: Int
    public let audioStreams: Int
    public let subtitleStreams: Int
    public let artworks: Int
    public let warnings: Int

    public init(targetContainer: String, videoStreams: Int, audioStreams: Int, subtitleStreams: Int, artworks: Int, warnings: Int) {
        self.targetContainer = targetContainer
        self.videoStreams = max(0, videoStreams)
        self.audioStreams = max(0, audioStreams)
        self.subtitleStreams = max(0, subtitleStreams)
        self.artworks = max(0, artworks)
        self.warnings = max(0, warnings)
    }
}

public struct MultimediaTechnicalReportContext: Sendable {
    public let fileName: String
    public let inspection: MediaInspectionResult
    public let timing: AudioTimingAnalysis
    public let loudness: [AudioLoudnessReportItem]
    public let signal: [AudioSignalReportItem]
    public let advancedAudio: [AudioAdvancedReportItem]
    public let ocrSummaries: [BitmapSubtitleOCRReportSummary]
    public let structuralEdit: MultimediaStructuralEditReportSummary?

    public init(
        fileName: String,
        inspection: MediaInspectionResult,
        timing: AudioTimingAnalysis,
        loudness: [AudioLoudnessReportItem],
        signal: [AudioSignalReportItem] = [],
        advancedAudio: [AudioAdvancedReportItem] = [],
        ocrSummaries: [BitmapSubtitleOCRReportSummary] = [],
        structuralEdit: MultimediaStructuralEditReportSummary? = nil
    ) {
        self.fileName = fileName
        self.inspection = inspection
        self.timing = timing
        self.loudness = loudness
        self.signal = signal
        self.advancedAudio = advancedAudio
        self.ocrSummaries = ocrSummaries
        self.structuralEdit = structuralEdit
    }
}

public struct MultimediaTechnicalReportExporter: Sendable {
    private let publisher: MultimediaOutputPublisher

    public init(publisher: MultimediaOutputPublisher = .init()) { self.publisher = publisher }

    public func export(
        context: MultimediaTechnicalReportContext,
        format: MultimediaTechnicalReportFormat,
        proposedOutput: URL,
        protectedOriginals: [URL],
        sections: MultimediaTechnicalReportSections = .all
    ) throws -> URL {
        let data = try data(context: context, format: format, sections: sections)
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("zeuve-report-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let temporary = root.appendingPathComponent("report.\(format.rawValue)")
        try data.write(to: temporary, options: [.atomic])
        return try publisher.publish(temporary: temporary, proposed: proposedOutput, protectedOriginals: protectedOriginals)
    }

    public func data(
        context: MultimediaTechnicalReportContext,
        format: MultimediaTechnicalReportFormat,
        sections: MultimediaTechnicalReportSections = .all
    ) throws -> Data {
        let payload = ReportPayload(context: context, sections: sections)
        switch format {
        case .json:
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
            return try encoder.encode(payload)
        case .text:
            return Data(payload.text(markdown: false).utf8)
        case .markdown:
            return Data(payload.text(markdown: true).utf8)
        }
    }
}

private struct ReportPayload: Codable {
    struct Stream: Codable {
        let index: Int?
        let type: String?
        let codec: String?
        let codecLongName: String?
        let profile: String?
        let width: Int?
        let height: Int?
        let frameRate: Double?
        let pixelFormat: String?
        let sampleRate: Double?
        let channels: Int?
        let channelLayout: String?
        let language: String?
        let title: String?
        let startTime: String?
        let duration: String?
        let bitRate: String?
        let tags: [String: String]?
    }

    struct Chapter: Codable {
        let index: Int
        let startTime: String?
        let endTime: String?
        let title: String?
    }

    struct LoudnessTimelineSample: Codable {
        let time: TimeInterval
        let momentaryLUFS: Double?
        let shortTermLUFS: Double?
        let integratedLUFS: Double?
        let momentaryMinimumLUFS: Double?
        let momentaryMaximumLUFS: Double?
        let shortTermMinimumLUFS: Double?
        let shortTermMaximumLUFS: Double?
        let sampleCount: Int
    }

    struct LoudnessTimeline: Codable {
        let durationAnalyzed: TimeInterval?
        let shortTermMinimumLUFS: Double?
        let shortTermMaximumLUFS: Double?
        let shortTermAverageLUFS: Double?
        let samples: [LoudnessTimelineSample]
    }

    struct Loudness: Codable {
        let label: String
        let integratedLUFS: Double?
        let loudnessRangeLU: Double?
        let truePeakDBTP: Double?
        let samplePeakDBFS: Double?
        let durationAnalyzed: TimeInterval?
        let timeline: LoudnessTimeline?
    }

    struct SilenceSegment: Codable {
        let startTime: TimeInterval
        let endTime: TimeInterval
        let duration: TimeInterval
    }

    struct ClippingEvent: Codable {
        let startTime: TimeInterval
        let endTime: TimeInterval
        let channelIndex: Int
        let peakDBFS: Double
        let sampleCount: Int
    }

    struct Signal: Codable {
        let label: String
        let durationAnalyzed: TimeInterval
        let silenceSegmentCount: Int
        let totalSilenceDuration: TimeInterval
        let clippingEventCount: Int
        let omittedSilenceSegments: Int
        let omittedClippingEvents: Int
        let silenceSegments: [SilenceSegment]
        let clippingEvents: [ClippingEvent]
    }

    struct VideoDetail: Codable {
        let index: Int?
        let codec: String?
        let profile: String?
        let width: Int?
        let height: Int?
        let frameRate: Double?
        let pixelFormat: String?
        let bitRate: Int64?
        let rotationDegrees: Int?
        let hdrDescription: String?
        let colorRange: String?
        let colorSpace: String?
        let colorTransfer: String?
        let colorPrimaries: String?
        let isDefault: Bool
    }

    struct Artwork: Codable {
        let streamIndex: Int?
        let codec: String?
        let title: String?
    }

    struct Evidence: Codable {
        let title: String
        let detail: String
        let weight: Double
    }

    struct Anomaly: Codable {
        let start: TimeInterval
        let end: TimeInterval
        let severity: Double
        let title: String
        let detail: String
    }

    struct AdvancedAudio: Codable {
        let label: String
        let indication: String
        let confidence: Double
        let analyzedDuration: TimeInterval
        let activeWindowCount: Int
        let discardedWindowCount: Int
        let spectralRolloffHz: Double?
        let effectiveBandwidthHz: Double?
        let persistentCutoffCandidateHz: Double?
        let highBandEnergyRatio: Double?
        let totalAnomalyCount: Int
        let anomaliesWereTruncated: Bool
        let evidence: [Evidence]
        let anomalies: [Anomaly]
    }

    let schemaVersion: Int
    let fileName: String
    let container: String?
    let durationSeconds: Double?
    let sizeBytes: Int64?
    let bitRate: Int64?
    let formatTags: [String: String]?
    let streams: [Stream]
    let chapters: [Chapter]
    let timing: AudioTimingAnalysis
    let loudness: [Loudness]
    let signal: [Signal]
    let videoDetails: [VideoDetail]
    let artworks: [Artwork]
    let advancedAudio: [AdvancedAudio]
    let ocrSummaries: [BitmapSubtitleOCRReportSummary]
    let structuralEdit: MultimediaStructuralEditReportSummary?

    init(context: MultimediaTechnicalReportContext, sections: MultimediaTechnicalReportSections) {
        schemaVersion = 3
        fileName = context.fileName
        container = context.inspection.format?.format_long_name ?? context.inspection.format?.format_name
        durationSeconds = context.inspection.durationSeconds
        sizeBytes = context.inspection.format?.sizeBytes
        bitRate = context.inspection.format?.bitRateValue
        formatTags = sections.includeGlobalMetadata ? context.inspection.format?.tags : nil
        streams = sections.includeStreams ? context.inspection.streams.map { stream in
            Stream(
                index: stream.index, type: stream.codec_type, codec: stream.codec_name, codecLongName: stream.codec_long_name,
                profile: stream.profile, width: stream.width, height: stream.height, frameRate: stream.frameRate,
                pixelFormat: stream.pix_fmt, sampleRate: stream.sampleRateValue, channels: stream.channels,
                channelLayout: stream.channel_layout, language: stream.language, title: stream.title,
                startTime: stream.start_time, duration: stream.duration, bitRate: stream.bit_rate, tags: stream.tags
            )
        } : []
        chapters = sections.includeChapters ? (context.inspection.chapters ?? []).enumerated().map { offset, chapter in
            Chapter(index: offset + 1, startTime: chapter.start_time, endTime: chapter.end_time, title: chapter.tags?["title"])
        } : []
        timing = sections.includeTiming ? context.timing : AudioTimingAnalysis(referenceLabel: "", referenceStartTime: nil, referenceDuration: nil, entries: [])
        loudness = sections.includeLoudness ? context.loudness.map { item in
            let value = item.result
            let timeline = value.timeline.map { timeline in
                LoudnessTimeline(
                    durationAnalyzed: timeline.durationAnalyzed,
                    shortTermMinimumLUFS: timeline.shortTermMinimumLUFS,
                    shortTermMaximumLUFS: timeline.shortTermMaximumLUFS,
                    shortTermAverageLUFS: timeline.shortTermAverageLUFS,
                    samples: timeline.samples.map { sample in
                        LoudnessTimelineSample(
                            time: sample.time,
                            momentaryLUFS: sample.momentaryLUFS,
                            shortTermLUFS: sample.shortTermLUFS,
                            integratedLUFS: sample.integratedLUFS,
                            momentaryMinimumLUFS: sample.momentaryMinimumLUFS,
                            momentaryMaximumLUFS: sample.momentaryMaximumLUFS,
                            shortTermMinimumLUFS: sample.shortTermMinimumLUFS,
                            shortTermMaximumLUFS: sample.shortTermMaximumLUFS,
                            sampleCount: sample.sampleCount
                        )
                    }
                )
            }
            return Loudness(
                label: item.label,
                integratedLUFS: value.integratedLUFS,
                loudnessRangeLU: value.loudnessRangeLU,
                truePeakDBTP: value.truePeakDBTP,
                samplePeakDBFS: value.samplePeakDBFS,
                durationAnalyzed: value.durationAnalyzed,
                timeline: timeline
            )
        } : []
        signal = sections.includeSignalAnalysis ? context.signal.map { item in
            let value = item.result
            return Signal(
                label: item.label,
                durationAnalyzed: value.durationAnalyzed,
                silenceSegmentCount: value.silenceSegmentCount,
                totalSilenceDuration: value.totalSilenceDuration,
                clippingEventCount: value.clippingEventCount,
                omittedSilenceSegments: value.omittedSilenceSegments,
                omittedClippingEvents: value.omittedClippingEvents,
                silenceSegments: value.silenceSegments.map {
                    SilenceSegment(startTime: $0.startTime, endTime: $0.endTime, duration: $0.duration)
                },
                clippingEvents: value.clippingEvents.map {
                    ClippingEvent(startTime: $0.startTime, endTime: $0.endTime, channelIndex: $0.channelIndex, peakDBFS: $0.peakDBFS, sampleCount: $0.sampleCount)
                }
            )
        } : []
        videoDetails = sections.includeVideoDetails ? context.inspection.videoStreams.map { stream in
            VideoDetail(
                index: stream.index, codec: stream.codec_name, profile: stream.profile,
                width: stream.width, height: stream.height, frameRate: stream.frameRate,
                pixelFormat: stream.pix_fmt, bitRate: stream.bitRateValue,
                rotationDegrees: stream.rotationDegrees, hdrDescription: stream.inferredHDRDescription,
                colorRange: stream.color_range, colorSpace: stream.color_space,
                colorTransfer: stream.color_transfer, colorPrimaries: stream.color_primaries,
                isDefault: stream.isDefault
            )
        } : []
        artworks = sections.includeArtwork ? context.inspection.streams.filter { $0.isAttachedPicture }.map { stream in
            Artwork(streamIndex: stream.index, codec: stream.codec_name, title: stream.title)
        } : []
        advancedAudio = sections.includeAdvancedAudioAnalysis ? context.advancedAudio.map { item in
            AdvancedAudio(
                label: item.label,
                indication: item.result.indication.displayName,
                confidence: item.result.confidence,
                analyzedDuration: item.result.analyzedDuration,
                activeWindowCount: item.result.activeWindowCount,
                discardedWindowCount: item.result.discardedWindowCount,
                spectralRolloffHz: item.result.spectralRolloffHz,
                effectiveBandwidthHz: item.result.effectiveBandwidthHz,
                persistentCutoffCandidateHz: item.result.persistentCutoffCandidateHz,
                highBandEnergyRatio: item.result.highBandEnergyRatio,
                totalAnomalyCount: item.result.totalAnomalyCount,
                anomaliesWereTruncated: item.result.anomaliesWereTruncated,
                evidence: item.result.evidence.map { Evidence(title: $0.title, detail: $0.detail, weight: $0.weight) },
                anomalies: item.result.anomalies.map { Anomaly(start: $0.start, end: $0.end, severity: $0.severity, title: $0.title, detail: $0.detail) }
            )
        } : []
        ocrSummaries = sections.includeOCRSummary ? context.ocrSummaries : []
        structuralEdit = sections.includeStructuralEditSummary ? context.structuralEdit : nil
    }

    func text(markdown: Bool) -> String {
        let heading = markdown ? "# Informe técnico multimedia" : "INFORME TÉCNICO MULTIMEDIA"
        var lines = [heading, "", "Archivo: \(fileName)"]
        if let container { lines.append("Contenedor: \(container)") }
        if let durationSeconds { lines.append(String(format: "Duración: %.3f s", durationSeconds)) }
        if let sizeBytes { lines.append("Tamaño: \(sizeBytes) bytes") }
        if let bitRate { lines.append("Bitrate: \(bitRate) bit/s") }
        if let formatTags, !formatTags.isEmpty {
            lines += ["", markdown ? "## Metadatos globales" : "METADATOS GLOBALES"]
            for key in formatTags.keys.sorted() { lines.append("\(key): \(formatTags[key] ?? "")") }
        }
        lines += ["", markdown ? "## Streams" : "STREAMS"]
        for stream in streams {
            lines.append("")
            lines.append("Stream \(stream.index ?? -1) · \(stream.type ?? "desconocido") · \(stream.codec?.uppercased() ?? "sin códec")")
            if let profile = stream.profile { lines.append("Perfil: \(profile)") }
            if let width = stream.width, let height = stream.height { lines.append("Resolución: \(width)×\(height)") }
            if let frameRate = stream.frameRate { lines.append(String(format: "FPS: %.3f", frameRate)) }
            if let sampleRate = stream.sampleRate { lines.append(String(format: "Sample rate: %.0f Hz", sampleRate)) }
            if let channels = stream.channels { lines.append("Canales: \(channels)") }
            if let channelLayout = stream.channelLayout { lines.append("Layout: \(channelLayout)") }
            if let language = stream.language { lines.append("Idioma: \(language)") }
            if let title = stream.title { lines.append("Título: \(title)") }
            if let startTime = stream.startTime { lines.append("Inicio: \(startTime)") }
            if let duration = stream.duration { lines.append("Duración: \(duration)") }
            if let tags = stream.tags, !tags.isEmpty {
                for key in tags.keys.sorted() { lines.append("Tag \(key): \(tags[key] ?? "")") }
            }
        }
        if !chapters.isEmpty {
            lines += ["", markdown ? "## Capítulos" : "CAPÍTULOS"]
            for chapter in chapters {
                lines.append("\(chapter.index). \(chapter.title ?? "Capítulo") · \(chapter.startTime ?? "?") → \(chapter.endTime ?? "?")")
            }
        }
        if !timing.entries.isEmpty {
            lines += ["", markdown ? "## Sincronización" : "SINCRONIZACIÓN"]
            lines.append("Referencia: \(timing.referenceLabel)")
            for entry in timing.entries {
                let offset = entry.offsetFromReference.map { String(format: "%+.3f s", $0) } ?? "no disponible"
                let difference = entry.durationDifference.map { String(format: "%+.3f s", $0) } ?? "no disponible"
                lines.append("Stream \(entry.streamIndex) · \(entry.label) · offset \(offset) · diferencia de duración \(difference)")
            }
        }
        if !loudness.isEmpty {
            lines += ["", markdown ? "## Sonoridad calculada" : "SONORIDAD CALCULADA"]
            for value in loudness {
                let integrated = value.integratedLUFS.map { String(format: "%.1f LUFS", $0) } ?? "n/d"
                let lra = value.loudnessRangeLU.map { String(format: "%.1f LU", $0) } ?? "n/d"
                let truePeak = value.truePeakDBTP.map { String(format: "%.1f dBTP", $0) } ?? "n/d"
                let samplePeak = value.samplePeakDBFS.map { String(format: "%.1f dBFS", $0) } ?? "n/d"
                lines.append("\(value.label): I \(integrated) · LRA \(lra) · True Peak \(truePeak) · Sample Peak \(samplePeak)")
                if let timeline = value.timeline {
                    let minimum = timeline.shortTermMinimumLUFS.map { String(format: "%.1f", $0) } ?? "n/d"
                    let maximum = timeline.shortTermMaximumLUFS.map { String(format: "%.1f", $0) } ?? "n/d"
                    let average = timeline.shortTermAverageLUFS.map { String(format: "%.1f", $0) } ?? "n/d"
                    lines.append("  Evolución short-term: mín \(minimum) LUFS · máx \(maximum) LUFS · media \(average) LUFS · \(timeline.samples.count) muestras retenidas")
                }
            }
        }
        if !signal.isEmpty {
            lines += ["", markdown ? "## Análisis de señal" : "ANÁLISIS DE SEÑAL"]
            for value in signal {
                lines.append("\(value.label): \(value.silenceSegmentCount) silencios · \(String(format: "%.3f", value.totalSilenceDuration)) s totales · \(value.clippingEventCount) posibles clippings")
                for segment in value.silenceSegments.prefix(20) {
                    lines.append(String(format: "  Silencio %.3f → %.3f s (%.3f s)", segment.startTime, segment.endTime, segment.duration))
                }
                if value.silenceSegmentCount > min(value.silenceSegments.count, 20) { lines.append("  … más silencios disponibles en JSON") }
                for event in value.clippingEvents.prefix(20) {
                    lines.append(String(format: "  Posible clipping %.3f → %.3f s · canal %d · pico %.2f dBFS", event.startTime, event.endTime, event.channelIndex + 1, event.peakDBFS))
                }
                if value.clippingEventCount > min(value.clippingEvents.count, 20) { lines.append("  … más eventos disponibles en JSON") }
            }
        }
        if !videoDetails.isEmpty {
            lines += ["", markdown ? "## Vídeo" : "VÍDEO"]
            for video in videoDetails {
                var description = "Stream \(video.index ?? -1) · \(video.codec?.uppercased() ?? "sin códec")"
                if let width = video.width, let height = video.height { description += " · \(width)×\(height)" }
                if let fps = video.frameRate { description += String(format: " · %.3f FPS", fps) }
                if let hdr = video.hdrDescription { description += " · \(hdr)" }
                lines.append(description)
            }
        }
        if !artworks.isEmpty {
            lines += ["", markdown ? "## Carátulas" : "CARÁTULAS"]
            for artwork in artworks { lines.append("Stream \(artwork.streamIndex ?? -1) · \(artwork.codec?.uppercased() ?? "sin códec") · \(artwork.title ?? "sin título")") }
        }
        if !advancedAudio.isEmpty {
            lines += ["", markdown ? "## Análisis avanzado de audio" : "ANÁLISIS AVANZADO DE AUDIO"]
            for value in advancedAudio {
                lines.append("\(value.label): \(value.indication) · confianza descriptiva \(Int(value.confidence * 100)) %")
                if let rolloff = value.spectralRolloffHz { lines.append(String(format: "  Rolloff espectral (99,5 %%): %.0f Hz", rolloff)) }
                if let bandwidth = value.effectiveBandwidthHz { lines.append(String(format: "  Banda efectiva aproximada: %.0f Hz", bandwidth)) }
                if let cutoff = value.persistentCutoffCandidateHz { lines.append(String(format: "  Caída persistente candidata: %.0f Hz", cutoff)) }
                lines.append("  Ventanas útiles: \(value.activeWindowCount) · descartadas: \(value.discardedWindowCount)")
                for evidence in value.evidence { lines.append("  • \(evidence.title): \(evidence.detail)") }
                if value.totalAnomalyCount > 0 {
                    lines.append("  Anomalías temporales detectadas: \(value.totalAnomalyCount)" + (value.anomaliesWereTruncated ? " (se conservan \(value.anomalies.count) eventos representativos)" : ""))
                }
            }
        }
        if !ocrSummaries.isEmpty {
            lines += ["", markdown ? "## OCR de subtítulos bitmap" : "OCR DE SUBTÍTULOS BITMAP"]
            for value in ocrSummaries {
                lines.append("Stream \(value.streamIndex) · \(value.codec) · \(value.eventCount) eventos · \(value.needsReviewCount) requieren revisión" + (value.language.map { " · idioma \($0)" } ?? ""))
            }
            lines.append("El informe no incluye el texto reconocido.")
        }
        if let structuralEdit {
            lines += ["", markdown ? "## Borrador de edición estructural" : "BORRADOR DE EDICIÓN ESTRUCTURAL"]
            lines.append("Destino: \(structuralEdit.targetContainer) · vídeo \(structuralEdit.videoStreams) · audio \(structuralEdit.audioStreams) · subtítulos \(structuralEdit.subtitleStreams) · carátulas \(structuralEdit.artworks) · avisos \(structuralEdit.warnings)")
        }
        lines.append("")
        return lines.joined(separator: "\n")
    }
}
