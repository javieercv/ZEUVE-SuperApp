import Foundation
import XCTest
@testable import OrganizerModule

final class OrganizerExecutionTests: OrganizerTestCase {
    func testExecuteSelectedFilesAndUndo() throws {
        let first = try write("a.pdf", contents: "a")
        let second = try write("b.pdf", contents: "b")
        let plan = try OrganizerPlanner().buildPlan(folder: root)
        let selected = Set(plan.operations.filter { $0.source.lastPathComponent == "a.pdf" }.map(\.id))
        let result = try OrganizerExecutor().execute(plan: plan, selectedIDs: selected)
        XCTAssertEqual(result.moved, 1)
        XCTAssertFalse(FileManager.default.fileExists(atPath: first.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: second.path))

        let history = try makeHistory()
        try history.save(result)
        let undo = try history.undo(recordID: result.operationID)
        XCTAssertEqual(undo.status, .undone)
        XCTAssertTrue(FileManager.default.fileExists(atPath: first.path))
    }

    func testSourceChangeInvalidatesEntirePlan() throws {
        let first = try write("a.pdf", contents: "a")
        let second = try write("b.pdf", contents: "b")
        let plan = try OrganizerPlanner().buildPlan(folder: root)
        try Data("changed-size".utf8).write(to: second)
        XCTAssertThrowsError(try OrganizerExecutor().execute(plan: plan))
        XCTAssertTrue(FileManager.default.fileExists(atPath: first.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: second.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent("Documentos").path))
    }

    func testDestinationAppearingAfterPreviewPreventsOverwrite() throws {
        try write("foto.png", contents: "new")
        let plan = try OrganizerPlanner().buildPlan(folder: root)
        let destination = try XCTUnwrap(plan.operations.first?.destination)
        try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("foreign".utf8).write(to: destination)
        XCTAssertThrowsError(try OrganizerExecutor().execute(plan: plan))
        XCTAssertEqual(try String(contentsOf: destination, encoding: .utf8), "foreign")
        XCTAssertTrue(FileManager.default.fileExists(atPath: root.appendingPathComponent("foto.png").path))
    }

    func testUndoSkipsModifiedDestination() throws {
        let original = try write("manual.pdf", contents: "x")
        let result = try OrganizerExecutor().execute(plan: OrganizerPlanner().buildPlan(folder: root))
        let history = try makeHistory()
        try history.save(result)
        let destination = try XCTUnwrap(result.operations.first?.destination)
        try Data("modified-content".utf8).write(to: destination)
        let undo = try history.undo(recordID: result.operationID)
        XCTAssertEqual(undo.status, .undoUnavailable)
        XCTAssertEqual(undo.skipped, 1)
        XCTAssertFalse(FileManager.default.fileExists(atPath: original.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: destination.path))
    }

    func testUndoKeepsFoldersWithForeignContent() throws {
        let original = try write("manual.pdf")
        let result = try OrganizerExecutor().execute(plan: OrganizerPlanner().buildPlan(folder: root))
        let targetFolder = root.appendingPathComponent("Documentos/PDF")
        try Data("keep".utf8).write(to: targetFolder.appendingPathComponent("ajeno.txt"))
        let history = try makeHistory()
        try history.save(result)
        let undo = try history.undo(recordID: result.operationID)
        XCTAssertEqual(undo.restored, 1)
        XCTAssertTrue(FileManager.default.fileExists(atPath: original.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: targetFolder.appendingPathComponent("ajeno.txt").path))
    }

    func testCancelledExecutionDoesNotMoveAnything() async throws {
        try write("a.pdf")
        let plan = try OrganizerPlanner().buildPlan(folder: root)
        let task = Task.detached { () throws -> OrganizerExecutionResult in
            withUnsafeCurrentTask { $0?.cancel() }
            return try OrganizerExecutor().execute(plan: plan)
        }
        do {
            _ = try await task.value
            XCTFail("La operación cancelada no debería completarse")
        } catch is CancellationError {
            // Resultado esperado.
        } catch {
            XCTFail("Error inesperado: \(error)")
        }
        XCTAssertTrue(FileManager.default.fileExists(atPath: root.appendingPathComponent("a.pdf").path))
    }

    func testCancellationAfterFirstMoveRollsBackCompletedMoves() async throws {
        try write("a.pdf")
        try write("b.pdf")
        let plan = try OrganizerPlanner().buildPlan(folder: root)
        let task = Task.detached { () throws -> OrganizerExecutionResult in
            try OrganizerExecutor().execute(plan: plan) { update in
                if update.completed == 1 {
                    withUnsafeCurrentTask { $0?.cancel() }
                }
            }
        }
        do {
            _ = try await task.value
            XCTFail("La operación cancelada no debería completarse")
        } catch is CancellationError {
            // Resultado esperado.
        } catch {
            XCTFail("Error inesperado: \(error)")
        }
        XCTAssertTrue(FileManager.default.fileExists(atPath: root.appendingPathComponent("a.pdf").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: root.appendingPathComponent("b.pdf").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent("Documentos").path))
    }

    func testCSVIncludesIncludedAndExcludedRows() throws {
        try write("a.pdf")
        try write("b.pdf")
        let plan = try OrganizerPlanner().buildPlan(folder: root)
        let selected = Set([try XCTUnwrap(plan.operations.first?.id)])
        let output = root.appendingPathComponent("plan.csv")
        try OrganizerCSVExporter().export(plan: plan, to: output, selectedIDs: selected)
        let text = try String(contentsOf: output, encoding: .utf8)
        XCTAssertTrue(text.contains("Incluido"))
        XCTAssertTrue(text.contains("Excluido"))
    }
}
