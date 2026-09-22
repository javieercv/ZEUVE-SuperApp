import SwiftUI
import AppKit
import CleanerModule

struct CleanerSettingsView: View {
    @ObservedObject var model: CleanerViewModel
    @State private var confirmClearInventory = false
    @State private var confirmRestore = false

    var body: some View {
        Form {
            Section("General") {
                Picker("Al eliminar", selection: $model.preferences.deletionMode) {
                    Text("Mover a Papelera").tag(CleanerDeletionMode.trash)
                    Text("Eliminar permanentemente").tag(CleanerDeletionMode.permanent)
                }
                Toggle("Preseleccionar únicamente elementos seguros", isOn: $model.preferences.safeSelectionEnabled)
                if model.preferences.deletionMode == .permanent {
                    Text("El borrado permanente no dispone de Deshacer y requiere confirmación reforzada.").foregroundStyle(.orange)
                }
            }

            Section("Análisis") {
                Toggle("Cachés", isOn: $model.preferences.scanCaches)
                Toggle("Logs", isOn: $model.preferences.scanLogs)
                Toggle("Xcode DerivedData e índices regenerables", isOn: $model.preferences.scanXcode)
                Toggle("Instaladores antiguos", isOn: $model.preferences.scanOldInstallers)
                if model.preferences.scanOldInstallers {
                    Stepper("Antigüedad mínima: \(model.preferences.oldInstallerDays) días", value: $model.preferences.oldInstallerDays, in: 1...3650)
                }
                Button("Añadir ubicación adicional…") { addLocation() }
                ForEach(Array(model.additionalLocationNames().enumerated()), id: \.offset) { index, path in
                    HStack { Text(path).lineLimit(1).truncationMode(.middle); Spacer(); Button("Quitar") { model.removeAdditionalLocation(at: index) } }
                }
            }

            Section("Conservados") {
                if model.conservedPaths.isEmpty { Text("No hay decisiones de conservación guardadas.").foregroundStyle(.secondary) }
                ForEach(model.conservedPaths, id: \.self) { path in
                    HStack { Text(path).lineLimit(1).truncationMode(.middle); Spacer(); Button("Revocar") { model.revokeConservedPath(path) } }
                }
            }

            Section("Privacidad y cobertura") {
                Text("El Limpiador funciona localmente y no usa Internet. Poder analizar una ubicación no autoriza a eliminarla: cada eliminación exige un plan revisable y revalidación justo antes de ejecutarse.")
                    .foregroundStyle(.secondary)
                Button("Abrir Acceso total al disco en Ajustes del Sistema") {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") { NSWorkspace.shared.open(url) }
                }
            }

            Section("Datos del Limpiador") {
                Button("Borrar inventario histórico del Limpiador", role: .destructive) { confirmClearInventory = true }
                Button("Restaurar preferencias del módulo", role: .destructive) { confirmRestore = true }
            }
        }
        .formStyle(.grouped)
        .padding()
        .onChange(of: model.preferences) { _, _ in model.persistPreferences() }
        .confirmationDialog("¿Borrar el inventario histórico del Limpiador?", isPresented: $confirmClearInventory, titleVisibility: .visible) {
            Button("Borrar inventario", role: .destructive) { model.clearInventoryHistory() }
            Button("Cancelar", role: .cancel) { }
        } message: { Text("No se borrará el historial global ni las decisiones «Conservar». Tampoco se eliminará ningún archivo del usuario.") }
        .confirmationDialog("¿Restaurar las preferencias del Limpiador?", isPresented: $confirmRestore, titleVisibility: .visible) {
            Button("Restaurar", role: .destructive) { model.restorePreferences() }
            Button("Cancelar", role: .cancel) { }
        }
    }

    private func addLocation() {
        let panel = NSOpenPanel(); panel.canChooseDirectories=true; panel.canChooseFiles=false; panel.allowsMultipleSelection=false
        if panel.runModal() == .OK, let url = panel.url { model.addAdditionalLocation(url) }
    }
}
