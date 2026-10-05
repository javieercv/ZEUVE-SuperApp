import Foundation

/// Añade covr al MOV temporal propio. mdat no se mueve ni se carga en memoria.
public struct QuickTimeArtworkWriter: Sendable {
    public init() {}
    private let maximumMetadataBytes = 64 * 1024 * 1024

    public func write(image: URL, codec: String, workspace: MultimediaWorkspace) throws {
        let output = workspace.output
        let marker = workspace.root.appendingPathComponent(".zeuve-owned")
        guard output.pathExtension.lowercased() == "mov",
              UUID(uuidString: workspace.root.lastPathComponent) != nil,
              try String(contentsOf: marker, encoding: .utf8) == workspace.root.lastPathComponent,
              (try output.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])).isRegularFile == true,
              (try output.resourceValues(forKeys: [.isSymbolicLinkKey])).isSymbolicLink != true else { throw invalid() }
        let imageValues = try image.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
        guard imageValues.isRegularFile == true, imageValues.isSymbolicLink != true,
              let imageSize = imageValues.fileSize, imageSize > 0, imageSize < maximumMetadataBytes else { throw invalid() }
        let dataType: UInt32
        switch codec.lowercased() {
        case "mjpeg", "jpeg": dataType = 13
        case "png": dataType = 14
        default: throw invalid()
        }
        let imageData = try Data(contentsOf: image)
        guard imageData.count == imageSize, imageData.count < maximumMetadataBytes else { throw invalid() }
        let cover = try box("covr", payload: box("data", payload: word(dataType) + word(0) + imageData))
        let handle = try FileHandle(forUpdating: output)
        defer { try? handle.close() }
        let fileSize = try handle.seekToEnd()
        var position: UInt64 = 0
        var movie: (offset: UInt64, size: UInt64, header: Int)?
        var quickTime = false
        while position < fileSize {
            try Task.checkCancellation()
            try handle.seek(toOffset: position)
            let header = try read(handle, count: 8)
            let type = String(decoding: header[4..<8], as: UTF8.self)
            var size = UInt64(number(header[0..<4]))
            var headerSize = 8
            if size == 1 { size = number64(try read(handle, count: 8)); headerSize = 16 }
            if size == 0 { size = fileSize - position }
            guard size >= UInt64(headerSize), size <= fileSize - position else { throw invalid() }
            if type == "ftyp", size >= UInt64(headerSize + 4) {
                quickTime = try read(handle, count: 4) == Data("qt  ".utf8)
            }
            if type == "moov" {
                guard movie == nil else { throw invalid() }
                movie = (position, size, headerSize)
            }
            position += size
        }
        guard quickTime, let movie, movie.offset + movie.size == fileSize,
              movie.size < UInt64(maximumMetadataBytes) else { throw invalid() }
        try handle.seek(toOffset: movie.offset + UInt64(movie.header))
        let original = try read(handle, count: Int(movie.size) - movie.header)
        let modified = try addingCover(toMovie: original, cover: cover)
        guard modified.count < maximumMetadataBytes else { throw invalid() }
        let result = try box("moov", payload: modified)
        try Task.checkCancellation()
        // Solo moov, al final del archivo: los offsets de todas las muestras siguen válidos.
        try handle.seek(toOffset: movie.offset)
        try handle.write(contentsOf: result)
        try handle.truncate(atOffset: movie.offset + UInt64(result.count))
        try handle.synchronize()
    }

    private func addingCover(toMovie movie: Data, cover: Data) throws -> Data {
        var found = false
        var result = Data()
        for child in try children(movie) {
            if child.type == "udta" {
                guard !found else { throw invalid() }; found = true
                result += try box("udta", payload: addingCover(toUserData: child.payload, cover: cover))
            } else { result += child.raw }
        }
        if !found { result += try box("udta", payload: newMetadata(cover: cover)) }
        return result
    }

    private func addingCover(toUserData data: Data, cover: Data) throws -> Data {
        var found = false
        var result = Data()
        for child in try children(data) {
            if child.type == "meta" {
                guard !found, child.payload.count >= 4 else { throw invalid() }; found = true
                var payload = Data(child.payload.prefix(4))
                let entries = try children(Data(child.payload.dropFirst(4)))
                // covr pertenece al esquema iTunes; no reinterpretar metadata mdta ajena.
                let handlers = entries.filter { $0.type == "hdlr" }
                guard handlers.count == 1, handlers[0].payload.count >= 12,
                      handlers[0].payload[8..<12] == Data("mdir".utf8) else { throw invalid() }
                var hasList = false
                for entry in entries {
                    if entry.type == "ilst" {
                        guard !hasList else { throw invalid() }; hasList = true
                        let retained = try children(entry.payload).filter { $0.type != "covr" }.reduce(Data()) { $0 + $1.raw }
                        payload += try box("ilst", payload: retained + cover)
                    } else { payload += entry.raw }
                }
                if !hasList { payload += try box("ilst", payload: cover) }
                result += try box("meta", payload: payload)
            } else { result += child.raw }
        }
        if !found { result += try newMetadata(cover: cover) }
        return result
    }

    private func newMetadata(cover: Data) throws -> Data {
        let handler = try box("hdlr", payload: Data(repeating: 0, count: 8) + Data("mdirappl".utf8) + Data(repeating: 0, count: 9))
        return try box("meta", payload: word(0) + handler + box("ilst", payload: cover))
    }

    private func children(_ data: Data) throws -> [(type: String, payload: Data, raw: Data)] {
        var result: [(String, Data, Data)] = []
        var offset = 0
        while offset < data.count {
            guard data.count - offset >= 8 else { throw invalid() }
            let size = Int(number(data[offset..<(offset + 4)]))
            guard size >= 8, size <= data.count - offset else { throw invalid() }
            result.append((String(decoding: data[(offset + 4)..<(offset + 8)], as: UTF8.self),
                           Data(data[(offset + 8)..<(offset + size)]), Data(data[offset..<(offset + size)])))
            offset += size
        }
        return result
    }

    private func box(_ type: String, payload: Data) throws -> Data {
        guard payload.count < Int(UInt32.max) - 8 else { throw invalid() }
        return word(UInt32(payload.count + 8)) + Data(type.utf8) + payload
    }
    private func word(_ value: UInt32) -> Data {
        Data([UInt8((value >> 24) & 255), UInt8((value >> 16) & 255), UInt8((value >> 8) & 255), UInt8(value & 255)])
    }
    private func number(_ data: Data.SubSequence) -> UInt32 { data.reduce(0) { ($0 << 8) | UInt32($1) } }
    private func number64(_ data: Data) -> UInt64 { data.reduce(0) { ($0 << 8) | UInt64($1) } }
    private func read(_ handle: FileHandle, count: Int) throws -> Data {
        let data = try handle.read(upToCount: count) ?? Data()
        guard data.count == count else { throw invalid() }
        return data
    }
    private func invalid() -> MultimediaInspectorError {
        .invalidOutput("la carátula MOV no se puede incorporar de forma segura al temporal QuickTime")
    }
}
