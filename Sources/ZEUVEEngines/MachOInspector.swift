import Foundation

public enum MachOInspector {
    private static let mhMagic64: UInt32 = 0xfeedfacf
    private static let mhCigam64: UInt32 = 0xcffaedfe
    private static let fatMagic: UInt32 = 0xcafebabe
    private static let fatCigam: UInt32 = 0xbebafeca
    private static let fatMagic64: UInt32 = 0xcafebabf
    private static let fatCigam64: UInt32 = 0xbfbafeca
    private static let cpuTypeARM64: UInt32 = 0x0100000c

    public static func architectures(at url: URL) throws -> Set<EngineArchitecture> {
        let data = try Data(contentsOf: url, options: [.mappedIfSafe])
        guard data.count >= 8 else { return [] }
        let magic = readUInt32(data, offset: 0, bigEndian: true)

        if magic == mhMagic64 || magic == mhCigam64 {
            let little = magic == mhCigam64
            let cpu = readUInt32(data, offset: 4, bigEndian: !little)
            return cpu == cpuTypeARM64 ? [.arm64] : []
        }

        let isFat32 = magic == fatMagic || magic == fatCigam
        let isFat64 = magic == fatMagic64 || magic == fatCigam64
        guard isFat32 || isFat64 else { return [] }
        let little = magic == fatCigam || magic == fatCigam64
        let count = Int(readUInt32(data, offset: 4, bigEndian: !little))
        let entrySize = isFat64 ? 32 : 20
        guard count > 0, data.count >= 8 + count * entrySize else { return [] }
        var hasARM64 = false
        var hasOther = false
        for index in 0..<count {
            let cpu = readUInt32(data, offset: 8 + index * entrySize, bigEndian: !little)
            if cpu == cpuTypeARM64 { hasARM64 = true } else { hasOther = true }
        }
        if hasARM64 && hasOther { return [.arm64, .universal] }
        return hasARM64 ? [.arm64] : []
    }

    public static func satisfies(_ expected: EngineArchitecture, at url: URL) -> Bool {
        guard let found = try? architectures(at: url) else { return false }
        switch expected {
        case .arm64: return found.contains(.arm64)
        case .universal: return found.contains(.universal)
        }
    }

    private static func readUInt32(_ data: Data, offset: Int, bigEndian: Bool) -> UInt32 {
        let bytes = [UInt8](data[offset..<(offset + 4)])
        if bigEndian {
            return UInt32(bytes[0]) << 24 | UInt32(bytes[1]) << 16 | UInt32(bytes[2]) << 8 | UInt32(bytes[3])
        }
        return UInt32(bytes[3]) << 24 | UInt32(bytes[2]) << 16 | UInt32(bytes[1]) << 8 | UInt32(bytes[0])
    }
}
