import XCTest
@testable import ZEUVECore

private final class ThreadSafeValues<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [Value] = []
    func append(_ value: Value) { lock.lock(); storage.append(value); lock.unlock() }
    func snapshot() -> [Value] { lock.lock(); defer { lock.unlock() }; return storage }
}

final class LatestValueCoalescerTests: XCTestCase {
    func testCoalescerKeepsLatestPendingValue() async throws {
        let values = ThreadSafeValues<Int>()
        let coalescer = LatestValueCoalescer<Int>(minimumIntervalNanoseconds: 20_000_000) {
            values.append($0)
        }

        for value in 1...20 { coalescer.submit(value) }
        try await Task.sleep(nanoseconds: 70_000_000)
        coalescer.flush()

        let captured = values.snapshot()
        XCTAssertEqual(captured.last, 20)
        XCTAssertLessThan(captured.count, 20)
    }

    func testImmediateSubmissionBypassesDelay() {
        let values = ThreadSafeValues<Int>()
        let coalescer = LatestValueCoalescer<Int>(minimumIntervalNanoseconds: 1_000_000_000) {
            values.append($0)
        }

        coalescer.submit(1)
        coalescer.submit(2, immediately: true)

        XCTAssertEqual(values.snapshot(), [2])
    }
}
