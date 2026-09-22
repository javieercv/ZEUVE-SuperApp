import Foundation
import ZEUVECore

struct ConverterCodingKey: CodingKey {
    let stringValue: String
    let intValue: Int? = nil

    init(_ stringValue: String) { self.stringValue = stringValue }
    init?(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { return nil }
}

extension KeyedDecodingContainer where Key == ConverterCodingKey {
    func value<T: Decodable>(_ type: T.Type, for key: String, default defaultValue: T) throws -> T {
        try decodeIfPresent(type, forKey: ConverterCodingKey(key)) ?? defaultValue
    }
}
