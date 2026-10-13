import SwiftUI
import AppKit
import Carbon
import ZEUVECore
import ZEUVEQuickUtilities

@main
struct ZEUVEApp: App {
    @StateObject private var runtime: ResidentRuntime
    @NSApplicationDelegateAdaptor(AppLifecycleDelegate.self) private var lifecycleDelegate

    init() {
        let resident = ResidentRuntime()
        _runtime = StateObject(wrappedValue: resident)
        lifecycleDelegate.runtime = resident
    }
    var body: some Scene {
        MenuBarExtra("ZEUVE", systemImage: "bolt.circle") {
            Button("Abrir ZEUVE") { runtime.openMainWindow() }.disabled(!runtime.isReady)
            Button("Utilidades rápidas") { runtime.openSettings(quickUtilities: true) }.disabled(!runtime.isReady)
            Divider()
            if runtime.audioProtection?.isDiagnosticRunning == true {
                Text("Ruta de prueba de audio en ejecución; eficacia pendiente")
            }
            ForEach(runtime.utilities.snapshots) { snapshot in
                let descriptor = QuickUtilitiesCatalog.descriptor(for: snapshot.id)
                Toggle(isOn: Binding(get: { snapshot.requested }, set: { runtime.setUtilityEnabled($0, id: snapshot.id) })) {
                    Text("\(descriptor.name) — \(snapshot.state.title)")
                }.disabled(snapshot.state.isTransitioning || !runtime.isReady)
            }
            Divider()
            Button("Ajustes…") { runtime.openSettings() }
            Button("Detener todas las utilidades") { runtime.stopUtilities() }
            Button("Salir de ZEUVE") { NSApp.terminate(nil) }.keyboardShortcut("q")
        }
        .menuBarExtraStyle(.menu)
        .commands {
            CommandGroup(replacing: .newItem) { }
            CommandGroup(replacing: .appSettings) {
                Button("Ajustes…") { runtime.openSettings() }.keyboardShortcut(",")
            }
            CommandMenu("ZEUVE") {
                Button("Abrir ZEUVE") { runtime.openMainWindow() }
                Button("Utilidades rápidas") { runtime.openSettings(quickUtilities: true) }
                ForEach(runtime.navigationModules) { module in
                    let shortcut = runtime.navigationPreferences.effectiveShortcut(for: module.descriptor.primaryIdentifier, defaults: BuiltInModuleCatalog.navigationDefaults)
                    Button(module.descriptor.commandTitle) { runtime.openMainWindow(destination: .module(module.id)) }
                        .keyboardShortcut(shortcut?.swiftUIShortcut)
                }
                let shortcut = runtime.navigationPreferences.effectiveShortcut(for: BuiltInModuleCatalog.historyTargetID, defaults: BuiltInModuleCatalog.navigationDefaults)
                Button("Ver historial") { runtime.openMainWindow(destination: .history) }
                    .keyboardShortcut(shortcut?.swiftUIShortcut)
            }
        }
    }
}

@MainActor
final class AppLifecycleDelegate: NSObject, NSApplicationDelegate {
    weak var runtime: ResidentRuntime?
    private var terminationTask: Task<Void, Never>?
    func applicationDidFinishLaunching(_ notification: Notification) {
        let event = NSAppleEventManager.shared().currentAppleEvent
        runtime?.beginLaunch(showMainWindow: ResidentLaunchPolicy.opensMainWindow(for: event))
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        runtime?.openMainWindow(); return false
    }
    func applicationDidBecomeActive(_ notification: Notification) { runtime?.refreshLoginStatus() }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let runtime else { return .terminateNow }
        guard terminationTask == nil else { return .terminateLater }
        terminationTask = Task {
            await runtime.shutdown()
            sender.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }
}

private extension KeyboardShortcutDescriptor {
    var swiftUIShortcut: SwiftUI.KeyboardShortcut? {
        keyEquivalent.map { SwiftUI.KeyboardShortcut($0, modifiers: eventModifiers) }
    }
    var keyEquivalent: KeyEquivalent? {
        guard key.count == 1, let character = key.first else { return nil }
        return KeyEquivalent(character)
    }
    var eventModifiers: SwiftUI.EventModifiers {
        var value: SwiftUI.EventModifiers = []
        if command { value.insert(.command) }; if option { value.insert(.option) }; if control { value.insert(.control) }; if shift { value.insert(.shift) }
        return value
    }
}
