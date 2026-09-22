import SwiftUI
import AppKit
import ZEUVECore

@main
struct ZEUVEApp: App {
    @StateObject private var model = AppModel()
    @NSApplicationDelegateAdaptor(AppLifecycleDelegate.self) private var lifecycleDelegate

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(model)
                .preferredColorScheme(model.theme.colorScheme)
                .task {
                    lifecycleDelegate.model = model
                    await model.start()
                }
        }
        .windowStyle(.automatic)
        .defaultSize(width: 1_180, height: 780)
        .commands {
            CommandGroup(replacing: .newItem) { }
            CommandMenu("ZEUVE") {
                ForEach(model.navigationModules) { module in
                    if let shortcut = model.shortcut(for: module.id), let key = shortcut.keyEquivalent {
                        Button(module.descriptor.commandTitle) { model.selectModule(module.id) }
                            .keyboardShortcut(key, modifiers: shortcut.eventModifiers)
                    } else {
                        Button(module.descriptor.commandTitle) { model.selectModule(module.id) }
                    }
                }
                if let shortcut = model.historyShortcut, let key = shortcut.keyEquivalent {
                    Button("Ver historial") { model.selection = .history }
                        .keyboardShortcut(key, modifiers: shortcut.eventModifiers)
                } else {
                    Button("Ver historial") { model.selection = .history }
                }
            }
        }
        Settings {
            SettingsView().environmentObject(model).frame(width: 920, height: 680)
        }
    }
}

@MainActor
final class AppLifecycleDelegate: NSObject, NSApplicationDelegate {
    weak var model: AppModel?
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let model else { return .terminateNow }
        Task {
            // Se ejecuta incluso si el coordinador ya no muestra una operación: el diagnóstico
            // de motores también puede tener un proceso auxiliar brevemente activo.
            await model.terminateExternalProcesses()
            await MainActor.run { sender.reply(toApplicationShouldTerminate: true) }
        }
        return .terminateLater
    }
}


private extension KeyboardShortcutDescriptor {
    var keyEquivalent: KeyEquivalent? {
        guard key.count == 1, let character = key.first else { return nil }
        return KeyEquivalent(character)
    }
    var eventModifiers: EventModifiers {
        var value: EventModifiers = []
        if command { value.insert(.command) }; if option { value.insert(.option) }; if control { value.insert(.control) }; if shift { value.insert(.shift) }
        return value
    }
}
