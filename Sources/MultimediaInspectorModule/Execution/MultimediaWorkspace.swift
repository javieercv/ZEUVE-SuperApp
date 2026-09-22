import Foundation

public struct MultimediaWorkspace: Sendable {
    public let root: URL
    public let output: URL
    private let marker: URL
    public init(operationID: UUID, extension fileExtension: String, fileManager: FileManager = .default) throws {
        let base = fileManager.temporaryDirectory.appendingPathComponent("ZEUVE/MultimediaInspector", isDirectory: true)
        root = base.appendingPathComponent(operationID.uuidString, isDirectory: true)
        marker = root.appendingPathComponent(".zeuve-owned", isDirectory: false)
        output = root.appendingPathComponent("result.\(fileExtension)", isDirectory: false)
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        try operationID.uuidString.data(using: .utf8)?.write(to: marker, options: .atomic)
    }
    public func auxiliaryFile(named name: String) -> URL { root.appendingPathComponent(name, isDirectory: false) }

    public func cleanup(fileManager: FileManager = .default) {
        guard fileManager.fileExists(atPath: marker.path), root.path.contains("/ZEUVE/MultimediaInspector/") else { return }
        try? fileManager.removeItem(at: root)
    }
}
