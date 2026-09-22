import Foundation

public struct MultimediaOutputPublisher: Sendable {
    private let names: MultimediaFilenamePolicy
    public init(names: MultimediaFilenamePolicy = .init()) { self.names = names }
    public func publish(temporary: URL, proposed: URL, protectedOriginals: [URL], fileManager: FileManager = .default) throws -> URL {
        let protected = Set(protectedOriginals.map(MultimediaFilenamePolicy.canonical))
        let requested = proposed.standardizedFileURL
        guard !protected.contains(MultimediaFilenamePolicy.canonical(requested)) else { throw MultimediaInspectorError.outputMatchesOriginal }
        let parent = requested.deletingLastPathComponent()
        var isDir: ObjCBool = false
        guard fileManager.fileExists(atPath: parent.path, isDirectory: &isDir), isDir.boolValue, fileManager.isWritableFile(atPath: parent.path) else { throw MultimediaInspectorError.permissionDenied }
        let destination = try names.conflictFreeURL(requested, protectedPaths: protected, fileManager: fileManager)
        guard !protected.contains(MultimediaFilenamePolicy.canonical(destination)) else { throw MultimediaInspectorError.outputMatchesOriginal }
        let values = try temporary.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
        guard values.isRegularFile == true, values.isSymbolicLink != true, (values.fileSize ?? 0) > 0 else { throw MultimediaInspectorError.invalidOutput("el resultado temporal está vacío") }
        let staging = parent.appendingPathComponent(".zeuve-publish-\(UUID().uuidString)", isDirectory: false)
        defer { try? fileManager.removeItem(at: staging) }
        try fileManager.copyItem(at: temporary, to: staging)
        guard !fileManager.fileExists(atPath: destination.path) else { throw MultimediaInspectorError.invalidOutput("el destino cambió durante la publicación") }
        try fileManager.moveItem(at: staging, to: destination)
        return destination
    }
}
