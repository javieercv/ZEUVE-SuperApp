import Foundation

public struct UniversalPlatformDownloadProfile: Codable, Sendable, Equatable, Identifiable {
    public var platform: UniversalDownloadPlatform
    public var settings: UniversalDownloadSettings

    public var id: String { platform.rawValue }

    public init(platform: UniversalDownloadPlatform, settings: UniversalDownloadSettings) {
        self.platform = platform
        self.settings = settings
    }
}

public struct UniversalCustomDownloadProfile: Codable, Sendable, Equatable, Identifiable {
    public let id: UUID
    public var name: String
    public var host: String
    public var includesSubdomains: Bool
    public var isEnabled: Bool
    public var settings: UniversalDownloadSettings

    public init(
        id: UUID = UUID(),
        name: String,
        host: String,
        includesSubdomains: Bool = true,
        isEnabled: Bool = true,
        settings: UniversalDownloadSettings
    ) {
        self.id = id
        self.name = name
        self.host = host
        self.includesSubdomains = includesSubdomains
        self.isEnabled = isEnabled
        self.settings = settings
    }

    public func matches(host candidate: String) -> Bool {
        let candidate = candidate.lowercased()
        let rule = host.lowercased()
        return candidate == rule || (includesSubdomains && candidate.hasSuffix(".\(rule)"))
    }
}

public struct UniversalDownloadProfiles: Codable, Sendable, Equatable {
    public static let currentSchemaVersion = 2

    public var schemaVersion: Int
    public var platformProfiles: [UniversalPlatformDownloadProfile]
    public var customProfiles: [UniversalCustomDownloadProfile]

    public init(
        schemaVersion: Int = UniversalDownloadProfiles.currentSchemaVersion,
        platformProfiles: [UniversalPlatformDownloadProfile] = UniversalDownloadProfiles.factoryPlatformProfiles,
        customProfiles: [UniversalCustomDownloadProfile] = []
    ) {
        self.schemaVersion = schemaVersion
        self.platformProfiles = platformProfiles
        self.customProfiles = customProfiles
        normalize()
    }

    public static var configurablePlatforms: [UniversalDownloadPlatform] {
        UniversalDownloadPlatform.allCases.filter { $0 != .automatic }
    }

    public static var factoryPlatformProfiles: [UniversalPlatformDownloadProfile] {
        configurablePlatforms.map { platform in
            UniversalPlatformDownloadProfile(
                platform: platform,
                settings: factorySettings(for: platform)
            )
        }
    }

    public static func factorySettings(for platform: UniversalDownloadPlatform) -> UniversalDownloadSettings {
        UniversalDownloadSettings(
            mode: .original,
            maximumResolution: .best,
            container: .automatic
        )
    }

    public mutating func normalize() {
        let sourceSchemaVersion = schemaVersion
        if sourceSchemaVersion < 2,
           let youtubeIndex = platformProfiles.firstIndex(where: { $0.platform == .youtube }),
           platformProfiles[youtubeIndex].settings == Self.legacyYouTubeFactorySettings {
            platformProfiles[youtubeIndex].settings = Self.factorySettings(for: .youtube)
        }
        schemaVersion = Self.currentSchemaVersion

        var seen = Set<UniversalDownloadPlatform>()
        platformProfiles = platformProfiles.compactMap { profile in
            guard profile.platform != .automatic, seen.insert(profile.platform).inserted else { return nil }
            var value = profile
            value.settings = Self.normalizedProfileSettings(value.settings, for: profile.platform)
            return value
        }
        for platform in Self.configurablePlatforms where !seen.contains(platform) {
            platformProfiles.append(.init(platform: platform, settings: Self.factorySettings(for: platform)))
        }
        platformProfiles.sort { lhs, rhs in
            let left = Self.configurablePlatforms.firstIndex(of: lhs.platform) ?? Int.max
            let right = Self.configurablePlatforms.firstIndex(of: rhs.platform) ?? Int.max
            return left < right
        }

        var customHosts = Set<String>()
        customProfiles = customProfiles.compactMap { profile in
            guard let host = try? UniversalCustomProfileHost.normalized(profile.host),
                  customHosts.insert(host).inserted else { return nil }
            var value = profile
            value.name = profile.name.trimmingCharacters(in: .whitespacesAndNewlines)
            if value.name.isEmpty { value.name = host }
            value.host = host
            value.settings = Self.normalizedProfileSettings(value.settings, for: .webpage)
            return value
        }
    }

    public func profile(for platform: UniversalDownloadPlatform) -> UniversalPlatformDownloadProfile {
        platformProfiles.first(where: { $0.platform == platform })
            ?? .init(platform: platform, settings: Self.factorySettings(for: platform))
    }

    public mutating func setSettings(_ settings: UniversalDownloadSettings, for platform: UniversalDownloadPlatform) {
        guard platform != .automatic else { return }
        let normalized = Self.normalizedProfileSettings(settings, for: platform)
        if let index = platformProfiles.firstIndex(where: { $0.platform == platform }) {
            platformProfiles[index].settings = normalized
        } else {
            platformProfiles.append(.init(platform: platform, settings: normalized))
        }
        normalize()
    }

    public mutating func restoreFactorySettings(for platform: UniversalDownloadPlatform) {
        setSettings(Self.factorySettings(for: platform), for: platform)
    }

    public mutating func restoreAllFactorySettings(keepingCustomProfiles: Bool = true) {
        platformProfiles = Self.factoryPlatformProfiles
        if !keepingCustomProfiles { customProfiles = [] }
        normalize()
    }

    public static func migrated(from legacy: UniversalDownloadSettings) -> UniversalDownloadProfiles {
        guard legacy.mode != .automatic else { return UniversalDownloadProfiles() }
        let profiles = configurablePlatforms.map {
            UniversalPlatformDownloadProfile(
                platform: $0,
                settings: normalizedProfileSettings(legacy, for: $0)
            )
        }
        return UniversalDownloadProfiles(platformProfiles: profiles)
    }

    private static var legacyYouTubeFactorySettings: UniversalDownloadSettings {
        UniversalDownloadSettings(
            mode: .audio,
            audioOutput: .mp3,
            mp3Bitrate: .kbps320
        )
    }

    fileprivate static func normalizedProfileSettings(
        _ settings: UniversalDownloadSettings,
        for platform: UniversalDownloadPlatform
    ) -> UniversalDownloadSettings {
        var value = settings
        if value.mode == .automatic {
            value = factorySettings(for: platform)
        }
        value.exactVideoFormatID = nil
        value.exactAudioFormatID = nil
        return value
    }
}

public enum UniversalCustomProfileHost {
    public static func normalized(_ rawValue: String) throws -> String {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw UniversalCustomProfileError.missingAddress }

        let candidate = trimmed.contains("://") ? trimmed : "https://\(trimmed)"
        guard let components = URLComponents(string: candidate),
              let scheme = components.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              components.user == nil,
              components.password == nil,
              let rawHost = components.host else {
            throw UniversalCustomProfileError.invalidAddress
        }
        let host = rawHost.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "."))
        guard !host.isEmpty, !host.contains(" "), host.contains(".") || host == "localhost" else {
            throw UniversalCustomProfileError.invalidAddress
        }
        return host
    }
}

public enum UniversalCustomProfileError: LocalizedError, Equatable {
    case missingAddress
    case invalidAddress
    case duplicateHost(String)

    public var errorDescription: String? {
        switch self {
        case .missingAddress:
            return "Introduce un enlace o dominio para la plataforma personalizada."
        case .invalidAddress:
            return "El enlace no contiene un dominio HTTP o HTTPS válido."
        case .duplicateHost(let host):
            return "Ya existe una plataforma personalizada para \(host)."
        }
    }
}

public struct UniversalDownloadSettingsResolver: Sendable {
    public init() {}

    public func settings(
        for item: UniversalDownloadItem,
        operationSettings: UniversalDownloadSettings,
        profiles: UniversalDownloadProfiles
    ) -> UniversalDownloadSettings {
        guard operationSettings.mode == .automatic else { return operationSettings }

        let host = sourceHost(for: item)
        let custom = host.flatMap { candidate in
            profiles.customProfiles
                .filter { $0.isEnabled && $0.matches(host: candidate) }
                .sorted { lhs, rhs in lhs.host.count > rhs.host.count }
                .first
        }
        let platform = effectivePlatform(for: item)
        var resolved = custom?.settings ?? profiles.profile(for: platform).settings
        resolved = UniversalDownloadProfiles.normalizedProfileSettings(resolved, for: platform)

        switch item.mediaKind.mediaClass {
        case .image, .collection:
            resolved.mode = .original
        case .audio where resolved.mode == .video:
            resolved.mode = .original
        default:
            break
        }

        // Red y autorizaciones continúan perteneciendo a la operación, no al perfil.
        resolved.network = operationSettings.network
        if operationSettings.conflictPolicy == .replaceConfirmed {
            resolved.conflictPolicy = .replaceConfirmed
        }
        return resolved
    }

    public func sourceHost(for item: UniversalDownloadItem) -> String? {
        let host = item.pageOrigin?.pageURL.host ?? item.sourceURL.host
        return host?.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "."))
    }

    public func effectivePlatform(for item: UniversalDownloadItem) -> UniversalDownloadPlatform {
        item.platform == .automatic ? UniversalDownloadPlatform.detect(from: item.sourceURL) : item.platform
    }
}
