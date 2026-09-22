import SwiftUI
import AppKit
import UniversalDownloaderModule
import ZEUVEEngines

struct UniversalContentSettingsView: View {
    @ObservedObject var model: UniversalDownloaderViewModel
    @State private var confirmAdultContent = false
    @State private var customDomainsText = ""

    var body: some View {
        Form {
            Section {
                Toggle("Permitir contenido para adultos", isOn: Binding(
                    get: { model.universalPreferences.allowAdultContent },
                    set: { newValue in
                        if newValue { confirmAdultContent = true }
                        else {
                            model.universalPreferences.allowAdultContent = false
                            model.persistUniversalPreferences()
                        }
                    }
                ))
                Text("Está desactivado por defecto. Cuando está desactivado, ZEUVE bloquea el análisis antes de cargar miniaturas o contenido de dominios identificados como adultos.")
                    .font(.caption).foregroundStyle(.secondary)
            } header: {
                Text("Contenido adulto")
            } footer: {
                Text("La detección combina dominios conocidos, la plataforma elegida y la clasificación de los extractores. Ningún clasificador puede reconocer de forma perfecta todas las páginas genéricas.")
            }

            Section("Dominios adicionales") {
                TextEditor(text: $customDomainsText)
                    .font(.body.monospaced())
                    .frame(minHeight: 100)
                Button("Guardar dominios") {
                    model.universalPreferences.adultDomainsAddedByUser = customDomainsText
                        .split(whereSeparator: { $0.isNewline || $0 == "," })
                        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
                        .filter { !$0.isEmpty }
                    model.persistUniversalPreferences()
                }
                Text("Un dominio por línea. Se usa para bloquear páginas no incluidas todavía en la lista local.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section("Sesión de Instagram") {
                Toggle("Recordar sesiones en el Llavero por defecto", isOn: $model.rememberInstagramSession)
                    .onChange(of: model.rememberInstagramSession) { _, _ in model.persistUniversalPreferences() }
                Button("Eliminar sesión recordada", role: .destructive) { model.clearRememberedInstagramSession() }
                Text("Las sesiones temporales se eliminan al terminar. ZEUVE nunca pide la contraseña de Instagram ni guarda cookies en registros, historial o presets.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear {
            customDomainsText = model.universalPreferences.adultDomainsAddedByUser.joined(separator: "\n")
        }
        .confirmationDialog("¿Permitir contenido para adultos?", isPresented: $confirmAdultContent, titleVisibility: .visible) {
            Button("Permitir") {
                model.universalPreferences.allowAdultContent = true
                model.persistUniversalPreferences()
            }
            Button("Cancelar", role: .cancel) { }
        } message: {
            Text("ZEUVE podrá analizar y mostrar miniaturas de páginas para adultos cuando tú introduzcas un enlace. Esta opción no inicia búsquedas ni descargas automáticas.")
        }
    }
}
