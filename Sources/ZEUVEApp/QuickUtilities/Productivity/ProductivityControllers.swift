import SwiftUI
import AppKit
import UniformTypeIdentifiers
import ZEUVEQuickUtilities

@MainActor final class NewFilePanelController: ObservableObject {
    @Published var error: String?
    @Published var isCreating = false
    private let service: NewFileUtilityService
    private var task: Task<Void, Never>?
    private var activePanel: NSSavePanel?
    private var generation: UInt64 = 0
    init(service: NewFileUtilityService) {
        self.service = service
        service.willStop = { [weak self] in self?.cancelPendingPanel() }
    }
    func open(directory: URL? = nil, template: FileTemplate? = nil, format: NewFileFormat? = nil) {
        do { try present(directory: directory, template: template, format: format) }
        catch { self.error = error.localizedDescription }
    }
    func present(directory: URL? = nil, template: FileTemplate? = nil, format: NewFileFormat? = nil) throws {
        guard service.state == .active else { throw QuickUtilityError.failure("Activa Crear archivos antes de utilizarlo.") }
        guard !isCreating, activePanel == nil else { throw QuickUtilityError.failure("Ya hay una creación o un diálogo pendiente.") }
        let panel = NSSavePanel()
        activePanel = panel
        let requestGeneration = generation
        let selected = format ?? service.preferences.format
        let ext = template?.fileExtension ?? selected.fileExtension
        panel.title = "Crear un archivo nuevo"; panel.prompt = "Crear"
        panel.nameFieldStringValue = "Nuevo archivo" + (ext.isEmpty ? "" : ".\(ext)")
        panel.directoryURL = directory; panel.canCreateDirectories = false
        panel.message = "El contenido será el de la plantilla elegida o un archivo vacío. ZEUVE no reemplazará un archivo existente."
        panel.begin { [weak self] response in
            guard let self, self.generation == requestGeneration else { return }
            activePanel = nil
            guard response == .OK, let url = panel.url, service.state == .active else { return }
            let content = template?.content ?? selected.initialContent
            isCreating = true; error = nil
            task = Task { [weak self] in
                guard let self else { return }
                defer { isCreating = false; task = nil }
                do {
                    let result = try await service.create(directory: url.deletingLastPathComponent(), name: url.lastPathComponent, content: content)
                    NSWorkspace.shared.activateFileViewerSelecting([result])
                } catch { self.error = error.localizedDescription }
            }
        }
    }
    private func cancelPendingPanel() { generation &+= 1; activePanel?.cancel(nil); activePanel = nil; task?.cancel() }
    func shutdown() async { cancelPendingPanel(); await task?.value }
}

@MainActor final class FileShelfPanelController: ObservableObject {
    @Published var items: [FileShelfItem] = []
    @Published var error: String?
    private let service: FileShelfUtilityService
    private var panel: NSPanel?
    private var picker: NSOpenPanel?
    private var generation: UInt64 = 0
    private var loads: [UUID: Progress] = [:]
    init(service: FileShelfUtilityService) {
        self.service = service
        service.itemsDidChange = { [weak self, weak service] in self?.items = service?.items ?? [] }
        service.presentShelf = { [weak self] in self?.show() }
        service.dismissShelf = { [weak self] in self?.dismiss() }
    }
    func show() {
        if panel == nil {
            let panel = NSPanel(contentRect: .init(x: 0, y: 0, width: 440, height: 380), styleMask: [.titled, .closable, .resizable, .utilityWindow], backing: .buffered, defer: false)
            panel.title = "Bandeja temporal de ZEUVE"; panel.isReleasedWhenClosed = false; panel.isFloatingPanel = true
            // Keep the destination visible while Finder or a drag destination is active.
            panel.hidesOnDeactivate = false; panel.center()
            panel.contentViewController = NSHostingController(rootView: FileShelfPanelView(controller: self))
            self.panel = panel
        }
        _ = service.removeMissing(); panel?.orderFront(nil)
    }
    func add(_ urls: [URL]) { do { try service.add(urls) } catch { self.error = error.localizedDescription } }
    func remove(_ id: UUID) { service.remove(id) }
    func chooseFiles() {
        guard service.state == .active, picker == nil else { return }
        let panel = NSOpenPanel(); panel.canChooseDirectories = true; panel.canChooseFiles = true; panel.allowsMultipleSelection = true
        picker = panel; let requestGeneration = generation
        panel.begin { [weak self] response in
            guard let self, self.generation == requestGeneration else { return }
            self.picker = nil
            if response == .OK, self.service.state == .active { self.add(panel.urls) }
        }
    }
    func validate() { _ = service.removeMissing() }
    func load(_ providers: [NSItemProvider]) -> Bool {
        guard service.state == .active else { return false }
        let requestGeneration = generation
        for provider in providers {
            let id = UUID()
            let progress = provider.loadObject(ofClass: URL.self) { [weak self] url, _ in
                Task { @MainActor in
                    guard let self else { return }
                    self.loads[id] = nil
                    guard self.generation == requestGeneration, self.service.state == .active, let url else { return }
                    self.add([url])
                }
            }
            loads[id] = progress
        }
        return !providers.isEmpty
    }
    func provider(for item: FileShelfItem) -> NSItemProvider {
        do {
            let url = try service.referenceForDrag(id: item.id)
            return NSItemProvider(item: url as NSURL, typeIdentifier: UTType.fileURL.identifier)
        } catch {
            self.error = error.localizedDescription
            // An empty provider rejects this stale drag without exposing its URL.
            return NSItemProvider()
        }
    }
    private func dismiss() {
        generation &+= 1; picker?.cancel(nil); picker = nil
        loads.values.forEach { $0.cancel() }; loads.removeAll()
        panel?.close()
    }
}

private struct FileShelfPanelView: View {
    @ObservedObject var controller: FileShelfPanelController
    var body: some View {
        VStack(alignment: .leading) {
            Text("Arrastra archivos aquí. Al añadirlos no se copian ni se mueven; las referencias se borran al desactivar o salir.").font(.caption).foregroundStyle(.secondary)
            List(controller.items) { item in
                HStack {
                    Image(nsImage: NSWorkspace.shared.icon(forFile: item.url.path)).resizable().frame(width: 24, height: 24)
                    Text(item.name).lineLimit(1)
                    Spacer()
                    Button { controller.remove(item.id) } label: { Image(systemName: "xmark.circle") }.buttonStyle(.borderless).help("Retirar referencia")
                }
                .onDrag { controller.provider(for: item) }
            }
            .onDrop(of: [UTType.fileURL], isTargeted: nil) { providers in
                controller.load(providers)
            }
            if let error = controller.error { Text(error).foregroundStyle(.red).font(.caption) }
            Button("Añadir archivos…") { controller.chooseFiles() }
            Text("El destino externo decide si copia o mueve al soltar. ZEUVE no valida ni ejecuta esa operación.").font(.caption2).foregroundStyle(.secondary)
        }.padding().frame(minWidth: 340, minHeight: 280)
    }
}

@MainActor final class QuickUtilitiesServicesProvider: NSObject {
    private let files: NewFilePanelController
    private let text: TextActionsUtilityService
    init(files: NewFilePanelController, text: TextActionsUtilityService) { self.files = files; self.text = text }
    @objc func createFile(_ pasteboard: NSPasteboard, userData: String?, error: AutoreleasingUnsafeMutablePointer<NSString?>) {
        guard let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL], urls.count == 1 else {
            error.pointee = "Selecciona una carpeta en Finder para crear el archivo."; return
        }
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: urls[0].path, isDirectory: &isDirectory), isDirectory.boolValue else {
            error.pointee = "El destino seleccionado debe ser una carpeta disponible."; return
        }
        do { try files.present(directory: urls[0]) }
        catch let problem { error.pointee = problem.localizedDescription as NSString }
    }
    @objc func transformText(_ pasteboard: NSPasteboard, userData: String?, error: AutoreleasingUnsafeMutablePointer<NSString?>) {
        guard let userData, let action = TextAction(rawValue: userData), let original = pasteboard.string(forType: .string) else {
            error.pointee = "Esta aplicación no ha entregado una selección de texto compatible."; return
        }
        // Preserve document formatting where the host supplies RTF. Do not silently flatten it.
        if pasteboard.availableType(from: [.rtf, .rtfd, .html]) != nil {
            error.pointee = "La selección contiene formato enriquecido. Usa estas acciones sobre texto sin formato para conservar tu documento."; return
        }
        do {
            let result = try text.transform(original, action: action)
            pasteboard.clearContents()
            guard pasteboard.setString(result, forType: .string) else { throw QuickUtilityError.failure("No se pudo devolver el texto transformado.") }
        } catch let problem { error.pointee = problem.localizedDescription as NSString }
    }
}
