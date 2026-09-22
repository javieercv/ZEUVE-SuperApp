import SwiftUI
import AppKit
import UniversalDownloaderModule
import ZEUVEEngines

struct UniversalDownloaderDefaultsSettingsView: View {
    @ObservedObject var model: UniversalDownloaderViewModel
    @State private var confirmRestore = false

    var body: some View {
        Form {
            Section {
                HelpToggleRow(
                    "Abrir nuevas operaciones en modo avanzado",
                    topic: ZEUVEHelpTopics.interfaceMode,
                    isOn: $model.defaultAdvancedMode
                )
                HelpPickerRow(
                    "Contenido",
                    topic: ZEUVEHelpTopics.downloadContent,
                    selection: $model.defaultSettings.mode
                ) {
                    Text("Automático por plataforma").tag(DownloadMode.automatic)
                    Text("Original sin convertir").tag(DownloadMode.original)
                    Text("Vídeo").tag(DownloadMode.video)
                    Text("Solo audio").tag(DownloadMode.audio)
                }

                if model.defaultSettings.mode == .automatic {
                    Label(
                        "Se aplicará el perfil editable de cada plataforma o dominio.",
                        systemImage: "wand.and.stars"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                } else if model.defaultSettings.mode == .original {
                    Text("Se conservará el contenido original de máxima calidad sin conversión automática.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if model.defaultSettings.mode == .video {
                    HelpPickerRow(
                        "Resolución máxima",
                        topic: ZEUVEHelpTopics.maximumResolution,
                        selection: $model.defaultSettings.maximumResolution
                    ) {
                        ForEach(MaximumResolution.allCases) { resolution in
                            Text(resolution.spanishName).tag(resolution)
                        }
                    }
                    HelpPickerRow(
                        "Formato del archivo",
                        topic: ZEUVEHelpTopics.videoFormat,
                        selection: $model.defaultSettings.container
                    ) {
                        ForEach(ContainerPreference.allCases) { container in
                            Text(container.spanishName).tag(container)
                        }
                    }
                    HelpPickerRow(
                        "Rango dinámico",
                        topic: ZEUVEHelpTopics.dynamicRange,
                        selection: $model.defaultSettings.hdrPreference
                    ) {
                        Text("Automático").tag(HDRPreference.automatic)
                        Text("Preferir SDR").tag(HDRPreference.preferSDR)
                        Text("Preferir HDR").tag(HDRPreference.preferHDR)
                    }
                } else if model.defaultSettings.mode == .audio {
                    HelpPickerRow(
                        "Formato de audio",
                        topic: ZEUVEHelpTopics.audioFormat,
                        selection: $model.defaultSettings.audioOutput
                    ) {
                        ForEach(AudioOutputFormat.allCases) { output in
                            Text(output.spanishName).tag(output)
                        }
                    }
                    if model.defaultSettings.audioOutput == .mp3 {
                        HelpPickerRow(
                            "Calidad MP3",
                            topic: ZEUVEHelpTopics.mp3Bitrate,
                            selection: $model.defaultSettings.mp3Bitrate
                        ) {
                            ForEach(MP3Bitrate.allCases) { bitrate in
                                Text(bitrate.spanishName).tag(bitrate)
                            }
                        }
                    }
                }
            } header: {
                HStack {
                    Text("Valores predeterminados")
                    ContextualHelpButton(topic: ZEUVEHelpTopics.moduleDefaults)
                }
            } footer: {
                Text("Las selecciones exactas de pistas, el proxy y las cookies siguen siendo decisiones de cada operación y no se guardan como valores generales.")
            }

            Section("Nombre y listas") {
                HelpPickerRow(
                    "Nombre de archivo",
                    topic: ZEUVEHelpTopics.filename,
                    selection: $model.defaultSettings.filenamePreset
                ) {
                    Text("Título").tag(DownloadFilenamePreset.title)
                    Text("Título e ID").tag(DownloadFilenamePreset.titleAndID)
                    Text("Fecha y título").tag(DownloadFilenamePreset.dateAndTitle)
                    Text("Canal y título").tag(DownloadFilenamePreset.channelAndTitle)
                    Text("Índice y título").tag(DownloadFilenamePreset.playlistIndexAndTitle)
                    Text("Colección, índice y título").tag(DownloadFilenamePreset.playlistAndIndexAndTitle)
                }
                HelpPickerRow(
                    "Conflictos",
                    topic: ZEUVEHelpTopics.fileConflicts,
                    selection: $model.defaultSettings.conflictPolicy
                ) {
                    Text("Renombrar automáticamente").tag(DownloadConflictPolicy.renameAutomatically)
                    Text("Omitir").tag(DownloadConflictPolicy.skip)
                    Text("Reemplazar con confirmación").tag(DownloadConflictPolicy.replaceConfirmed)
                }
                HelpToggleRow(
                    "Crear una carpeta para la lista",
                    topic: ZEUVEHelpTopics.playlistFolder,
                    isOn: $model.defaultSettings.createPlaylistFolder
                )
                HelpToggleRow(
                    "Numerar elementos de listas",
                    topic: ZEUVEHelpTopics.playlistNumbering,
                    isOn: $model.defaultSettings.numberPlaylistItems
                )
            }

            Section("Metadatos y archivos auxiliares") {
                HelpToggleRow("Incrustar metadatos", topic: ZEUVEHelpTopics.embedMetadata, isOn: $model.defaultSettings.metadata.embedMetadata)
                HelpToggleRow("Incrustar miniatura", topic: ZEUVEHelpTopics.thumbnails, isOn: $model.defaultSettings.metadata.embedThumbnail)
                HelpToggleRow("Guardar miniatura por separado", topic: ZEUVEHelpTopics.thumbnails, isOn: $model.defaultSettings.metadata.saveThumbnail)
                HelpToggleRow("Añadir capítulos", topic: ZEUVEHelpTopics.chapters, isOn: $model.defaultSettings.metadata.addChapters)
                HelpToggleRow("Guardar descripción", topic: ZEUVEHelpTopics.descriptionAndJSON, isOn: $model.defaultSettings.metadata.saveDescription)
                HelpToggleRow("Guardar JSON informativo", topic: ZEUVEHelpTopics.descriptionAndJSON, isOn: $model.defaultSettings.metadata.saveInfoJSON)
                HelpToggleRow("Conservar la fecha de publicación", topic: ZEUVEHelpTopics.publicationDate, isOn: $model.defaultSettings.metadata.preservePublicationDate)
                HelpToggleRow("Guardar metadatos de la lista", topic: ZEUVEHelpTopics.descriptionAndJSON, isOn: $model.defaultSettings.metadata.savePlaylistMetadata)
            }

            Section("Procedencia de vídeos encontrados en páginas") {
                HelpToggleRow(
                    "Guardar procedencia en los metadatos del archivo",
                    topic: ZEUVEHelpTopics.pageSourceMetadata,
                    isOn: $model.defaultSettings.pageSource.embedSourceMetadata
                )
                HelpToggleRow(
                    "Añadir la fecha de descarga",
                    topic: ZEUVEHelpTopics.pageSourceDownloadDate,
                    isOn: $model.defaultSettings.pageSource.includeDownloadDate
                )
                .disabled(!model.defaultSettings.pageSource.embedSourceMetadata)
                HelpToggleRow(
                    "Añadir «De dónde» de macOS",
                    topic: ZEUVEHelpTopics.macOSWhereFrom,
                    isOn: $model.defaultSettings.pageSource.applyMacOSWhereFrom
                )
                Text("Estos valores se aplicarán a operaciones nuevas. Las opciones de formato y los presets no modifican los vídeos encontrados al analizar una página.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Subtítulos") {
                HStack(spacing: 6) {
                    TextField("Idiomas separados por comas", text: subtitleLanguages)
                    ContextualHelpButton(topic: ZEUVEHelpTopics.subtitles)
                }
                HelpToggleRow("Incluir subtítulos automáticos", topic: ZEUVEHelpTopics.subtitles, isOn: $model.defaultSettings.subtitles.includeAutomatic)
                HelpToggleRow("Incrustar subtítulos", topic: ZEUVEHelpTopics.subtitles, isOn: $model.defaultSettings.subtitles.embed)
                HelpToggleRow("Convertir subtítulos a SRT", topic: ZEUVEHelpTopics.subtitles, isOn: $model.defaultSettings.subtitles.convertToSRT)
            }

            Section("Red") {
                HelpToggleRow(
                    "Permitir HTTP y direcciones de la red local",
                    topic: ZEUVEHelpTopics.insecureLocalNetwork,
                    isOn: $model.defaultSettings.network.allowInsecureLocalNetwork
                )
                Text("Desactivado por seguridad. Solo debe habilitarse para servidores locales de confianza.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HelpStepperRow(
                    "Reintentos: \(model.defaultSettings.network.retryCount)",
                    topic: ZEUVEHelpTopics.retries,
                    value: $model.defaultSettings.network.retryCount,
                    in: 0...100
                )
                HelpStepperRow(
                    "Reintentos de fragmentos: \(model.defaultSettings.network.fragmentRetryCount)",
                    topic: ZEUVEHelpTopics.retries,
                    value: $model.defaultSettings.network.fragmentRetryCount,
                    in: 0...100
                )
                HelpStepperRow(
                    "Tiempo de espera: \(model.defaultSettings.network.connectionTimeoutSeconds) s",
                    topic: ZEUVEHelpTopics.retries,
                    value: $model.defaultSettings.network.connectionTimeoutSeconds,
                    in: 5...120
                )
                HelpToggleRow(
                    "Aceleración automática en vídeos encontrados en páginas",
                    topic: ZEUVEHelpTopics.adaptivePageFragments,
                    isOn: $model.defaultSettings.network.adaptivePageFragments
                )
                if !model.defaultSettings.network.adaptivePageFragments {
                    HelpStepperRow(
                        "Fragmentos simultáneos: \(model.defaultSettings.network.concurrentFragments)",
                        topic: ZEUVEHelpTopics.concurrentFragments,
                        value: $model.defaultSettings.network.concurrentFragments,
                        in: 1...16
                    )
                }
                TextField("Límite de velocidad opcional, por ejemplo 5M", text: speedLimit)
            }

            Section("Operación actual") {
                Button("Aplicar estos valores a la operación actual") {
                    model.applyDefaultSettingsToCurrentOperation()
                }
                .disabled(model.state.isBusy)
            }

            Section("Restablecer") {
                Button("Restaurar valores predeterminados", role: .destructive) {
                    confirmRestore = true
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .onChange(of: model.defaultSettings) { _, _ in model.persistDefaultSettings() }
        .onChange(of: model.defaultAdvancedMode) { _, _ in model.persistDefaultSettings() }
        .confirmationDialog(
            "¿Restaurar los ajustes del Descargador universal?",
            isPresented: $confirmRestore,
            titleVisibility: .visible
        ) {
            Button("Restaurar", role: .destructive) { model.restoreDefaultSettings() }
            Button("Cancelar", role: .cancel) { }
        } message: {
            Text("Se recuperarán MP4, MP3 a 320 kbps, Título y el resto de valores iniciales. Los presets guardados no se eliminarán.")
        }
    }

    private var subtitleLanguages: Binding<String> {
        Binding(
            get: { model.defaultSettings.subtitles.languages.joined(separator: ", ") },
            set: { value in
                model.defaultSettings.subtitles.languages = value
                    .split(separator: ",")
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
            }
        )
    }

    private var speedLimit: Binding<String> {
        Binding(
            get: { model.defaultSettings.network.speedLimit ?? "" },
            set: { value in
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                model.defaultSettings.network.speedLimit = trimmed.isEmpty ? nil : trimmed
            }
        )
    }
}
