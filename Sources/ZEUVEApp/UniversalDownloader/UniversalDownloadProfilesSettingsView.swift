import SwiftUI
import UniversalDownloaderModule

struct UniversalDownloadProfilesSettingsView: View {
    @ObservedObject var model: UniversalDownloaderViewModel
    @State private var selectedPlatform: UniversalDownloadPlatform = .youtube
    @State private var selectedCustomID: UUID?
    @State private var showingAddProfile = false
    @State private var confirmRestoreAll = false

    var body: some View {
        Form {
            Section {
                Picker("Plataforma", selection: $selectedPlatform) {
                    ForEach(UniversalDownloadProfiles.configurablePlatforms) { platform in
                        Text(platform.spanishName).tag(platform)
                    }
                }
                .pickerStyle(.menu)

                Label(
                    "Este perfil define qué significa «Por defecto de la plataforma» para \(selectedPlatform.spanishName).",
                    systemImage: "slider.horizontal.3"
                )
                .font(.caption)
                .foregroundStyle(.secondary)

                Menu("Aplicar un preset") {
                    ForEach(model.presets) { preset in
                        Button(preset.name) { platformSettings.wrappedValue = preset.settings }
                    }
                }
                .disabled(model.presets.isEmpty)

                Button("Restaurar \(selectedPlatform.spanishName)", role: .destructive) {
                    model.restorePlatformProfile(selectedPlatform)
                }
            } header: {
                Text("Plataformas incorporadas")
            } footer: {
                Text("Los valores de fábrica solo se conservan para restaurarlos. El perfil que edites será el utilizado en las operaciones futuras.")
            }

            DownloadProfileSettingsEditor(settings: platformSettings)

            Section {
                Button("Añadir plataforma personalizada") { showingAddProfile = true }

                if model.downloadProfiles.customProfiles.isEmpty {
                    ContentUnavailableView(
                        "No hay plataformas personalizadas",
                        systemImage: "globe.badge.chevron.backward",
                        description: Text("Añade un enlace de ejemplo para aplicar ajustes propios a ese dominio.")
                    )
                } else {
                    ForEach(model.downloadProfiles.customProfiles) { profile in
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(profile.name).font(.headline)
                                Text(profile.host).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            if !profile.isEnabled {
                                Text("Desactivada").font(.caption).foregroundStyle(.secondary)
                            }
                            Button("Editar") { selectedCustomID = profile.id }
                        }
                    }
                }
            } header: {
                Text("Plataformas personalizadas")
            } footer: {
                Text("ZEUVE guarda únicamente el dominio normalizado. Crear una regla no añade compatibilidad a una web que los motores no puedan resolver.")
            }

            Section("Restablecer") {
                Button("Restaurar todas las plataformas incorporadas", role: .destructive) {
                    confirmRestoreAll = true
                }
                Text("Las plataformas personalizadas no se eliminarán.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
        .onChange(of: model.downloadProfiles) { _, _ in model.persistDownloadProfiles() }
        .sheet(isPresented: $showingAddProfile) {
            AddCustomDownloadProfileView(model: model)
        }
        .sheet(isPresented: Binding(
            get: { selectedCustomID != nil },
            set: { if !$0 { selectedCustomID = nil } }
        )) {
            if let selectedCustomID {
                EditCustomDownloadProfileView(model: model, profileID: selectedCustomID)
            }
        }
        .confirmationDialog(
            "¿Restaurar todas las plataformas incorporadas?",
            isPresented: $confirmRestoreAll,
            titleVisibility: .visible
        ) {
            Button("Restaurar", role: .destructive) { model.restoreAllPlatformProfiles() }
            Button("Cancelar", role: .cancel) { }
        } message: {
            Text("Se recuperarán las recomendaciones incluidas de ZEUVE. Las reglas personalizadas permanecerán intactas.")
        }
    }

    private var platformSettings: Binding<UniversalDownloadSettings> {
        Binding(
            get: { model.downloadProfiles.profile(for: selectedPlatform).settings },
            set: { model.downloadProfiles.setSettings($0, for: selectedPlatform) }
        )
    }
}

private struct DownloadProfileSettingsEditor: View {
    @Binding var settings: UniversalDownloadSettings

    var body: some View {
        Section("Contenido, formato y calidad") {
            HelpPickerRow(
                "Contenido predeterminado",
                topic: ZEUVEHelpTopics.downloadContent,
                selection: $settings.mode
            ) {
                Text("Original sin convertir").tag(DownloadMode.original)
                Text("Vídeo").tag(DownloadMode.video)
                Text("Solo audio").tag(DownloadMode.audio)
            }

            if settings.mode == .video {
                HelpPickerRow(
                    "Resolución máxima",
                    topic: ZEUVEHelpTopics.maximumResolution,
                    selection: $settings.maximumResolution
                ) {
                    ForEach(MaximumResolution.allCases) { resolution in
                        Text(resolution.spanishName).tag(resolution)
                    }
                }
                HelpPickerRow(
                    "Formato del archivo",
                    topic: ZEUVEHelpTopics.videoFormat,
                    selection: $settings.container
                ) {
                    ForEach(ContainerPreference.allCases) { container in
                        Text(container.spanishName).tag(container)
                    }
                }
                HelpPickerRow(
                    "Rango dinámico",
                    topic: ZEUVEHelpTopics.dynamicRange,
                    selection: $settings.hdrPreference
                ) {
                    Text("Automático").tag(HDRPreference.automatic)
                    Text("Preferir SDR").tag(HDRPreference.preferSDR)
                    Text("Preferir HDR").tag(HDRPreference.preferHDR)
                }
            } else if settings.mode == .audio {
                HelpPickerRow(
                    "Formato de audio",
                    topic: ZEUVEHelpTopics.audioFormat,
                    selection: $settings.audioOutput
                ) {
                    ForEach(AudioOutputFormat.allCases) { output in
                        Text(output.spanishName).tag(output)
                    }
                }
                if settings.audioOutput == .mp3 {
                    HelpPickerRow(
                        "Calidad MP3",
                        topic: ZEUVEHelpTopics.mp3Bitrate,
                        selection: $settings.mp3Bitrate
                    ) {
                        ForEach(MP3Bitrate.allCases) { bitrate in
                            Text(bitrate.spanishName).tag(bitrate)
                        }
                    }
                }
            } else {
                Text("Se conservará el archivo original de mayor calidad que ofrezca la web, sin extraer audio ni forzar un contenedor.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }

        Section("Nombre, listas y conflictos") {
            HelpPickerRow("Nombre de archivo", topic: ZEUVEHelpTopics.filename, selection: $settings.filenamePreset) {
                Text("Título").tag(DownloadFilenamePreset.title)
                Text("Título e ID").tag(DownloadFilenamePreset.titleAndID)
                Text("Fecha y título").tag(DownloadFilenamePreset.dateAndTitle)
                Text("Canal y título").tag(DownloadFilenamePreset.channelAndTitle)
                Text("Índice y título").tag(DownloadFilenamePreset.playlistIndexAndTitle)
                Text("Colección, índice y título").tag(DownloadFilenamePreset.playlistAndIndexAndTitle)
            }
            HelpPickerRow("Conflictos", topic: ZEUVEHelpTopics.fileConflicts, selection: $settings.conflictPolicy) {
                Text("Renombrar automáticamente").tag(DownloadConflictPolicy.renameAutomatically)
                Text("Omitir").tag(DownloadConflictPolicy.skip)
                Text("Reemplazar con confirmación").tag(DownloadConflictPolicy.replaceConfirmed)
            }
            HelpToggleRow("Crear una carpeta para la lista", topic: ZEUVEHelpTopics.playlistFolder, isOn: $settings.createPlaylistFolder)
            HelpToggleRow("Numerar elementos de listas", topic: ZEUVEHelpTopics.playlistNumbering, isOn: $settings.numberPlaylistItems)
        }

        Section("Metadatos y archivos auxiliares") {
            HelpToggleRow("Incrustar metadatos", topic: ZEUVEHelpTopics.embedMetadata, isOn: $settings.metadata.embedMetadata)
            HelpToggleRow("Incrustar miniatura", topic: ZEUVEHelpTopics.thumbnails, isOn: $settings.metadata.embedThumbnail)
            HelpToggleRow("Guardar miniatura por separado", topic: ZEUVEHelpTopics.thumbnails, isOn: $settings.metadata.saveThumbnail)
            HelpToggleRow("Añadir capítulos", topic: ZEUVEHelpTopics.chapters, isOn: $settings.metadata.addChapters)
            HelpToggleRow("Guardar descripción", topic: ZEUVEHelpTopics.descriptionAndJSON, isOn: $settings.metadata.saveDescription)
            HelpToggleRow("Guardar JSON informativo", topic: ZEUVEHelpTopics.descriptionAndJSON, isOn: $settings.metadata.saveInfoJSON)
            HelpToggleRow("Conservar fecha de publicación", topic: ZEUVEHelpTopics.publicationDate, isOn: $settings.metadata.preservePublicationDate)
            HelpToggleRow("Guardar metadatos de la lista", topic: ZEUVEHelpTopics.descriptionAndJSON, isOn: $settings.metadata.savePlaylistMetadata)
        }

        Section("Subtítulos") {
            TextField("Idiomas separados por comas", text: subtitleLanguages)
            HelpToggleRow("Incluir subtítulos automáticos", topic: ZEUVEHelpTopics.subtitles, isOn: $settings.subtitles.includeAutomatic)
            HelpToggleRow("Incrustar subtítulos", topic: ZEUVEHelpTopics.subtitles, isOn: $settings.subtitles.embed)
            HelpToggleRow("Convertir subtítulos a SRT", topic: ZEUVEHelpTopics.subtitles, isOn: $settings.subtitles.convertToSRT)
        }

        Section("Procedencia de páginas") {
            HelpToggleRow("Guardar procedencia en metadatos", topic: ZEUVEHelpTopics.pageSourceMetadata, isOn: $settings.pageSource.embedSourceMetadata)
            HelpToggleRow("Añadir fecha de descarga", topic: ZEUVEHelpTopics.pageSourceDownloadDate, isOn: $settings.pageSource.includeDownloadDate)
                .disabled(!settings.pageSource.embedSourceMetadata)
            HelpToggleRow("Añadir «De dónde» de macOS", topic: ZEUVEHelpTopics.macOSWhereFrom, isOn: $settings.pageSource.applyMacOSWhereFrom)
        }
    }

    private var subtitleLanguages: Binding<String> {
        Binding(
            get: { settings.subtitles.languages.joined(separator: ", ") },
            set: { value in
                settings.subtitles.languages = value
                    .split(separator: ",")
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
            }
        )
    }
}

private struct AddCustomDownloadProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var model: UniversalDownloaderViewModel
    @State private var name = ""
    @State private var address = ""
    @State private var includesSubdomains = true

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Añadir plataforma personalizada").font(.title2.bold())
            TextField("Nombre opcional", text: $name)
            TextField("Enlace de ejemplo o dominio", text: $address)
            Toggle("Aplicar también a los subdominios", isOn: $includesSubdomains)
            Text("Se guardará únicamente el dominio. La ruta, los parámetros y posibles identificadores del enlace se descartarán.")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack {
                Spacer()
                Button("Cancelar", role: .cancel) { dismiss() }
                Button("Añadir") {
                    if model.addCustomDownloadProfile(name: name, address: address, includesSubdomains: includesSubdomains) != nil {
                        dismiss()
                    }
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(minWidth: 480)
    }
}

private struct EditCustomDownloadProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var model: UniversalDownloaderViewModel
    let profileID: UUID
    @State private var confirmDelete = false

    var body: some View {
        NavigationStack {
            Form {
                if let binding = profileBinding {
                    Section("Regla") {
                        TextField("Nombre", text: binding.name)
                        LabeledContent("Dominio", value: binding.wrappedValue.host)
                        Toggle("Activada", isOn: binding.isEnabled)
                        Toggle("Incluir subdominios", isOn: binding.includesSubdomains)
                        Menu("Aplicar un preset") {
                            ForEach(model.presets) { preset in
                                Button(preset.name) { binding.settings.wrappedValue = preset.settings }
                            }
                        }
                        .disabled(model.presets.isEmpty)
                        Text("Para cambiar el dominio, elimina esta regla y crea otra. Así no se guarda accidentalmente un dominio incompleto mientras lo escribes.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    DownloadProfileSettingsEditor(settings: binding.settings)
                    Section {
                        Button("Eliminar regla", role: .destructive) { confirmDelete = true }
                    }
                } else {
                    ContentUnavailableView("La regla ya no existe", systemImage: "exclamationmark.triangle")
                }
            }
            .formStyle(.grouped)
            .navigationTitle(profileBinding?.wrappedValue.name ?? "Plataforma personalizada")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Cerrar") { dismiss() } }
            }
            .onChange(of: model.downloadProfiles) { _, _ in model.persistDownloadProfiles() }
            .confirmationDialog("¿Eliminar esta plataforma personalizada?", isPresented: $confirmDelete) {
                Button("Eliminar", role: .destructive) {
                    model.deleteCustomDownloadProfile(id: profileID)
                    dismiss()
                }
                Button("Cancelar", role: .cancel) { }
            }
        }
        .frame(minWidth: 620, minHeight: 720)
    }

    private var profileBinding: Binding<UniversalCustomDownloadProfile>? {
        guard let index = model.downloadProfiles.customProfiles.firstIndex(where: { $0.id == profileID }) else { return nil }
        return Binding(
            get: { model.downloadProfiles.customProfiles[index] },
            set: { model.downloadProfiles.customProfiles[index] = $0 }
        )
    }
}
