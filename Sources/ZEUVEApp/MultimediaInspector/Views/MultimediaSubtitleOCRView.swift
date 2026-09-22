import SwiftUI
import MultimediaInspectorModule

struct MultimediaSubtitleOCRView: View {
    @ObservedObject var model: MultimediaInspectorViewModel

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    if let draft = model.ocrDraft {
                        summary(draft)
                        ForEach(draft.events) { event in
                            eventRow(event)
                        }
                    } else if model.isRunningBitmapSubtitleOCR {
                        VStack(spacing: 12) {
                            ProgressView()
                            Text("Reconociendo subtítulos bitmap localmente…")
                            Text("FFmpeg extrae los eventos y Vision reconoce el texto. El contenido no sale del Mac.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, minHeight: 260)
                    }
                }
                .padding(16)
            }
            Divider()
            footer
        }
        .frame(minWidth: 760, minHeight: 520)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "text.viewfinder").font(.title2)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text("OCR de subtítulos bitmap").font(.headline)
                    ContextualHelpButton(topic: ZEUVEHelpTopics.multimediaBitmapSubtitles)
                }
                Text("Borrador revisable · la pista original nunca se sustituye automáticamente")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Cerrar") { model.dismissOCRDraft() }
        }
        .padding(16)
    }

    private func summary(_ draft: BitmapSubtitleOCRDraft) -> some View {
        let included = draft.events.filter(\.included).count
        let review = draft.events.filter { $0.included && $0.needsReview }.count
        return GroupBox {
            HStack(spacing: 18) {
                Label("Stream \(draft.sourceStreamIndex)", systemImage: "captions.bubble")
                Text(draft.sourceCodec.uppercased()).monospaced()
                if let language = draft.language, !language.isEmpty { Text(language) }
                Spacer()
                Text("\(included) incluidos · \(review) por revisar")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(review > 0 ? .orange : .secondary)
            }
            .padding(.vertical, 4)
        } label: {
            HelpLabel("Resultado OCR", topic: ZEUVEHelpTopics.multimediaBitmapSubtitles)
        }
    }

    private func eventRow(_ event: BitmapSubtitleOCREvent) -> some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    Toggle("Incluir", isOn: eventBinding(event, \.included))
                        .toggleStyle(.checkbox)
                    TextField("Inicio", text: timeBinding(event, keyPath: \.start))
                        .frame(width: 90)
                        .textFieldStyle(.roundedBorder)
                    Text("→").foregroundStyle(.secondary)
                    TextField("Fin", text: timeBinding(event, keyPath: \.end))
                        .frame(width: 90)
                        .textFieldStyle(.roundedBorder)
                    Text("Confianza \(Int(event.confidence * 100)) %")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(event.needsReview ? .orange : .secondary)
                    Spacer()
                    if event.needsReview {
                        Label("Revisar", systemImage: "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
                TextEditor(text: eventBinding(event, \.text))
                    .font(.body)
                    .frame(minHeight: 52, maxHeight: 110)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(.quaternary))
            }
            .padding(.vertical, 3)
        } label: {
            Text(formatTime(event.start))
                .font(.caption.monospacedDigit())
        }
    }

    private var footer: some View {
        HStack(spacing: 10) {
            if model.isRunningBitmapSubtitleOCR {
                Button("Cancelar") { model.cancelCurrentOperation() }
            }
            Spacer()
            Button("Exportar SRT…") { model.exportOCRDraft() }
                .disabled(model.ocrDraft == nil)
            Button("Guardar y añadir al borrador…") { model.exportOCRDraft(addToEditing: true) }
                .buttonStyle(.borderedProminent)
                .disabled(model.ocrDraft == nil || !model.isEditing)
                .help(model.isEditing ? "Guarda un SRT revisado y lo incorpora como pista externa al borrador." : "Activa edición para añadir el SRT al borrador; exportarlo sigue disponible.")
        }
        .padding(16)
    }

    private func eventBinding<T>(_ event: BitmapSubtitleOCREvent, _ keyPath: WritableKeyPath<BitmapSubtitleOCREvent, T>) -> Binding<T> {
        Binding(
            get: { model.ocrDraft?.events.first(where: { $0.id == event.id })?[keyPath: keyPath] ?? event[keyPath: keyPath] },
            set: { value in
                var updated = model.ocrDraft?.events.first(where: { $0.id == event.id }) ?? event
                updated[keyPath: keyPath] = value
                model.updateOCREvent(updated)
            }
        )
    }

    private func timeBinding(_ event: BitmapSubtitleOCREvent, keyPath: WritableKeyPath<BitmapSubtitleOCREvent, TimeInterval>) -> Binding<String> {
        Binding(
            get: {
                let value = model.ocrDraft?.events.first(where: { $0.id == event.id })?[keyPath: keyPath] ?? event[keyPath: keyPath]
                return String(format: "%.3f", value)
            },
            set: { text in
                guard let value = Double(text.replacingOccurrences(of: ",", with: ".")), value.isFinite else { return }
                var updated = model.ocrDraft?.events.first(where: { $0.id == event.id }) ?? event
                updated[keyPath: keyPath] = value
                model.updateOCREvent(updated)
            }
        )
    }

    private func formatTime(_ value: TimeInterval) -> String {
        let total = max(value, 0)
        let hours = Int(total) / 3600
        let minutes = (Int(total) % 3600) / 60
        let seconds = total.truncatingRemainder(dividingBy: 60)
        return hours > 0 ? String(format: "%02d:%02d:%06.3f", hours, minutes, seconds) : String(format: "%02d:%06.3f", minutes, seconds)
    }
}
