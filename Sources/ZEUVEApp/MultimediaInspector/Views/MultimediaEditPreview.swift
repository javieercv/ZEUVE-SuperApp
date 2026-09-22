import SwiftUI
import MultimediaInspectorModule
import ZEUVEEngines

struct MultimediaEditPreview: View {
    let plan: MediaEditPlan
    let inspection: MediaInspectionResult
    let execute: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading) {
                    Text("ARCHIVO RESULTANTE").font(.caption.bold()).foregroundStyle(.secondary)
                    Text(plan.targetContainer.displayName).font(.title2.bold())
                }
                Spacer()
                Button("Generar archivo nuevo", action: execute).buttonStyle(.borderedProminent)
            }
            Divider()
            Text("Vídeo y audio: stream copy obligatorio").font(.headline)
            ForEach(inspection.videoStreams, id: \.id) { stream in
                HStack {
                    Image(systemName: "checkmark.circle")
                    Text("Vídeo · \(stream.codec_name?.uppercased() ?? "códec desconocido")")
                    Spacer()
                    Text("Copia exacta").foregroundStyle(.secondary)
                }
            }
            ForEach(plan.audioTracks) { item in row(item) }
            ForEach(plan.subtitleTracks) { item in row(item) }
            ForEach(plan.removedTracks) { item in row(item) }

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
            let added = plan.attachments.filter { $0.action == .add }.count
            let kept = plan.attachments.filter { $0.action == .keep }.count
            let removed = plan.removedAttachments.count
            Label("Adjuntos: \(kept) conservados · \(added) añadidos · \(removed) eliminados", systemImage: "paperclip")
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
            Text(item.track.title.isEmpty ? (item.track.language.isEmpty ? item.track.codec.uppercased() : item.track.language) : item.track.title)
            Spacer()
            Text(presentation.detail).foregroundStyle(presentation.emphasis)
        }
    }
}
