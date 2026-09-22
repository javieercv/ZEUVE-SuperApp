import SwiftUI
import ZEUVEEngines
import MultimediaInspectorModule

struct MultimediaTechnicalStructureView: View {
    @ObservedObject var model: MultimediaInspectorViewModel
    let inspection: MediaInspectionResult
    var timing: AudioTimingAnalysis?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            chaptersSection
            timingSection
            attachmentsSection
            programsSection
            otherStreamsSection
        }
    }

    @ViewBuilder private var chaptersSection: some View {
        if model.isEditing {
            DisclosureGroup {
                VStack(alignment: .leading, spacing: 8) {
                    if model.editableChapters.isEmpty {
                        Text("Sin capítulos en el borrador.").foregroundStyle(.secondary)
                    }
                    ForEach(Array(model.editableChapters.enumerated()), id: \.element.id) { offset, chapter in
                        HStack(spacing: 8) {
                            Text(String(format: "%02d", offset + 1)).font(.caption.monospaced()).foregroundStyle(.secondary)
                            TextField("Título", text: Binding(
                                get: { model.currentDraft?.chapters.first(where: { $0.id == chapter.id })?.title ?? chapter.title },
                                set: { model.updateChapterTitle(chapter.id, title: $0) }
                            ))
                            .textFieldStyle(.roundedBorder)
                            .frame(minWidth: 180)
                            TextField("Tiempo", value: Binding(
                                get: { model.currentDraft?.chapters.first(where: { $0.id == chapter.id })?.startTime ?? chapter.startTime },
                                set: { model.updateChapterTime(chapter.id, time: $0) }
                            ), format: .number.precision(.fractionLength(3)))
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 105)
                            Text("s").foregroundStyle(.secondary)
                            Button { model.seekToEditableChapter(chapter) } label: { Image(systemName: "play.fill") }
                                .buttonStyle(.borderless).help("Ir al inicio del capítulo")
                            Button(role: .destructive) { model.removeChapter(chapter.id) } label: { Image(systemName: "trash") }
                                .buttonStyle(.borderless).help("Eliminar capítulo del borrador")
                        }
                    }
                    Button("Añadir capítulo en posición actual") { model.addChapterAtCurrentPosition() }
                        .buttonStyle(.bordered)
                        .help("Usa la posición actual del reproductor. El final se calcula con el inicio del capítulo siguiente.")
                    Text("Los capítulos se editan como marcadores de inicio. El final de cada uno se calcula automáticamente.")
                        .font(.caption).foregroundStyle(.secondary)
                }.padding(.top, 6)
            } label: { HelpLabel("Capítulos · \(model.editableChapters.count)", topic: ZEUVEHelpTopics.multimediaChapters) }
        } else if let chapters = inspection.chapters, !chapters.isEmpty {
            DisclosureGroup {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(chapters.enumerated()), id: \.offset) { offset, chapter in
                        let content = HStack(alignment: .firstTextBaseline) {
                            Text(String(format: "%02d", offset + 1)).font(.caption.monospaced()).foregroundStyle(.secondary)
                            Text(chapter.tags?.first(where: { $0.key.caseInsensitiveCompare("title") == .orderedSame })?.value ?? "Capítulo \(offset + 1)")
                            Spacer()
                            Text([chapter.start_time, chapter.end_time].compactMap { $0 }.joined(separator: " → "))
                                .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                        }
                        if MultimediaTimeParser.seconds(chapter.start_time) != nil {
                            Button { model.seekToChapter(chapter) } label: { content }
                                .buttonStyle(.plain)
                                .help("Reproducir desde el inicio del capítulo")
                        } else { content }
                    }
                }.padding(.top, 6)
            } label: { HelpLabel("Capítulos · \(chapters.count)", topic: ZEUVEHelpTopics.multimediaChapters) }
        }
    }

    @ViewBuilder private var timingSection: some View {
        if let timing, !timing.entries.isEmpty {
            DisclosureGroup {
                VStack(alignment: .leading, spacing: 7) {
                    Text("Referencia: \(timing.referenceLabel)").font(.caption).foregroundStyle(.secondary)
                    ForEach(timing.entries) { entry in
                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Stream \(entry.streamIndex) · \(entry.label)")
                                Text(timingDetail(entry)).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                    }
                    Text("Los valores son diferencias de timestamps y duración declarados; no constituyen por sí solos un diagnóstico de desincronización.")
                        .font(.caption).foregroundStyle(.secondary)
                }.padding(.top, 6)
            } label: { HelpLabel("Sincronización de audio · \(timing.entries.count)", topic: ZEUVEHelpTopics.multimediaAudioTiming) }
        }
    }

    @ViewBuilder private var attachmentsSection: some View {
        let attachedPictures = inspection.streams.filter { $0.codec_type == "video" && $0.isAttachedPicture }
        if model.isEditing {
            DisclosureGroup {
                VStack(alignment: .leading, spacing: 8) {
                    if model.editableAttachments.isEmpty { Text("Sin adjuntos editables.").foregroundStyle(.secondary) }
                    ForEach(model.editableAttachments) { attachment in
                        HStack(spacing: 8) {
                            TextField("Nombre", text: Binding(
                                get: { model.currentDraft?.attachments.first(where: { $0.id == attachment.id })?.filename ?? attachment.filename },
                                set: { value in var updated = attachment; updated.filename = value; model.updateAttachment(updated) }
                            ))
                            .textFieldStyle(.roundedBorder)
                            TextField("MIME", text: Binding(
                                get: { model.currentDraft?.attachments.first(where: { $0.id == attachment.id })?.mimeType ?? attachment.mimeType },
                                set: { value in var updated = attachment; updated.mimeType = value; model.updateAttachment(updated) }
                            ))
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 220)
                            ContextualHelpButton(topic: ZEUVEHelpTopics.multimediaAttachmentMIME)
                            if case .original(let streamIndex) = attachment.source {
                                Button("Extraer…") { model.extractAttachment(streamIndex: streamIndex) }.buttonStyle(.link)
                            }
                            Button(role: .destructive) { model.removeAttachment(attachment.id) } label: { Image(systemName: "trash") }
                                .buttonStyle(.borderless).help("Eliminar adjunto del borrador")
                        }
                    }
                    Button("Añadir adjunto…") { model.chooseAttachment() }.buttonStyle(.bordered)
                    Divider()
                    HStack {
                        Text("Carátula / attached_pic").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                        ContextualHelpButton(topic: ZEUVEHelpTopics.multimediaAttachments)
                        Spacer()
                        Button(model.editableArtworks.isEmpty ? "Añadir carátula…" : "Sustituir…") { model.chooseArtwork() }
                            .buttonStyle(.bordered)
                            .disabled(model.isProcessingArtwork)
                    }
                    if let data = model.artworkPreviewData, let image = NSImage(data: data) {
                        HStack {
                            Image(nsImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: 180, maxHeight: 180)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .accessibilityLabel("Previsualización de la carátula")
                            Spacer()
                        }
                    }
                    ForEach(model.editableArtworks) { artwork in
                        HStack(spacing: 8) {
                            Text(artwork.codec.uppercased()).font(.caption.monospaced())
                            TextField("Título", text: Binding(
                                get: { model.currentDraft?.artworks.first(where: { $0.id == artwork.id })?.title ?? artwork.title },
                                set: { value in var updated = artwork; updated.title = value; model.updateArtwork(updated) }
                            )).textFieldStyle(.roundedBorder)
                            if case .original(let streamIndex) = artwork.source {
                                Button("Extraer…") { model.extractArtwork(streamIndex: streamIndex) }.buttonStyle(.link)
                            }
                            Button(role: .destructive) { model.removeArtwork(artwork.id) } label: { Image(systemName: "trash") }
                                .buttonStyle(.borderless).help("Eliminar carátula del borrador")
                        }
                    }
                    if model.editableArtworks.isEmpty { Text("Sin carátula attached_pic en el borrador.").font(.caption).foregroundStyle(.secondary) }
                }.padding(.top, 6)
            } label: { HelpLabel("Adjuntos · \(model.editableAttachments.count)", topic: ZEUVEHelpTopics.multimediaAttachments) }
        } else if !inspection.attachmentStreams.isEmpty || !attachedPictures.isEmpty {
            DisclosureGroup {
                VStack(alignment: .leading, spacing: 8) {
                    if let data = model.artworkPreviewData, let image = NSImage(data: data) {
                        Image(nsImage: image).resizable().scaledToFit().frame(maxWidth: 180, maxHeight: 180).clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    ForEach(inspection.attachmentStreams, id: \.id) { stream in attachmentReadOnlyRow(stream, canExtract: true) }
                    ForEach(attachedPictures, id: \.id) { stream in artworkReadOnlyRow(stream) }
                }.padding(.top, 6)
            } label: { HelpLabel("Adjuntos e imágenes · \(inspection.attachmentStreams.count + attachedPictures.count)", topic: ZEUVEHelpTopics.multimediaAttachments) }
        }
    }

    private func artworkReadOnlyRow(_ stream: MediaInspectionStream) -> some View {
        HStack {
            Text("Carátula · stream \(stream.index ?? -1) · \(stream.codec_name ?? "desconocido")")
            Spacer()
            if let title = stream.title { Text(title).foregroundStyle(.secondary) }
            if let index = stream.index { Button("Extraer…") { model.extractArtwork(streamIndex: index) }.buttonStyle(.link) }
            Button("Copiar") { MultimediaClipboard.copy(MediaInspectionTextFormatter().stream(stream)) }.buttonStyle(.link)
        }
    }

    private func attachmentReadOnlyRow(_ stream: MediaInspectionStream, canExtract: Bool) -> some View {
        HStack {
            Text("Stream \(stream.index ?? -1) · \(stream.codec_name ?? stream.codec_type ?? "desconocido")")
            Spacer()
            if let title = stream.title { Text(title).foregroundStyle(.secondary) }
            if canExtract, let index = stream.index {
                Button("Extraer…") { model.extractAttachment(streamIndex: index) }.buttonStyle(.link)
            }
            Button("Copiar") { MultimediaClipboard.copy(MediaInspectionTextFormatter().stream(stream)) }.buttonStyle(.link)
        }
    }

    @ViewBuilder private var programsSection: some View {
        if let programs = inspection.programs, !programs.isEmpty {
            DisclosureGroup("Programas · \(programs.count)") {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(programs) { program in
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Programa \(program.program_id ?? program.program_num ?? -1)").font(.headline)
                            Text("\(program.nb_streams ?? program.streams?.count ?? 0) streams").font(.caption).foregroundStyle(.secondary)
                            if let tags = program.tags, !tags.isEmpty {
                                Text(tags.keys.sorted().map { "\($0)=\(tags[$0] ?? "")" }.joined(separator: " · "))
                                    .font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                            }
                        }
                    }
                }.padding(.top, 6)
            }
        }
    }

    @ViewBuilder private var otherStreamsSection: some View {
        if !inspection.dataStreams.isEmpty || !inspection.unknownStreams.isEmpty {
            DisclosureGroup("Otros streams · \(inspection.dataStreams.count + inspection.unknownStreams.count)") {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(inspection.dataStreams + inspection.unknownStreams, id: \.id) { stream in
                        HStack {
                            Text("Stream \(stream.index ?? -1) · \(stream.codec_type ?? "desconocido") · \(stream.codec_name ?? "sin códec")")
                            Spacer()
                            Button("Copiar") { MultimediaClipboard.copy(MediaInspectionTextFormatter().stream(stream)) }.buttonStyle(.link)
                        }
                    }
                }.padding(.top, 6)
            }
        }
    }

    private func timingDetail(_ entry: AudioTimingEntry) -> String {
        let start = entry.startTime.map { String(format: "inicio %.3f s", $0) }
        let offset = entry.offsetFromReference.map { String(format: "offset %+.3f s", $0) }
        let duration = entry.durationDifference.map { String(format: "Δ duración %+.3f s", $0) }
        let values = [start, offset, duration].compactMap { $0 }
        return values.isEmpty ? "Timestamps no disponibles" : values.joined(separator: " · ")
    }
}
