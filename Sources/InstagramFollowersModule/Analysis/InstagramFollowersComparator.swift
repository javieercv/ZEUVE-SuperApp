import Foundation

public struct InstagramFollowersComparator: Sendable {
    public init() {}

    public func compare(
        following: [InstagramAccount],
        followers: [[InstagramAccount]],
        startedAt: Date,
        inputType: InstagramFollowersInputType,
        warnings: [String]
    ) throws -> InstagramFollowersComparisonResult {
        try Task.checkCancellation()
        let followingMap = deduplicated(following)
        var followerMap: [String: InstagramAccount] = [:]
        for fileAccounts in followers {
            try Task.checkCancellation()
            for account in fileAccounts where followerMap[account.normalizedKey] == nil {
                followerMap[account.normalizedKey] = account
            }
        }

        let followingKeys = Set(followingMap.keys)
        let followerKeys = Set(followerMap.keys)
        let notFollowingBack = followingKeys.subtracting(followerKeys).compactMap { followingMap[$0] }.sorted()
        let followersNotFollowed = followerKeys.subtracting(followingKeys).compactMap { followerMap[$0] }.sorted()
        let mutual = followingKeys.intersection(followerKeys).compactMap { followingMap[$0] ?? followerMap[$0] }.sorted()

        return InstagramFollowersComparisonResult(
            startedAt: startedAt,
            finishedAt: Date(),
            inputType: inputType,
            followerFileCount: followers.count,
            followingCount: followingMap.count,
            followerCount: followerMap.count,
            notFollowingBack: notFollowingBack,
            followersNotFollowed: followersNotFollowed,
            mutual: mutual,
            warnings: warnings
        )
    }

    private func deduplicated(_ accounts: [InstagramAccount]) -> [String: InstagramAccount] {
        var result: [String: InstagramAccount] = [:]
        for account in accounts where result[account.normalizedKey] == nil { result[account.normalizedKey] = account }
        return result
    }
}
