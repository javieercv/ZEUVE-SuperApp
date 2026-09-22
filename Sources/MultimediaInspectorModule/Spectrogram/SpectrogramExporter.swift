import Foundation
#if canImport(CoreGraphics) && canImport(ImageIO)
import CoreGraphics
import ImageIO
#endif
#if canImport(UniformTypeIdentifiers)
import UniformTypeIdentifiers
#endif

public struct SpectrogramExporter: Sendable {
    private let rasterizer = SpectrogramRasterizer()

    public init() {}

    public func exportPNG(
        _ result: SpectrogramResult,
        frequencyScale: SpectrogramFrequencyScale = .linear,
        to url: URL,
        width requestedWidth: Int = 1600,
        height requestedHeight: Int = 900,
        shouldCancel: @Sendable () -> Bool = { false }
    ) throws {
        #if canImport(CoreGraphics) && canImport(ImageIO) && canImport(UniformTypeIdentifiers)
        let width = max(64, min(requestedWidth, 4096))
        let height = max(64, min(requestedHeight, 4096))
        let raster = try rasterizer.rasterize(
            result,
            frequencyScale: frequencyScale,
            width: width,
            height: height,
            shouldCancel: shouldCancel
        )
        if shouldCancel() { throw MultimediaInspectorError.cancelled }

        let data = Data(raster.rgba8)
        guard let provider = CGDataProvider(data: data as CFData) else {
            throw MultimediaInspectorError.exportUnavailable
        }
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let image = CGImage(
            width: raster.width,
            height: raster.height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: raster.width * 4,
            space: colorSpace,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        ), let destination = CGImageDestinationCreateWithURL(
            url as CFURL,
            UTType.png.identifier as CFString,
            1,
            nil
        ) else {
            throw MultimediaInspectorError.exportUnavailable
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw MultimediaInspectorError.exportUnavailable
        }
        #else
        throw MultimediaInspectorError.exportUnavailable
        #endif
    }
}
