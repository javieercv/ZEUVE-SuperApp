import Foundation

public struct NativePDFService: Sendable {
    public init() {}

    public func pdfToImages(source: URL, destinationDirectory: URL, format: ConverterFormat, dpi: Int, password: String? = nil) throws -> [URL] {
#if canImport(PDFKit) && canImport(AppKit)
        return try MacPDFBridge.pdfToImages(source: source, destinationDirectory: destinationDirectory, format: format, dpi: dpi, password: password)
#else
        throw UniversalConverterError.unsupportedPlatform("La conversión PDF a imágenes requiere PDFKit en macOS.")
#endif
    }

    public func pdfToText(source: URL, destination: URL, password: String? = nil) throws -> URL {
#if canImport(PDFKit)
        return try MacPDFBridge.pdfToText(source: source, destination: destination, password: password)
#else
        throw UniversalConverterError.unsupportedPlatform("La extracción de texto PDF requiere PDFKit en macOS.")
#endif
    }

    public func imagesToPDF(sources: [URL], destination: URL) throws -> URL {
#if canImport(PDFKit) && canImport(AppKit) && canImport(ImageIO)
        return try MacPDFBridge.imagesToPDF(sources: sources, destination: destination)
#else
        throw UniversalConverterError.unsupportedPlatform("La creación de PDF requiere PDFKit en macOS.")
#endif
    }
}

#if canImport(PDFKit) && canImport(AppKit)
import PDFKit
import AppKit
#if canImport(ImageIO)
import ImageIO
#endif

private enum MacPDFBridge {
    static func pdfToImages(source: URL, destinationDirectory: URL, format: ConverterFormat, dpi: Int, password: String?) throws -> [URL] {
        guard format == .png || format == .jpeg else { throw UniversalConverterError.incompatibleRecipe("PDF a imágenes admite PNG o JPG.") }
        let document = try openDocument(source: source, password: password)
        guard document.pageCount > 0 else {
            throw UniversalConverterError.invalidResult("El PDF no contiene páginas legibles.")
        }
        try FileManager.default.createDirectory(at: destinationDirectory, withIntermediateDirectories: true)
        var outputs: [URL] = []
        for index in 0..<document.pageCount {
            if Task.isCancelled { throw CancellationError() }
            guard let page = document.page(at: index) else { continue }
            let bounds = page.bounds(for: .mediaBox)
            let scale = CGFloat(max(72, min(dpi, 600))) / 72
            let width = max(1, Int((bounds.width * scale).rounded(.up)))
            let height = max(1, Int((bounds.height * scale).rounded(.up)))
            guard let rep = NSBitmapImageRep(
                bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height,
                bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
            ), let context = NSGraphicsContext(bitmapImageRep: rep) else {
                throw UniversalConverterError.invalidResult("No se ha podido preparar la página \(index + 1).")
            }
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = context
            context.cgContext.setFillColor(NSColor.white.cgColor)
            context.cgContext.fill(CGRect(x: 0, y: 0, width: width, height: height))
            context.cgContext.scaleBy(x: scale, y: scale)
            page.draw(with: .mediaBox, to: context.cgContext)
            NSGraphicsContext.restoreGraphicsState()
            let type: NSBitmapImageRep.FileType = format == .png ? .png : .jpeg
            let properties: [NSBitmapImageRep.PropertyKey: Any] = format == .jpeg ? [.compressionFactor: 0.96] : [:]
            guard let data = rep.representation(using: type, properties: properties) else {
                throw UniversalConverterError.invalidResult("No se ha podido codificar la página \(index + 1).")
            }
            let output = destinationDirectory.appendingPathComponent(String(format: "pagina_%04d.%@", index + 1, format.fileExtension))
            try data.write(to: output, options: .atomic)
            outputs.append(output)
        }
        guard !outputs.isEmpty else { throw UniversalConverterError.invalidResult("No se ha generado ninguna página.") }
        return outputs
    }

    static func pdfToText(source: URL, destination: URL, password: String?) throws -> URL {
        let document = try openDocument(source: source, password: password)
        guard document.pageCount > 0 else {
            throw UniversalConverterError.invalidResult("El PDF no contiene páginas legibles.")
        }
        var pageTexts: [String] = []
        pageTexts.reserveCapacity(document.pageCount)
        for index in 0..<document.pageCount {
            if Task.isCancelled { throw CancellationError() }
            if let text = document.page(at: index)?.string { pageTexts.append(text) }
        }
        let text = pageTexts.joined(separator: "\n\n").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            throw UniversalConverterError.invalidResult("El PDF no contiene texto extraíble. Puede ser un documento escaneado.")
        }
        try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(text.utf8).write(to: destination, options: .atomic)
        return destination
    }

    private static func openDocument(source: URL, password: String?) throws -> PDFDocument {
        guard let document = PDFDocument(url: source) else {
            throw UniversalConverterError.corruptFile(source.lastPathComponent)
        }
        guard document.isLocked else { return document }
        guard let password, !password.isEmpty else {
            throw UniversalConverterError.passwordRequired("PDF")
        }
        guard document.unlock(withPassword: password), !document.isLocked else {
            throw UniversalConverterError.passwordIncorrect("PDF")
        }
        return document
    }

#if canImport(ImageIO)
    static func imagesToPDF(sources: [URL], destination: URL) throws -> URL {
        let document = PDFDocument()
        var pageIndex = 0
        for source in sources {
            if Task.isCancelled { throw CancellationError() }
            guard let imageSource = CGImageSourceCreateWithURL(source as CFURL, nil) else {
                throw UniversalConverterError.invalidResult("No se puede leer \(source.lastPathComponent).")
            }
            let count = max(CGImageSourceGetCount(imageSource), 1)
            for index in 0..<count {
                if Task.isCancelled { throw CancellationError() }
                guard let cgImage = CGImageSourceCreateImageAtIndex(imageSource, index, nil) else { continue }
                let image = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
                guard let page = PDFPage(image: image) else { continue }
                document.insert(page, at: pageIndex); pageIndex += 1
            }
        }
        guard pageIndex > 0 else { throw UniversalConverterError.invalidResult("No se ha podido crear ninguna página.") }
        try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        guard document.write(to: destination) else { throw UniversalConverterError.invalidResult("No se ha podido guardar el PDF.") }
        return destination
    }
#endif
}
#endif
