import Foundation

public struct NativeImageService: Sendable {
    public init() {}

    @discardableResult
    public func convert(
        source: URL,
        destination: URL,
        target: ConverterFormat,
        options: ConverterOperationOptions,
        outputAsDirectory: Bool,
        progress: @escaping @Sendable (Double?) -> Void = { _ in }
    ) async throws -> [URL] {
#if canImport(ImageIO) && canImport(UniformTypeIdentifiers)
        return try await MacImageBridge.convert(
            source: source,
            destination: destination,
            target: target,
            options: options,
            outputAsDirectory: outputAsDirectory,
            progress: progress
        )
#else
        throw UniversalConverterError.unsupportedPlatform("La conversión nativa de imágenes requiere ImageIO en macOS.")
#endif
    }
}

#if canImport(ImageIO) && canImport(UniformTypeIdentifiers)
import ImageIO
import UniformTypeIdentifiers

private enum MacImageBridge {
    static func convert(
        source: URL,
        destination: URL,
        target: ConverterFormat,
        options: ConverterOperationOptions,
        outputAsDirectory: Bool,
        progress: @escaping @Sendable (Double?) -> Void
    ) async throws -> [URL] {
        guard let sourceRef = CGImageSourceCreateWithURL(source as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary) else {
            throw UniversalConverterError.invalidResult("No se puede leer la imagen «\(source.lastPathComponent)».")
        }
        let count = max(CGImageSourceGetCount(sourceRef), 1)
        let type = try destinationType(for: target)
        let supported = Set((CGImageDestinationCopyTypeIdentifiers() as NSArray).compactMap { $0 as? String })
        guard supported.contains(type as String) else {
            throw UniversalConverterError.incompatibleRecipe("macOS no ofrece un codificador para \(target.displayName) en este equipo.")
        }

        if outputAsDirectory {
            try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
            var outputs: [URL] = []
            outputs.reserveCapacity(count)
            for index in 0..<count {
                try Task.checkCancellation()
                let output = destination.appendingPathComponent(String(format: "imagen_%08d.%@", index + 1, target.fileExtension))
                try encodeFrame(
                    source: sourceRef,
                    index: index,
                    destination: output,
                    type: type,
                    options: options
                )
                outputs.append(output)
                progress(Double(index + 1) / Double(count))
            }
            guard !outputs.isEmpty else {
                throw UniversalConverterError.invalidResult("No se ha generado ninguna imagen.")
            }
            return outputs
        }

        try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        guard let destinationRef = CGImageDestinationCreateWithURL(destination as CFURL, type, count, nil) else {
            throw UniversalConverterError.invalidResult("No se puede preparar el archivo de salida \(target.displayName).")
        }
        for index in 0..<count {
            try Task.checkCancellation()
            guard let decoded = CGImageSourceCreateImageAtIndex(sourceRef, index, [kCGImageSourceShouldCacheImmediately: true] as CFDictionary) else {
                throw UniversalConverterError.invalidResult("No se puede decodificar la imagen o página \(index + 1).")
            }
            let image = try resizedImage(decoded, options: options)
            let properties = frameProperties(
                source: sourceRef,
                index: index,
                target: target,
                quality: options.quality,
                metadataPolicy: options.metadataPolicy
            )
            CGImageDestinationAddImage(destinationRef, image, properties)
            progress(Double(index + 1) / Double(count))
        }
        guard CGImageDestinationFinalize(destinationRef) else {
            throw UniversalConverterError.invalidResult("No se ha podido guardar la imagen convertida.")
        }
        return [destination]
    }

    private static func encodeFrame(
        source: CGImageSource,
        index: Int,
        destination: URL,
        type: CFString,
        options: ConverterOperationOptions
    ) throws {
        guard let decoded = CGImageSourceCreateImageAtIndex(source, index, [kCGImageSourceShouldCacheImmediately: true] as CFDictionary),
              let output = CGImageDestinationCreateWithURL(destination as CFURL, type, 1, nil) else {
            throw UniversalConverterError.invalidResult("No se puede preparar la imagen \(index + 1).")
        }
        let image = try resizedImage(decoded, options: options)
        let target = ConverterFormat.from(pathExtension: destination.pathExtension)
        CGImageDestinationAddImage(
            output,
            image,
            frameProperties(source: source, index: index, target: target, quality: options.quality, metadataPolicy: options.metadataPolicy)
        )
        guard CGImageDestinationFinalize(output) else {
            throw UniversalConverterError.invalidResult("No se ha podido guardar la imagen \(index + 1).")
        }
    }

    private static func resizedImage(_ image: CGImage, options: ConverterOperationOptions) throws -> CGImage {
        let sourceWidth = image.width
        let sourceHeight = image.height
        let requested: (Int, Int)?
        switch options.imageResizeMode {
        case .original:
            requested = nil
        case .percentage:
            let scale = Double(options.imageResizePercentage) / 100.0
            requested = (max(1, Int((Double(sourceWidth) * scale).rounded())), max(1, Int((Double(sourceHeight) * scale).rounded())))
        case .dimensions:
            if options.imageMaintainAspectRatio {
                var scale = min(Double(options.imageMaximumWidth) / Double(sourceWidth), Double(options.imageMaximumHeight) / Double(sourceHeight))
                if options.avoidUpscaling { scale = min(scale, 1) }
                requested = (max(1, Int((Double(sourceWidth) * scale).rounded())), max(1, Int((Double(sourceHeight) * scale).rounded())))
            } else {
                requested = (options.imageMaximumWidth, options.imageMaximumHeight)
            }
        }
        guard var requested else { return image }
        if options.avoidUpscaling {
            requested.0 = min(requested.0, sourceWidth)
            requested.1 = min(requested.1, sourceHeight)
        }
        guard requested.0 != sourceWidth || requested.1 != sourceHeight else { return image }

        let bits = image.bitsPerComponent > 8 ? 16 : 8
        let colorSpace = image.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        let byteOrder: UInt32 = bits == 16 ? CGImageByteOrderInfo.order16Big.rawValue : CGImageByteOrderInfo.order32Big.rawValue
        let bitmapInfo = CGBitmapInfo(rawValue: byteOrder | CGImageAlphaInfo.premultipliedLast.rawValue)
        guard let context = CGContext(
            data: nil,
            width: requested.0,
            height: requested.1,
            bitsPerComponent: bits,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else {
            throw UniversalConverterError.invalidResult("No se ha podido preparar el cambio de tamaño de la imagen.")
        }
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: requested.0, height: requested.1))
        guard let result = context.makeImage() else {
            throw UniversalConverterError.invalidResult("No se ha podido generar la imagen redimensionada.")
        }
        return result
    }

    private static func frameProperties(
        source: CGImageSource,
        index: Int,
        target: ConverterFormat,
        quality: ConverterQualityProfile,
        metadataPolicy: ConverterMetadataPolicy
    ) -> CFDictionary? {
        var values: [CFString: Any] = [:]
        if let original = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any] {
            switch metadataPolicy {
            case .allCompatible:
                values = original
            case .essentialOnly:
                if let tiff = original[kCGImagePropertyTIFFDictionary] { values[kCGImagePropertyTIFFDictionary] = tiff }
                if let exif = original[kCGImagePropertyExifDictionary] as? [CFString: Any] {
                    var essentialExif: [CFString: Any] = [:]
                    if let date = exif[kCGImagePropertyExifDateTimeOriginal] { essentialExif[kCGImagePropertyExifDateTimeOriginal] = date }
                    if let digitized = exif[kCGImagePropertyExifDateTimeDigitized] { essentialExif[kCGImagePropertyExifDateTimeDigitized] = digitized }
                    if !essentialExif.isEmpty { values[kCGImagePropertyExifDictionary] = essentialExif }
                }
                if let profile = original[kCGImagePropertyProfileName] { values[kCGImagePropertyProfileName] = profile }
            case .removeAll:
                break
            }
        }
        if target == .jpeg || target == .heic || target == .webp {
            let value: Double
            switch quality {
            case .low: value = 0.80
            case .medium: value = 0.90
            case .high: value = 0.97
            case .maximum, .custom: value = 1.0
            }
            values[kCGImageDestinationLossyCompressionQuality] = value
        }
        return values.isEmpty ? nil : values as CFDictionary
    }

    private static func destinationType(for format: ConverterFormat) throws -> CFString {
        switch format {
        case .png: return UTType.png.identifier as CFString
        case .jpeg: return UTType.jpeg.identifier as CFString
        case .heic: return UTType.heic.identifier as CFString
        case .webp: return UTType.webP.identifier as CFString
        case .tiff: return UTType.tiff.identifier as CFString
        case .bmp: return UTType.bmp.identifier as CFString
        case .gif: return UTType.gif.identifier as CFString
        default:
            throw UniversalConverterError.incompatibleRecipe("ImageIO no admite la salida \(format.displayName).")
        }
    }
}
#endif
