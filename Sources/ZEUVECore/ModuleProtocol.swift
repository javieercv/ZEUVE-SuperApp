import Foundation

public struct ModuleRequest: Codable, Sendable, Equatable {
    public let protocolVersion: String
    public let requestID: UUID
    public let moduleID: String
    public let action: String
    public let payload: [String: JSONValue]

    public init(
        protocolVersion: String = "1.0",
        requestID: UUID = UUID(),
        moduleID: String,
        action: String,
        payload: [String: JSONValue] = [:]
    ) {
        self.protocolVersion = protocolVersion
        self.requestID = requestID
        self.moduleID = moduleID
        self.action = action
        self.payload = payload
    }
}

public enum ModuleEventKind: String, Codable, Sendable {
    case accepted
    case progress
    case log
    case warning
    case result
    case failure
    case cancelled
}

public struct ModuleEvent: Codable, Sendable, Equatable {
    public let protocolVersion: String
    public let requestID: UUID
    public let kind: ModuleEventKind
    public let sequence: Int
    public let payload: [String: JSONValue]

    public init(
        protocolVersion: String = "1.0",
        requestID: UUID,
        kind: ModuleEventKind,
        sequence: Int,
        payload: [String: JSONValue] = [:]
    ) {
        self.protocolVersion = protocolVersion
        self.requestID = requestID
        self.kind = kind
        self.sequence = sequence
        self.payload = payload
    }
}
