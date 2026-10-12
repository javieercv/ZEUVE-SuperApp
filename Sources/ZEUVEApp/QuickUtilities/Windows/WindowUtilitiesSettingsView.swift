import SwiftUI
import AppKit
import ZEUVEQuickUtilities

struct WindowSwitcherSettingsView: View {
    @ObservedObject var service: WindowSwitcherService
    @State private var error: String?
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Atajo global: \(service.preferences.shortcut.displayName)")
            HStack {
                Button("Usar ⌥Tab") { assign(.init(keyCode: 48, option: true)) }
                Button("Usar ⌃⌥Tab") { assign(.init(keyCode: 48, option: true, control: true)) }
                Button("Abrir selector") { service.show() }.disabled(service.state != .active)
            }
            WindowGlobalShortcutRecorder(shortcut: service.preferences.shortcut, onChange: assign)
            Text("Complementa ⌘Tab. No solicita Grabación de pantalla. Las ventanas minimizadas se recuperan únicamente al seleccionarlas; Esc conserva la aplicación activa.")
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            if let error { Text(error).foregroundStyle(.red) }
            if let message = service.message { Text(message).foregroundStyle(.orange) }
        }
    }
    private func assign(_ shortcut: GlobalShortcut) {
        do { try service.setShortcut(shortcut); error = nil } catch { self.error = error.localizedDescription }
    }
}

private struct WindowGlobalShortcutRecorder: NSViewRepresentable {
    let shortcut: GlobalShortcut
    let onChange: (GlobalShortcut) -> Void
    func makeNSView(context: Context) -> WindowShortcutButton {
        let button = WindowShortcutButton(title: "", target: nil, action: nil)
        button.onShortcut = onChange
        return button
    }
    func updateNSView(_ button: WindowShortcutButton, context: Context) {
        button.onShortcut = onChange
        if !button.recording { button.title = "Personalizar atajo (\(shortcut.displayName))" }
    }
}

private final class WindowShortcutButton: NSButton {
    var onShortcut: ((GlobalShortcut) -> Void)?
    var recording = false
    override var acceptsFirstResponder: Bool { true }
    override func mouseDown(with event: NSEvent) {
        recording = true; title = "Pulsa el nuevo atajo… (Esc cancela)"; window?.makeFirstResponder(self)
    }
    override func keyDown(with event: NSEvent) {
        guard recording else { super.keyDown(with: event); return }
        recording = false
        if event.keyCode == 53 { title = "Personalizar atajo"; return }
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        onShortcut?(.init(keyCode: UInt32(event.keyCode), command: modifiers.contains(.command), option: modifiers.contains(.option), control: modifiers.contains(.control), shift: modifiers.contains(.shift)))
        title = "Personalizar atajo"
    }
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard recording else { return super.performKeyEquivalent(with: event) }
        keyDown(with: event); return true
    }
}

struct WindowLayoutsSettingsView: View {
    @ObservedObject var service: WindowLayoutsService
    @State private var selectedWindows: Set<UUID> = []
    @State private var name = "Mi distribución"
    @State private var names: [UUID: String] = [:]
    @State private var error: String?
    @State private var isSaving = false
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Las posiciones guardadas conservan aplicación y geometría, sin títulos ni documentos. Tras cerrar ventanas, desactivar la utilidad o reiniciar ZEUVE tendrás que reasociarlas explícitamente.")
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            HStack {
                Button("Actualizar ventanas") { service.refreshWindows() }.disabled(service.state != .active || service.isRestoring)
                if service.isRestoring { ProgressView().controlSize(.small); Button("Cancelar restauración") { service.cancelRestoration() } }
            }
            if service.state == .active {
                DisclosureGroup("Guardar una distribución con ventanas elegidas") {
                    VStack(alignment: .leading, spacing: 6) {
                        TextField("Nombre de la distribución", text: $name)
                        ForEach(service.windows.filter(\.canRestoreGeometry)) { window in
                            Toggle(isOn: Binding(get: { selectedWindows.contains(window.id) }, set: { checked in
                                if checked { selectedWindows.insert(window.id) } else { selectedWindows.remove(window.id) }
                            })) { Text("\(window.applicationName) — \(window.displayTitle)").lineLimit(1) }
                        }
                        if service.windows.filter(\.canRestoreGeometry).isEmpty { Text("No hay ventanas manipulables. Actualiza la lista con las ventanas abiertas.").foregroundStyle(.secondary) }
                        Button("Guardar ventanas seleccionadas") { save() }
                            .disabled(selectedWindows.isEmpty || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving || service.isRestoring)
                    }.padding(.vertical, 6)
                }
            }
            ForEach(service.preferences.profiles) { profile in
                DisclosureGroup(profile.name) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            TextField("Nombre", text: Binding(get: { names[profile.id] ?? profile.name }, set: { names[profile.id] = $0 }))
                            Button("Renombrar") { perform { try service.renameProfile(profile.id, name: names[profile.id] ?? profile.name) } }
                            Button("Eliminar") { perform { try service.deleteProfile(profile.id) } }
                        }
                        ForEach(Array(profile.slots.enumerated()), id: \.element.id) { index, slot in
                            Picker("\(index + 1). \(applicationName(slot.bundleIdentifier))", selection: Binding<UUID?>(get: { service.associations[slot.id] }, set: { windowID in perform { try service.associate(slotID: slot.id, windowID: windowID) } })) {
                                Text("Sin asociación: se omitirá").tag(Optional<UUID>.none)
                                ForEach(service.windows.filter { $0.bundleIdentifier == slot.bundleIdentifier && $0.canRestoreGeometry }) { window in
                                    Text(window.displayTitle).tag(Optional(window.id))
                                }
                            }
                        }
                        Text("\(profile.slots.filter { service.associations[$0.id] != nil }.count) de \(profile.slots.count) posiciones asociadas. Las no asociadas se omiten. Si falta una pantalla, la restauración explícita adapta las ventanas a la pantalla principal.")
                            .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                        Button("Restaurar distribución") { service.restoreProfile(profile.id) }
                            .disabled(service.state != .active || service.isRestoring || !profile.slots.contains(where: { service.associations[$0.id] != nil }))
                    }.padding(.vertical, 6).disabled(service.isRestoring)
                }
            }
            if !service.preferences.profiles.isEmpty {
                Picker("Distribución automática", selection: Binding<UUID?>(get: { service.preferences.automaticProfileID }, set: { profileID in
                    perform { try service.setAutomaticRestoration(service.preferences.automaticallyRestore && profileID != nil, profileID: profileID) }
                })) {
                    Text("Ninguna").tag(Optional<UUID>.none)
                    ForEach(service.preferences.profiles) { profile in Text(profile.name).tag(Optional(profile.id)) }
                }
                Toggle("Restaurar automáticamente al recuperar la configuración de pantallas", isOn: Binding(get: { service.preferences.automaticallyRestore }, set: { enabled in
                    perform { try service.setAutomaticRestoration(enabled, profileID: service.preferences.automaticProfileID) }
                })).disabled(service.preferences.automaticProfileID == nil)
                Text("Automático solo con la misma configuración de pantallas y asociaciones verificadas. No abre documentos ni modifica Spaces, ventanas minimizadas o fullscreen.")
                    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            if let result = service.lastResult { Text(result.summary).font(.callout) }
            if let message = service.message { Text(message).foregroundStyle(.orange) }
            if let error { Text(error).foregroundStyle(.red) }
        }
        .task { service.refreshWindows() }
        .onChange(of: service.state) { _, state in if state == .active { service.refreshWindows() } }
        .onChange(of: service.windows) { _, windows in selectedWindows.formIntersection(Set(windows.map(\.id))) }
    }
    private func applicationName(_ bundleID: String) -> String {
        if let name = service.windows.first(where: { $0.bundleIdentifier == bundleID })?.applicationName { return name }
        return NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)?.deletingPathExtension().lastPathComponent ?? "Aplicación no disponible"
    }
    private func perform(_ action: () throws -> Void) {
        do { try action(); error = nil } catch { self.error = error.localizedDescription }
    }
    private func save() {
        isSaving = true
        Task { @MainActor in
            defer { isSaving = false }
            do { try await service.saveProfile(name: name, windowIDs: selectedWindows); error = nil; selectedWindows.removeAll() }
            catch { self.error = error.localizedDescription }
        }
    }
}
