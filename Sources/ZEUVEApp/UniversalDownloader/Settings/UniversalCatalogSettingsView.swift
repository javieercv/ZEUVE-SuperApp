import SwiftUI
import AppKit
import UniversalDownloaderModule
import ZEUVEEngines

struct UniversalCatalogSettingsView: View {
    @ObservedObject var model: UniversalDownloaderViewModel

    var body: some View {
        Form {
            Section("Entrada") {
                Picker("Plataforma predeterminada", selection: $model.selectedPlatform) {
                    ForEach(UniversalDownloadPlatform.allCases) { Text($0.spanishName).tag($0) }
                }
            }
            Section("Catálogo de Instagram") {
                Picker("Diseño", selection: $model.universalPreferences.catalogLayout) {
                    ForEach(UniversalCatalogLayout.allCases) { Text($0.spanishName).tag($0) }
                }
                Stepper("Elementos iniciales: \(model.universalPreferences.initialCatalogBatchSize)", value: $model.universalPreferences.initialCatalogBatchSize, in: 6...200, step: 6)
                Stepper("Elementos al cargar más: \(model.universalPreferences.catalogPageSize)", value: $model.universalPreferences.catalogPageSize, in: 6...200, step: 6)
                Stepper("Tamaño de miniatura: \(model.universalPreferences.thumbnailSize) px", value: $model.universalPreferences.thumbnailSize, in: 80...320, step: 20)
                Toggle("Seleccionar solo contenido nuevo por defecto", isOn: $model.universalPreferences.selectNewItemsByDefault)
                Toggle("Conservar historial local de fotos de perfil", isOn: $model.universalPreferences.keepLocalProfilePictureHistory)
            }
            Section("Organización") {
                Toggle("Crear carpetas por plataforma y perfil", isOn: $model.universalPreferences.createPlatformFolders)
                Toggle("Crear subcarpeta para publicaciones con varios elementos", isOn: $model.universalPreferences.createSubfolderForMultiItemPosts)
            }
            Section("Secciones visibles") {
                ForEach(UniversalCatalogSection.allCases.filter { $0 != .all }) { section in
                    Toggle(section.spanishName, isOn: Binding(
                        get: { model.universalPreferences.enabledSections.contains(section) },
                        set: { enabled in
                            if enabled { model.universalPreferences.enabledSections.insert(section) }
                            else { model.universalPreferences.enabledSections.remove(section) }
                        }
                    ))
                }
            }
            Section("Restablecer") {
                Button("Restaurar ajustes del Descargador universal", role: .destructive) { model.restoreUniversalPreferences() }
            }
        }
        .formStyle(.grouped)
        .padding()
        .onChange(of: model.selectedPlatform) { _, _ in model.persistUniversalPreferences() }
        .onChange(of: model.universalPreferences) { _, _ in model.persistUniversalPreferences() }
    }
}
