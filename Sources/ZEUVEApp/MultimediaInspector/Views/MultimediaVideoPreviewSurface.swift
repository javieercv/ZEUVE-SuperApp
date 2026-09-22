import SwiftUI
import AppKit
import MultimediaInspectorModule

struct MultimediaVideoPreviewSurface: View {
    let frame: MultimediaVideoPreviewFrame?
    let scaleMode: MultimediaVideoPreviewScaleMode

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.black)
            if let image = frame.flatMap(Self.makeImage) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: scaleMode == .fit ? .fit : .fill)
                    .clipped()
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "play.rectangle")
                        .font(.system(size: 30))
                    Text("Sin frame de vídeo")
                        .font(.caption)
                }
                .foregroundStyle(.secondary)
            }
        }
        .aspectRatio(16.0 / 9.0, contentMode: .fit)
        .frame(maxWidth: .infinity)
        .accessibilityLabel("Previsualización de vídeo")
    }

    private static func makeImage(_ frame: MultimediaVideoPreviewFrame) -> NSImage? {
        let bytesPerRow = frame.width * 4
        guard frame.pixelsBGRA.count >= bytesPerRow * frame.height,
              let provider = CGDataProvider(data: frame.pixelsBGRA as CFData),
              let image = CGImage(
                width: frame.width,
                height: frame.height,
                bitsPerComponent: 8,
                bitsPerPixel: 32,
                bytesPerRow: bytesPerRow,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue),
                provider: provider,
                decode: nil,
                shouldInterpolate: true,
                intent: .defaultIntent
              ) else { return nil }
        return NSImage(cgImage: image, size: NSSize(width: frame.width, height: frame.height))
    }
}
