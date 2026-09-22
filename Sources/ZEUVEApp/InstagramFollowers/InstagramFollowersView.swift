import SwiftUI
import AppKit
import UniformTypeIdentifiers
import InstagramFollowersModule

struct InstagramFollowersView: View {
    @EnvironmentObject private var model: InstagramFollowersViewModel

    var body: some View {
        InstagramFollowersContent(model: model)
    }
}

private struct InstagramFollowersContent: View {
    @ObservedObject var model: InstagramFollowersViewModel

    var body: some View {
        Group {
            if model.result == nil { InstagramFollowersImportView(model: model) }
            else { InstagramFollowersResultsView(model: model) }
        }
        .navigationTitle("Comparador de seguidores de Instagram")
        .sheet(isPresented: $model.showingGuide) { InstagramFollowersGuideView() }
        .sheet(isPresented: $model.showingExport) { InstagramFollowersExportView(model: model) }
        .alert("No se ha podido completar la acción", isPresented: Binding(
            get: { model.errorMessage != nil },
            set: { if !$0 { model.errorMessage = nil } }
        )) {
            Button("Aceptar", role: .cancel) { model.errorMessage = nil }
        } message: { Text(model.errorMessage ?? "Error desconocido") }
        .alert("Aviso", isPresented: Binding(
            get: { model.warningMessage != nil },
            set: { if !$0 { model.warningMessage = nil } }
        )) {
            Button("Aceptar", role: .cancel) { model.warningMessage = nil }
        } message: { Text(model.warningMessage ?? "") }
    }
}

private struct InstagramFollowersImportView: View {
    @ObservedObject var model: InstagramFollowersViewModel
    @State private var isTargeted = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                privacyCard
                Picker("Tipo de importación", selection: Binding(
                    get: { model.importMode },
                    set: { model.changeMode($0) }
                )) {
                    ForEach(InstagramFollowersImportMode.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 520)
                inputArea
                if let catalog = model.catalog { catalogCard(catalog) }
                actionBar
            }
            .padding(30)
            .frame(maxWidth: 1_050, alignment: .leading)
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 7) {
                Text("Comparador de seguidores de Instagram").font(.largeTitle.bold())
                Text("Compara una exportación de Instagram sin iniciar sesión ni enviar datos fuera del Mac.")
                    .font(.title3).foregroundStyle(.secondary)
            }
            Spacer()
            Button { model.showingGuide = true } label: { Label("Cómo exportar", systemImage: "questionmark.circle") }
        }
    }

    private var privacyCard: some View {
        GroupBox {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "lock.shield.fill").font(.title).foregroundStyle(.green)
                VStack(alignment: .leading, spacing: 5) {
                    Text("Lectura privada y completamente local").font(.headline)
                    Text("ZEUVE abre los originales en lectura, no extrae el ZIP completo y no guarda permanentemente nombres de usuario ni resultados.")
                        .foregroundStyle(.secondary)
                }
            }.frame(maxWidth: .infinity, alignment: .leading).padding(4)
        }
    }

    private var inputArea: some View {
        VStack(spacing: 15) {
            Image(systemName: isTargeted ? "tray.and.arrow.down.fill" : "person.2.badge.gearshape")
                .font(.system(size: 44)).foregroundStyle(isTargeted ? Color.accentColor : .secondary)
            if model.importMode == .archive { archiveControls } else { jsonControls }
            if model.isPreparing { HStack { ProgressView().controlSize(.small); Text("Inspeccionando archivos…").foregroundStyle(.secondary) } }
        }
        .frame(maxWidth: .infinity, minHeight: 220)
        .padding(18)
        .background(Color.accentColor.opacity(isTargeted ? 0.12 : 0.045), in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(isTargeted ? Color.accentColor : Color.secondary.opacity(0.25), style: StrokeStyle(lineWidth: isTargeted ? 2 : 1, dash: [7])))
        .onDrop(of: [UTType.fileURL.identifier], isTargeted: $isTargeted) { providers in
            for provider in providers {
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                    let url: URL?
                    if let data = item as? Data { url = URL(dataRepresentation: data, relativeTo: nil) }
                    else { url = item as? URL }
                    if let url { Task { @MainActor in model.handleDropped(urls: [url]) } }
                }
            }
            return true
        }
    }

    private var archiveControls: some View {
        VStack(spacing: 10) {
            Text("Suelta aquí el ZIP completo exportado por Instagram").font(.headline)
            Text("Se localizarán following.json y todos los followers_<número>.json, aunque exista una carpeta raíz adicional.")
                .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
            Button("Seleccionar ZIP…") { model.selectArchive() }.buttonStyle(.borderedProminent)
            if let url = model.archiveURL { Label(url.lastPathComponent, systemImage: "archivebox").font(.caption) }
        }
    }

    private var jsonControls: some View {
        VStack(spacing: 12) {
            Text("Selecciona los JSON de seguidores y seguidos").font(.headline)
            Text("Debes incluir un following.json y todos los followers_<número>.json de la misma exportación.")
                .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
            HStack {
                Button("Elegir following.json…") { model.selectFollowing() }
                Button("Elegir followers_*.json…") { model.selectFollowers() }
            }
            VStack(alignment: .leading, spacing: 4) {
                Label(model.followingURL?.lastPathComponent ?? "following.json no seleccionado", systemImage: model.followingURL == nil ? "circle" : "checkmark.circle.fill")
                Label("\(model.followerURLs.count) archivos followers seleccionados", systemImage: model.followerURLs.isEmpty ? "circle" : "checkmark.circle.fill")
            }.font(.caption).foregroundStyle(.secondary)
        }
    }

    private func catalogCard(_ catalog: InstagramFollowersInputCatalog) -> some View {
        GroupBox("Archivos detectados") {
            VStack(alignment: .leading, spacing: 10) {
                fileRow(catalog.following)
                Divider()
                ForEach(catalog.followers) { fileRow($0) }
                if let count = catalog.archiveEntryCount {
                    Divider()
                    Text("El ZIP contiene \(count) entradas; solo se leerán los \(catalog.followers.count + 1) JSON necesarios.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                ForEach(catalog.warnings, id: \.self) { Label($0, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.orange) }
            }.padding(4)
        }
    }

    private func fileRow(_ file: InstagramFollowersFileDescriptor) -> some View {
        HStack {
            Image(systemName: "doc.text")
            VStack(alignment: .leading, spacing: 2) {
                Text(file.name).fontWeight(.medium)
                Text(file.path).font(.caption2).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
            }
            Spacer()
            Text(ByteCountFormatter.string(fromByteCount: file.size, countStyle: .file)).font(.caption).foregroundStyle(.secondary)
        }
    }

    private var actionBar: some View {
        HStack {
            if model.catalog != nil { Button("Cambiar selección", role: .destructive) { model.clearInput() } }
            Spacer()
            Button("Analizar exportación") { model.analyze() }
                .buttonStyle(.borderedProminent)
                .disabled(!model.canAnalyze)
            if model.isAnalyzing { Button("Cancelar", role: .destructive) { model.cancel() } }
        }
    }
}

private struct InstagramFollowersResultsView: View {
    @ObservedObject var model: InstagramFollowersViewModel

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    resultHeader
                    snapshotNotice
                    summaryCards
                    controls
                }
                .padding(28)
            }
            .frame(maxHeight: 390)
            Divider()
            accountList
        }
    }

    private var resultHeader: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Resultado de la comparación").font(.largeTitle.bold())
                if let result = model.result {
                    Text("\(result.followingCount) cuentas seguidas · \(result.followerCount) seguidores · \(result.followerFileCount) archivos de seguidores")
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Button("Exportar…") { model.showingExport = true }
            Button("Analizar otra exportación") { model.analyzeAnother() }.buttonStyle(.borderedProminent)
        }
    }

    private var snapshotNotice: some View {
        Label("Estos resultados corresponden al momento en que Instagram generó la exportación; no son una consulta en tiempo real.", systemImage: "clock.badge.exclamationmark")
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
    }

    private var summaryCards: some View {
        HStack(spacing: 14) {
            summaryCard(.notFollowingBack, systemImage: "person.crop.circle.badge.minus")
            summaryCard(.followersNotFollowed, systemImage: "person.crop.circle.badge.plus")
            summaryCard(.mutual, systemImage: "person.2.fill")
        }
    }

    private func summaryCard(_ category: InstagramFollowersCategory, systemImage: String) -> some View {
        Button { model.selectedCategory = category } label: {
            VStack(alignment: .leading, spacing: 7) {
                Image(systemName: systemImage).font(.title2)
                Text("\(model.result?.accounts(in: category).count ?? 0)").font(.system(size: 30, weight: .bold, design: .rounded))
                Text(category.title).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(model.selectedCategory == category ? Color.accentColor.opacity(0.14) : Color.secondary.opacity(0.07), in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(model.selectedCategory == category ? Color.accentColor : Color.clear))
        }.buttonStyle(.plain)
    }

    private var controls: some View {
        VStack(spacing: 12) {
            Picker("Categoría", selection: $model.selectedCategory) {
                ForEach(InstagramFollowersCategory.allCases) { Text($0.title).tag($0) }
            }.pickerStyle(.segmented)
            HStack {
                TextField("Buscar nombre de usuario", text: $model.searchText).textFieldStyle(.roundedBorder)
                Button {
                    model.sortAscending.toggle()
                } label: {
                    Label(model.sortAscending ? "A–Z" : "Z–A", systemImage: model.sortAscending ? "arrow.up" : "arrow.down")
                }
                Text("\(model.visibleAccounts.count) de \(model.categoryTotal)").font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private var accountList: some View {
        Group {
            if model.visibleAccounts.isEmpty {
                ContentUnavailableView(
                    model.appliedSearchText.isEmpty ? "No hay cuentas en esta categoría" : "No hay coincidencias",
                    systemImage: "person.slash",
                    description: Text(model.appliedSearchText.isEmpty ? "La exportación no contiene resultados para esta comparación." : "Prueba con otro nombre de usuario.")
                )
            } else {
                List(model.visibleAccounts) { account in
                    HStack {
                        Image(systemName: "person.crop.circle").foregroundStyle(.secondary)
                        Text(account.username).textSelection(.enabled)
                        Spacer()
                        Button("Abrir en Instagram") { model.openProfile(account) }
                            .help("Abre manualmente el perfil público en el navegador. Esta es la única acción del módulo que puede usar Internet.")
                    }.padding(.vertical, 4)
                }.listStyle(.inset)
            }
        }
    }
}

private struct InstagramFollowersExportView: View {
    @ObservedObject var model: InstagramFollowersViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var format: InstagramFollowersExportFormat = .csv
    @State private var visibleOnly = false

    private var count: Int { visibleOnly ? model.visibleAccounts.count : model.categoryTotal }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Exportar resultados").font(.title.bold())
            Text("Se exportarán \(count) cuentas de «\(model.selectedCategory.title)».")
                .foregroundStyle(.secondary)
            Picker("Formato", selection: $format) {
                Text("CSV").tag(InstagramFollowersExportFormat.csv)
                Text("TXT").tag(InstagramFollowersExportFormat.txt)
            }.pickerStyle(.segmented)
            Toggle("Exportar solo los resultados visibles tras la búsqueda", isOn: $visibleOnly)
            Text(format == .csv ? "El CSV incluirá las columnas username, category y URL." : "El TXT incluirá un nombre de usuario por línea.")
                .font(.caption).foregroundStyle(.secondary)
            HStack {
                Button("Cancelar", role: .cancel) { dismiss() }
                Spacer()
                Button("Elegir ubicación…") {
                    dismiss()
                    model.export(category: model.selectedCategory, visibleOnly: visibleOnly, format: format)
                }
                .buttonStyle(.borderedProminent)
                .disabled(count == 0)
            }
        }.padding(26).frame(width: 520)
    }
}

private struct InstagramFollowersGuideView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("Cómo obtener la exportación").font(.title.bold())
                Spacer(); Button("Cerrar") { dismiss() }
            }
            Text("En Instagram abre Configuración y actividad y entra en el Centro de cuentas.")
            numbered(1, "Abre «Tu información y permisos» y elige «Exportar tu información».")
            numbered(2, "Crea una exportación, selecciona el perfil de Instagram y elige exportar al dispositivo.")
            numbered(3, "Selecciona la información de seguidores y seguidos, el intervalo deseado y el formato JSON.")
            numbered(4, "Cuando Meta prepare el archivo, descárgalo y selecciónalo aquí como ZIP completo.")
            Label("La disponibilidad y los nombres exactos de los menús pueden cambiar en Instagram. ZEUVE no necesita tu contraseña, cookies ni acceso a la cuenta.", systemImage: "info.circle")
                .font(.caption).foregroundStyle(.secondary)
            Spacer()
        }.padding(28).frame(width: 620, height: 440)
    }

    private func numbered(_ number: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)").font(.headline).frame(width: 28, height: 28).background(Color.accentColor.opacity(0.15), in: Circle())
            Text(text).fixedSize(horizontal: false, vertical: true)
        }
    }
}
