import Foundation
import ZEUVEEngines

/// Presentación del plan efectivo, compartida por edición individual y lote.
public struct MediaEditReview: Sendable {
    public struct Change: Sendable, Equatable, Identifiable {
        public let id: String
        public let field: String
        public let before: String
        public let after: String
    }
    public let tracks: [PlannedTrack]
    public let changes: [Change]

    public init(plan: MediaEditPlan, original: MediaInspectionResult) {
        tracks = plan.videoTracks + plan.audioTracks + plan.subtitleTracks + plan.removedTracks
        var values: [Change] = []
        for item in tracks {
            let index = item.track.source.originalStreamIndex
            let stream = original.streams.first { $0.index == index }
            let prefix = "\(item.kind.displayName) · \(index.map { "stream \($0)" } ?? "pista añadida")"
            let id = item.id.uuidString
            if item.action == .remove {
                values.append(.init(id: id, field: prefix, before: stream?.title ?? item.track.codec.uppercased(), after: "Se eliminará"))
                continue
            }
            if item.action == .add {
                values.append(.init(id: id, field: prefix, before: "No existe", after: "Se añadirá · \(item.outputCodec.uppercased())"))
            }
            let fields: [(String, String, String)] = [
                ("Idioma", stream?.language ?? "", item.track.language),
                ("Título", stream?.title ?? "", item.track.title),
                ("Default", stream?.isDefault == true ? "Sí" : "No", item.track.isDefault ? "Sí" : "No"),
                ("Forced", stream?.isForced == true ? "Sí" : "No", item.track.isForced ? "Sí" : "No"),
                ("Códec", stream?.codec_name ?? item.track.codec, item.outputCodec)
            ]
            for (field, before, after) in fields where before != after {
                values.append(.init(id: id + field, field: prefix + " · " + field,
                                    before: before.isEmpty ? "Sin indicar" : before, after: after.isEmpty ? "Sin indicar" : after))
            }
        }
        for key in plan.metadata.touchedContainerKeys.sorted() {
            values.append(.init(id: "container-" + key, field: "Archivo · " + key,
                                before: original.format?.tags?.first { $0.key.caseInsensitiveCompare(key) == .orderedSame }?.value ?? "Sin indicar",
                                after: plan.metadata.containerValues[key].flatMap { $0.isEmpty ? nil : $0 } ?? "Se eliminará"))
        }
        for (index, keys) in plan.metadata.touchedVideoKeysByStream.sorted(by: { $0.key < $1.key }) {
            guard plan.videoTracks.contains(where: { $0.track.source.originalStreamIndex == index }) else { continue }
            let stream = original.streams.first { $0.index == index }
            for key in keys.sorted() where key != "title" {
                values.append(.init(id: "video-\(index)-\(key)", field: "Vídeo · stream \(index) · \(key)",
                                    before: stream?.tags?.first { $0.key.caseInsensitiveCompare(key) == .orderedSame }?.value ?? "Sin indicar",
                                    after: plan.metadata.videoValuesByStream[index]?[key].flatMap { $0.isEmpty ? nil : $0 } ?? "Se eliminará"))
            }
        }
        changes = values
    }
}
