import SwiftUI
import MultimediaInspectorModule
import ZEUVEEngines

struct MultimediaEditPreview: View {
    let plan: MediaEditPlan
    let inspection: MediaInspectionResult
    let execute: (() -> Void)?

    init(plan: MediaEditPlan, inspection: MediaInspectionResult, execute: (() -> Void)? = nil) {
        self.plan = plan; self.inspection = inspection; self.execute = execute
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading) {
                    Text("ARCHIVO RESULTANTE").font(.caption.bold()).foregroundStyle(.secondary)
                    Text(plan.targetContainer.displayName).font(.title2.bold())
                }
                Spacer()
                if let execute { Button("Generar archivo nuevo", action: execute).buttonStyle(.borderedProminent) }
            }
            Divider()
            Text("Vídeo y audio: stream copy obligatorio").font(.headline)
            let review = MediaEditReview(plan: plan, original: inspection)
            ForEach(review.tracks) { item in row(item) }
            if !review.changes.isEmpty {
                Text("Cambios previstos").font(.headline)
                ForEach(review.changes) { change in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(change.field).font(.caption.bold())
                        Text("\(change.before) → \(change.after)").font(.caption).textSelection(.enabled)
                    }
                }
            }

            Divider()
            structuralSummary

            ForEach(plan.warnings, id: \.self) {
                Label($0, systemImage: "exclamationmark.triangle").foregroundStyle(.orange)
            }
        }
        .padding(16)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 14))
    }

    private var structuralSummary: some View {
        VStack(alignment: .leading, spacing: 7) {
            Label("Capítulos: \(plan.chapters.count) en el resultado", systemImage: "bookmark")
            ForEach(plan.chapters) { chapter in
                Text("\(chapter.startTime.formatted())–\(chapter.endTime.formatted()) s · \(chapter.title)").font(.caption)
            }
            let added = plan.attachments.filter { $0.action == .add }.count
            let kept = plan.attachments.filter { $0.action == .keep }.count
            let removed = plan.removedAttachments.count
            Label("Adjuntos: \(kept) conservados · \(added) añadidos · \(removed) eliminados", systemImage: "paperclip")
            ForEach(plan.attachments + plan.removedAttachments) { item in
                Text("\(item.attachment.filename) · \(item.attachment.mimeType) · \(item.action == .remove ? "Se eliminará" : item.action == .add ? "Se añadirá" : "Se conservará")").font(.caption)
            }
            ForEach(plan.artworks + plan.removedArtworks) { item in
                Text("Carátula · \(item.artwork.codec.uppercased()) · \(item.action == .remove ? "Se eliminará" : item.action == .add ? "Se añadirá" : "Se conservará")").font(.caption)
            }
            let metadataChanges = plan.metadata.touchedContainerKeys.count + plan.metadata.touchedVideoKeysByStream.values.reduce(0) { $0 + $1.count }
            Label("Metadatos: \(metadataChanges) campos modificados · \(plan.preserveMetadata ? "se preservan los tags no editados" : "los tags no editados no se copiarán")", systemImage: "tag")
            let preservedAuxiliaryCount = inspection.streams.filter { !["video", "audio", "subtitle", "attachment"].contains($0.codec_type ?? "") }.count
            if preservedAuxiliaryCount > 0 {
                Label("Se preservarán \(preservedAuxiliaryCount) streams auxiliares no editables cuando el contenedor lo permita.", systemImage: "shippingbox")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func row(_ item: PlannedTrack) -> some View {
        let presentation: (icon: String, detail: String, emphasis: Color) = {
            switch item.action {
            case .keep: return ("checkmark.circle", "Copia exacta", .secondary)
            case .add: return ("plus.circle", "+ Se añadirá · Copia exacta", .secondary)
            case .remove: return ("xmark.circle", "✕ Se eliminará", .red)
            case .convertSubtitle: return ("arrow.triangle.2.circlepath", "\(item.track.codec) → \(item.outputCodec)", .orange)
            }
        }()
        return HStack {
            Image(systemName: presentation.icon)
            Text("\(item.kind.displayName) · \(item.track.title.isEmpty ? item.track.codec.uppercased() : item.track.title)")
            Spacer()
            Text(presentation.detail).foregroundStyle(presentation.emphasis)
        }
    }
}
