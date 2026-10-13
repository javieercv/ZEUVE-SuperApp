import Foundation
import CoreGraphics
@preconcurrency import ApplicationServices
import Carbon

@MainActor public protocol InputEventTapControlling: AnyObject {
    var otherInputFiltersDetected: Bool? { get }
    func setFailureHandler(for id: QuickUtilityID, handler: (@MainActor (QuickUtilityError) -> Void)?)
    func startScroll(_ options: ScrollDirectionOptions) async throws
    func stopScroll() async throws
    func startButtons(_ options: AdditionalMouseButtonsOptions) async throws
    func stopButtons() async throws
    func captureNextButton(_ handler: @escaping @MainActor (Int) -> Void) async throws
    func cancelButtonCapture() async throws
}

public extension InputEventTapControlling {
    var otherInputFiltersDetected: Bool? { nil }
}

private struct InputTapConfiguration: Sendable {
    var scroll: ScrollDirectionOptions?
    var buttons: AdditionalMouseButtonsOptions?
    var capturing = false
    var captureID = UUID()
    var eventMask: CGEventMask {
        var mask: CGEventMask = 0
        if scroll != nil { mask |= CGEventMask(1) << CGEventType.scrollWheel.rawValue }
        if buttons != nil || capturing {
            for type in [CGEventType.otherMouseDown, .otherMouseUp, .otherMouseDragged] { mask |= CGEventMask(1) << type.rawValue }
        }
        return mask
    }
}

/// Single owner of the native tap shared by the two input utilities. Mutations are serialized;
/// native teardown completes before an operation returns. No keyboard event is observed.
@MainActor public final class InputEventTapBroker: InputEventTapControlling {
    private var configuration = InputTapConfiguration()
    private var engine: NativeInputTap?
    private var tail: Task<Void, Never>?
    private var failureHandlers: [QuickUtilityID: @MainActor (QuickUtilityError) -> Void] = [:]
    private var captureHandler: (@MainActor (Int) -> Void)?
    private var generation: UInt64 = 0
    public init() {}

    /// Metadata only: another visible modifying tap is a possible conflict, not proof
    /// of inversion or a way to discover every vendor driver. Nothing is persisted.
    public var otherInputFiltersDetected: Bool? {
        var count: UInt32 = 0
        guard CGGetEventTapList(0, nil, &count) == .success, count <= 4096 else { return nil }
        if count == 0 { return false }
        var entries = Array(repeating: CGEventTapInformation(), count: Int(count))
        let error = entries.withUnsafeMutableBufferPointer { CGGetEventTapList(count, $0.baseAddress, &count) }
        guard error == .success else { return nil }
        let mouseMask = (CGEventMask(1) << CGEventType.scrollWheel.rawValue) | (CGEventMask(1) << CGEventType.otherMouseDown.rawValue)
        return entries.prefix(min(Int(count), entries.count)).contains {
            $0.enabled && $0.tappingProcess != getpid() && ($0.options.rawValue & CGEventTapOptions.listenOnly.rawValue) == 0 && $0.eventsOfInterest & mouseMask != 0
        }
    }

    public static var accessibilityAuthorized: Bool { AXIsProcessTrusted() }
    /// Called exclusively by the explicit permission button, never by restoration on startup.
    public static func requestAccessibilityPermission() {
        QuickUtilityPermissions.request(.accessibility)
    }
    public func setFailureHandler(for id: QuickUtilityID, handler: (@MainActor (QuickUtilityError) -> Void)?) { failureHandlers[id] = handler }

    public func startScroll(_ options: ScrollDirectionOptions) async throws {
        try options.validate()
        try await serialized { self.configuration.scroll = options; try await self.reconcile() }
    }
    public func stopScroll() async throws {
        try await serialized {
            self.configuration.scroll = nil
            // Rebuilding a remaining utility may fail, but this utility's resources have
            // already been removed; reconcile reports that failure to the remaining owner.
            do { try await self.reconcile() } catch { }
        }
    }
    public func startButtons(_ options: AdditionalMouseButtonsOptions) async throws {
        try options.validate()
        try await serialized { self.configuration.buttons = options; try await self.reconcile() }
    }
    public func stopButtons() async throws {
        try await serialized {
            self.configuration.buttons = nil; self.configuration.capturing = false; self.captureHandler = nil
            do { try await self.reconcile() } catch { }
        }
    }
    public func captureNextButton(_ handler: @escaping @MainActor (Int) -> Void) async throws {
        try await serialized {
            self.captureHandler = handler; self.configuration.capturing = true; self.configuration.captureID = UUID()
            try await self.reconcile()
        }
    }
    public func cancelButtonCapture() async throws {
        try await serialized {
            self.configuration.capturing = false; self.captureHandler = nil
            do { try await self.reconcile() } catch { }
        }
    }

    private func serialized(_ operation: @escaping @MainActor () async throws -> Void) async throws {
        let previous = tail
        let task = Task { @MainActor in
            await previous?.value
            try Task.checkCancellation()
            try await operation()
        }
        tail = Task { _ = await task.result }
        try await task.value
    }
    private func serializedCallback(_ operation: @escaping @MainActor () async -> Void) async {
        let previous = tail
        let task = Task { @MainActor in await previous?.value; await operation() }
        tail = task
        await task.value
    }
    private func reconcile(failureOwner: QuickUtilityID? = nil) async throws {
        let mask = configuration.eventMask
        if mask == 0 {
            generation &+= 1
            let old = engine; engine = nil
            await old?.stop()
            return
        }
        guard Self.accessibilityAuthorized else {
            await fail(.requiresPermission(.accessibility), additionalOwner: failureOwner)
            throw QuickUtilityError.requiresPermission(.accessibility)
        }
        if let engine, engine.eventMask == mask, engine.isRunning {
            engine.update(configuration)
            return
        }
        generation &+= 1
        let currentGeneration = generation
        let old = engine; engine = nil
        await old?.stop()
        let native = NativeInputTap(configuration: configuration, fault: { [weak self] error in
            Task { @MainActor in
                guard let self else { return }
                await self.serializedCallback {
                    guard self.generation == currentGeneration else { return }
                    await self.fail(error)
                }
            }
        }, captured: { [weak self] button, captureID in
            Task { @MainActor in
                await self?.completeCapture(button: button, captureID: captureID, generation: currentGeneration)
            }
        })
        engine = native
        do {
            try await native.start()
            guard generation == currentGeneration, engine === native, native.isRunning, Self.accessibilityAuthorized else {
                throw Self.accessibilityAuthorized ? QuickUtilityError.failure("El filtro de entrada se detuvo durante la activación.") : .requiresPermission(.accessibility)
            }
        }
        catch {
            await fail((error as? QuickUtilityError) ?? .failure(error.localizedDescription), additionalOwner: failureOwner)
            throw error
        }
    }
    private func completeCapture(button: Int, captureID: UUID, generation expectedGeneration: UInt64) async {
        await serializedCallback {
            // Check after preceding configuration operations have completed, not before
            // enqueueing: a delayed A callback must never cancel a newer B capture.
            guard self.generation == expectedGeneration, self.configuration.capturing,
                  self.configuration.captureID == captureID else { return }
            let handler = self.captureHandler
            self.configuration.capturing = false; self.captureHandler = nil
            do { try await self.reconcile(failureOwner: .mouseButtons) }
            catch {
                // Every throwing reconcile path calls fail, including the capture owner
                // whose temporary request was just removed. Do not deliver a success.
                return
            }
            handler?(button)
        }
    }
    private func fail(_ error: QuickUtilityError, additionalOwner: QuickUtilityID? = nil) async {
        generation &+= 1
        let old = engine; engine = nil
        await old?.stop()
        var affected: Set<QuickUtilityID> = []
        if configuration.scroll != nil { affected.insert(.scroll) }
        if configuration.buttons != nil || configuration.capturing { affected.insert(.mouseButtons) }
        if let additionalOwner { affected.insert(additionalOwner) }
        configuration = .init(); captureHandler = nil
        for id in affected { failureHandlers[id]?(error) }
    }
}

/// CF resources and event mutation stay on this object's worker run loop. The lock protects
/// only tiny immutable configuration snapshots and lifecycle handoff, not event delivery.
private final class NativeInputTap: @unchecked Sendable {
    static let ownEventMarker: Int64 = 0x5A45555645494E50
    let eventMask: CGEventMask
    private let lock = NSLock()
    private var configuration: InputTapConfiguration
    private var loop: CFRunLoop?
    private var running = false
    private var stopRequested = false
    private var stopWaiters: [CheckedContinuation<Void, Never>] = []
    private var pairs = MouseButtonPairTracker()
    private var deliveredCaptureID: UUID?
    private let fault: @Sendable (QuickUtilityError) -> Void
    private let captured: @Sendable (Int, UUID) -> Void

    init(configuration: InputTapConfiguration, fault: @escaping @Sendable (QuickUtilityError) -> Void, captured: @escaping @Sendable (Int, UUID) -> Void) {
        self.configuration = configuration; eventMask = configuration.eventMask
        self.fault = fault; self.captured = captured
    }
    var isRunning: Bool { lock.withLock { running && !stopRequested } }
    func update(_ value: InputTapConfiguration) { lock.withLock { configuration = value } }
    func start() async throws {
        try await withCheckedThrowingContinuation { continuation in
            lock.withLock { running = true }
            let thread = Thread { self.run(continuation) }
            thread.name = "ZEUVE entrada"
            thread.qualityOfService = .userInteractive
            thread.start()
        }
    }
    func stop() async {
        await withCheckedContinuation { continuation in
            let state: (Bool, CFRunLoop?) = lock.withLock {
                stopRequested = true
                guard running else { return (false, nil) }
                stopWaiters.append(continuation)
                return (true, loop)
            }
            if !state.0 { continuation.resume(); return }
            if let loop = state.1 {
                // The block also handles a stop arriving just before CFRunLoopRun starts.
                CFRunLoopPerformBlock(loop, CFRunLoopMode.defaultMode.rawValue) { CFRunLoopStop(loop) }
                CFRunLoopStop(loop); CFRunLoopWakeUp(loop)
            }
        }
    }
    private func run(_ continuation: CheckedContinuation<Void, any Error>) {
        let currentLoop = CFRunLoopGetCurrent()!
        let context = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap, eventsOfInterest: eventMask, callback: { _, type, event, context in
            guard let context else { return Unmanaged.passUnretained(event) }
            return Unmanaged<NativeInputTap>.fromOpaque(context).takeUnretainedValue().handle(type, event: event)
        }, userInfo: context), let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) else {
            continuation.resume(throwing: AXIsProcessTrusted() ? QuickUtilityError.failure("macOS no permitió crear el filtro de entrada.") : .requiresPermission(.accessibility))
            completeStop(); return
        }
        CFRunLoopAddSource(currentLoop, source, .commonModes)
        // Permission changes do not have a universal public notification. While the tap is
        // running this spaced timer verifies access even when no pointer events arrive.
        let timer = CFRunLoopTimerCreateWithHandler(kCFAllocatorDefault, CFAbsoluteTimeGetCurrent() + 2, 2, 0, 0) { [weak self] _ in
            guard let self else { return }
            let problem: QuickUtilityError
            if !AXIsProcessTrusted() { problem = .requiresPermission(.accessibility) }
            else if !CFMachPortIsValid(tap) || !CGEvent.tapIsEnabled(tap: tap) {
                problem = .failure("macOS ha detenido el filtro de entrada. Reactiva la utilidad para volver a intentarlo.")
            } else { return }
            self.fault(problem)
            CFRunLoopStop(currentLoop)
        }!
        CFRunLoopAddTimer(currentLoop, timer, .commonModes)
        let shouldRun = lock.withLock { loop = currentLoop; return !stopRequested }
        CGEvent.tapEnable(tap: tap, enable: shouldRun)
        let enabled = shouldRun && CGEvent.tapIsEnabled(tap: tap)
        if shouldRun && !enabled {
            continuation.resume(throwing: AXIsProcessTrusted() ? QuickUtilityError.failure("macOS no permitió habilitar el filtro de entrada.") : .requiresPermission(.accessibility))
        } else { continuation.resume() }
        if enabled { CFRunLoopRun() }
        CGEvent.tapEnable(tap: tap, enable: false)
        CFRunLoopTimerInvalidate(timer)
        CFRunLoopRemoveTimer(currentLoop, timer, .commonModes)
        CFRunLoopRemoveSource(currentLoop, source, .commonModes)
        CFRunLoopSourceInvalidate(source)
        CFMachPortInvalidate(tap)
        completeStop()
    }
    private func completeStop() {
        let waiters = lock.withLock { running = false; loop = nil; let result = stopWaiters; stopWaiters = []; return result }
        for waiter in waiters { waiter.resume() }
    }
    private func handle(_ type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            fault(AXIsProcessTrusted() ? .failure("macOS ha detenido el filtro de entrada. Reactiva la utilidad para volver a intentarlo.") : .requiresPermission(.accessibility))
            if let current = lock.withLock({ loop }) { CFRunLoopStop(current) }
            return Unmanaged.passUnretained(event)
        }
        let snapshot = lock.withLock { (configuration, stopRequested) }
        guard !snapshot.1, event.getIntegerValueField(.eventSourceUserData) != Self.ownEventMarker else { return Unmanaged.passUnretained(event) }
        if type == .scrollWheel, let options = snapshot.0.scroll {
            let original = DiscreteScrollSample(continuous: event.getIntegerValueField(.scrollWheelEventIsContinuous) != 0,
                verticalLines: event.getIntegerValueField(.scrollWheelEventDeltaAxis1), horizontalLines: event.getIntegerValueField(.scrollWheelEventDeltaAxis2),
                verticalPoints: event.getIntegerValueField(.scrollWheelEventPointDeltaAxis1), horizontalPoints: event.getIntegerValueField(.scrollWheelEventPointDeltaAxis2),
                verticalFixed: event.getDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1), horizontalFixed: event.getDoubleValueField(.scrollWheelEventFixedPtDeltaAxis2))
            let changed = original.transformed(using: options)
            guard original != changed else { return Unmanaged.passUnretained(event) }
            event.setIntegerValueField(.scrollWheelEventDeltaAxis1, value: changed.verticalLines)
            event.setIntegerValueField(.scrollWheelEventDeltaAxis2, value: changed.horizontalLines)
            event.setIntegerValueField(.scrollWheelEventPointDeltaAxis1, value: changed.verticalPoints)
            event.setIntegerValueField(.scrollWheelEventPointDeltaAxis2, value: changed.horizontalPoints)
            event.setDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1, value: changed.verticalFixed)
            event.setDoubleValueField(.scrollWheelEventFixedPtDeltaAxis2, value: changed.horizontalFixed)
            // Returning the transformed event does not post it back into earlier taps.
            return Unmanaged.passUnretained(event)
        }
        let button = Int(event.getIntegerValueField(.mouseEventButtonNumber))
        guard (3...31).contains(button) else { return Unmanaged.passUnretained(event) }
        if type == .otherMouseUp, pairs.up(button) { return nil }
        if type == .otherMouseDragged, pairs.dragging(button) { return nil }
        if snapshot.0.capturing {
            if type == .otherMouseDown, deliveredCaptureID != snapshot.0.captureID {
                deliveredCaptureID = snapshot.0.captureID; captured(button, snapshot.0.captureID)
            }
            // Capture observes, it does not consume a button or execute its assignment.
            return Unmanaged.passUnretained(event)
        }
        if type == .otherMouseDown, let action = snapshot.0.buttons?.assignments[button], !IsSecureEventInputEnabled() {
            guard pairs.down(button, mapped: true) else { return nil }
            if !post(action) { _ = pairs.up(button); return Unmanaged.passUnretained(event) }
            return nil
        }
        return Unmanaged.passUnretained(event)
    }
    private func post(_ shortcut: MouseButtonShortcut) -> Bool {
        guard AXIsProcessTrusted(), (try? shortcut.validate()) != nil,
              let source = CGEventSource(stateID: .privateState),
              let down = CGEvent(keyboardEventSource: source, virtualKey: shortcut.keyCode, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: shortcut.keyCode, keyDown: false) else { return false }
        var flags = CGEventFlags()
        if shortcut.command { flags.insert(.maskCommand) }; if shortcut.option { flags.insert(.maskAlternate) }
        if shortcut.control { flags.insert(.maskControl) }; if shortcut.shift { flags.insert(.maskShift) }
        for event in [down, up] {
            event.flags = flags; event.setIntegerValueField(.eventSourceUserData, value: Self.ownEventMarker)
            event.post(tap: .cgSessionEventTap)
        }
        return true
    }
}
