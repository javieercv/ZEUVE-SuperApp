import Foundation

public struct ConverterDiskSpaceChecker: Sendable {
    public init() {}
    public func availableBytes(at url: URL) throws -> Int64 {
        let attributes = try FileManager.default.attributesOfFileSystem(forPath: url.path)
        guard let value = attributes[.systemFreeSize] as? NSNumber else {
            throw UniversalConverterError.unavailable("No se ha podido comprobar el espacio disponible.")
        }
        return value.int64Value
    }
    public func require(estimatedBytes: Int64?, at url: URL, safetyMultiplier: Double = 1.15) throws {
        guard let estimatedBytes, estimatedBytes > 0 else { return }
        let required = Int64((Double(estimatedBytes) * max(safetyMultiplier, 1)).rounded(.up))
        let available = try availableBytes(at: url)
        guard available >= required else { throw UniversalConverterError.insufficientDiskSpace(required: required, available: available) }
    }
}
