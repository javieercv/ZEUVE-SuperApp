import SwiftUI
import AppKit
import UniversalDownloaderModule
import ZEUVEEngines

struct UniversalDownloaderDiagnosticsSettingsView: View {
    @ObservedObject var model: UniversalDownloaderViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Diagnóstico de motores")
                        .font(.title2.bold())
                    Text("Comprueba los componentes incluidos que utiliza el Descargador.")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Comprobar de nuevo") {
                    Task { await model.refreshDiagnostics() }
                }
                .disabled(model.state.isBusy)
            }

            if model.diagnostics.isEmpty {
                ContentUnavailableView(
                    "Motores no disponibles",
                    systemImage: "wrench.and.screwdriver",
                    description: Text(model.unavailableMessage ?? "No se ha podido leer el registro compartido de motores incluidos.")
                )
            } else {
                List(model.diagnostics) { diagnostic in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: diagnostic.isReady ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                            .foregroundStyle(diagnostic.isReady ? .green : .orange)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(diagnostic.descriptor.name) \(diagnostic.descriptor.version)")
                                .font(.headline)
                            Text(diagnostic.message)
                                .foregroundStyle(.secondary)
                            Text(diagnostic.descriptor.architecture.spanishName)
                                .font(.caption)
                            if !diagnostic.technicalDetails.isEmpty {
                                DisclosureGroup("Detalles técnicos") {
                                    ForEach(diagnostic.technicalDetails.indices, id: \.self) { index in
                                        Text(diagnostic.technicalDetails[index])
                                            .font(.caption.monospaced())
                                            .textSelection(.enabled)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                            }
                            if !diagnostic.dynamicDependencies.isEmpty {
                                DisclosureGroup("Dependencias dinámicas") {
                                    ForEach(diagnostic.dynamicDependencies, id: \.self) { dependency in
                                        Text(dependency)
                                            .font(.caption.monospaced())
                                            .textSelection(.enabled)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding(24)
    }
}
