import SwiftUI
import AppKit

@main
struct ZEUVEApp: App {
    @StateObject private var model = AppModel()
    @NSApplicationDelegateAdaptor(AppLifecycleDelegate.self) private var lifecycleDelegate

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(model)
                .environmentObject(model.organizer)
                .environmentObject(model.youtubeDownloader)
                .environmentObject(model.chatAnalyzer)
                .environmentObject(model.universalConverter)
                .environmentObject(model.globalHistory)
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
                Button("Abrir organizador") { model.selection = .organizer }.keyboardShortcut("1", modifiers: [.command])
                Button("Abrir Descargador de YouTube") { model.selection = .youtubeDownloader }.keyboardShortcut("2", modifiers: [.command])
                Button("Abrir Analizador de chats") { model.selection = .chatAnalyzer }.keyboardShortcut("3", modifiers: [.command])
                Button("Abrir Conversor universal") { model.selection = .universalConverter }.keyboardShortcut("4", modifiers: [.command])
                Button("Ver historial") { model.selection = .history }.keyboardShortcut("5", modifiers: [.command])
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
