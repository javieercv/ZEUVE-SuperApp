import Foundation

public struct MediaDisposition: Codable, Sendable, Equatable {
    public let `default`: Int?
    public let dub: Int?
    public let original: Int?
    public let comment: Int?
    public let lyrics: Int?
    public let karaoke: Int?
    public let forced: Int?
    public let hearing_impaired: Int?
    public let visual_impaired: Int?
    public let clean_effects: Int?
    public let attached_pic: Int?
    public let timed_thumbnails: Int?
    public let non_diegetic: Int?
    public let captions: Int?
    public let descriptions: Int?
    public let metadata: Int?
    public let dependent: Int?
    public let still_image: Int?

    public init(
        default: Int? = nil,
        dub: Int? = nil,
        original: Int? = nil,
        comment: Int? = nil,
        lyrics: Int? = nil,
        karaoke: Int? = nil,
        forced: Int? = nil,
        hearing_impaired: Int? = nil,
        visual_impaired: Int? = nil,
        clean_effects: Int? = nil,
        attached_pic: Int? = nil,
        timed_thumbnails: Int? = nil,
        non_diegetic: Int? = nil,
        captions: Int? = nil,
        descriptions: Int? = nil,
        metadata: Int? = nil,
        dependent: Int? = nil,
        still_image: Int? = nil
    ) {
        self.default = `default`
        self.dub = dub
        self.original = original
        self.comment = comment
        self.lyrics = lyrics
        self.karaoke = karaoke
        self.forced = forced
        self.hearing_impaired = hearing_impaired
        self.visual_impaired = visual_impaired
        self.clean_effects = clean_effects
        self.attached_pic = attached_pic
        self.timed_thumbnails = timed_thumbnails
        self.non_diegetic = non_diegetic
        self.captions = captions
        self.descriptions = descriptions
        self.metadata = metadata
        self.dependent = dependent
        self.still_image = still_image
    }
}

public struct MediaSideData: Codable, Sendable, Equatable {
    public let side_data_type: String?
    public let displaymatrix: String?
    public let rotation: Int?
    public let red_x: String?
    public let red_y: String?
    public let green_x: String?
    public let green_y: String?
    public let blue_x: String?
    public let blue_y: String?
    public let white_point_x: String?
    public let white_point_y: String?
    public let min_luminance: String?
    public let max_luminance: String?
    public let max_content: Int?
    public let max_average: Int?

    public init(
        side_data_type: String? = nil, displaymatrix: String? = nil, rotation: Int? = nil,
        red_x: String? = nil, red_y: String? = nil, green_x: String? = nil, green_y: String? = nil,
        blue_x: String? = nil, blue_y: String? = nil, white_point_x: String? = nil, white_point_y: String? = nil,
        min_luminance: String? = nil, max_luminance: String? = nil, max_content: Int? = nil, max_average: Int? = nil
    ) {
        self.side_data_type = side_data_type
        self.displaymatrix = displaymatrix
        self.rotation = rotation
        self.red_x = red_x
        self.red_y = red_y
        self.green_x = green_x
        self.green_y = green_y
        self.blue_x = blue_x
        self.blue_y = blue_y
        self.white_point_x = white_point_x
        self.white_point_y = white_point_y
        self.min_luminance = min_luminance
        self.max_luminance = max_luminance
        self.max_content = max_content
        self.max_average = max_average
    }
}

public enum MediaSubtitleRepresentation: String, Codable, Sendable, Equatable {
    case text
    case bitmap
}

public struct MediaInspectionStream: Codable, Sendable, Equatable, Identifiable {
    public let index: Int?
    public let codec_name: String?
    public let codec_long_name: String?
    public let profile: String?
    public let codec_type: String?
    public let codec_tag_string: String?
    public let codec_tag: String?
    public let level: Int?
    public let width: Int?
    public let height: Int?
    public let coded_width: Int?
    public let coded_height: Int?
    public let closed_captions: Int?
    public let film_grain: Int?
    public let has_b_frames: Int?
    public let sample_aspect_ratio: String?
    public let display_aspect_ratio: String?
    public let pix_fmt: String?
    public let bits_per_raw_sample: String?
    public let bits_per_sample: Int?
    public let bit_rate: String?
    public let r_frame_rate: String?
    public let avg_frame_rate: String?
    public let time_base: String?
    public let start_pts: Int64?
    public let start_time: String?
    public let duration_ts: Int64?
    public let duration: String?
    public let nb_frames: String?
    public let field_order: String?
    public let color_range: String?
    public let color_space: String?
    public let color_transfer: String?
    public let color_primaries: String?
    public let chroma_location: String?
    public let refs: Int?
    public let sample_fmt: String?
    public let sample_rate: String?
    public let channels: Int?
    public let channel_layout: String?
    public let initial_padding: Int?
    public let extradata_size: Int?
    public let disposition: MediaDisposition?
    public let tags: [String: String]?
    public let side_data_list: [MediaSideData]?

    public var id: Int { index ?? -1 }
    public var language: String? { tags?.firstValue(caseInsensitiveKey: "language") }
    public var title: String? { tags?.firstValue(caseInsensitiveKey: "title") }
    public var isAttachedPicture: Bool { disposition?.attached_pic == 1 }
    public var isDefault: Bool { disposition?.default == 1 }
    public var isForced: Bool { disposition?.forced == 1 }
    public var sampleRateValue: Double? { Self.finiteDouble(sample_rate) }
    public var bitRateValue: Int64? { Self.positiveInt64(bit_rate) }
    public var durationSeconds: Double? { Self.finiteDouble(duration) }
    public var frameRate: Double? { Self.rationalValue(avg_frame_rate) ?? Self.rationalValue(r_frame_rate) }
    public var rotationDegrees: Int? {
        side_data_list?.compactMap(\.rotation).first ?? tags?.firstValue(caseInsensitiveKey: "rotate").flatMap(Int.init)
    }
    public var inferredHDRDescription: String? {
        let transfer = color_transfer?.lowercased()
        let primaries = color_primaries?.lowercased()
        if transfer == "smpte2084" { return primaries == "bt2020" ? "HDR (PQ · BT.2020)" : "HDR (PQ)" }
        if transfer == "arib-std-b67" { return "HDR (HLG)" }
        return nil
    }
    public var subtitleRepresentation: MediaSubtitleRepresentation? {
        guard codec_type == "subtitle", let codec = codec_name?.lowercased() else { return nil }
        let textCodecs: Set<String> = ["subrip", "srt", "ass", "ssa", "mov_text", "webvtt", "text", "microdvd", "sami", "jacosub", "realtext", "subviewer", "subviewer1"]
        if textCodecs.contains(codec) { return .text }
        let bitmapCodecs: Set<String> = ["hdmv_pgs_subtitle", "dvd_subtitle", "dvb_subtitle", "xsub"]
        if bitmapCodecs.contains(codec) { return .bitmap }
        return nil
    }

    private static func finiteDouble(_ value: String?) -> Double? {
        guard let value, !value.isEmpty, value.uppercased() != "N/A", let parsed = Double(value), parsed.isFinite else { return nil }
        return parsed
    }

    private static func positiveInt64(_ value: String?) -> Int64? {
        guard let value, value.uppercased() != "N/A", let parsed = Int64(value), parsed >= 0 else { return nil }
        return parsed
    }

    public static func rationalValue(_ raw: String?) -> Double? {
        guard let raw, !raw.isEmpty, raw.uppercased() != "N/A" else { return nil }
        let pieces = raw.split(separator: "/", omittingEmptySubsequences: false)
        if pieces.count == 2,
           let numerator = Double(pieces[0]),
           let denominator = Double(pieces[1]),
           denominator != 0 {
            let value = numerator / denominator
            return value.isFinite ? value : nil
        }
        guard let value = Double(raw), value.isFinite else { return nil }
        return value
    }
}

public struct MediaInspectionFormat: Codable, Sendable, Equatable {
    public let filename: String?
    public let nb_streams: Int?
    public let nb_programs: Int?
    public let format_name: String?
    public let format_long_name: String?
    public let start_time: String?
    public let duration: String?
    public let size: String?
    public let bit_rate: String?
    public let probe_score: Int?
    public let tags: [String: String]?

    public var durationSeconds: Double? { Self.finiteDouble(duration) }
    public var sizeBytes: Int64? { Self.positiveInt64(size) }
    public var bitRateValue: Int64? { Self.positiveInt64(bit_rate) }
    public var startTimeSeconds: Double? { Self.finiteDouble(start_time) }

    private static func finiteDouble(_ value: String?) -> Double? {
        guard let value, !value.isEmpty, value.uppercased() != "N/A", let parsed = Double(value), parsed.isFinite else { return nil }
        return parsed
    }
    private static func positiveInt64(_ value: String?) -> Int64? {
        guard let value, value.uppercased() != "N/A", let parsed = Int64(value), parsed >= 0 else { return nil }
        return parsed
    }
}

public struct MediaInspectionChapter: Codable, Sendable, Equatable, Identifiable {
    public let id: Int?
    public let time_base: String?
    public let start: Int64?
    public let start_time: String?
    public let end: Int64?
    public let end_time: String?
    public let tags: [String: String]?

    public var stableID: Int { id ?? -1 }
}

public struct MediaInspectionProgram: Codable, Sendable, Equatable, Identifiable {
    public let program_id: Int?
    public let program_num: Int?
    public let nb_streams: Int?
    public let pmt_pid: Int?
    public let pcr_pid: Int?
    public let tags: [String: String]?
    public let streams: [MediaInspectionStream]?

    public var id: Int { program_id ?? program_num ?? -1 }
}

public struct MediaInspectionResult: Codable, Sendable, Equatable {
    public let streams: [MediaInspectionStream]
    public let format: MediaInspectionFormat?
    public let chapters: [MediaInspectionChapter]?
    public let programs: [MediaInspectionProgram]?

    public init(
        streams: [MediaInspectionStream],
        format: MediaInspectionFormat? = nil,
        chapters: [MediaInspectionChapter]? = nil,
        programs: [MediaInspectionProgram]? = nil
    ) {
        self.streams = streams
        self.format = format
        self.chapters = chapters
        self.programs = programs
    }

    public var isPartial: Bool { format == nil || streams.isEmpty }
    public var durationSeconds: Double? {
        if let value = format?.durationSeconds { return value }
        return streams.compactMap(\.durationSeconds).max()
    }
    public var videoStreams: [MediaInspectionStream] { streams.filter { $0.codec_type == "video" && !$0.isAttachedPicture } }
    public var audioStreams: [MediaInspectionStream] { streams.filter { $0.codec_type == "audio" } }
    public var subtitleStreams: [MediaInspectionStream] { streams.filter { $0.codec_type == "subtitle" } }
    public var attachmentStreams: [MediaInspectionStream] { streams.filter { $0.codec_type == "attachment" } }
    public var dataStreams: [MediaInspectionStream] { streams.filter { $0.codec_type == "data" } }
    public var unknownStreams: [MediaInspectionStream] {
        streams.filter { stream in
            guard let type = stream.codec_type else { return true }
            return !["video", "audio", "subtitle", "attachment", "data"].contains(type)
        }
    }
    public var videoStream: MediaInspectionStream? { videoStreams.first ?? streams.first { $0.codec_type == "video" } }
    public var audioStream: MediaInspectionStream? { audioStreams.first }
    public var attachedPictureStream: MediaInspectionStream? { streams.first { $0.codec_type == "video" && $0.isAttachedPicture } }
    public var frameRate: Double? { videoStream?.frameRate }
    public var estimatedFrameCount: Int64? {
        if let raw = videoStream?.nb_frames, raw.uppercased() != "N/A", let count = Int64(raw), count > 0 { return count }
        guard let durationSeconds, let frameRate, durationSeconds > 0, frameRate > 0 else { return nil }
        return Int64((durationSeconds * frameRate).rounded())
    }
    public var requiresHighBitDepthFrameOutput: Bool {
        guard let pixel = videoStream?.pix_fmt?.lowercased() else { return false }
        return pixel.contains("10") || pixel.contains("12") || pixel.contains("14") || pixel.contains("16") || pixel.contains("p010")
    }
}

private extension Dictionary where Key == String, Value == String {
    func firstValue(caseInsensitiveKey key: String) -> String? {
        first { $0.key.caseInsensitiveCompare(key) == .orderedSame }?.value
    }
}
