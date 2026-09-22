import SwiftUI
import MultimediaInspectorModule

/// Raster en segundo plano; publicación de la imagen y Canvas aislados por SwiftUI.
struct SpectrogramRasterView: View {
    let result: SpectrogramResult
    let scale: SpectrogramFrequencyScale
    @State private var image: CGImage?

    private struct RenderKey: Equatable {
        let id: UUID
        let scale: SpectrogramFrequencyScale
        let width: Int
        let height: Int
    }

    var body: some View {
        GeometryReader { geometry in
            let key = RenderKey(id: result.renderID, scale: scale,
                                width: max(1, min(Int(geometry.size.width), 4096)),
                                height: max(1, min(Int(geometry.size.height), 4096)))
            Canvas { context, size in
                if let image {
                    context.draw(Image(decorative: image, scale: 1), in: CGRect(origin: .zero, size: size))
                }
            }
            .task(id: key) {
                let result = result
                let work = Task.detached(priority: .userInitiated) {
                    try SpectrogramRasterizer().rasterize(result, frequencyScale: key.scale,
                        width: key.width, height: key.height, shouldCancel: { Task.isCancelled })
                }
                let raster = try? await withTaskCancellationHandler {
                    try await work.value
                } onCancel: { work.cancel() }
                guard !Task.isCancelled, let raster,
                      let provider = CGDataProvider(data: Data(raster.rgba8) as CFData) else { return }
                image = CGImage(width: raster.width, height: raster.height, bitsPerComponent: 8, bitsPerPixel: 32,
                    bytesPerRow: raster.width * 4, space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                    provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)
            }
        }
    }
}
