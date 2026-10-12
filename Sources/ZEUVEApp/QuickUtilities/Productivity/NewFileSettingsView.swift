import SwiftUI
import ZEUVEQuickUtilities

struct NewFileSettingsView: View {
    @ObservedObject var service: NewFileUtilityService
    @ObservedObject var panel: NewFilePanelController
    @State private var preferences = NewFilePreferences()
    @State private var name = ""
    @State private var fileExtension = "txt"
    @State private var content = ""
    @State private var error: String?
    @State private var editingTemplate: UUID?
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Formato predeterminado", selection: $preferences.format) {
                ForEach(NewFileFormat.allCases, id: \.self) { Text($0.title).tag($0) }
            }.onChange(of: preferences.format) { _, _ in save() }
            Button("Crear archivo…") { panel.open(format: preferences.format) }.disabled(service.state != .active || panel.isCreating)
            Text("Desde Finder: selecciona una carpeta y abre Servicios > ZEUVE > Crear archivo en esta carpeta. La carpeta y el nombre se confirman en el diálogo. El contenido JSON inicial es {} y los demás formatos incorporados empiezan vacíos.").font(.caption)
            ForEach(preferences.templates) { template in
                HStack {
                    Text("\(template.name) (.\(template.fileExtension))")
                    Spacer()
                    Button("Editar") { editingTemplate = template.id; name = template.name; fileExtension = template.fileExtension; content = template.content }
                    Button("Crear") { panel.open(template: template) }.disabled(service.state != .active)
                    Button("Eliminar", role: .destructive) { preferences.templates.removeAll { $0.id == template.id }; save() }
                }
            }
            DisclosureGroup("Añadir plantilla de texto") {
                TextField("Nombre de la plantilla", text: $name)
                TextField("Extensión permitida, sin punto", text: $fileExtension)
                TextEditor(text: $content).frame(minHeight: 80)
                Button(editingTemplate == nil ? "Guardar plantilla" : "Guardar cambios") {
                    let template = FileTemplate(id: editingTemplate ?? UUID(), name: name, fileExtension: fileExtension, content: content)
                    do {
                        try template.validate()
                        var updated = preferences
                        if let index = updated.templates.firstIndex(where: { $0.id == template.id }) { updated.templates[index] = template }
                        else { updated.templates.append(template) }
                        try service.save(updated); preferences = updated
                        name = ""; content = ""; error = nil; editingTemplate = nil
                    } catch { self.error = error.localizedDescription }
                }
                if editingTemplate != nil { Button("Cancelar edición") { editingTemplate = nil; name = ""; content = "" } }
                Text("La plantilla contiene únicamente el texto mostrado. No ejecuta programas ni interpreta comandos.").font(.caption)
            }
            if let error = error ?? panel.error { Text(error).foregroundStyle(.red) }
        }.onChange(of: service.preferences) { _, value in preferences = value }
        .onAppear {
            do { try service.prepareSettings(); preferences = service.preferences }
            catch { self.error = error.localizedDescription }
        }
    }
    private func save() {
        do { try service.save(preferences); error = nil }
        catch { self.error = error.localizedDescription; preferences = service.preferences }
    }
}
