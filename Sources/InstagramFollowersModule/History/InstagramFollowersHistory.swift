import Foundation
import ZEUVECore
import ZEUVEStorage

public struct InstagramFollowersHistoryPayload: Codable, Sendable, Equatable {
    public let inputType: InstagramFollowersInputType
    public let followerFileCount: Int
    public let followingCount: Int
    public let followerCount: Int
    public let notFollowingBackCount: Int
    public let followersNotFollowedCount: Int
    public let mutualCount: Int
    public let warningCount: Int
    public let durationSeconds: Double
    public let exported: Bool

    public init(
        inputType: InstagramFollowersInputType,
        followerFileCount: Int,
        followingCount: Int,
        followerCount: Int,
        notFollowingBackCount: Int,
        followersNotFollowedCount: Int,
        mutualCount: Int,
        warningCount: Int,
        durationSeconds: Double,
        exported: Bool
    ) {
        self.inputType = inputType
        self.followerFileCount = followerFileCount
        self.followingCount = followingCount
        self.followerCount = followerCount
        self.notFollowingBackCount = notFollowingBackCount
        self.followersNotFollowedCount = followersNotFollowedCount
        self.mutualCount = mutualCount
        self.warningCount = warningCount
        self.durationSeconds = durationSeconds
        self.exported = exported
    }

    public init(result: InstagramFollowersComparisonResult, exported: Bool = false) {
        self.init(
            inputType: result.inputType,
            followerFileCount: result.followerFileCount,
            followingCount: result.followingCount,
            followerCount: result.followerCount,
            notFollowingBackCount: result.notFollowingBack.count,
            followersNotFollowedCount: result.followersNotFollowed.count,
            mutualCount: result.mutual.count,
            warningCount: result.warnings.count,
            durationSeconds: result.finishedAt.timeIntervalSince(result.startedAt),
            exported: exported
        )
    }
}

public final class InstagramFollowersHistoryService: @unchecked Sendable {
    private let repository: HistoryRepository?

    public init(repository: HistoryRepository?) {
        self.repository = repository
    }

    public func save(_ result: InstagramFollowersComparisonResult) throws {
        guard let repository else { return }
        let payload = InstagramFollowersHistoryPayload(result: result)
        try repository.add(OperationHistoryRecord(
            id: result.id,
            moduleID: instagramFollowersModuleIdentifier,
            kind: "compare-instagram-followers",
            baseFolder: nil,
            createdAt: result.finishedAt,
            status: .completed,
            undoAvailable: false,
            payload: try JSONEncoder().encode(payload)
        ))
    }

    public func markExported(id: UUID) throws {
        guard let repository, let record = try repository.record(id: id),
              var payload = try? JSONDecoder().decode(InstagramFollowersHistoryPayload.self, from: record.payload) else { return }
        payload = InstagramFollowersHistoryPayload(
            inputType: payload.inputType,
            followerFileCount: payload.followerFileCount,
            followingCount: payload.followingCount,
            followerCount: payload.followerCount,
            notFollowingBackCount: payload.notFollowingBackCount,
            followersNotFollowedCount: payload.followersNotFollowedCount,
            mutualCount: payload.mutualCount,
            warningCount: payload.warningCount,
            durationSeconds: payload.durationSeconds,
            exported: true
        )
        try repository.updateUndoState(
            id: id,
            status: record.status,
            undoAvailable: false,
            payload: try JSONEncoder().encode(payload)
        )
    }
}

public struct InstagramFollowersHistoryPresenter: ModuleHistoryPresenter {
    public let moduleID = instagramFollowersModuleIdentifier
    public init() {}

    public func presentation(for record: OperationHistoryRecord) -> ModuleHistoryPresentation {
        guard let payload = try? JSONDecoder().decode(InstagramFollowersHistoryPayload.self, from: record.payload) else {
            return GenericModuleHistoryPresenter(moduleID: moduleID).presentation(for: record)
        }
        return ModuleHistoryPresentation(
            title: "Comparación de seguidores",
            subtitle: "\(payload.followingCount) seguidos · \(payload.followerCount) seguidores",
            details: [
                "\(payload.notFollowingBackCount) no te siguen · \(payload.followersNotFollowedCount) no sigues · \(payload.mutualCount) mutuos",
                "\(payload.inputType.rawValue) · \(payload.followerFileCount) archivos de seguidores",
                "\(payload.warningCount) advertencias · " + (payload.exported ? "resultado exportado" : "sin exportar")
            ],
            outputFolder: nil
        )
    }
}
