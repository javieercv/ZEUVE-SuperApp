import SwiftUI
import AppKit
import UniversalDownloaderModule
import ZEUVEEngines

private enum UniversalDownloaderSettingsSection: String, CaseIterable, Identifiable {
    case defaults
    case platforms
    case content
    case catalog
    case presets
    case engines
    case diagnostics

    var id: String { rawValue }

    var title: String {
        switch self {
        case .defaults: return "Predeterminados"
        case .platforms: return "Plataformas"
        case .content: return "Contenido"
        case .catalog: return "Catálogo"
        case .presets: return "Presets"
        case .engines: return "Motores"
        case .diagnostics: return "Diagnóstico"
        }
    }
}

struct UniversalDownloaderSettingsView: View {
    @ObservedObject var model: UniversalDownloaderViewModel
    @State private var section: UniversalDownloaderSettingsSection = .defaults

    var body: some View {
        VStack(spacing: 0) {
            Picker("Sección", selection: $section) {
                ForEach(UniversalDownloaderSettingsSection.allCases) { item in
                    Text(item.title).tag(item)
                }
            }
            .pickerStyle(.segmented)
            .padding([.top, .horizontal])

            Group {
                switch section {
                case .defaults:
                    UniversalDownloaderDefaultsSettingsView(model: model)
                case .platforms:
                    UniversalDownloadProfilesSettingsView(model: model)
                case .content:
                    UniversalContentSettingsView(model: model)
                case .catalog:
                    UniversalCatalogSettingsView(model: model)
                case .presets:
                    UniversalDownloadPresetsSettingsView(model: model)
                case .engines:
                    UniversalEngineSettingsView(model: model)
                case .diagnostics:
                    UniversalDownloaderDiagnosticsSettingsView(model: model)
                }
            }
        }
        .alert("No se ha podido guardar el ajuste", isPresented: Binding(
            get: { model.errorMessage != nil },
            set: { if !$0 { model.errorMessage = nil } }
        )) {
            Button("Aceptar", role: .cancel) { model.errorMessage = nil }
        } message: {
            Text(model.errorMessage ?? "Error desconocido")
        }
    }
}
