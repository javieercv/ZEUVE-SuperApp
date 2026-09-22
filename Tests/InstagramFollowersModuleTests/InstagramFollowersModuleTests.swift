import XCTest
import ZEUVECore
import ZEUVEStorage
import ZEUVEOperations
@testable import InstagramFollowersModule

final class InstagramFollowersModuleTests: XCTestCase {
    private let parser = InstagramFollowersJSONParser()

    func testFollowingUsesValueBeforeHrefAndTitle() throws {
        let data = try jsonData([
            "relationships_following": [[
                "title": "title_user",
                "string_list_data": [[
                    "href": "https://www.instagram.com/href_user/?x=1",
                    "value": "Value.User"
                ]]
            ]]
        ])
        let result = try parser.parse(data: data, role: .following, sourceName: "following.json")
        XCTAssertEqual(result.accounts.map(\.username), ["Value.User"])
    }

    func testHrefSupportsDirectAndUnderscoreUPaths() throws {
        let data = try jsonData([
            ["string_list_data": [["href": "https://www.instagram.com/_u/first.user/?hl=es"]]],
            ["string_list_data": [["href": "https://instagram.com/second_user/#fragment"]]]
        ])
        let result = try parser.parse(data: data, role: .followers, sourceName: "followers_1.json")
        XCTAssertEqual(Set(result.accounts.map(\.username)), Set(["first.user", "second_user"]))
    }

    func testTitleAndLegacyFallbacks() throws {
        let data = try jsonData([
            ["title": "Title_User"],
            ["media_list_data": [["value": "legacy.user"]]]
        ])
        let result = try parser.parse(data: data, role: .followers, sourceName: "followers_1.json")
        XCTAssertEqual(Set(result.accounts.map(\.normalizedKey)), Set(["title_user", "legacy.user"]))
    }

    func testInvalidAndURLOnlyEntriesAreIgnored() throws {
        let data = try jsonData([
            ["string_list_data": [["value": "https://instagram.com/not_a_value"]]],
            ["title": "invalid name"],
            NSNull()
        ])
        let result = try parser.parse(data: data, role: .followers, sourceName: "followers_1.json")
        XCTAssertTrue(result.accounts.isEmpty)
        XCTAssertEqual(result.ignoredEntries, 3)
    }

    func testEmptyValidFilesAreAccepted() throws {
        let following = try parser.parse(data: try jsonData(["relationships_following": []]), role: .following, sourceName: "following.json")
        let followers = try parser.parse(data: try jsonData([]), role: .followers, sourceName: "followers_1.json")
        XCTAssertTrue(following.accounts.isEmpty)
        XCTAssertTrue(followers.accounts.isEmpty)
    }

    func testMalformedAndIncompatibleJSONAreDifferent() throws {
        XCTAssertThrowsError(try parser.parse(data: Data("{".utf8), role: .following, sourceName: "following.json")) { error in
            XCTAssertEqual(error as? InstagramFollowersError, .malformedJSON("following.json"))
        }
        XCTAssertThrowsError(try parser.parse(data: try jsonData([]), role: .following, sourceName: "following.json")) { error in
            XCTAssertEqual(error as? InstagramFollowersError, .incompatibleJSON("following.json"))
        }
    }

    func testComparisonIsCaseInsensitiveAndDeduplicatedAcrossFollowerFiles() throws {
        let following = [account("Alpha"), account("beta.user"), account("OnlyFollowing")]
        let followers = [
            [account("alpha"), account("FollowerOnly")],
            [account("ALPHA"), account("Beta.User")]
        ]
        let result = try InstagramFollowersComparator().compare(
            following: following,
            followers: followers,
            startedAt: Date(),
            inputType: .jsonFiles,
            warnings: []
        )
        XCTAssertEqual(result.followingCount, 3)
        XCTAssertEqual(result.followerCount, 3)
        XCTAssertEqual(result.notFollowingBack.map(\.normalizedKey), ["onlyfollowing"])
        XCTAssertEqual(result.followersNotFollowed.map(\.normalizedKey), ["followeronly"])
        XCTAssertEqual(Set(result.mutual.map(\.normalizedKey)), Set(["alpha", "beta.user"]))
    }

    func testNormalizerPreservesDotsAndUnderscores() {
        XCTAssertEqual(InstagramUsernameNormalizer.account(from: "  @User.Name_1 ")?.username, "User.Name_1")
        XCTAssertEqual(InstagramUsernameNormalizer.account(from: "  @User.Name_1 ")?.normalizedKey, "user.name_1")
    }

    func testCSVExportEscapesFieldsAndRefusesSilentOverwrite() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let output = directory.appendingPathComponent("result.csv")
        let exporter = InstagramFollowersExporter()
        try exporter.export(accounts: [account("valid.user")], category: .mutual, format: .csv, destination: output, overwrite: false)
        let text = try String(contentsOf: output, encoding: .utf8)
        XCTAssertTrue(text.contains("username,category,url"))
        XCTAssertTrue(text.contains("valid.user,seguimiento_mutuo,https://www.instagram.com/valid.user/"))
        XCTAssertThrowsError(try exporter.export(accounts: [], category: .mutual, format: .csv, destination: output, overwrite: false))
        try exporter.export(accounts: [account("replacement.user")], category: .mutual, format: .csv, destination: output, overwrite: true)
        let replaced = try String(contentsOf: output, encoding: .utf8)
        XCTAssertTrue(replaced.contains("replacement.user"))
        XCTAssertFalse(replaced.contains("valid.user"))
    }


    func testArchiveCatalogFindsArbitraryRootAndOrdersMultipleFollowerFilesWithGaps() throws {
        let root = try temporaryDirectory()
        let dataFolder = root.appendingPathComponent("export-2026/connections/followers_and_following", isDirectory: true)
        try FileManager.default.createDirectory(at: dataFolder, withIntermediateDirectories: true)
        try jsonData(["relationships_following": []]).write(to: dataFolder.appendingPathComponent("following.json"))
        try jsonData([]).write(to: dataFolder.appendingPathComponent("followers_10.json"))
        try jsonData([]).write(to: dataFolder.appendingPathComponent("followers_2.json"))
        let zip = try zipDirectory(root)
        let catalog = try InstagramFollowersArchiveReader(url: zip).catalog()
        XCTAssertEqual(catalog.followers.map(\.sequence), [2, 10])
        XCTAssertEqual(catalog.following.name, "following.json")
        let payloads = try InstagramFollowersArchiveReader(url: zip).readRelevantFiles(catalog: catalog)
        XCTAssertEqual(payloads.count, 3)
    }

    func testArchiveRejectsMultipleFollowingFilesAndMissingFollowers() throws {
        let root = try temporaryDirectory()
        for folderName in ["one", "two"] {
            let folder = root.appendingPathComponent("\(folderName)/connections/followers_and_following", isDirectory: true)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try jsonData(["relationships_following": []]).write(to: folder.appendingPathComponent("following.json"))
            try jsonData([]).write(to: folder.appendingPathComponent("followers_1.json"))
        }
        let zip = try zipDirectory(root)
        XCTAssertThrowsError(try InstagramFollowersArchiveReader(url: zip).catalog()) { error in
            XCTAssertEqual(error as? InstagramFollowersError, .multipleFollowingFiles)
        }

        let secondRoot = try temporaryDirectory()
        let folder = secondRoot.appendingPathComponent("connections/followers_and_following", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try jsonData(["relationships_following": []]).write(to: folder.appendingPathComponent("following.json"))
        let missingZip = try zipDirectory(secondRoot)
        XCTAssertThrowsError(try InstagramFollowersArchiveReader(url: missingZip).catalog()) { error in
            XCTAssertEqual(error as? InstagramFollowersError, .followersNotFound)
        }
    }

    func testAdvancedCatalogSortsFilesAndRejectsDuplicateSequence() async throws {
        let root = try temporaryDirectory()
        let following = root.appendingPathComponent("following.json")
        let followersTwo = root.appendingPathComponent("followers_2.json")
        let followersOne = root.appendingPathComponent("followers_1.json")
        try jsonData(["relationships_following": []]).write(to: following)
        try jsonData([]).write(to: followersTwo)
        try jsonData([]).write(to: followersOne)
        let service = InstagramFollowersService(coordinator: OperationCoordinator(), history: InstagramFollowersHistoryService(repository: nil))
        let prepared = try await service.inspectJSONFiles(following: following, followers: [followersTwo, followersOne])
        XCTAssertEqual(prepared.catalog.followers.map(\.sequence), [1, 2])
        await XCTAssertThrowsErrorAsync(try await service.inspectJSONFiles(following: following, followers: [followersOne, followersOne]))
    }

    func testServiceAnalyzesSeveralFollowerFilesWithoutPersistingUsernames() async throws {
        let root = try temporaryDirectory()
        let following = root.appendingPathComponent("following.json")
        let followersOne = root.appendingPathComponent("followers_1.json")
        let followersThree = root.appendingPathComponent("followers_3.json")
        try jsonData(["relationships_following": [relationship("PrivateFollowing"), relationship("Mutual.User")]]).write(to: following)
        try jsonData([relationship("mutual.user")]).write(to: followersOne)
        try jsonData([relationship("PrivateFollower")]).write(to: followersThree)
        let storage = try StorageContainer(databaseURL: root.appendingPathComponent("history.sqlite"))
        let service = InstagramFollowersService(coordinator: OperationCoordinator(), history: InstagramFollowersHistoryService(repository: storage.history))
        let prepared = try await service.inspectJSONFiles(following: following, followers: [followersThree, followersOne])
        let result = try await service.analyze(prepared)
        XCTAssertEqual(result.notFollowingBack.map(\.normalizedKey), ["privatefollowing"])
        XCTAssertEqual(result.followersNotFollowed.map(\.normalizedKey), ["privatefollower"])
        XCTAssertEqual(result.mutual.map(\.normalizedKey), ["mutual.user"])
        let record = try XCTUnwrap(storage.history.records(moduleID: instagramFollowersModuleIdentifier).first)
        let raw = String(data: record.payload, encoding: .utf8) ?? ""
        XCTAssertFalse(raw.contains("PrivateFollowing"))
        XCTAssertFalse(raw.contains("PrivateFollower"))
        XCTAssertFalse(raw.contains("Mutual.User"))
        XCTAssertNil(record.baseFolder)
    }

    func testHistoryExportFlagUpdatesOnlyAggregatePayload() throws {
        let root = try temporaryDirectory()
        let storage = try StorageContainer(databaseURL: root.appendingPathComponent("history.sqlite"))
        let now = Date()
        let result = InstagramFollowersComparisonResult(
            startedAt: now,
            finishedAt: now,
            inputType: .archive,
            followerFileCount: 2,
            followingCount: 3,
            followerCount: 4,
            notFollowingBack: [account("secret.one")],
            followersNotFollowed: [],
            mutual: [],
            warnings: []
        )
        let history = InstagramFollowersHistoryService(repository: storage.history)
        try history.save(result)
        try history.markExported(id: result.id)
        let record = try XCTUnwrap(storage.history.record(id: result.id))
        let payload = try JSONDecoder().decode(InstagramFollowersHistoryPayload.self, from: record.payload)
        XCTAssertTrue(payload.exported)
        XCTAssertFalse((String(data: record.payload, encoding: .utf8) ?? "").contains("secret.one"))
    }

    func testLargeComparisonProducesStableCounts() throws {
        let following = (0..<40_000).map { account("follow_\($0)") }
        let followersA = (20_000..<50_000).map { account("FOLLOW_\($0)") }
        let followersB = (45_000..<55_000).map { account("follow_\($0)") }
        let result = try InstagramFollowersComparator().compare(
            following: following,
            followers: [followersA, followersB],
            startedAt: Date(),
            inputType: .jsonFiles,
            warnings: []
        )
        XCTAssertEqual(result.followingCount, 40_000)
        XCTAssertEqual(result.followerCount, 35_000)
        XCTAssertEqual(result.notFollowingBack.count, 20_000)
        XCTAssertEqual(result.followersNotFollowed.count, 15_000)
        XCTAssertEqual(result.mutual.count, 20_000)
    }

    func testParserHonorsCancellationWithoutReturningPartialLists() async throws {
        let relationships = (0..<10_000).map { relationship("cancel_\($0)") }
        let data = try jsonData(["relationships_following": relationships])
        let parser = InstagramFollowersJSONParser()
        let task = Task.detached { try parser.parse(data: data, role: .following, sourceName: "following.json") }
        task.cancel()
        do {
            _ = try await task.value
            XCTFail("La operación cancelada no debe devolver una lista parcial")
        } catch is CancellationError {
        }
    }

    func testSafeArchivePathsRejectTraversalAbsoluteAndDrivePaths() throws {
        for path in ["../following.json", "/absolute/following.json", "C:/following.json", "folder/../../following.json"] {
            XCTAssertThrowsError(try InstagramFollowersSafeArchivePath.normalize(path)) { error in
                guard case .archiveUnsafe = error as? InstagramFollowersError else {
                    return XCTFail("Se esperaba archiveUnsafe para \\(path)")
                }
            }
        }
        XCTAssertEqual(
            try InstagramFollowersSafeArchivePath.normalize("root\\connections\\followers_and_following\\following.json"),
            "root/connections/followers_and_following/following.json"
        )
    }

    func testArchiveRejectsSymbolicLinksEvenWhenIrrelevant() throws {
        let root = try temporaryDirectory()
        let folder = root.appendingPathComponent("connections/followers_and_following", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try jsonData(["relationships_following": []]).write(to: folder.appendingPathComponent("following.json"))
        try jsonData([]).write(to: folder.appendingPathComponent("followers_1.json"))
        try FileManager.default.createSymbolicLink(
            at: root.appendingPathComponent("unsafe-link"),
            withDestinationURL: folder.appendingPathComponent("following.json")
        )
        let zip = try zipDirectory(root, extraArguments: ["-y"])
        XCTAssertThrowsError(try InstagramFollowersArchiveReader(url: zip).catalog()) { error in
            guard case .archiveUnsafe = error as? InstagramFollowersError else {
                return XCTFail("Se esperaba archiveUnsafe")
            }
        }
    }

    func testArchiveRejectsEncryptedEntries() throws {
        let root = try temporaryDirectory()
        let folder = root.appendingPathComponent("connections/followers_and_following", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try jsonData(["relationships_following": []]).write(to: folder.appendingPathComponent("following.json"))
        try jsonData([]).write(to: folder.appendingPathComponent("followers_1.json"))
        let zip = try zipDirectory(root, extraArguments: ["-P", "test-password"])
        XCTAssertThrowsError(try InstagramFollowersArchiveReader(url: zip).catalog()) { error in
            XCTAssertEqual(error as? InstagramFollowersError, .archiveEncrypted)
        }
    }

    func testArchiveEnforcesDepthEntryAndRelevantSizeLimits() throws {
        let root = try temporaryDirectory()
        let folder = root.appendingPathComponent("one/two/connections/followers_and_following", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try jsonData(["relationships_following": []]).write(to: folder.appendingPathComponent("following.json"))
        try jsonData([]).write(to: folder.appendingPathComponent("followers_1.json"))
        let zip = try zipDirectory(root)

        XCTAssertThrowsError(try InstagramFollowersArchiveReader(
            url: zip,
            limits: InstagramFollowersArchiveLimits(maximumFolderDepth: 2)
        ).catalog())
        XCTAssertThrowsError(try InstagramFollowersArchiveReader(
            url: zip,
            limits: InstagramFollowersArchiveLimits(entryMaximumCount: 1)
        ).catalog())
        XCTAssertThrowsError(try InstagramFollowersArchiveReader(
            url: zip,
            limits: InstagramFollowersArchiveLimits(relevantEntryMaximumBytes: 1)
        ).catalog())
    }

    func testManifestIsValidAndOffline() throws {
        let manifest = try InstagramFollowersModuleDefinition.manifest()
        XCTAssertEqual(manifest.identifier, instagramFollowersModuleIdentifier)
        XCTAssertFalse(manifest.permissions.contains(.networkAccess))
        XCTAssertTrue(manifest.permissions.contains(.openExternalApplications))
        XCTAssertTrue(manifest.capabilities.contains(.history))
    }


    private func relationship(_ username: String) -> [String: Any] {
        ["string_list_data": [["value": username, "href": "https://www.instagram.com/\(username)/"]]]
    }

    private func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("ZEUVEInstagramFollowersTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
    }

    private func zipDirectory(_ folder: URL, extraArguments: [String] = []) throws -> URL {
        let destination = FileManager.default.temporaryDirectory.appendingPathComponent("ZEUVEInstagramFollowersTests-\(UUID().uuidString).zip")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        process.currentDirectoryURL = folder
        process.arguments = ["-q", "-r"] + extraArguments + [destination.path, "."]
        try process.run()
        process.waitUntilExit()
        XCTAssertEqual(process.terminationStatus, 0)
        addTeardownBlock { try? FileManager.default.removeItem(at: destination) }
        return destination
    }

    private func account(_ value: String) -> InstagramAccount {
        InstagramUsernameNormalizer.account(from: value)!
    }

    private func jsonData(_ object: Any) throws -> Data {
        try JSONSerialization.data(withJSONObject: object)
    }
}

private func XCTAssertThrowsErrorAsync<T>(
    _ expression: @autoclosure () async throws -> T,
    file: StaticString = #filePath,
    line: UInt = #line
) async {
    do {
        _ = try await expression()
        XCTFail("Se esperaba un error", file: file, line: line)
    } catch { }
}
