import XCTest
@testable import ZEUVEOperations
import ZEUVECore

final class OperationCoordinatorTests: XCTestCase {
    func testOnlyOneOperationCanRun() async throws {
        let coordinator = OperationCoordinator()
        let firstID = try await coordinator.begin(moduleID: "one", name: "Primera")
        do {
            _ = try await coordinator.begin(moduleID: "two", name: "Segunda")
            XCTFail("La segunda operación no debería iniciarse")
        } catch let error as OperationCoordinatorError {
            guard case .busy(let snapshot) = error else { return XCTFail("Error inesperado") }
            XCTAssertEqual(snapshot.id, firstID)
        }
        try await coordinator.finish(id: firstID)
        let currentAfterFinish = await coordinator.current()
        XCTAssertNil(currentAfterFinish)
    }

    func testProgressAndCancellationAreTracked() async throws {
        let coordinator = OperationCoordinator()
        let id = try await coordinator.begin(moduleID: "test", name: "Prueba")
        try await coordinator.update(
            id: id,
            progress: OperationProgress(completed: 2, total: 4, phase: "Procesando")
        )
        let progressFraction = await coordinator.current()?.progress?.fraction
        XCTAssertEqual(progressFraction, 0.5)
        try await coordinator.requestCancellation(id: id)
        let shouldCancel = await coordinator.shouldCancel(id: id)
        XCTAssertTrue(shouldCancel)
        let status = await coordinator.current()?.status
        XCTAssertEqual(status, .cancelling)
    }
}
