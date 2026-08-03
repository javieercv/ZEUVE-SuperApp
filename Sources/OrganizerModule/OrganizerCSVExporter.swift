import Foundation

public struct OrganizerCSVExporter: Sendable {
    public init() {}

    @discardableResult
    public func export(
        plan: OrganizerPlan,
        to destination: URL,
        selectedIDs: Set<UUID>? = nil
    ) throws -> URL {
        let selected = selectedIDs ?? Set(plan.operations.map(\.id))
        var lines = ["Ruta original,Ruta de destino,Categoría,Formato,Estado,Conflicto"]
        for operation in plan.operations {
            lines.append([
                operation.source.path,
                operation.destination.path,
                operation.category,
                operation.formatFolder,
                selected.contains(operation.id) ? "Incluido" : "Excluido",
                operation.conflict ? "Sí" : "No",
            ].map(escape).joined(separator: ","))
        }
        let contents = "\u{FEFF}" + lines.joined(separator: "\r\n") + "\r\n"
        try contents.write(to: destination, atomically: true, encoding: .utf8)
        return destination
    }

    private func escape(_ value: String) -> String {
        let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
        if escaped.contains(",") || escaped.contains("\"") || escaped.contains("\n") || escaped.contains("\r") {
            return "\"\(escaped)\""
        }
        return escaped
    }
}
