import SwiftUI
import ZEUVECore

struct RootView: View {
    @EnvironmentObject private var app: AppModel

    var body: some View {
        NavigationSplitView {
            List(selection: $app.selection) {
                Section { navigationRow(.dashboard) }
                Section("Herramientas") {
                    ForEach(app.navigationModules) { module in
                        moduleNavigationRow(module)
                    }
                }
                Section {
                    navigationRow(.history)
                    navigationRow(.settings)
                }
            }
            .navigationTitle("ZEUVE")
            .listStyle(.sidebar)
            .safeAreaInset(edge: .bottom) {
                if let operation = app.activeOperation { ActiveOperationCard(operation: operation).padding(10) }
            }
        } detail: {
            Group {
                switch app.selection ?? .dashboard {
                case .dashboard:
                    DashboardView()
                case .module(let moduleID):
                    BuiltInModuleViewRouter(moduleID: moduleID)
                case .history:
                    GlobalHistoryView()
                        .environmentObject(app.globalHistory)
                case .settings:
                    SettingsView()
                }
            }.frame(minWidth: 780, minHeight: 620)
        }
        .alert("ZEUVE no ha podido iniciarse completamente", isPresented: Binding(get: { app.startupError != nil }, set: { if !$0 { app.startupError = nil } })) {
            Button("Aceptar", role: .cancel) { app.startupError = nil }
        } message: { Text(app.startupError ?? "Error desconocido") }
    }

    private func navigationRow(_ destination: AppDestination) -> some View {
        Label(destination.title, systemImage: destination.systemImage).tag(destination)
    }

    private func moduleNavigationRow(_ module: RegisteredBuiltInModule) -> some View {
        Label(module.descriptor.registrationName, systemImage: module.manifest.presentation.systemImage)
            .tag(AppDestination.module(module.id))
    }
}

private struct ActiveOperationCard: View {
    let operation: OperationSnapshot
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack { ProgressView().controlSize(.small); Text(operation.name).font(.caption.weight(.semibold)).lineLimit(1) }
            if let progress = operation.progress {
                if let fraction = progress.fraction { ProgressView(value: fraction) } else { ProgressView() }
                Text(progress.currentItem ?? progress.phase).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
            }
        }.padding(10).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
    }
}
