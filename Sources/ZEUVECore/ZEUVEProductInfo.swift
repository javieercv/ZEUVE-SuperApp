import Foundation

public enum ZEUVEProductInfo {
    public static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Desconocida"
    }

    public static var build: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "Desconocido"
    }

    public static var revision: String {
        Bundle.main.object(forInfoDictionaryKey: "ZEUVEReleaseRevision") as? String ?? "0"
    }

    /// Versión canónica propia de ZEUVE. Apple conserva MAJOR.MINOR.PATCH en
    /// CFBundleShortVersionString y ZEUVE añade REVISION desde su metadata de bundle.
    public static var releaseVersion: String {
        version == "Desconocida" ? version : "\(version).\(revision)"
    }

    public static var displayVersion: String {
        if releaseVersion == "Desconocida", build == "Desconocido" { return "Desconocida" }
        if build == "Desconocido" { return releaseVersion }
        return "\(releaseVersion) (\(build))"
    }

    public static var httpUserAgentToken: String {
        version == "Desconocida" ? "ZEUVE" : "ZEUVE/\(version)"
    }
}
