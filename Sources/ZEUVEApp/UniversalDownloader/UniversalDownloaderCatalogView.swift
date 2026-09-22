import Foundation
import SwiftUI
import UniversalDownloaderModule

struct UniversalDownloaderCatalogView: View {
    @EnvironmentObject private var model: UniversalDownloaderViewModel
    let analysis: DownloadAnalysis
    @State private var rangeStart = 1
    @State private var rangeEnd = 1

    private var visibleEntries: [DownloadCatalogItem] {
        analysis.playlistEntries.filter(model.isCatalogEntryVisible)
    }

    private var usesGrid: Bool {
        model.universalPreferences.catalogLayout == .grid
            && (analysis.platform == .instagram || analysis.kind == .profile || analysis.kind == .gallery)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("\(visibleEntries.count) elementos visibles")
                    .font(.subheadline.weight(.semibold))
                if visibleEntries.count != analysis.playlistEntries.count {
                    Text("de \(analysis.playlistEntries.count)")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Seleccionar visibles") { model.selectAll(in: analysis) }
                Button("Quitar selección") { model.clearSelection(in: analysis) }
            }
            if !usesGrid {
                HStack {
                    Stepper("Desde \(rangeStart)", value: $rangeStart, in: validRange)
                    Stepper("Hasta \(rangeEnd)", value: $rangeEnd, in: validRange)
                    Button("Aplicar intervalo") { model.selectRange(in: analysis, start: rangeStart, end: rangeEnd) }
                }
                .font(.caption)
                .disabled(visibleEntries.isEmpty)
            }
            if visibleEntries.isEmpty {
                ContentUnavailableView(
                    "No hay elementos visibles",
                    systemImage: "line.3.horizontal.decrease.circle",
                    description: Text("Activa más secciones en Ajustes > Descargador universal > Catálogo.")
                )
                .frame(minHeight: 150)
            } else if usesGrid {
                let minimum = CGFloat(max(120, model.universalPreferences.thumbnailSize))
                LazyVGrid(columns: [GridItem(.adaptive(minimum: minimum), spacing: 10)], spacing: 10) {
                    ForEach(visibleEntries) { entry in
                        gridCard(entry)
                    }
                }
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(visibleEntries) { entry in
                        listRow(entry)
                        Divider()
                    }
                }
            }
        }
        .onAppear { rangeEnd = max(1, visibleEntries.count) }
        .onChange(of: visibleEntries.count) { _, count in
            rangeEnd = max(1, count)
            rangeStart = min(rangeStart, max(1, count))
        }
    }

    private func listRow(_ entry: DownloadCatalogItem) -> some View {
        HStack {
            Toggle("", isOn: selectionBinding(entry))
                .labelsHidden().toggleStyle(.checkbox).disabled(!entry.isAvailable)
            Text(entry.playlistIndex.map(String.init) ?? "–")
                .font(.caption.monospacedDigit()).frame(width: 38, alignment: .trailing)
            mediaPreview(entry, width: 52, height: 42)
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.title).lineLimit(1)
                Label((entry.mediaKind ?? .unknown).spanishName, systemImage: (entry.mediaKind ?? .unknown).systemImage)
                    .font(.caption2).foregroundStyle(.secondary)
            }
            Spacer()
            if let duration = entry.duration { Text(durationText(duration)).font(.caption).foregroundStyle(.secondary) }
            statusLabels(entry)
            if let service = entry.serviceName { Text(service).font(.caption2).foregroundStyle(.secondary) }
        }
        .padding(.vertical, 6)
    }

    private func gridCard(_ entry: DownloadCatalogItem) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            ZStack(alignment: .topLeading) {
                mediaPreview(
                    entry,
                    width: CGFloat(max(120, model.universalPreferences.thumbnailSize)),
                    height: CGFloat(max(100, model.universalPreferences.thumbnailSize))
                )
                Toggle("Seleccionar", isOn: selectionBinding(entry))
                    .labelsHidden().toggleStyle(.checkbox)
                    .padding(7)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6))
                    .padding(6)
                    .disabled(!entry.isAvailable)
            }
            Text(entry.title).font(.subheadline.weight(.medium)).lineLimit(2)
            Label((entry.mediaKind ?? .unknown).spanishName, systemImage: (entry.mediaKind ?? .unknown).systemImage)
                .font(.caption).foregroundStyle(.secondary)
            HStack(spacing: 6) {
                if let duration = entry.duration { Text(durationText(duration)) }
                statusLabels(entry)
            }
            .font(.caption2)
        }
        .padding(8)
        .background(.quaternary.opacity(0.22), in: RoundedRectangle(cornerRadius: 9))
    }

    @ViewBuilder
    private func mediaPreview(_ entry: DownloadCatalogItem, width: CGFloat, height: CGFloat) -> some View {
        if let thumbnail = entry.thumbnailURL {
            AsyncImage(url: thumbnail) { phase in
                switch phase {
                case .success(let image): image.resizable().scaledToFill()
                case .failure: placeholder(entry)
                default: ZStack { Rectangle().fill(.quaternary.opacity(0.25)); ProgressView().controlSize(.small) }
                }
            }
            .frame(width: width, height: height)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 7))
        } else {
            placeholder(entry)
                .frame(width: width, height: height)
                .background(.quaternary.opacity(0.25), in: RoundedRectangle(cornerRadius: 7))
        }
    }

    private func placeholder(_ entry: DownloadCatalogItem) -> some View {
        Image(systemName: (entry.mediaKind ?? .unknown).systemImage)
            .resizable().scaledToFit().padding(12).foregroundStyle(.secondary)
    }

    @ViewBuilder
    private func statusLabels(_ entry: DownloadCatalogItem) -> some View {
        if model.isPreviouslyDownloaded(entry.canonicalID) {
            Text("Ya descargado").foregroundStyle(.secondary)
        }
        if model.isPossibleDuplicate(entry.canonicalID) {
            Text("Posible duplicado").foregroundStyle(.orange)
        }
        if !entry.isAvailable {
            Text("No disponible").foregroundStyle(.orange)
        }
    }

    private var validRange: ClosedRange<Int> { 1...max(1, visibleEntries.count) }

    private func selectionBinding(_ entry: DownloadCatalogItem) -> Binding<Bool> {
        let id = model.selectionID(analysis: analysis, entry: entry)
        return Binding(
            get: { model.selectedItemIDs.contains(id) },
            set: { selected in
                if selected { model.selectedItemIDs.insert(id) } else { model.selectedItemIDs.remove(id) }
            }
        )
    }

    private func durationText(_ value: Double) -> String {
        let total = max(0, Int(value))
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
