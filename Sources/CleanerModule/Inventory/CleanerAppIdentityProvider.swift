import Foundation
#if os(macOS)
import AppKit
import Security
#endif

public protocol CleanerAppIdentityProviding: Sendable {
    func identity(for url: URL) -> CleanerAppIdentity?
    func runningBundleIdentifiers() -> Set<String>
    func knownApplicationURLs() -> [URL]
}

public struct SystemCleanerAppIdentityProvider: CleanerAppIdentityProviding {
    public init() {}
    public func identity(for url: URL) -> CleanerAppIdentity? {
        let standardized = url.standardizedFileURL
        guard standardized.pathExtension.lowercased() == "app", let bundle = Bundle(url: standardized) else { return nil }
        let bundleID = bundle.bundleIdentifier
        let name = (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
            ?? (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String)
            ?? standardized.deletingPathExtension().lastPathComponent
        let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let build = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        var signingIdentifier: String?; var teamID: String?; var groups: [String] = []; var isSigned = false
        #if os(macOS)
        var staticCode: SecStaticCode?
        if SecStaticCodeCreateWithPath(standardized as CFURL, [], &staticCode) == errSecSuccess, let staticCode {
            var signingInfo: CFDictionary?
            if SecCodeCopySigningInformation(staticCode, SecCSFlags(rawValue: kSecCSSigningInformation), &signingInfo) == errSecSuccess,
               let info = signingInfo as? [String: Any] {
                signingIdentifier = info[kSecCodeInfoIdentifier as String] as? String
                teamID = info[kSecCodeInfoTeamIdentifier as String] as? String
                if let entitlements = info[kSecCodeInfoEntitlementsDict as String] as? [String: Any] {
                    groups = entitlements["com.apple.security.application-groups"] as? [String] ?? []
                }
                isSigned = signingIdentifier != nil || teamID != nil
            }
        }
        #endif
        let components = standardized.path.split(separator: "/")
        let volumePath: String? = (standardized.path.hasPrefix("/Volumes/") && components.count >= 2) ? "/Volumes/\(components[1])" : "/"
        return CleanerAppIdentity(bundleID: bundleID, name: name, version: version, build: build, path: standardized.path, volumePath: volumePath, signingIdentifier: signingIdentifier, teamID: teamID, appGroups: groups.sorted(), isSigned: isSigned)
    }
    public func runningBundleIdentifiers() -> Set<String> {
        #if os(macOS)
        return Set(NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier))
        #else
        return []
        #endif
    }
    public func knownApplicationURLs() -> [URL] {
        #if os(macOS)
        return NSWorkspace.shared.runningApplications.compactMap(\.bundleURL)
        #else
        return []
        #endif
    }
}

