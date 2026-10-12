import SwiftUI
import AppKit
import ZEUVEQuickUtilities

struct ScrollDirectionSettingsView: View {
    @ObservedObject var service: ScrollDirectionService
    @State private var error: String?
    @State private var saving = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle("Invertir desplazamiento vertical de la rueda", isOn: binding(\.invertVertical))
            Toggle("Invertir desplazamiento horizontal de la rueda", isOn: binding(\.invertHorizontal))
            Text("Se aplica a eventos discretos de rueda. Los eventos continuos y gestos conservan el comportamiento de macOS. La opción invierte la dirección actual; no cambia los ajustes del sistema.")
                .font(.caption).foregroundStyle(.secondary)
            Text("El Logitech G305 es el primer ratón previsto para validación. Esta opción no identifica el ratón físico y afecta a todas las ruedas discretas compatibles. No se garantiza el comportamiento junto a otros controladores de desplazamiento.")
                .font(.caption).foregroundStyle(.secondary)
            Button("Autorizar Accesibilidad…") { InputEventTapBroker.requestAccessibilityPermission() }
            if service.otherInputFiltersDetected {
                Text("Se detectó otro filtro de entrada activo. Comprueba que no aplique también una inversión o asignación de botones.").font(.caption).foregroundStyle(.orange)
            }
            if let message = error ?? service.settingsError { Text(message).font(.caption).foregroundStyle(.red) }
        }
        .disabled(saving)
    }
    private func binding(_ key: WritableKeyPath<ScrollDirectionOptions, Bool>) -> Binding<Bool> {
        Binding(get: { service.options[keyPath: key] }, set: { value in
            var options = service.options; options[keyPath: key] = value
            saving = true
            Task { @MainActor in
                defer { saving = false }
                do { try await service.updateOptions(options); error = nil }
                catch { self.error = error.localizedDescription }
            }
        })
    }
}

struct AdditionalMouseButtonsSettingsView: View {
    @ObservedObject var service: AdditionalMouseButtonsService
    @State private var error: String?
    @State private var saving = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Las asignaciones se aplican por número de botón a todos los ratones compatibles. Se protegen los botones primario, secundario y central. No se instalan drivers ni se crean perfiles físicos.")
                .font(.caption).foregroundStyle(.secondary)
            HStack {
                Button(service.isCapturing ? "Pulsa un botón adicional…" : "Detectar botón adicional") {
                    run { try await service.captureButton() }
                }.disabled(service.isCapturing || saving)
                if service.isCapturing { Button("Cancelar") { run { try await service.cancelCapture() } } }
                Button("Autorizar Accesibilidad…") { InputEventTapBroker.requestAccessibilityPermission() }
            }
            if service.isCapturing {
                Text("Captura durante 15 segundos. La pulsación mantiene su comportamiento original. No se registran teclas.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            ForEach(buttons, id: \.self) { button in
                VStack(alignment: .leading, spacing: 7) {
                    HStack {
                        Text("Botón \(button + 1) (índice \(button))").fontWeight(.medium)
                        Spacer()
                        MouseActionShortcutRecorder(shortcut: service.options.assignments[button]) { shortcut in
                            run { try await service.assign(shortcut, to: button) }
                        }
                        if service.options.assignments[button] != nil {
                            Button("Quitar") { run { try await service.assign(nil, to: button) } }
                        }
                    }
                    HStack {
                        preset("Atrás (navegador)", shortcut: .back, button: button)
                        preset("Adelante (navegador)", shortcut: .forward, button: button)
                        preset("Mission Control (⌃↑)", shortcut: .missionControl, button: button)
                        preset("Escritorio (F11)", shortcut: .showDesktop, button: button)
                    }.buttonStyle(.borderless)
                }.padding(.vertical, 4)
            }
            if buttons.isEmpty { Text("Detecta un botón y asígnale un atajo antes de activar esta utilidad.").font(.caption).foregroundStyle(.secondary) }
            Text("Los presets envían el atajo indicado. Atrás/Adelante requieren un navegador compatible. Mission Control y Escritorio requieren que esos atajos estén habilitados en macOS; si los cambiaste, captura aquí tu combinación. No se modifica la configuración del sistema. Comprueba cada asignación en la aplicación de destino.")
                .font(.caption).foregroundStyle(.secondary)
            Text("La captura no permite certificar qué dispositivo produjo el evento. Desactiva asignaciones equivalentes del software del fabricante para evitar acciones duplicadas. Las acciones se omiten mientras macOS indica entrada segura.")
                .font(.caption).foregroundStyle(.secondary)
            Text("Los atajos guardan la tecla física. Revisa las asignaciones si cambias la distribución del teclado.")
                .font(.caption).foregroundStyle(.secondary)
            if service.otherInputFiltersDetected {
                Text("Se detectó otro filtro de entrada activo; comprueba posibles asignaciones duplicadas.").font(.caption).foregroundStyle(.orange)
            }
            if let message = error ?? service.settingsError { Text(message).font(.caption).foregroundStyle(.red) }
        }
        .disabled(saving)
        .onDisappear { Task { @MainActor in do { try await service.cancelCapture() } catch { self.error = error.localizedDescription } } }
    }
    private var buttons: [Int] {
        Set(service.options.assignments.keys).union(service.lastCapturedButton.map { [$0] } ?? []).sorted()
    }
    private func preset(_ title: String, shortcut: MouseButtonShortcut, button: Int) -> some View {
        Button(title) { run { try await service.assign(shortcut, to: button) } }
    }
    private func run(_ operation: @escaping @MainActor () async throws -> Void) {
        saving = true
        Task { @MainActor in
            defer { saving = false }
            do { try await operation(); error = nil } catch { self.error = error.localizedDescription }
        }
    }
}

/// Captures a single shortcut only while this local control is armed. No global keyboard monitor.
private struct MouseActionShortcutRecorder: View {
    let shortcut: MouseButtonShortcut?
    let onChange: (MouseButtonShortcut) -> Void
    @State private var recording = false
    @State private var monitor: Any?
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Button(recording ? "Pulsa el atajo… (Esc cancela)" : shortcut?.displayName ?? "Asignar atajo…") {
                if recording { stop() } else { start() }
            }
            if let error { Text(error).font(.caption).foregroundStyle(.red) }
        }
        .onDisappear { stop() }
    }
    private func start() {
        stop(); recording = true; error = nil
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard recording else { return event }
            if event.keyCode == 53 { stop(); return nil }
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            let shortcut = MouseButtonShortcut(keyCode: event.keyCode, label: label(for: event),
                command: flags.contains(.command), option: flags.contains(.option), control: flags.contains(.control), shift: flags.contains(.shift))
            do { try shortcut.validate(); stop(); onChange(shortcut) }
            catch { self.error = error.localizedDescription }
            return nil
        }
    }
    private func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }; monitor = nil; recording = false
    }
    private func label(for event: NSEvent) -> String {
        let special: [UInt16: String] = [48: "Tab", 49: "Espacio", 36: "↩", 76: "Enter", 51: "⌫", 117: "⌦", 123: "←", 124: "→", 125: "↓", 126: "↑", 122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6", 98: "F7", 100: "F8", 101: "F9", 109: "F10", 103: "F11", 111: "F12", 105: "F13", 107: "F14", 113: "F15", 106: "F16", 64: "F17", 79: "F18", 80: "F19", 90: "F20"]
        if let label = special[event.keyCode] { return label }
        return event.charactersIgnoringModifiers.map { String($0.prefix(1)).uppercased() } ?? "Tecla \(event.keyCode)"
    }
}
