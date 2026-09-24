import XCTest
@testable import CleanerModule
import ZEUVECore
import ZEUVEStorage
import ZEUVEOperations

private struct TestIdentityProvider: CleanerAppIdentityProviding {
    let paths: [String: String]
    init(paths: [String: String]) { self.paths = paths }
    func identity(for url: URL) -> CleanerAppIdentity? {
        guard let bundleID = paths[url.standardizedFileURL.path] else { return nil }
        return .init(bundleID: bundleID, name: url.deletingPathExtension().lastPathComponent, path: url.standardizedFileURL.path, volumePath: "/")
    }
    func runningBundleIdentifiers() -> Set<String> { [] }
    func knownApplicationURLs() -> [URL] { [] }
}

private struct TestTrashMutator: CleanerFileMutating {
    let trashRoot: URL

    func moveToTrash(_ url: URL) throws -> URL {
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: trashRoot, withIntermediateDirectories: true)
        var target = trashRoot.appendingPathComponent(url.lastPathComponent)
        if fileManager.fileExists(atPath: target.path) {
            target = trashRoot.appendingPathComponent(UUID().uuidString + "-" + url.lastPathComponent)
        }
        try fileManager.moveItem(at: url, to: target)
        return target
    }

    func removePermanently(_ url: URL) throws {
        try FileManager.default.removeItem(at: url)
    }

    func restore(_ trashURL: URL, to originalURL: URL) throws {
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: originalURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try fileManager.moveItem(at: trashURL, to: originalURL)
    }
}


final class CleanerModuleTests: XCTestCase {
    private func tempDirectory() throws -> URL { let u=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString,isDirectory:true);try FileManager.default.createDirectory(at:u,withIntermediateDirectories:true);return u }

    func testManifestDeclaresMaintenancePermissionsWithoutNetwork() throws {
        let m=try CleanerModuleDefinition.manifest();XCTAssertEqual(m.identifier,cleanerModuleIdentifier);XCTAssertTrue(m.permissions.contains(.scanLocalStorage));XCTAssertTrue(m.permissions.contains(.removeLocalItems));XCTAssertFalse(m.permissions.contains(.networkAccess));XCTAssertFalse(m.permissions.contains(.executeBundledTools))
    }

    func testPersistentDataIsNeverSafePreselected() throws {
        let root=try tempDirectory();defer{try? FileManager.default.removeItem(at:root)}
        let cache=root.appendingPathComponent("cache");try Data("x".utf8).write(to:cache);let fp=CleanerFileInspection.fingerprint(at:cache)!
        let safe=CleanerCandidate(url:cache,category:.cache,evidences:[.init(strength:.strong,explanation:"test")],confidence:.high,status:.probableResidue,risk:.low,logicalSize:fp.logicalSize,allocatedSize:fp.allocatedSize,consequence:"regenerable",fingerprint:fp)
        let data=CleanerCandidate(url:cache,category:.applicationSupport,evidences:[.init(strength:.strong,explanation:"test")],confidence:.high,status:.probableResidue,risk:.high,logicalSize:fp.logicalSize,containsPotentialUserData:true,consequence:"persistente",fingerprint:fp)
        let plan=CleanerPlanner.plan(candidates:[safe,data],selectSafeItems:true);XCTAssertTrue(plan.candidates[0].selected);XCTAssertFalse(plan.candidates[1].selected)
    }

    func testSymlinkFingerprintDoesNotFollowTarget() throws {
        let root=try tempDirectory();defer{try? FileManager.default.removeItem(at:root)};let target=root.appendingPathComponent("target");try Data(repeating:1,count:4096).write(to:target);let link=root.appendingPathComponent("link");try FileManager.default.createSymbolicLink(at:link,withDestinationURL:target);let fp=CleanerFileInspection.fingerprint(at:link);XCTAssertEqual(fp?.isSymbolicLink,true);XCTAssertNotEqual(fp?.logicalSize,4096)
    }

    func testMigrationCreatesCleanerTables() throws {
        let root=try tempDirectory();defer{try? FileManager.default.removeItem(at:root)};let db=try SQLiteDatabase(url:root.appendingPathComponent("db.sqlite"));try StorageMigrations.migrate(db);let names=try db.query("SELECT name FROM sqlite_master WHERE type='table'").compactMap{try? $0.string("name")};for name in ["cleaner_app_inventory","cleaner_associated_roots","cleaner_user_decisions","cleaner_scan_metadata","cleaner_undo_items"]{XCTAssertTrue(names.contains(name),name)}
    }

    func testChangedCandidateIsSkippedImmediatelyBeforeExecution() async throws {
        let root=try tempDirectory();defer{try? FileManager.default.removeItem(at:root)};let file=root.appendingPathComponent("cache");try Data("old".utf8).write(to:file);let fp=CleanerFileInspection.fingerprint(at:file)!;var c=CleanerCandidate(url:file,category:.cache,evidences:[.init(strength:.strong,explanation:"test")],confidence:.high,status:.probableResidue,risk:.low,logicalSize:fp.logicalSize,consequence:"cache",selected:true,fingerprint:fp);c.selected=true;try Data("changed-value".utf8).write(to:file);let db=try SQLiteDatabase(url:root.appendingPathComponent("history.sqlite"));let repo=try CleanerRepository(database:db);let history=try HistoryRepository(database:db);let service=CleanerExecutionService(coordinator:OperationCoordinator(),cleanerRepository:repo,history:history);let out=try await service.execute(plan:.init(candidates:[c]),mode:.permanent);XCTAssertEqual(out.summary.skippedCount,1);XCTAssertTrue(FileManager.default.fileExists(atPath:file.path))
    }

    func testInventoryUsesInjectedRootsAndDoesNotFollowSymlinkedApplication() throws {
        let root = try tempDirectory(); defer { try? FileManager.default.removeItem(at: root) }
        let appsRoot = root.appendingPathComponent("Apps"); try FileManager.default.createDirectory(at: appsRoot, withIntermediateDirectories: true)
        let real = appsRoot.appendingPathComponent("Real.app"); try FileManager.default.createDirectory(at: real, withIntermediateDirectories: true)
        let nested = appsRoot.appendingPathComponent("Group/Nested.app"); try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        let linked = appsRoot.appendingPathComponent("Linked.app"); try FileManager.default.createSymbolicLink(at: linked, withDestinationURL: real)
        let provider = TestIdentityProvider(paths: [real.path: "com.test.real", nested.path: "com.test.nested"])
        let scan = CleanerInventoryService(identityProvider: provider, standardRoots: []).scan(additionalRoots: [appsRoot])
        XCTAssertEqual(Set(scan.applications.compactMap { $0.identity.bundleID }), Set(["com.test.real", "com.test.nested"]))
        XCTAssertFalse(scan.applications.contains { $0.identity.path == linked.path })
    }

    func testRepositoryTracksTwoCopiesOfSameBundleIndependently() throws {
        let root = try tempDirectory(); defer { try? FileManager.default.removeItem(at: root) }
        let db = try SQLiteDatabase(url: root.appendingPathComponent("db.sqlite")); let repo = try CleanerRepository(database: db)
        let a = CleanerAppInventoryItem(identity: .init(bundleID: "com.test.app", name: "App", path: "/Applications/App.app", volumePath: "/"))
        let b = CleanerAppInventoryItem(identity: .init(bundleID: "com.test.app", name: "App", path: "/Volumes/Test/App.app", volumePath: "/Volumes/Test"))
        try repo.upsertInventory([a,b]); try repo.markMissingInventory(except: Set([a.id]))
        let items = try repo.loadInventory(); XCTAssertEqual(items.count, 2)
        XCTAssertEqual(items.first(where: { $0.identity.path == a.identity.path })?.availability, .installed)
        XCTAssertEqual(items.first(where: { $0.identity.path == b.identity.path })?.availability, .externalVolumeUnavailable)
    }

    func testSharedAppGroupIsHighRiskAndCannotBeSelected() throws {
        let home = try tempDirectory(); defer { try? FileManager.default.removeItem(at: home) }
        let groups = home.appendingPathComponent("Library/Group Containers"); try FileManager.default.createDirectory(at: groups, withIntermediateDirectories: true)
        let shared = groups.appendingPathComponent("group.shared"); try FileManager.default.createDirectory(at: shared, withIntermediateDirectories: true)
        let apps = [
            CleanerAppInventoryItem(identity: .init(bundleID: "com.test.a", name: "A", path: "/a.app", appGroups: ["group.shared"])),
            CleanerAppInventoryItem(identity: .init(bundleID: "com.test.b", name: "B", path: "/b.app", appGroups: ["group.shared"])),
        ]
        let result = CleanerAssociationService(homeDirectory: home, systemLibraryRoot: nil).scan(installedApps: apps, historicalApps: apps, keptPaths: [], runningBundleIDs: [])
        let candidate = try XCTUnwrap(result.candidates.first { $0.category == .groupContainer && $0.url.standardizedFileURL.path == shared.standardizedFileURL.path })
        XCTAssertTrue(candidate.isShared); XCTAssertEqual(candidate.risk, .high); XCTAssertFalse(CleanerPlanner.canSelect(candidate))
    }

    func testConservedDecisionWinsOverResidueClassification() throws {
        let home = try tempDirectory(); defer { try? FileManager.default.removeItem(at: home) }
        let caches = home.appendingPathComponent("Library/Caches"); try FileManager.default.createDirectory(at: caches, withIntermediateDirectories: true)
        let url = caches.appendingPathComponent("com.test.old"); try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        var old = CleanerAppInventoryItem(identity: .init(bundleID: "com.test.old", name: "Old", path: "/missing/Old.app")); old.availability = .missing
        let result = CleanerAssociationService(homeDirectory: home, systemLibraryRoot: nil).scan(installedApps: [], historicalApps: [old], keptPaths: [url.path], runningBundleIDs: [])
        XCTAssertEqual(result.candidates.first?.status, .keptByUser)
        XCTAssertFalse(result.candidates.first?.selected ?? true)
    }

    func testBrokenLaunchItemIsDetectedWithoutTouchingRealLaunchAgents() throws {
        let root = try tempDirectory(); defer { try? FileManager.default.removeItem(at: root) }
        let plist = root.appendingPathComponent("broken.plist")
        let object: [String: Any] = ["Label": "test", "Program": "/definitely/missing/zeuve-test", "AssociatedBundleIdentifiers": ["com.test.app"]]
        let data = try PropertyListSerialization.data(fromPropertyList: object, format: .xml, options: 0); try data.write(to: plist)
        let result = CleanerLaunchItemScanner(roots: [root]).scan(); let candidate = try XCTUnwrap(result.candidates.first)
        XCTAssertEqual(candidate.category, .launchItem); XCTAssertEqual(candidate.status, .possibleResidue); XCTAssertFalse(candidate.selected)
    }

    func testOldInstallerIsNeverAutomaticallySelected() throws {
        let root = try tempDirectory(); defer { try? FileManager.default.removeItem(at: root) }
        let installer = root.appendingPathComponent("old.dmg"); try Data("installer".utf8).write(to: installer)
        try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSinceNow: -120 * 86_400)], ofItemAtPath: installer.path)
        let candidate = try XCTUnwrap(CleanerInstallerScanner().scan(roots: [root], olderThanDays: 90).first)
        XCTAssertEqual(candidate.category, .installer); XCTAssertEqual(candidate.confidence, .low); XCTAssertFalse(candidate.canBeSafelyPreselected)
    }

    func testXcodeScannerExcludesArchivesAndAvoidsOverlappingDerivedDataRoot() throws {
        let home = try tempDirectory(); defer { try? FileManager.default.removeItem(at: home) }
        let derived = home.appendingPathComponent("Library/Developer/Xcode/DerivedData/Project-A"); try FileManager.default.createDirectory(at: derived, withIntermediateDirectories: true)
        let archive = home.appendingPathComponent("Library/Developer/Xcode/Archives/Keep.xcarchive"); try FileManager.default.createDirectory(at: archive, withIntermediateDirectories: true)
        let items = CleanerDevelopmentScanner(homeDirectory: home).scanXcode()
        XCTAssertEqual(items.count, 1); XCTAssertEqual(items.first?.url.standardizedFileURL.path, derived.standardizedFileURL.path); XCTAssertFalse(items.contains { $0.url.path.contains("Archives") })
    }

    func testUninstallDoesNotRemoveRelatedDataWhenApplicationIsNotSelected() async throws {
        let root = try tempDirectory(); defer { try? FileManager.default.removeItem(at: root) }
        let app = root.appendingPathComponent("App.app"); let related = root.appendingPathComponent("cache")
        try FileManager.default.createDirectory(at: app, withIntermediateDirectories: true); try Data("cache".utf8).write(to: related)
        let appFP = try XCTUnwrap(CleanerFileInspection.fingerprint(at: app)); let relatedFP = try XCTUnwrap(CleanerFileInspection.fingerprint(at: related))
        let appCandidate = CleanerCandidate(url: app, category: .application, associatedAppName: "App", associatedBundleID: "com.test.app", evidences: [], confidence: .high, status: .notResidue, risk: .medium, consequence: "app", selected: false, fingerprint: appFP)
        let relatedCandidate = CleanerCandidate(url: related, category: .cache, associatedAppName: "App", associatedBundleID: "com.test.app", evidences: [], confidence: .high, status: .probableResidue, risk: .low, consequence: "cache", selected: true, fingerprint: relatedFP)
        let output = try await CleanerExecutionService(coordinator: OperationCoordinator(), cleanerRepository: nil, history: nil).execute(plan: .init(candidates: [appCandidate, relatedCandidate]), mode: .permanent, kind: "uninstall")
        XCTAssertEqual(output.summary.removedCount, 0); XCTAssertTrue(FileManager.default.fileExists(atPath: related.path))
    }

    func testTrashOperationCanBeUndoneAndConflictNeverOverwrites() async throws {
        let root = try tempDirectory(); defer { try? FileManager.default.removeItem(at: root) }
        let db = try SQLiteDatabase(url: root.appendingPathComponent("db.sqlite")); let repo = try CleanerRepository(database: db); let history = try HistoryRepository(database: db)
        let file = root.appendingPathComponent("cache"); try Data("old".utf8).write(to: file); let fp = try XCTUnwrap(CleanerFileInspection.fingerprint(at: file))
        let candidate = CleanerCandidate(url: file, category: .cache, evidences: [.init(strength: .strong, explanation: "test")], confidence: .high, status: .probableResidue, risk: .low, logicalSize: fp.logicalSize, consequence: "cache", selected: true, fingerprint: fp)
        let mutator = TestTrashMutator(trashRoot: root.appendingPathComponent("TestTrash", isDirectory: true))
        let execution = try await CleanerExecutionService(coordinator: OperationCoordinator(), cleanerRepository: repo, history: history, mutator: mutator).execute(plan: .init(candidates: [candidate]), mode: .trash)
        XCTAssertFalse(FileManager.default.fileExists(atPath: file.path)); XCTAssertEqual(execution.summary.removedCount, 1)
        let undo = CleanerUndoService(coordinator: OperationCoordinator(), repository: repo, history: history, mutator: mutator)
        let restored = try await undo.undo(historyID: execution.historyID); XCTAssertEqual(restored.restoredCount, 1); XCTAssertTrue(FileManager.default.fileExists(atPath: file.path))

        let secondFP = try XCTUnwrap(CleanerFileInspection.fingerprint(at: file))
        let second = CleanerCandidate(url: file, category: .cache, evidences: [], confidence: .high, status: .probableResidue, risk: .low, consequence: "cache", selected: true, fingerprint: secondFP)
        let execution2 = try await CleanerExecutionService(coordinator: OperationCoordinator(), cleanerRepository: repo, history: history, mutator: mutator).execute(plan: .init(candidates: [second]), mode: .trash)
        try Data("new object".utf8).write(to: file)
        let conflicted = try await undo.undo(historyID: execution2.historyID); XCTAssertEqual(conflicted.results.first?.status, .restoreConflict)
        XCTAssertEqual(try String(contentsOf: file, encoding: .utf8), "new object")
    }

    func testSystemTrashAndUndoRestoreDisposableFileIntact() async throws {
        let root = try tempDirectory(); defer { try? FileManager.default.removeItem(at: root) }
        let db = try SQLiteDatabase(url: root.appendingPathComponent("qa.sqlite"))
        let repository = try CleanerRepository(database: db)
        let history = try HistoryRepository(database: db)
        let file = root.appendingPathComponent("zeuve-cleaner-qa-cache")
        let original = Data("contenido de prueba recuperable".utf8)
        try original.write(to: file)
        let fingerprint = try XCTUnwrap(CleanerFileInspection.fingerprint(at: file))
        let candidate = CleanerCandidate(url: file, category: .cache, evidences: [], confidence: .high, status: .regenerable, risk: .low, logicalSize: fingerprint.logicalSize, consequence: "fixture", selected: true, fingerprint: fingerprint)
        let output = try await CleanerExecutionService(coordinator: OperationCoordinator(), cleanerRepository: repository, history: history).execute(plan: .init(candidates: [candidate]), mode: .trash)
        XCTAssertEqual(output.summary.removedCount, 1)
        let trash = try XCTUnwrap(output.summary.results.first?.trashPath)
        defer { try? FileManager.default.removeItem(atPath: trash) }
        XCTAssertFalse(FileManager.default.fileExists(atPath: file.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: trash))
        let restored = try await CleanerUndoService(coordinator: OperationCoordinator(), repository: repository, history: history).undo(historyID: output.historyID)
        XCTAssertEqual(restored.restoredCount, 1)
        XCTAssertEqual(try Data(contentsOf: file), original)
    }

    func testClearingInventoryPreservesConservedDecisions() throws {
        let root = try tempDirectory(); defer { try? FileManager.default.removeItem(at: root) }
        let db = try SQLiteDatabase(url: root.appendingPathComponent("db.sqlite")); let repo = try CleanerRepository(database: db)
        try repo.keep(path: "/private/user/data", value: true); try repo.clearInventoryHistory()
        XCTAssertTrue(try repo.keptPaths().contains("/private/user/data"))
    }

    func testUninstallSelectionKeepsApplicationAndNeverAutoSelectsPreferences() throws {
        let root = try tempDirectory(); defer { try? FileManager.default.removeItem(at: root) }
        let app = CleanerCandidate(url: root.appendingPathComponent("App.app"), category: .application, associatedBundleID: "com.test.app", evidences: [], confidence: .high, status: .notResidue, risk: .medium, consequence: "app", selected: true)
        let cache = CleanerCandidate(url: root.appendingPathComponent("cache"), category: .cache, associatedBundleID: "com.test.app", evidences: [], confidence: .high, status: .notResidue, risk: .low, consequence: "cache")
        let preference = CleanerCandidate(url: root.appendingPathComponent("preference"), category: .preference, associatedBundleID: "com.test.app", evidences: [], confidence: .high, status: .notResidue, risk: .high, containsPotentialUserData: true, consequence: "preference", selected: true)
        let safe = CleanerPlanner.selectingSafeUninstallItems(in: .init(candidates: [app, cache, preference]))
        XCTAssertTrue(safe.candidates[0].selected)
        XCTAssertTrue(safe.candidates[1].selected)
        XCTAssertFalse(safe.candidates[2].selected)
        let withoutApp = CleanerPlanner.settingUninstallSelection(false, candidateID: app.id, in: safe)
        XCTAssertEqual(withoutApp.selectedCandidates.count, 0)
        let invalid = CleanerPlanner.settingUninstallSelection(true, candidateID: cache.id, in: withoutApp)
        XCTAssertEqual(invalid.selectedCandidates.count, 0)
    }

    func testRecursiveSizeUsesFileSizesAndStopsAtSymlink() throws {
        let root = try tempDirectory(); defer { try? FileManager.default.removeItem(at: root) }
        let bundle = root.appendingPathComponent("Bundle.app")
        try FileManager.default.createDirectory(at: bundle.appendingPathComponent("Contents"), withIntermediateDirectories: true)
        try Data(repeating: 1, count: 19).write(to: bundle.appendingPathComponent("Contents/one"))
        try Data(repeating: 2, count: 23).write(to: bundle.appendingPathComponent("Contents/two"))
        try FileManager.default.createSymbolicLink(at: bundle.appendingPathComponent("linked"), withDestinationURL: root)
        XCTAssertEqual(CleanerFileInspection.recursiveSize(at: bundle).logical, 42)
        XCTAssertEqual(CleanerFileInspection.fingerprint(at: bundle)?.logicalSize, 42)
    }

    func testSpotlightDiscoveryCompletesWhenTaskWasCancelledBeforeStarting() async {
        let gate = AsyncStream<Void>.makeStream()
        let task = Task {
            for await _ in gate.stream { break }
            return await CleanerSpotlightApplicationDiscovery().discoverApplications()
        }
        task.cancel()
        gate.continuation.yield(())
        let result = await task.value
        XCTAssertEqual(result.status, .cancelled)
    }

    func testSpotlightDiscoveryHasABoundedActiveQuery() async {
        let clock = ContinuousClock()
        let started = clock.now
        let result = await CleanerSpotlightApplicationDiscovery(timeout: .milliseconds(50)).discoverApplications()
        XCTAssertLessThan(started.duration(to: clock.now), .seconds(3))
        XCTAssertNotEqual(result.status, .cancelled)
    }

    func testIncompleteDiscoveryProtectsHistoricallyInstalledApplications() {
        let current = CleanerAppInventoryItem(identity: .init(bundleID: "com.test.current", name: "Current", path: "/Applications/Current.app"))
        let historical = CleanerAppInventoryItem(identity: .init(bundleID: "com.test.external", name: "External", path: "/Volumes/External/External.app"))
        var knownMissing = CleanerAppInventoryItem(identity: .init(bundleID: "com.test.missing", name: "Missing", path: "/Applications/Missing.app"))
        knownMissing.availability = .missing
        XCTAssertFalse(CleanerAnalysisService.canConfirmAbsentApplications(discoveryStatus: .timedOut, inaccessibleLocations: []))
        XCTAssertFalse(CleanerAnalysisService.canConfirmAbsentApplications(discoveryStatus: .complete, inaccessibleLocations: ["/Applications"]))
        let protected = CleanerAnalysisService.applicationsForAssociation(current: [current], historical: [historical, knownMissing], canConfirmAbsent: false)
        XCTAssertEqual(Set(protected.map(\.id)), Set([current.id, historical.id]))
        let complete = CleanerAnalysisService.applicationsForAssociation(current: [current], historical: [historical], canConfirmAbsent: true)
        XCTAssertEqual(complete.map(\.id), [current.id])
    }

}
