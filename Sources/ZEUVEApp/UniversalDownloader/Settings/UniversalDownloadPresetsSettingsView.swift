import SwiftUI
import AppKit
import UniversalDownloaderModule
import ZEUVEEngines

struct UniversalDownloadPresetsSettingsView: View {
    @ObservedObject var model: UniversalDownloaderViewModel
    @State private var newPresetName = ""
    @State private var renameID: UUID?
    @State private var renameText = ""
    @State private var confirmRestore = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Presets de descarga")
                        .font(.title2.bold())
                    Text("Crea y administra configuraciones reutilizables. Dentro del Descargador solo se muestra el selector rápido para aplicarlas.")
                        .foregroundStyle(.secondary)
                }

                GroupBox("Crear preset") {
                    HStack {
                        TextField("Nombre del nuevo preset", text: $newPresetName)
                        Button("Guardar valores predeterminados actuales") {
                            model.saveDefaultSettingsAsPreset(named: newPresetName)
                            newPresetName = ""
                        }
                        .disabled(newPresetName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    .padding(8)
                }

                if model.presets.isEmpty {
                    ContentUnavailableView(
                        "No hay presets",
                        systemImage: "slider.horizontal.3",
                        description: Text("Crea uno a partir de los valores predeterminados actuales o restaura los presets incluidos.")
                    )
                } else {
                    VStack(spacing: 10) {
                        ForEach(model.presets) { preset in
                            HStack(spacing: 12) {
                                Button { model.toggleFavorite(preset) } label: {
                                    Image(systemName: preset.isFavorite ? "star.fill" : "star")
                                }
                                .buttonStyle(.plain)
                                .help(preset.isFavorite ? "Quitar de favoritos" : "Marcar como favorito")

                                VStack(alignment: .leading, spacing: 4) {
                                    if renameID == preset.id {
                                        TextField("Nombre", text: $renameText)
                                            .onSubmit {
                                                model.renamePreset(preset, to: renameText)
                                                renameID = nil
                                            }
                                    } else {
                                        Text(preset.name).font(.headline)
                                    }
                                    Text(presetSummary(preset))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Menu {
                                    Button("Aplicar a la operación actual") { model.applyPreset(preset) }
                                    Button("Usar como valores predeterminados") { model.usePresetAsDefaults(preset) }
                                    Button("Actualizar con los valores predeterminados") { model.updatePresetFromDefaultSettings(preset) }
                                    Button("Renombrar") {
                                        renameID = preset.id
                                        renameText = preset.name
                                    }
                                    Button("Duplicar") { model.duplicatePreset(preset) }
                                    Divider()
                                    Button("Eliminar", role: .destructive) { model.deletePreset(preset) }
                                } label: {
                                    Image(systemName: "ellipsis.circle")
                                }
                            }
                            .padding(12)
                            .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 10))
                        }
                    }
                }

                HStack {
                    Button("Restaurar presets incluidos", role: .destructive) { confirmRestore = true }
                    Spacer()
                }
            }
            .padding(24)
            .frame(maxWidth: 900, alignment: .leading)
        }
        .confirmationDialog(
            "¿Restaurar los presets incluidos?",
            isPresented: $confirmRestore,
            titleVisibility: .visible
        ) {
            Button("Restaurar", role: .destructive) { model.restoreDefaultPresets() }
            Button("Cancelar", role: .cancel) { }
        } message: {
            Text("Se sustituirá la lista actual de presets. Esta acción no modifica los archivos descargados.")
        }
    }

    private func presetSummary(_ preset: UniversalDownloadPreset) -> String {
        if preset.settings.mode == .automatic {
            return "Automático por plataforma"
        }
        if preset.settings.mode == .original {
            return "Original sin convertir"
        }
        if preset.settings.mode == .video {
            return "Vídeo · \(preset.settings.maximumResolution.spanishName) · \(preset.settings.container.spanishName)"
        }
        let quality = preset.settings.audioOutput == .mp3 ? " · \(preset.settings.mp3Bitrate.spanishName)" : ""
        return "Audio · \(preset.settings.audioOutput.spanishName)\(quality)"
    }
}
