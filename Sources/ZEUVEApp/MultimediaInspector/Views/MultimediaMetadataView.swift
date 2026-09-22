import SwiftUI
import ZEUVEEngines
import MultimediaInspectorModule

struct MultimediaMetadataView: View {
    @ObservedObject var model: MultimediaInspectorViewModel
    let inspection: MediaInspectionResult
    @State private var query = ""
    private let compatibility = MediaMetadataCompatibilityRegistry()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HelpLabel("Metadatos", topic: ZEUVEHelpTopics.multimediaMetadataTab)
                    .font(.title3.weight(.semibold))
                if model.isEditing {
                    editableMetadata
                    Divider()
                    HelpLabel("Otros tags · solo lectura", topic: ZEUVEHelpTopics.multimediaMetadata)
                        .font(.headline)
                }

                HStack {
                    TextField("Buscar clave o valor", text: $query)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 360)
                    if !query.isEmpty {
                        Text("\(matchCount) coincidencia\(matchCount == 1 ? "" : "s")")
                            .font(.caption).foregroundStyle(.secondary)
                        Button("Limpiar") { query = "" }.buttonStyle(.link)
                    }
                    Spacer()
                }

                tagGroup("Metadatos globales", inspection.format?.tags ?? [:])
                ForEach(inspection.streams, id: \.id) { stream in
                    tagGroup("Stream \(stream.index ?? -1) · \(stream.codec_type ?? "desconocido")", stream.tags ?? [:])
                }

                if allTags.isEmpty && !model.isEditing {
                    ContentUnavailableView("Sin metadatos", systemImage: "tag", description: Text("FFprobe no ha devuelto tags para este archivo."))
                } else if matchCount == 0, !query.isEmpty {
                    ContentUnavailableView("Sin coincidencias", systemImage: "magnifyingglass", description: Text("Prueba con otra clave o valor."))
                }
            }
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var editableMetadata: some View {
        VStack(alignment: .leading, spacing: 14) {
            GroupBox {
                Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 8) {
                    ForEach(compatibility.editableContainerKeys, id: \.self) { key in
                        GridRow {
                            Text(label(for: key)).foregroundStyle(.secondary)
                            TextField(label(for: key), text: Binding(
                                get: { model.currentDraft?.metadata.containerValues[key] ?? originalContainerValue(key) },
                                set: { model.updateContainerMetadata(key: key, value: $0) }
                            ))
                            .textFieldStyle(.roundedBorder)
                        }
                    }
                }
                .padding(.top, 4)
            } label: {
                HelpLabel("Metadatos globales editables", topic: ZEUVEHelpTopics.multimediaMetadata)
            }

            ForEach(inspection.videoStreams, id: \.id) { stream in
                if let index = stream.index {
                    GroupBox("Vídeo · stream \(index)") {
                        HStack {
                            Text("Título").foregroundStyle(.secondary).frame(width: 120, alignment: .leading)
                            TextField("Título", text: Binding(
                                get: { model.currentDraft?.metadata.videoValuesByStream[index]?["title"] ?? stream.title ?? "" },
                                set: { model.updateVideoMetadata(streamIndex: index, key: "title", value: $0) }
                            ))
                            .textFieldStyle(.roundedBorder)
                        }
                    }
                }
            }

            ForEach(model.audioTracks) { track in
                trackMetadataGroup(track, heading: "Audio")
            }
            ForEach(model.subtitleTracks) { track in
                trackMetadataGroup(track, heading: "Subtítulo")
            }

            Text("Los tags no reconocidos permanecen visibles y se preservan cuando «Preservar metadatos» está activo, pero no se editan para evitar incompatibilidades entre contenedores.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private func trackMetadataGroup(_ track: MediaEditableTrack, heading: String) -> some View {
        GroupBox("\(heading) · stream \(track.source.streamIndex)") {
            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 8) {
                GridRow {
                    Text("Título").foregroundStyle(.secondary)
                    TextField("Título", text: trackBinding(track, keyPath: \.title)).textFieldStyle(.roundedBorder)
                }
                GridRow {
                    Text("Idioma").foregroundStyle(.secondary)
                    TextField("Idioma", text: trackBinding(track, keyPath: \.language)).textFieldStyle(.roundedBorder)
                }
            }
            .padding(.top, 4)
        }
    }

    private func trackBinding(_ track: MediaEditableTrack, keyPath: WritableKeyPath<MediaEditableTrack, String>) -> Binding<String> {
        Binding(
            get: {
                let source = track.kind == .audio ? model.audioTracks : model.subtitleTracks
                return source.first(where: { $0.id == track.id })?[keyPath: keyPath] ?? track[keyPath: keyPath]
            },
            set: { value in
                var updated = track
                updated[keyPath: keyPath] = value
                model.updateTrack(updated)
            }
        )
    }

    private func originalContainerValue(_ key: String) -> String {
        inspection.format?.tags?.first(where: { $0.key.caseInsensitiveCompare(key) == .orderedSame })?.value ?? ""
    }

    private func label(for key: String) -> String {
        switch key {
        case "title": return "Título"
        case "artist": return "Artista"
        case "album": return "Álbum"
        case "album_artist": return "Artista del álbum"
        case "composer": return "Compositor"
        case "genre": return "Género"
        case "date": return "Fecha"
        case "comment": return "Comentario"
        case "copyright": return "Copyright"
        default: return key
        }
    }

    private func tagGroup(_ title: String, _ tags: [String: String]) -> some View {
        let filtered = filteredTags(tags)
        return GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(title).font(.headline)
                    Spacer()
                    if !tags.isEmpty {
                        Button("Copiar grupo") { MultimediaClipboard.copy(MediaInspectionTextFormatter().tags(tags)) }
                            .buttonStyle(.link)
                    }
                }
                if tags.isEmpty {
                    Text("Sin tags").foregroundStyle(.secondary)
                } else if filtered.isEmpty {
                    Text("Sin coincidencias en este grupo").font(.caption).foregroundStyle(.tertiary)
                } else {
                    Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 7) {
                        ForEach(filtered, id: \.key) { item in
                            GridRow {
                                Text(item.key).font(.caption.monospaced()).foregroundStyle(.secondary)
                                Text(item.value).textSelection(.enabled)
                                Button { MultimediaClipboard.copy(item.value) } label: { Image(systemName: "doc.on.doc") }
                                    .buttonStyle(.borderless)
                                    .accessibilityLabel("Copiar \(item.key)")
                            }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var allTags: [(String, String)] {
        var values = (inspection.format?.tags ?? [:]).map { ($0.key, $0.value) }
        for stream in inspection.streams { values.append(contentsOf: (stream.tags ?? [:]).map { ($0.key, $0.value) }) }
        return values
    }

    private var matchCount: Int {
        if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return allTags.count }
        return allTags.filter { matches(key: $0.0, value: $0.1) }.count
    }

    private func filteredTags(_ tags: [String: String]) -> [(key: String, value: String)] {
        tags.keys.sorted().compactMap { key in
            let value = tags[key] ?? ""
            return matches(key: key, value: value) ? (key, value) : nil
        }
    }

    private func matches(key: String, value: String) -> Bool {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return true }
        return key.localizedCaseInsensitiveContains(trimmed) || value.localizedCaseInsensitiveContains(trimmed)
    }
}
