import SwiftUI
import AppKit
import UniversalDownloaderModule
import ZEUVEEngines

struct UniversalEngineSettingsView: View {
    @ObservedObject var model: UniversalDownloaderViewModel
    @State private var selectedEngine = "yt-dlp"
    @State private var version = ""
    @State private var confirmInstall = false
    @State private var pendingFile: URL?

    private let engineNames = ["yt-dlp", "deno", "ffmpeg", "ffprobe"]

    var body: some View {
        Form {
            Section {
                Label(EngineOverrideManager.updateWarning, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                if model.engineUpdateChannel == .experimental {
                    Label(EngineOverrideManager.experimentalWarning, systemImage: "flask.fill")
                        .foregroundStyle(.red)
                }
            } header: { Text("Advertencia obligatoria") }

            Section("Canal de actualización") {
                Picker("Canal", selection: $model.engineUpdateChannel) {
                    ForEach(EngineUpdateChannel.allCases) { Text($0.spanishName).tag($0) }
                }
                Text("La advertencia se aplica también a las versiones estables. Las actualizaciones son siempre manuales; nunca se comprueban ni instalan en segundo plano.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section("Instalar o sustituir desde un archivo local") {
                Picker("Motor", selection: $selectedEngine) {
                    ForEach(engineNames, id: \.self) { Text($0).tag($0) }
                }
                TextField("Versión", text: $version)
                Button("Seleccionar ejecutable e instalar") {
                    let panel = NSOpenPanel()
                    panel.title = "Seleccionar ejecutable del motor"
                    panel.canChooseDirectories = false
                    panel.canChooseFiles = true
                    panel.allowsMultipleSelection = false
                    guard panel.runModal() == .OK, let url = panel.url else { return }
                    pendingFile = url
                    confirmInstall = true
                }
                .disabled(version.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Text("El archivo se copia a ~/Library/Application Support/ZEUVE/Engines. La versión incluida dentro de la aplicación permanece intacta.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section("Versiones activas externas") {
                if model.installedEngineOverrides.isEmpty {
                    Text("Se están utilizando únicamente las versiones incluidas con ZEUVE.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(model.installedEngineOverrides) { item in
                        HStack {
                            VStack(alignment: .leading) {
                                Text("\(item.engineName) \(item.version)")
                                Text(item.channel.spanishName).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Restaurar incluida") { model.restoreBundledEngine(named: item.engineName) }
                        }
                    }
                }
                Button("Abrir carpeta de motores") { model.openEngineFolder() }
            }

            Section("Navegador opcional") {
                Text("No forma parte del peso principal de ZEUVE. Puede instalarse como motor verificado para páginas dinámicas y solo se usa como último recurso cuando los extractores normales fallan.")
                    .foregroundStyle(.secondary)
                Text("La guía completa para preparar, instalar, actualizar, probar y restaurar motores se encuentra en Docs/Motores/ENGINE_MANAGEMENT.md.")
                    .font(.caption)
            }
        }
        .formStyle(.grouped)
        .padding()
        .confirmationDialog("¿Instalar este motor?", isPresented: $confirmInstall, titleVisibility: .visible) {
            Button("Instalar") {
                guard let pendingFile else { return }
                model.installEngineOverride(
                    named: selectedEngine,
                    version: version.trimmingCharacters(in: .whitespacesAndNewlines),
                    source: pendingFile,
                    channel: model.engineUpdateChannel
                )
                self.pendingFile = nil
            }
            Button("Cancelar", role: .cancel) { pendingFile = nil }
        } message: {
            Text(EngineOverrideManager.updateWarning)
        }
    }
}
