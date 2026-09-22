import Foundation
import SwiftUI
import UniversalDownloaderModule

struct UniversalDownloaderCompletionView: View {
    @EnvironmentObject private var model: UniversalDownloaderViewModel
    let result: UniversalDownloadResult
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(completionTitle).font(.title.bold())
            if result.hasTotalFailure {
                Label(
                    "No se ha guardado ningún archivo. Consulta el detalle y la referencia técnica del elemento.",
                    systemImage: "exclamationmark.octagon.fill"
                )
                .foregroundStyle(.red)
            }
            HStack(spacing: 20) {
                Label("\(result.completedCount) correctos", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                Label("\(result.skippedCount) omitidos", systemImage: "minus.circle.fill").foregroundStyle(.orange)
                Label("\(result.failedCount) fallidos", systemImage: "xmark.circle.fill").foregroundStyle(.red)
            }
            if !result.warnings.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(result.warnings, id: \.self) { warning in
                        Label(warning, systemImage: "exclamationmark.triangle").foregroundStyle(.orange)
                    }
                }
            }
            List {
                ForEach(result.items) { item in
                    VStack(alignment: .leading) {
                        Text(item.title).font(.headline)
                        Text(item.userMessage ?? item.status.rawValue).font(.caption).foregroundStyle(.secondary)
                        if let reference = item.errorReference {
                            Text("Referencia: \(reference)")
                                .font(.caption2.monospaced())
                                .foregroundStyle(.secondary)
                        }
                        if !item.outputFiles.isEmpty {
                            Text("\(item.outputFiles.count) archivo(s) publicado(s)").font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                }
                if !result.auxiliaryFiles.isEmpty {
                    Section("Archivos auxiliares") {
                        ForEach(result.auxiliaryFiles, id: \.self) { file in
                            Label(file.lastPathComponent, systemImage: "doc.text")
                        }
                    }
                }
            }
            HStack {
                Button("Abrir carpeta") { model.openOutputFolder() }
                if result.failedCount > 0 {
                    Button("Abrir registros") { model.openLogsFolder() }
                }
                Spacer()
                Button("Cerrar") { dismiss() }.keyboardShortcut(.defaultAction)
            }
        }.padding(24).frame(minWidth: 620, minHeight: 430)
    }

    private var completionTitle: String {
        if result.wasCancelled { return "Descarga cancelada" }
        if result.hasTotalFailure { return "La descarga ha fallado" }
        if result.failedCount > 0 { return "Descarga completada con errores" }
        return "Descarga completada"
    }
}
