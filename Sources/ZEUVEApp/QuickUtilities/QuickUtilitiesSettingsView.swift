import SwiftUI
import AppKit
import ServiceManagement
import ZEUVEQuickUtilities

struct QuickUtilitiesSettingsView: View {
    @EnvironmentObject private var runtime: ResidentRuntime
    @State private var resetting = false
    var body: some View {
        Form {
            Section("ZEUVE residente") {
                HelpLabel("Cerrar, detener y salir", topic: QuickUtilitiesHelp.resident)
                Text("Cerrar la ventana mantiene ZEUVE en la barra de menús. «Salir de ZEUVE» detiene los servicios y cierra la aplicación.")
                Toggle("Iniciar ZEUVE al entrar en macOS", isOn: Binding(get: { runtime.loginRequested }, set: { runtime.setLaunchAtLogin($0) }))
                LabeledContent("Estado en macOS", value: runtime.loginStatusText)
                if runtime.loginStatus == .requiresApproval { Button("Abrir Ítems de inicio") { SMAppService.openSystemSettingsLoginItems() } }
                if let error = runtime.loginError { Text(error).foregroundStyle(.red) }
            }
            ForEach(runtime.utilities.snapshots) { snapshot in
                let descriptor = QuickUtilitiesCatalog.descriptor(for: snapshot.id)
                Section {
                    Toggle(isOn: Binding(get: { snapshot.requested }, set: { runtime.setUtilityEnabled($0, id: snapshot.id) })) {
                        HStack { Label(descriptor.name, systemImage: descriptor.icon); ContextualHelpButton(topic: QuickUtilitiesHelp.topic(for: snapshot.id)) }
                    }.disabled(snapshot.state.isTransitioning || !runtime.isReady)
                    Text(descriptor.summary).foregroundStyle(.secondary)
                    LabeledContent("Estado efectivo", value: snapshot.state.title)
                    if let error = runtime.utilities.operationErrors[snapshot.id] { Text(error).foregroundStyle(.red).font(.caption) }
                    if !descriptor.permissions.isEmpty {
                        Text("Permisos: " + descriptor.permissions.map(\.title).joined(separator: ", ")).font(.caption)
                    }
                    if case .requiresPermission(let permission) = snapshot.state {
                        Button("Autorizar \(permission.title)") { QuickUtilityPermissions.request(permission) }
                    }
                    if snapshot.requested && snapshot.state != .active && !snapshot.state.isTransitioning {
                        Button("Volver a comprobar") { runtime.retryUtility(snapshot.id) }
                    }
                    utilityOptions(snapshot.id)
                }
            }
            if let error = runtime.utilities.storageError {
                Section("Aviso") { Text(error).foregroundStyle(.red).textSelection(.enabled) }
            }
            if let error = runtime.utilitiesResetError {
                Section("Restauración") { Text(error).foregroundStyle(.red).textSelection(.enabled) }
            }
            Section {
                Button("Detener todas las utilidades") { runtime.stopUtilities() }
                Button("Restaurar preferencias de utilidades", role: .destructive) { resetting = true }
                    .disabled(runtime.isRestoringDefaults)
            }
        }
        .formStyle(.grouped).padding()
        .confirmationDialog("¿Restaurar las preferencias de las utilidades?", isPresented: $resetting, titleVisibility: .visible) {
            Button("Restaurar", role: .destructive) { runtime.restoreUtilitiesDefaults() }
        } message: { Text("Se detendrán las utilidades y el inicio automático. Se conservarán las plantillas y los perfiles personalizados.") }
    }
    @ViewBuilder private func utilityOptions(_ id: QuickUtilityID) -> some View {
        switch id {
        case .scroll: ScrollDirectionSettingsView(service: runtime.scroll)
        case .mouseButtons: AdditionalMouseButtonsSettingsView(service: runtime.mouseButtons)
        case .windowSwitcher: WindowSwitcherSettingsView(service: runtime.windowSwitcher)
        case .windowLayouts: WindowLayoutsSettingsView(service: runtime.windowLayouts)
        case .audioMixer:
            if let service = runtime.audioMixer { AudioMixerSettingsView(service: service) }
        case .audioProtection:
            if let service = runtime.audioProtection { AudioProtectionSettingsView(service: service) }
        case .newFile: NewFileSettingsView(service: runtime.newFiles, panel: runtime.filePanel)
        case .fileShelf:
            Button("Mostrar bandeja") { do { try runtime.fileShelf.show() } catch { runtime.loginError = error.localizedDescription } }
                .disabled(!runtime.utilities.isActive(.fileShelf))
            Text("Hasta 500 referencias en memoria. No se recuperan después de reiniciar.").font(.caption)
        case .selectedText:
            Text("En una aplicación compatible, selecciona texto sin formato y utiliza su menú Servicios > ZEUVE. La acción elegida reemplaza esa selección si la aplicación admite devolverla; nunca se vigila el portapapeles ni se fuerzan campos protegidos. El formato enriquecido se rechaza para conservar el documento.").font(.caption)
        }
    }
}
