import Foundation
#if SWIFT_PACKAGE
import ZEUVECore
#endif

public struct StorageContainer: Sendable {
    public let database: SQLiteDatabase
    public let settings: SettingsRepository
    public let history: HistoryRepository

    public init(databaseURL: URL) throws {
        let database = try SQLiteDatabase(url: databaseURL)
        self.database = database
        self.settings = try SettingsRepository(database: database)
        self.history = try HistoryRepository(database: database)
    }

    public static func live(fileManager: FileManager = .default) throws -> StorageContainer {
        let directory = try AppPaths.applicationSupport(fileManager: fileManager)
        return try StorageContainer(databaseURL: directory.appendingPathComponent("ZEUVE.sqlite"))
    }
}
