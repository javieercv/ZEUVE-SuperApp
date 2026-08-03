import Foundation

/// Agrupa valores muy frecuentes y entrega siempre el más reciente sin bloquear al productor.
/// Las llamadas marcadas como inmediatas cancelan la espera y publican el valor en el acto.
public final class LatestValueCoalescer<Value: Sendable>: @unchecked Sendable {
    private enum Pending {
        case none
        case value(Value)
    }

    private let lock = NSLock()
    private let deliveryLock = NSLock()
    private let minimumIntervalNanoseconds: UInt64
    private let delivery: @Sendable (Value) -> Void
    private var pending: Pending = .none
    private var worker: Task<Void, Never>?
    private var generation: UInt64 = 0
    private var cancelled = false

    public init(
        minimumIntervalNanoseconds: UInt64 = 100_000_000,
        delivery: @escaping @Sendable (Value) -> Void
    ) {
        self.minimumIntervalNanoseconds = minimumIntervalNanoseconds
        self.delivery = delivery
    }

    public func submit(_ value: Value, immediately: Bool = false) {
        lock.lock()
        guard !cancelled else {
            lock.unlock()
            return
        }
        pending = .value(value)
        if immediately {
            generation &+= 1
            let deliveryGeneration = generation
            let activeWorker = worker
            worker = nil
            let value = takePendingLocked()
            lock.unlock()
            activeWorker?.cancel()
            if let value { deliver(value, generation: deliveryGeneration) }
            return
        }
        if worker == nil {
            generation &+= 1
            let workerGeneration = generation
            worker = Task { [weak self] in
                await self?.drain(generation: workerGeneration)
            }
        }
        lock.unlock()
    }

    /// Publica el último valor pendiente de forma síncrona respecto al productor.
    public func flush() {
        lock.lock()
        guard !cancelled else {
            lock.unlock()
            return
        }
        generation &+= 1
        let deliveryGeneration = generation
        let activeWorker = worker
        worker = nil
        let value = takePendingLocked()
        lock.unlock()
        activeWorker?.cancel()
        if let value { deliver(value, generation: deliveryGeneration) }
    }

    public func cancel() {
        lock.lock()
        cancelled = true
        generation &+= 1
        pending = .none
        let activeWorker = worker
        worker = nil
        lock.unlock()
        activeWorker?.cancel()
    }

    deinit { cancel() }

    private func drain(generation workerGeneration: UInt64) async {
        while !Task.isCancelled {
            do {
                try await Task.sleep(nanoseconds: minimumIntervalNanoseconds)
            } catch {
                return
            }
            guard let value = nextValueForDrain(generation: workerGeneration) else { return }
            deliver(value, generation: workerGeneration)
            guard shouldContinueDraining(generation: workerGeneration) else { return }
        }
    }

    private func nextValueForDrain(generation workerGeneration: UInt64) -> Value? {
        lock.lock()
        defer { lock.unlock() }
        guard !cancelled, generation == workerGeneration else { return nil }
        guard let value = takePendingLocked() else {
            worker = nil
            return nil
        }
        return value
    }

    private func shouldContinueDraining(generation workerGeneration: UInt64) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard !cancelled, generation == workerGeneration else { return false }
        switch pending {
        case .none:
            worker = nil
            return false
        case .value:
            return true
        }
    }

    private func deliver(_ value: Value, generation deliveryGeneration: UInt64) {
        deliveryLock.lock()
        lock.lock()
        let shouldDeliver = !cancelled && generation == deliveryGeneration
        lock.unlock()
        if shouldDeliver { delivery(value) }
        deliveryLock.unlock()
    }

    private func takePendingLocked() -> Value? {
        switch pending {
        case .none:
            return nil
        case .value(let value):
            pending = .none
            return value
        }
    }
}
