import AppKit
import SwiftUI
import ZEUVEQuickUtilities

@MainActor private final class WindowSwitcherSelection: ObservableObject {
    @Published var selectedID: UUID?
}

private final class WindowSwitcherPanel: NSPanel {
    var handleKey: ((UInt16) -> Bool)?
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
    override func sendEvent(_ event: NSEvent) {
        if event.type == .keyDown, handleKey?(event.keyCode) == true { return }
        super.sendEvent(event)
    }
}

/// Retain alongside the resident services. It never activates ZEUVE or raises
/// an external window until the user confirms a selection.
@MainActor final class WindowSwitcherPanelController {
    private let service: WindowSwitcherService
    private let selection = WindowSwitcherSelection()
    private var panel: WindowSwitcherPanel?
    private var resignObserver: NSObjectProtocol?
    init(service: WindowSwitcherService) {
        self.service = service
        service.onShowSwitcher = { [weak self] in self?.show() }
        service.onCloseSwitcher = { [weak self] in self?.close() }
    }
    private func show() {
        if panel == nil {
            let panel = WindowSwitcherPanel(contentRect: NSRect(x: 0, y: 0, width: 610, height: 460), styleMask: [.titled, .fullSizeContentView, .nonactivatingPanel], backing: .buffered, defer: false)
            panel.title = "Selector de ventanas de ZEUVE"
            panel.titleVisibility = .hidden; panel.titlebarAppearsTransparent = true
            panel.isReleasedWhenClosed = false; panel.hidesOnDeactivate = false
            panel.level = .floating; panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            panel.contentView = NSHostingView(rootView: WindowSwitcherPanelView(service: service, selection: selection))
            panel.handleKey = { [weak self] key in self?.handleKey(key) ?? false }
            resignObserver = NotificationCenter.default.addObserver(forName: NSWindow.didResignKeyNotification, object: panel, queue: .main) { [weak self] _ in
                Task { @MainActor in if self?.service.isPresented == true { self?.service.cancel() } }
            }
            self.panel = panel
        }
        guard let panel else { return }
        selection.selectedID = service.windows.first?.id
        if let screen = NSScreen.main ?? NSScreen.screens.first {
            let frame = screen.visibleFrame
            panel.setFrameOrigin(NSPoint(x: frame.midX - panel.frame.width / 2, y: frame.midY - panel.frame.height / 2))
        }
        panel.makeKeyAndOrderFront(nil)
    }
    private func close() {
        if let resignObserver { NotificationCenter.default.removeObserver(resignObserver) }
        resignObserver = nil
        panel?.orderOut(nil); panel = nil; selection.selectedID = nil
    }
    private func handleKey(_ code: UInt16) -> Bool {
        switch code {
        case 53: service.cancel(); return true
        case 36, 76:
            if let selected = selection.selectedID { service.choose(selected) }
            return true
        case 125, 124, 48: move(1); return true
        case 126, 123: move(-1); return true
        default: return false
        }
    }
    private func move(_ delta: Int) {
        let items = service.windows
        guard !items.isEmpty else { return }
        let current = items.firstIndex(where: { $0.id == selection.selectedID }) ?? 0
        selection.selectedID = items[(current + delta + items.count) % items.count].id
    }
}

private struct WindowSwitcherPanelView: View {
    @ObservedObject var service: WindowSwitcherService
    @ObservedObject var selection: WindowSwitcherSelection
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Ventanas", systemImage: "macwindow.on.rectangle").font(.title2.bold())
                Spacer()
                Button("Cancelar") { service.cancel() }
            }
            Text("Flechas para elegir · Intro para activar · Esc para cancelar").font(.caption).foregroundStyle(.secondary)
            if let message = service.message { Text(message).foregroundStyle(.orange).fixedSize(horizontal: false, vertical: true) }
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(service.windows) { window in
                            Button { selection.selectedID = window.id; service.choose(window.id) } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: window.minimized ? "minus.rectangle" : "macwindow").frame(width: 24)
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(window.applicationName).font(.headline)
                                        Text(window.displayTitle).lineLimit(1).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    if window.minimized { Text("Minimizada").font(.caption).foregroundStyle(.secondary) }
                                }
                                .padding(10).frame(maxWidth: .infinity, alignment: .leading)
                                .background(selection.selectedID == window.id ? Color.accentColor.opacity(0.18) : Color.clear)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }.buttonStyle(.plain).id(window.id)
                        }
                    }
                }.onChange(of: selection.selectedID) { _, value in if let value { proxy.scrollTo(value, anchor: .center) } }
            }
            Text("Lista textual sin capturas. El orden reciente se conoce desde que activas esta utilidad; Spaces y algunas apps pueden limitar la activación.")
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .onChange(of: service.windows) { _, updated in
            if !updated.contains(where: { $0.id == selection.selectedID }) { selection.selectedID = updated.first?.id }
        }
    }
}
