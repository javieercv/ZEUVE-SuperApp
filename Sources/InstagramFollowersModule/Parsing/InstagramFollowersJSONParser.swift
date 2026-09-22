import Foundation

public struct InstagramFollowersParseResult: Sendable, Equatable {
    public let accounts: [InstagramAccount]
    public let ignoredEntries: Int

    public init(accounts: [InstagramAccount], ignoredEntries: Int) {
        self.accounts = accounts
        self.ignoredEntries = ignoredEntries
    }
}

public enum InstagramFollowersJSONRole: Sendable {
    case following
    case followers
}

public enum InstagramUsernameNormalizer {
    public static func account(from rawValue: String) -> InstagramAccount? {
        var value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        while value.hasPrefix("@") { value.removeFirst() }
        value = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, !looksLikeURL(value) else { return nil }
        guard value.range(of: #"^[A-Za-z0-9._]{1,30}$"#, options: .regularExpression) != nil else { return nil }
        return InstagramAccount(username: value, normalizedKey: value.lowercased(with: Locale(identifier: "en_US_POSIX")))
    }

    public static func account(fromInstagramURL rawValue: String) -> InstagramAccount? {
        guard let components = URLComponents(string: rawValue.trimmingCharacters(in: .whitespacesAndNewlines)),
              let host = components.host?.lowercased(),
              host == "instagram.com" || host.hasSuffix(".instagram.com") else { return nil }
        let pathComponents = components.path.split(separator: "/").map(String.init)
        guard !pathComponents.isEmpty else { return nil }
        let candidate: String
        if pathComponents.first?.lowercased() == "_u" {
            guard pathComponents.count >= 2 else { return nil }
            candidate = pathComponents[1]
        } else {
            let excluded = Set(["accounts", "about", "developer", "explore", "legal", "privacy", "reels", "stories"])
            guard let first = pathComponents.first, !excluded.contains(first.lowercased()) else { return nil }
            candidate = first
        }
        return account(from: candidate.removingPercentEncoding ?? candidate)
    }

    private static func looksLikeURL(_ value: String) -> Bool {
        let lower = value.lowercased()
        return lower.hasPrefix("http://") || lower.hasPrefix("https://") || lower.hasPrefix("www.") || lower.contains("instagram.com/")
    }
}

public struct InstagramFollowersJSONParser: Sendable {
    public init() {}

    public func parse(data: Data, role: InstagramFollowersJSONRole, sourceName: String) throws -> InstagramFollowersParseResult {
        let root: Any
        do {
            root = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
        } catch {
            throw InstagramFollowersError.malformedJSON(sourceName)
        }

        let relationships: [Any]
        switch role {
        case .following:
            guard let object = root as? [String: Any],
                  let array = object["relationships_following"] as? [Any] else {
                throw InstagramFollowersError.incompatibleJSON(sourceName)
            }
            relationships = array
        case .followers:
            guard let array = root as? [Any] else {
                throw InstagramFollowersError.incompatibleJSON(sourceName)
            }
            relationships = array
        }

        var byKey: [String: InstagramAccount] = [:]
        var ignored = 0
        for relationship in relationships {
            try Task.checkCancellation()
            guard let object = relationship as? [String: Any] else {
                ignored += 1
                continue
            }
            let extracted = extractAccounts(from: object)
            if extracted.isEmpty {
                ignored += 1
            } else {
                for account in extracted where byKey[account.normalizedKey] == nil {
                    byKey[account.normalizedKey] = account
                }
            }
        }
        return InstagramFollowersParseResult(accounts: Array(byKey.values).sorted(), ignoredEntries: ignored)
    }

    private func extractAccounts(from object: [String: Any]) -> [InstagramAccount] {
        if let data = object["string_list_data"] as? [[String: Any]] {
            let values = data.compactMap { entry -> InstagramAccount? in
                guard let value = entry["value"] as? String else { return nil }
                return InstagramUsernameNormalizer.account(from: value)
            }
            if !values.isEmpty { return deduplicated(values) }

            let links = data.compactMap { entry -> InstagramAccount? in
                guard let href = entry["href"] as? String else { return nil }
                return InstagramUsernameNormalizer.account(fromInstagramURL: href)
            }
            if !links.isEmpty { return deduplicated(links) }
        }

        if let title = object["title"] as? String,
           let account = InstagramUsernameNormalizer.account(from: title) {
            return [account]
        }

        if let data = object["media_list_data"] as? [[String: Any]] {
            let legacy = data.compactMap { entry -> InstagramAccount? in
                if let value = entry["value"] as? String,
                   let account = InstagramUsernameNormalizer.account(from: value) { return account }
                if let href = entry["href"] as? String { return InstagramUsernameNormalizer.account(fromInstagramURL: href) }
                return nil
            }
            if !legacy.isEmpty { return deduplicated(legacy) }
        }
        return []
    }

    private func deduplicated(_ accounts: [InstagramAccount]) -> [InstagramAccount] {
        var result: [InstagramAccount] = []
        var seen = Set<String>()
        for account in accounts where seen.insert(account.normalizedKey).inserted { result.append(account) }
        return result
    }
}
