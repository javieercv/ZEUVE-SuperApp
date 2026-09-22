import SwiftUI
import ZEUVECore

struct DashboardView: View {
    @EnvironmentObject private var app: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("ZEUVE").font(.system(size: 34, weight: .bold, design: .rounded))
                    Text("Tus herramientas locales, organizadas en una sola aplicación.").font(.title3).foregroundStyle(.secondary)
                }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 320), spacing: 16)], spacing: 16) {
                    ForEach(app.dashboardModules) { module in
                        Button { app.selectModule(module.id) } label: { ModuleCard(manifest: module.manifest) }.buttonStyle(.plain)
                    }
                }
                GroupBox {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "lock.shield").font(.title2).foregroundStyle(.green)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Privacidad bajo tu control").font(.headline)
                            Text("Las herramientas locales, incluidos el Analizador de chats, el Conversor universal, el Inspector multimedia, el Limpiador y el Comparador de seguidores de Instagram, no envían información. El Descargador universal solo usa Internet cuando decides analizar una URL o descargar el contenido detectado.").foregroundStyle(.secondary)
                        }
                        Spacer()
                    }.padding(4)
                }
            }.padding(32).frame(maxWidth: 1_000, alignment: .leading)
        }.navigationTitle("Inicio")
    }

}

private struct ModuleCard: View {
    let manifest: ModuleManifest
    var body: some View {
        HStack(spacing: 18) {
            Image(systemName: manifest.presentation.systemImage).font(.system(size: 34)).frame(width: 66, height: 66).background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
            VStack(alignment: .leading, spacing: 6) {
                Text(manifest.name).font(.title2.weight(.semibold))
                Text(manifest.summary).foregroundStyle(.secondary)
                Text(manifest.presentation.category.uppercased()).font(.caption.weight(.semibold)).foregroundStyle(.tertiary)
            }
            Spacer(); Image(systemName: "chevron.right").foregroundStyle(.tertiary)
        }.padding(22).background(.background.secondary, in: RoundedRectangle(cornerRadius: 18)).overlay(RoundedRectangle(cornerRadius: 18).stroke(.quaternary))
    }
}
