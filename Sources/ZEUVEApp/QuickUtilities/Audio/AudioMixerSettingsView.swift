import SwiftUI
import AppKit
import ZEUVEQuickUtilities

struct AudioMixerSettingsView: View {
    let service: ApplicationAudioMixerService
    @State private var revision = 0
    @State private var localLevels: [String: AudioApplicationLevel] = [:]
    @State private var busy = false
    @State private var error: String?
    var body: some View {
        let _ = revision
        return VStack(alignment: .leading, spacing: 12) {
            Text("Selecciona una fuente cambiando su volumen o silenciándola. No selecciones aplicaciones ni pestañas que reproduzcan conversaciones.")
                .font(.callout).foregroundStyle(.secondary)
            Text("Solo se procesa audio de la aplicación elegida, en memoria. No se utiliza el micrófono ni se cambia el volumen maestro. Al cambiar la salida o los procesos se recupera el sonido original; vuelve a elegir la fuente.")
                .font(.caption).foregroundStyle(.secondary)
            if service.state != .active {
                Text("Activa el mezclador para descubrir aplicaciones que estén reproduciendo audio.")
            } else if service.routing.sources.isEmpty {
                Text("No hay aplicaciones con salida de audio identificable. Inicia la reproducción en una aplicación.")
            } else {
                ForEach(service.routing.sources) { source in
                    HStack {
                        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: source.id) {
                            Image(nsImage: NSWorkspace.shared.icon(forFile: url.path)).resizable().frame(width: 24, height: 24)
                        }
                        VStack(alignment: .leading) {
                            Text(source.name)
                            if let limitation = source.limitation { Text(limitation).font(.caption).foregroundStyle(.secondary) }
                            else { Text(service.routing.routedSourceIDs.contains(source.id) ? "Procesando salida" : "Salida original").font(.caption).foregroundStyle(.secondary) }
                        }.frame(minWidth: 150, alignment: .leading)
                        Slider(value: Binding(get: { Double(level(source.id).gain) }, set: { value in
                            var option = level(source.id); option.gain = Float(value); localLevels[source.id] = option
                        }), in: 0...1, onEditingChanged: { editing in if !editing { apply(source.id) } })
                        .accessibilityLabel("Volumen de \(source.name)")
                        Text("\(Int(level(source.id).gain * 100)) %").monospacedDigit().frame(width: 48)
                        Toggle("Silencio", isOn: Binding(get: { level(source.id).muted }, set: { muted in
                            var option = level(source.id); option.muted = muted; localLevels[source.id] = option; apply(source.id)
                        }))
                    }.disabled(!source.supportsRouting || busy)
                }
            }
            if let error { Text(error).foregroundStyle(.red).font(.callout) }
        }
        .onAppear { service.contentDidChange = { revision += 1; localLevels.removeAll() } }
        .onDisappear { service.contentDidChange = nil }
    }
    private func level(_ id: String) -> AudioApplicationLevel {
        localLevels[id] ?? service.routing.preferences.levels[id] ?? AudioApplicationLevel()
    }
    private func apply(_ id: String) {
        guard !busy else { return }; let option = level(id); busy = true; error = nil
        Task { @MainActor in
            defer { busy = false }
            do { try await service.setLevel(sourceID: id, level: option) }
            catch { self.error = error.localizedDescription; localLevels.removeValue(forKey: id) }
        }
    }
}

struct AudioProtectionSettingsView: View {
    let service: CallAudioProtectionService
    @State private var revision = 0
    @State private var selected: Set<String> = []
    @State private var callPrepared = false
    @State private var error: String?
    var body: some View {
        let _ = revision
        return VStack(alignment: .leading, spacing: 10) {
            Label("Protección pendiente de validación", systemImage: "waveform.badge.shield")
            Text(CallAudioProtectionService.limitation).font(.callout).foregroundStyle(.secondary)
            Text("Prueba funcional: prepara tú una llamada de FaceTime con altavoces internos y reproduce música o vídeo. Compara la salida original antes y durante la llamada; después inicia y detén esta ruta para comprobar si cambia la atenuación. No selecciones aplicaciones ni pestañas con conversaciones.")
                .font(.caption).foregroundStyle(.secondary)
            Text("La prueba vuelve a reproducir únicamente las fuentes elegidas al 100 %, sin cambiar el volumen maestro. Necesita permiso de captura de audio del sistema. No graba ni persiste audio o resultados. Sigue ejecutándose hasta detenerla o salir de ZEUVE.")
                .font(.caption).foregroundStyle(.secondary)
            Text(service.diagnosticState.title).font(.callout)
            Button("Buscar fuentes en reproducción") { run { try await service.prepareDiagnostic() } }
                .disabled(service.diagnosticState.isTransitioning || service.isDiagnosticRunning)
            ForEach(service.diagnosticSources) { source in
                VStack(alignment: .leading, spacing: 3) {
                    Toggle(source.name, isOn: Binding(get: { selected.contains(source.id) }, set: { value in
                        if value { selected.insert(source.id) } else { selected.remove(source.id) }
                    }))
                    .disabled(service.diagnosticState.isTransitioning || service.isDiagnosticRunning || service.routing.diagnosticAvailabilityReason(sourceID: source.id) != nil)
                    if let limitation = service.routing.diagnosticAvailabilityReason(sourceID: source.id) {
                        Text(limitation).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            Toggle("He preparado FaceTime y estas fuentes solo reproducen música o vídeo", isOn: $callPrepared)
                .disabled(service.isDiagnosticRunning || service.diagnosticState.isTransitioning)
            HStack {
                Button("Probar ruta durante FaceTime") { run { try await service.beginDiagnostic(sourceIDs: selected) } }
                    .disabled(!callPrepared || selected.isEmpty || service.isDiagnosticRunning || service.diagnosticState.isTransitioning)
                Button("Detener prueba") { run { try await service.stopDiagnostic() } }
                    .disabled(service.diagnosticState == .idle)
            }
            if service.isDiagnosticRunning {
                Text("Niveles internos de la señal; no miden el volumen real de los altavoces ni acreditan que la protección funcione.")
                    .font(.caption).foregroundStyle(.secondary)
                if service.meters.isEmpty { Text("Esperando buffers de audio de las fuentes elegidas…").font(.caption) }
                ForEach(service.meters) { meter in
                    let name = service.diagnosticSources.first { $0.id == meter.id }?.name ?? "Fuente de audio"
                    Text("\(name): entrada \(level(meter.inputRMS)) dBFS · salida \(level(meter.outputRMS)) dBFS · \(meter.callbackCount) buffers")
                        .font(.caption).monospacedDigit()
                }
            }
            if let error { Text(error).foregroundStyle(.red).font(.callout) }
        }
        .onAppear { service.contentDidChange = { revision += 1 } }
        .onDisappear { service.contentDidChange = nil }
        .task {
            while !Task.isCancelled {
                do {
                    if service.isDiagnosticRunning { try await service.refreshDiagnosticMeters() }
                    try await Task.sleep(for: .milliseconds(500))
                } catch is CancellationError { return }
                catch { self.error = error.localizedDescription; return }
            }
        }
    }
    private func level(_ amplitude: Float) -> String {
        guard let decibels = AudioRouteMeter.decibels(amplitude) else { return "−∞" }
        return String(format: "%.1f", decibels)
    }
    private func run(_ action: @escaping @MainActor () async throws -> Void) {
        error = nil
        Task { @MainActor in
            do { try await action() }
            catch { self.error = error.localizedDescription }
            revision += 1
        }
    }
}
