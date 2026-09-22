import Foundation

public struct MultimediaDiskSpaceChecker: Sendable {
    public init() {}
    public func require(estimatedBytes: Int64, at url: URL, multiplier: Double = 1.15) throws {
        let attrs = try FileManager.default.attributesOfFileSystem(forPath: url.path)
        guard let raw = attrs[.systemFreeSize] as? NSNumber else { return }
        let required = Int64((Double(max(estimatedBytes, 1)) * max(multiplier, 1)).rounded(.up))
        let available = raw.int64Value
        guard available >= required else { throw MultimediaInspectorError.insufficientDiskSpace(required: required, available: available) }
    }
}
