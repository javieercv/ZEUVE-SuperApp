import Foundation
import XCTest
import ZEUVECore
import ZEUVEStorage
@testable import UniversalDownloaderModule

final class GlobalHistoryTests: XCTestCase {
    func testGlobalHistoryIsDataDrivenWithThirdSimulatedModule() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("ZEUVE-GlobalHistory-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let repository = try HistoryRepository(database: SQLiteDatabase(url: root.appendingPathComponent("history.sqlite")))
        let moduleIDs = ["com.zeuve.organizer", universalDownloaderModuleIdentifier, "com.zeuve.third"]
        for id in moduleIDs {
            try repository.add(.init(moduleID: id, kind: "operation", baseFolder: root.path, status: .completed, undoAvailable: false, payload: Data(id.utf8)))
        }
        let manifests = moduleIDs.enumerated().map { index, id in
            ModuleManifest(identifier: id, name: "Módulo \(index)", summary: "Prueba", version: "1.0.0", minimumZEUVEVersion: "0.1.0", technology: .swift, executionMode: .builtIn, permissions: [], capabilities: [.history], presentation: .init(systemImage: "puzzlepiece", category: "Prueba", order: index))
        }
        let entries = try GlobalHistoryService(repository: repository).entries(manifests: manifests, presenters: [ThirdPresenter()], limit: 20)
        XCTAssertEqual(Set(entries.map { $0.record.moduleID }), Set(moduleIDs))
        XCTAssertEqual(entries.first(where: { $0.record.moduleID == "com.zeuve.third" })?.presentation.title, "Detalle del tercer módulo")
        XCTAssertEqual(try GlobalHistoryService(repository: repository).entries(manifests: manifests, presenters: [], moduleID: "com.zeuve.third").count, 1)
    }
}

private struct ThirdPresenter: ModuleHistoryPresenter {
    let moduleID = "com.zeuve.third"
    func presentation(for record: OperationHistoryRecord) -> ModuleHistoryPresentation {
        .init(title: "Detalle del tercer módulo", subtitle: "Añadido sin cambiar la pantalla")
    }
}
