import Foundation

/// La persistencia acepta datos estructurados, nunca texto libre de motores o URLs.
enum DownloadDiagnosticMetadata {
    static func sanitized(_ metadata: [String: String]) -> [String: String] {
        var result: [String: String] = [:]
        let numbers: Set<String> = ["duracion_ms", "codigo_salida", "resultados", "archivos", "elementos_unicos", "duplicados_omitidos", "fragmentos", "siguiente", "bytes", "primer_byte_ms"]
        let booleans: Set<String> = ["sesion_aportada", "sesion_validada", "requiere_autenticacion", "gallery_dl", "catalogo_instagram"]
        let engines = Set(UniversalEngineKind.allCases.map(\.rawValue))
        for (key, value) in metadata {
            if numbers.contains(key), Int64(value) != nil { result[key] = value }
            else if booleans.contains(key), ["sí", "no", "desconocida", "no_comprobada", "disponible", "no_disponible"].contains(value) { result[key] = value }
            else if ["motor", "motor_inicial", "fallback"].contains(key), engines.contains(value) { result[key] = value }
            else if key == "plataforma", UniversalDownloadPlatform(rawValue: value) != nil { result[key] = value }
            else if ["tipo", "tipo_resultado"].contains(key), DownloadContentKind(rawValue: value) != nil { result[key] = value }
            else if key == "fase", ["inicio", "analisis", "descarga", "validacion", "publicacion", "cancelacion"].contains(value) { result[key] = value }
            else if key == "codigo", ["sin_codigo", "catalog_partial", "request_blocked", "session_not_validated", "profile_lookup_ambiguous", "profile_lookup_failed", "public_lookup_blocked", "profile_unavailable"].contains(value) { result[key] = value }
            else if key == "operacion", UUID(uuidString: value) != nil { result[key] = value }
            else if ["referencia", "referencia_error"].contains(key), value.range(of: "^YT-[A-Fa-f0-9-]{8,36}$", options: .regularExpression) != nil { result[key] = value }
            else if key == "error" {
                let classified = DownloadErrorClassifier().classify(stderr: value)
                result["categoria"] = classified.category.rawValue
                result["referencia"] = classified.technicalReference
            }
        }
        return result
    }
}
