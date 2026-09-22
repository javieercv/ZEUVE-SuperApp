import Foundation
import SwiftUI
import UniversalDownloaderModule

struct UniversalDownloaderSettingsCard: View {
    @ObservedObject var model: UniversalDownloaderViewModel

    var body: some View {
        GroupBox("Configuración") {
            VStack(alignment: .leading, spacing: 14) {
                if model.hasPageDiscoveredSelection {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "arrow.down.doc")
                            .foregroundStyle(.blue)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(model.onlyPageDiscoveredSelection ? "Descarga original" : "Configuración mixta")
                                .font(.headline)
                            Text(model.onlyPageDiscoveredSelection
                                 ? "Estos vídeos proceden del análisis de una página. Se descargarán en la mejor calidad original disponible, sin conversión ni formato forzado."
                                 : "Las opciones de formato se aplicarán solo a los enlaces directos. Los vídeos encontrados en páginas conservarán su descarga original.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        ContextualHelpButton(topic: ZEUVEHelpTopics.pageOriginalDownload)
                    }
                    .padding(10)
                    .background(.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                }

                if !model.onlyPageDiscoveredSelection {
                if !model.presets.isEmpty {
                    HelpPickerRow(
                        "Aplicar preset",
                        topic: ZEUVEHelpTopics.quickPreset,
                        selection: quickPresetSelection
                    ) {
                        Text("Selecciona un preset").tag("")
                        ForEach(model.presets) { preset in
                            Text(preset.name).tag(preset.id.uuidString)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    HelpLabel("Modo", topic: ZEUVEHelpTopics.interfaceMode)
                    Picker("", selection: $model.advancedMode) {
                        Text("Simple").tag(false)
                        Text("Avanzado").tag(true)
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                }

                VStack(alignment: .leading, spacing: 6) {
                    HelpLabel("Contenido", topic: ZEUVEHelpTopics.downloadContent)
                    Picker("", selection: $model.settings.mode) {
                        Text("Automático por plataforma").tag(DownloadMode.automatic)
                        Text("Original").tag(DownloadMode.original)
                        Text("Vídeo").tag(DownloadMode.video)
                        Text("Solo audio").tag(DownloadMode.audio)
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                }

                if model.settings.mode == .automatic {
                    Label(
                        "Se aplicará el perfil configurado para la plataforma o el dominio de cada elemento.",
                        systemImage: "wand.and.stars"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                } else if model.settings.mode == .original {
                    Label("Se conservará el contenido original de máxima calidad sin conversión automática.", systemImage: "shippingbox")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if model.settings.mode == .video {
                    HelpPickerRow(
                        "Resolución máxima",
                        topic: ZEUVEHelpTopics.maximumResolution,
                        selection: $model.settings.maximumResolution
                    ) {
                        ForEach(MaximumResolution.allCases) { resolution in
                            Text(resolution.spanishName).tag(resolution)
                        }
                    }

                    HelpPickerRow(
                        "Formato del archivo",
                        topic: ZEUVEHelpTopics.videoFormat,
                        selection: $model.settings.container
                    ) {
                        ForEach(ContainerPreference.allCases) { container in
                            Text(container.spanishName).tag(container)
                        }
                    }

                    if model.advancedMode {
                        HelpPickerRow(
                            "Rango dinámico",
                            topic: ZEUVEHelpTopics.dynamicRange,
                            selection: $model.settings.hdrPreference
                        ) {
                            Text("Automático").tag(HDRPreference.automatic)
                            Text("Preferir SDR").tag(HDRPreference.preferSDR)
                            Text("Preferir HDR").tag(HDRPreference.preferHDR)
                        }
                    }
                } else if model.settings.mode == .audio {
                    HelpPickerRow(
                        "Formato de audio",
                        topic: ZEUVEHelpTopics.audioFormat,
                        selection: $model.settings.audioOutput
                    ) {
                        ForEach(AudioOutputFormat.allCases) { output in
                            Text(output.spanishName).tag(output)
                        }
                    }

                    if model.settings.audioOutput == .mp3 {
                        HelpPickerRow(
                            "Calidad MP3",
                            topic: ZEUVEHelpTopics.mp3Bitrate,
                            selection: $model.settings.mp3Bitrate
                        ) {
                            ForEach(MP3Bitrate.allCases) { bitrate in
                                Text(bitrate.spanishName).tag(bitrate)
                            }
                        }
                    }

                    if model.settings.audioOutput.requiresTranscoding {
                        Label("La conversión puede ser con pérdida y no mejora la calidad de origen.", systemImage: "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }

                if model.advancedMode { advancedOptions }
                } else {
                    pageNetworkOptions
                }
            }
            .padding(8)
        }
    }

    private var advancedOptions: some View {
        DisclosureGroup("Opciones avanzadas") {
            VStack(alignment: .leading, spacing: 12) {
                if model.settings.mode == .video {
                    HelpPickerRow(
                        "Flujo de vídeo exacto",
                        topic: ZEUVEHelpTopics.exactVideoStream,
                        selection: exactVideoFormatBinding
                    ) {
                        Text("Selección automática").tag("")
                        ForEach(model.availableVideoFormats) { format in
                            Text(formatLabel(format)).tag(format.formatID)
                        }
                    }
                    HelpPickerRow(
                        "Flujo de audio exacto",
                        topic: ZEUVEHelpTopics.exactAudioStream,
                        selection: exactAudioFormatBinding
                    ) {
                        Text("Mejor audio automático").tag("")
                        ForEach(model.availableAudioFormats) { format in
                            Text(formatLabel(format)).tag(format.formatID)
                        }
                    }
                    if model.exactFormatAnalysis == nil {
                        Text("La selección exacta se habilita cuando hay un único vídeo seleccionado. Para lotes se utilizan reglas automáticas compatibles.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Divider()
                } else if model.settings.mode == .audio {
                    HelpPickerRow(
                        "Flujo de audio exacto",
                        topic: ZEUVEHelpTopics.exactAudioStream,
                        selection: exactAudioFormatBinding
                    ) {
                        Text("Selección automática").tag("")
                        ForEach(model.availableAudioFormats) { format in
                            Text(formatLabel(format)).tag(format.formatID)
                        }
                    }
                    Divider()
                }

                HelpToggleRow("Incrustar metadatos", topic: ZEUVEHelpTopics.embedMetadata, isOn: $model.settings.metadata.embedMetadata)
                HelpToggleRow("Incrustar miniatura", topic: ZEUVEHelpTopics.thumbnails, isOn: $model.settings.metadata.embedThumbnail)
                HelpToggleRow("Guardar miniatura por separado", topic: ZEUVEHelpTopics.thumbnails, isOn: $model.settings.metadata.saveThumbnail)
                HelpToggleRow("Añadir capítulos", topic: ZEUVEHelpTopics.chapters, isOn: $model.settings.metadata.addChapters)
                HelpToggleRow("Guardar descripción", topic: ZEUVEHelpTopics.descriptionAndJSON, isOn: $model.settings.metadata.saveDescription)
                HelpToggleRow("Guardar JSON informativo", topic: ZEUVEHelpTopics.descriptionAndJSON, isOn: $model.settings.metadata.saveInfoJSON)
                HelpToggleRow("Conservar la fecha de publicación cuando sea posible", topic: ZEUVEHelpTopics.publicationDate, isOn: $model.settings.metadata.preservePublicationDate)
                HelpToggleRow("Guardar metadatos de la lista seleccionada", topic: ZEUVEHelpTopics.descriptionAndJSON, isOn: $model.settings.metadata.savePlaylistMetadata)

                Divider()
                HStack(spacing: 6) {
                    TextField("Idiomas de subtítulos, separados por comas", text: subtitleLanguages)
                    ContextualHelpButton(topic: ZEUVEHelpTopics.subtitles)
                }
                if !model.availableSubtitleTracks.isEmpty {
                    ScrollView(.horizontal) {
                        HStack {
                            ForEach(model.availableSubtitleTracks) { track in
                                Button { toggleSubtitle(track.languageCode) } label: {
                                    Label(
                                        track.languageCode + (track.kind == .automatic ? " · automático" : " · manual"),
                                        systemImage: model.settings.subtitles.languages.contains(track.languageCode) ? "checkmark.circle.fill" : "circle"
                                    )
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    }
                    Text("Los subtítulos manuales los aporta el servicio de origen. Los automáticos pueden contener errores.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                HelpToggleRow("Incluir subtítulos automáticos", topic: ZEUVEHelpTopics.subtitles, isOn: $model.settings.subtitles.includeAutomatic)
                HelpToggleRow("Incrustar subtítulos", topic: ZEUVEHelpTopics.subtitles, isOn: $model.settings.subtitles.embed)
                HelpToggleRow("Convertir subtítulos a SRT", topic: ZEUVEHelpTopics.subtitles, isOn: $model.settings.subtitles.convertToSRT)

                Divider()
                networkAndAccessOptions
            }
            .padding(.top, 8)
        }
    }

    private var pageNetworkOptions: some View {
        DisclosureGroup("Red y acceso") {
            VStack(alignment: .leading, spacing: 12) {
                networkAndAccessOptions
            }
            .padding(.top, 8)
        }
    }

    @ViewBuilder private var networkAndAccessOptions: some View {
        HelpToggleRow(
            "Permitir HTTP y direcciones de la red local",
            topic: ZEUVEHelpTopics.insecureLocalNetwork,
            isOn: $model.settings.network.allowInsecureLocalNetwork
        )
        Text("Desactivado por seguridad. Actívalo solo para páginas o servidores locales de confianza.")
            .font(.caption)
            .foregroundStyle(.secondary)
        HelpToggleRow("Usar proxy solo en esta operación", topic: ZEUVEHelpTopics.proxy, isOn: $model.proxyEnabled)
        if model.proxyEnabled {
            TextField("https://proxy.ejemplo:8080", text: $model.proxyAddress)
            TextField("Usuario opcional", text: $model.proxyUsername)
            SecureField("Contraseña (no se guardará)", text: $model.proxyPassword)
        }
        HelpStepperRow(
            "Reintentos: \(model.settings.network.retryCount)",
            topic: ZEUVEHelpTopics.retries,
            value: $model.settings.network.retryCount,
            in: 0...100
        )
        if model.hasPageDiscoveredSelection {
            HelpToggleRow(
                "Aceleración automática de vídeos segmentados",
                topic: ZEUVEHelpTopics.adaptivePageFragments,
                isOn: $model.settings.network.adaptivePageFragments
            )
        }
        if !model.hasPageDiscoveredSelection || !model.settings.network.adaptivePageFragments {
            HelpStepperRow(
                "Fragmentos simultáneos: \(model.settings.network.concurrentFragments)",
                topic: ZEUVEHelpTopics.concurrentFragments,
                value: $model.settings.network.concurrentFragments,
                in: 1...16
            )
        }
        HStack {
            HelpLabel("Cookies", topic: ZEUVEHelpTopics.cookies)
            Text(model.cookiesFile?.lastPathComponent ?? "No se utilizan")
                .foregroundStyle(.secondary)
            Spacer()
            Button("Seleccionar cookies.txt") { model.chooseCookiesFile() }
            if model.cookiesFile != nil { Button("Quitar") { model.clearCookiesFile() } }
        }
        HelpToggleRow(
            "Usar sesión temporal del navegador",
            topic: ZEUVEHelpTopics.cookies,
            isOn: $model.browserCookiesEnabled
        )
        .disabled(model.cookiesFile != nil)
        if model.browserCookiesEnabled && model.cookiesFile == nil {
            Picker("Navegador", selection: $model.browserCookieSource) {
                ForEach(DownloadBrowserCookieSource.allCases) { browser in
                    Text(browser.displayName).tag(browser)
                }
            }
            .frame(maxWidth: 220)
            Text("Solo se consulta al pulsar Analizar o Descargar. La sesión no se copia ni se guarda en ZEUVE; macOS puede solicitar permiso para acceder al navegador.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        Button("Abrir carpeta de registros", systemImage: "doc.text.magnifyingglass") { model.openLogsFolder() }
    }

    private var quickPresetSelection: Binding<String> {
        Binding(
            get: { model.selectedPresetID?.uuidString ?? "" },
            set: { value in
                guard let id = UUID(uuidString: value), let preset = model.presets.first(where: { $0.id == id }) else {
                    model.selectedPresetID = nil
                    return
                }
                model.applyPreset(preset)
            }
        )
    }

    private var exactVideoFormatBinding: Binding<String> {
        Binding(
            get: { model.settings.exactVideoFormatID ?? "" },
            set: { model.settings.exactVideoFormatID = $0.isEmpty ? nil : $0 }
        )
    }

    private var exactAudioFormatBinding: Binding<String> {
        Binding(
            get: { model.settings.exactAudioFormatID ?? "" },
            set: { model.settings.exactAudioFormatID = $0.isEmpty ? nil : $0 }
        )
    }

    private func formatLabel(_ format: YTDLPFormat) -> String {
        var parts = [format.formatID]
        if let height = format.height { parts.append("\(height)p") }
        if let fps = format.fps { parts.append("\(Int(fps)) fps") }
        if let ext = format.extensionName { parts.append(ext.uppercased()) }
        if let vcodec = format.videoCodec, vcodec != "none" { parts.append(vcodec) }
        if let acodec = format.audioCodec, acodec != "none" { parts.append(acodec) }
        if let size = format.bestKnownSize { parts.append(ByteCountFormatter.string(fromByteCount: size, countStyle: .file)) }
        if format.dynamicRange == .hdr { parts.append("HDR") }
        return parts.joined(separator: " · ")
    }

    private func toggleSubtitle(_ language: String) {
        if let index = model.settings.subtitles.languages.firstIndex(of: language) {
            model.settings.subtitles.languages.remove(at: index)
        } else {
            model.settings.subtitles.languages.append(language)
        }
    }

    private var subtitleLanguages: Binding<String> {
        Binding(get: { model.settings.subtitles.languages.joined(separator: ",") }, set: { model.settings.subtitles.languages = $0.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty } })
    }

}
