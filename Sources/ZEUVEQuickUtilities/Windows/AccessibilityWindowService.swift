import Foundation
#if os(macOS)
import AppKit
import ApplicationServices
#endif

public struct WindowApplication: Sendable {
    public let pid: Int32
    public let name: String
    public let bundleIdentifier: String
    public let launchDate: Date?
    public init(pid: Int32, name: String, bundleIdentifier: String, launchDate: Date?) {
        self.pid = pid; self.name = name; self.bundleIdentifier = bundleIdentifier; self.launchDate = launchDate
    }
}

public protocol WindowAccessBackend: Sendable {
    func startMonitoring(changed: @escaping @Sendable () -> Void) async
    func stopMonitoring() async
    func snapshots(applications: [WindowApplication], frontmostPID: Int32?) async throws -> [WindowSnapshot]
    func noteFocus(processIdentifier: Int32) async
    func activateWindow(_ id: UUID) async throws
    func restoreWindow(_ id: UUID, frame: WindowFrame) async throws -> WindowFrame
}

#if os(macOS)
/// One owned, coalesced operation per AX observer prevents a burst of native
/// notifications from leaving untracked work behind after source removal.
final class AXWindowObserverContext: @unchecked Sendable {
    private let operation: @Sendable () async -> Void
    private let lock = NSLock()
    private var task: Task<Void, Never>?
    init(operation: @escaping @Sendable () async -> Void) { self.operation = operation }
    func notify() {
        lock.withLock {
            guard task == nil else { return }
            task = Task { [weak self] in
                guard let self else { return }
                if !Task.isCancelled { await operation() }
                lock.withLock { task = nil }
            }
        }
    }
    func cancelAndWait() async {
        let pending = lock.withLock { task }
        pending?.cancel()
        await pending?.value
        lock.withLock { task = nil }
    }
}
private let zeuveWindowObserverCallback: AXObserverCallback = { _, _, _, context in
    guard let context else { return }
    Unmanaged<AXWindowObserverContext>.fromOpaque(context).takeUnretainedValue().notify()
}

/// AX messaging is synchronous and may time out. All such calls stay in this
/// actor, off the main actor. The main run loop handles only the short callback.
public actor NativeWindowAccessBackend: WindowAccessBackend {
    private struct Entry {
        let element: AXUIElement
        let application: WindowApplication
        var recentOrder: UInt64
    }
    private struct Observation: @unchecked Sendable {
        let observer: AXObserver
        let element: AXUIElement
        let context: AXWindowObserverContext
        let launchDate: Date?
    }
    private var entries: [UUID: Entry] = [:]
    private var observations: [Int32: Observation] = [:]
    private var monitoring = false
    private var changed: (@Sendable () -> Void)?
    private var sequence: UInt64 = 0
    private var lastFocused: UUID?

    public init() {}
    public func startMonitoring(changed: @escaping @Sendable () -> Void) {
        self.changed = changed; monitoring = true
    }
    public func stopMonitoring() async {
        monitoring = false
        for observation in observations.values { await remove(observation) }
        observations.removeAll(); entries.removeAll(); lastFocused = nil; changed = nil
    }
    private func remove(_ observation: Observation) async {
        // Serialize source removal with its main-run-loop callback before dropping
        // the refcon owner, preventing a callback from reading freed context.
        await MainActor.run {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observation.observer), .commonModes)
        }
        await observation.context.cancelAndWait()
        for name in [kAXFocusedWindowChangedNotification, kAXWindowCreatedNotification, kAXUIElementDestroyedNotification] {
            AXObserverRemoveNotification(observation.observer, observation.element, name as CFString)
        }
    }
    private func permission() throws {
        guard AXIsProcessTrusted() else { throw QuickUtilityError.requiresPermission(.accessibility) }
    }
    private func applicationElement(_ pid: Int32) -> AXUIElement {
        let element = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(element, 0.15)
        return element
    }
    private func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
        return value
    }
    private func settable(_ element: AXUIElement, _ name: String) -> Bool {
        var result = DarwinBoolean(false)
        return AXUIElementIsAttributeSettable(element, name as CFString, &result) == .success && result.boolValue
    }
    private func geometry(_ element: AXUIElement) -> WindowFrame? {
        guard let position = attribute(element, kAXPositionAttribute), CFGetTypeID(position) == AXValueGetTypeID(),
              let size = attribute(element, kAXSizeAttribute), CFGetTypeID(size) == AXValueGetTypeID() else { return nil }
        var point = CGPoint.zero; var dimensions = CGSize.zero
        guard AXValueGetValue(position as! AXValue, .cgPoint, &point), AXValueGetValue(size as! AXValue, .cgSize, &dimensions) else { return nil }
        let frame = WindowFrame(x: point.x, y: point.y, width: dimensions.width, height: dimensions.height)
        return frame.isValid ? frame : nil
    }
    private func ensureObservation(_ application: WindowApplication, element: AXUIElement) async {
        guard monitoring else { return }
        if let prior = observations[application.pid], prior.launchDate == application.launchDate { return }
        if let prior = observations.removeValue(forKey: application.pid) { await remove(prior) }
        guard monitoring, !Task.isCancelled else { return }
        var observer: AXObserver?
        guard AXObserverCreate(application.pid, zeuveWindowObserverCallback, &observer) == .success, let observer else { return }
        let context = AXWindowObserverContext { [weak self] in
            await self?.observedChange(application.pid)
        }
        let opaque = Unmanaged.passUnretained(context).toOpaque()
        for name in [kAXFocusedWindowChangedNotification, kAXWindowCreatedNotification, kAXUIElementDestroyedNotification] {
            AXObserverAddNotification(observer, element, name as CFString, opaque)
        }
        observations[application.pid] = .init(observer: observer, element: element, context: context, launchDate: application.launchDate)
        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes)
    }
    private func observedChange(_ pid: Int32) {
        guard monitoring, !Task.isCancelled else { return }
        noteFocus(processIdentifier: pid)
        changed?()
    }
    public func noteFocus(processIdentifier pid: Int32) {
        guard monitoring, AXIsProcessTrusted(), let focus = attribute(applicationElement(pid), kAXFocusedWindowAttribute) else { return }
        guard let id = entries.first(where: { $0.value.application.pid == pid && CFEqual($0.value.element, focus) })?.key, id != lastFocused else { return }
        sequence &+= 1; entries[id]?.recentOrder = sequence; lastFocused = id
    }
    public func snapshots(applications: [WindowApplication], frontmostPID: Int32?) async throws -> [WindowSnapshot] {
        try permission(); try Task.checkCancellation()
        let livePIDs = Set(applications.map(\.pid))
        for pid in observations.keys.filter({ !livePIDs.contains($0) }) {
            if let observation = observations.removeValue(forKey: pid) { await remove(observation) }
        }
        var alive: Set<UUID> = []; var result: [WindowSnapshot] = []
        // Bounds limit the work of pathological accessibility providers.
        for application in applications.prefix(150) {
            try Task.checkCancellation()
            guard monitoring else { throw CancellationError() }
            let appElement = applicationElement(application.pid)
            await ensureObservation(application, element: appElement)
            guard monitoring else { throw CancellationError() }
            guard let windows = attribute(appElement, kAXWindowsAttribute) as? [AXUIElement] else { continue }
            for window in windows.prefix(100) {
                try Task.checkCancellation()
                guard monitoring else { throw CancellationError() }
                AXUIElementSetMessagingTimeout(window, 0.12)
                guard attribute(window, kAXRoleAttribute) as? String == kAXWindowRole,
                      let subrole = attribute(window, kAXSubroleAttribute) as? String,
                      [kAXStandardWindowSubrole, kAXDialogSubrole, kAXSystemDialogSubrole].contains(subrole),
                      let frame = geometry(window) else { continue }
                let oldID = entries.first { _, entry in
                    entry.application.pid == application.pid && entry.application.launchDate == application.launchDate && CFEqual(entry.element, window)
                }?.key
                let id = oldID ?? UUID()
                guard alive.insert(id).inserted else { continue }
                let recent = entries[id]?.recentOrder ?? 0
                entries[id] = .init(element: window, application: application, recentOrder: recent)
                let minimized = (attribute(window, kAXMinimizedAttribute) as? Bool) ?? false
                // Some providers advertise an AXFullScreen value; it is only read,
                // never used to force a fullscreen transition. Unknown capabilities
                // remain governed by public settable-position/size checks.
                let reportedFullScreen = (attribute(window, "AXFullScreen") as? Bool) ?? false
                let mutable = subrole == kAXStandardWindowSubrole && !minimized && !reportedFullScreen && settable(window, kAXPositionAttribute) && settable(window, kAXSizeAttribute)
                result.append(.init(id: id, applicationName: application.name, bundleIdentifier: application.bundleIdentifier,
                                    title: attribute(window, kAXTitleAttribute) as? String ?? "", processIdentifier: application.pid,
                                    frame: frame, minimized: minimized, canRestoreGeometry: mutable, recentOrder: recent))
            }
        }
        entries = entries.filter { alive.contains($0.key) }
        if let frontmostPID { noteFocus(processIdentifier: frontmostPID) }
        result = result.map { snapshot in
            .init(id: snapshot.id, applicationName: snapshot.applicationName, bundleIdentifier: snapshot.bundleIdentifier, title: snapshot.title,
                  processIdentifier: snapshot.processIdentifier, frame: snapshot.frame, minimized: snapshot.minimized,
                  canRestoreGeometry: snapshot.canRestoreGeometry, recentOrder: entries[snapshot.id]?.recentOrder ?? 0)
        }
        return result.sorted { a, b in
            if a.recentOrder != b.recentOrder { return a.recentOrder > b.recentOrder }
            if a.applicationName != b.applicationName { return a.applicationName.localizedStandardCompare(b.applicationName) == .orderedAscending }
            return a.id.uuidString < b.id.uuidString
        }
    }
    public func activateWindow(_ id: UUID) async throws {
        try permission(); try Task.checkCancellation()
        let entry = try await verifiedEntry(id)
        try permission(); try Task.checkCancellation()
        if (attribute(entry.element, kAXMinimizedAttribute) as? Bool) == true {
            guard settable(entry.element, kAXMinimizedAttribute), AXUIElementSetAttributeValue(entry.element, kAXMinimizedAttribute as CFString, kCFBooleanFalse) == .success else {
                throw QuickUtilityError.failure("Esta ventana no permite salir del estado minimizado.")
            }
        }
        guard AXUIElementPerformAction(entry.element, kAXRaiseAction as CFString) == .success else {
            throw QuickUtilityError.failure("La aplicación no permite activar esta ventana.")
        }
        let pid = entry.application.pid
        let launchDate = entry.application.launchDate
        let requested = await MainActor.run { () -> Bool in
            guard let app = NSRunningApplication(processIdentifier: pid), !app.isTerminated, app.launchDate == launchDate else { return false }
            if app.isHidden { _ = app.unhide() }
            if NSApp.isActive { NSApp.yieldActivation(to: app) }
            return app.activate(options: [])
        }
        guard requested else { throw QuickUtilityError.failure("macOS ha rechazado la activación de la aplicación.") }
        for _ in 0..<8 {
            try await Task.sleep(for: .milliseconds(50))
            let active = await MainActor.run { NSWorkspace.shared.frontmostApplication?.processIdentifier == pid }
            if active, let focus = attribute(applicationElement(entry.application.pid), kAXFocusedWindowAttribute), CFEqual(focus, entry.element) {
                noteFocus(processIdentifier: entry.application.pid); return
            }
        }
        throw QuickUtilityError.failure("No se pudo confirmar el foco de la ventana. Spaces o la aplicación pueden impedirlo.")
    }
    private func verifiedEntry(_ id: UUID) async throws -> Entry {
        guard monitoring else { throw CancellationError() }
        guard let entry = entries[id] else { throw QuickUtilityError.failure("La ventana ya no está disponible.") }
        let pid = entry.application.pid, launchDate = entry.application.launchDate
        let stillSameApplication = await MainActor.run {
            guard let app = NSRunningApplication(processIdentifier: pid), !app.isTerminated else { return false }
            return app.launchDate == launchDate
        }
        guard monitoring else { throw CancellationError() }
        guard stillSameApplication else { entries[id] = nil; throw QuickUtilityError.failure("La aplicación se ha cerrado o se ha reiniciado; reasocia la ventana.") }
        return entry
    }
    public func restoreWindow(_ id: UUID, frame: WindowFrame) async throws -> WindowFrame {
        try permission(); try Task.checkCancellation()
        let entry = try await verifiedEntry(id)
        try permission(); try Task.checkCancellation()
        guard frame.isValid, (attribute(entry.element, kAXMinimizedAttribute) as? Bool) != true,
              (attribute(entry.element, "AXFullScreen") as? Bool) != true,
              settable(entry.element, kAXPositionAttribute), settable(entry.element, kAXSizeAttribute) else {
            throw QuickUtilityError.failure("La ventana ya no admite restaurar su posición y tamaño.")
        }
        var size = CGSize(width: frame.width, height: frame.height); var point = CGPoint(x: frame.x, y: frame.y)
        guard let sizeValue = AXValueCreate(.cgSize, &size), let positionValue = AXValueCreate(.cgPoint, &point),
              AXUIElementSetAttributeValue(entry.element, kAXSizeAttribute as CFString, sizeValue) == .success,
              AXUIElementSetAttributeValue(entry.element, kAXPositionAttribute as CFString, positionValue) == .success,
              let actual = geometry(entry.element) else { throw QuickUtilityError.failure("La aplicación no ha completado el cambio de geometría.") }
        guard actual.approximatelyEquals(frame) else {
            throw QuickUtilityError.failure("La aplicación ha aplicado una geometría diferente a la solicitada.")
        }
        return actual
    }
}

@MainActor public final class WindowServicesBackend {
    public let access: any WindowAccessBackend
    public var changeHandlers: [QuickUtilityID: @MainActor () -> Void] = [:]
    public var permissionHandlers: [QuickUtilityID: @MainActor () -> Void] = [:]
    private var clients: Set<QuickUtilityID> = []
    private var workspaceObservers: [NSObjectProtocol] = []
    private var permissionTimer: Timer?
    private var eventTasks: [UUID: Task<Void, Never>] = [:]
    private var lifecycleTask: Task<Void, Never>?
    private let trusted: @MainActor () -> Bool
    public init(access: any WindowAccessBackend = NativeWindowAccessBackend(), trusted: @escaping @MainActor () -> Bool = { AXIsProcessTrusted() }) {
        self.access = access; self.trusted = trusted
    }
    public var isTrusted: Bool { trusted() }
    public func requestPermission() { QuickUtilityPermissions.request(.accessibility) }
    private func waitForLifecycle() async {
        while let pending = lifecycleTask {
            await pending.value
            await Task.yield()
        }
    }
    public func acquire(_ id: QuickUtilityID) async throws {
        await waitForLifecycle()
        try Task.checkCancellation()
        guard isTrusted else { throw QuickUtilityError.requiresPermission(.accessibility) }
        guard clients.insert(id).inserted else { return }
        guard clients.count == 1 else { return }
        let pending = Task { @MainActor [self] in
            await access.startMonitoring { [weak self] in Task { @MainActor in self?.notifyChanged() } }
            installWorkspaceObservers()
        }
        lifecycleTask = pending
        await pending.value
        lifecycleTask = nil
        do {
            try Task.checkCancellation()
            guard isTrusted else { throw QuickUtilityError.requiresPermission(.accessibility) }
        } catch { await release(id); throw error }
    }
    private func installWorkspaceObservers() {
        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didActivateApplicationNotification, NSWorkspace.didLaunchApplicationNotification, NSWorkspace.didTerminateApplicationNotification] {
            workspaceObservers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.workspaceChanged() }
            })
        }
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, !self.clients.isEmpty, !self.isTrusted else { return }
                for handler in Array(self.permissionHandlers.values) { handler() }
            }
        }
    }
    public func release(_ id: QuickUtilityID) async {
        await waitForLifecycle()
        let existed = clients.remove(id) != nil
        changeHandlers[id] = nil; permissionHandlers[id] = nil
        guard existed else { return }
        guard clients.isEmpty else { return }
        permissionTimer?.invalidate(); permissionTimer = nil
        let center = NSWorkspace.shared.notificationCenter
        workspaceObservers.forEach { center.removeObserver($0) }; workspaceObservers.removeAll()
        let pending = Task { @MainActor in
            let tasks = Array(eventTasks.values); tasks.forEach { $0.cancel() }
            for task in tasks { await task.value }
            eventTasks.removeAll()
            await access.stopMonitoring()
        }
        lifecycleTask = pending
        await pending.value
        lifecycleTask = nil
    }
    private func workspaceChanged() {
        guard !clients.isEmpty else { return }
        let pid = NSWorkspace.shared.frontmostApplication?.processIdentifier
        let id = UUID()
        eventTasks[id] = Task { [weak self] in
            guard let self else { return }
            if let pid { await access.noteFocus(processIdentifier: pid) }
            if !Task.isCancelled { notifyChanged() }
            eventTasks[id] = nil
        }
    }
    private func notifyChanged() { for handler in Array(changeHandlers.values) { handler() } }
    public func snapshots() async throws -> [WindowSnapshot] {
        await waitForLifecycle()
        try Task.checkCancellation()
        guard isTrusted else { throw QuickUtilityError.requiresPermission(.accessibility) }
        guard !clients.isEmpty else { throw QuickUtilityError.failure("Las utilidades de ventanas están detenidas.") }
        let applications = NSWorkspace.shared.runningApplications.compactMap { app -> WindowApplication? in
            guard !app.isTerminated, app.processIdentifier != ProcessInfo.processInfo.processIdentifier,
                  app.activationPolicy == .regular, let bundle = app.bundleIdentifier else { return nil }
            return .init(pid: app.processIdentifier, name: app.localizedName ?? "Aplicación", bundleIdentifier: bundle, launchDate: app.launchDate)
        }
        let result = try await access.snapshots(applications: applications, frontmostPID: NSWorkspace.shared.frontmostApplication?.processIdentifier)
        guard Set(result.map(\.id)).count == result.count, result.allSatisfy({ $0.frame.isValid }) else {
            throw QuickUtilityError.failure("El inventario de ventanas contiene identidades o geometrías incompatibles.")
        }
        return result
    }
    public static func displays() -> [WindowDisplayGeometry] {
        let screens = NSScreen.screens
        guard let primary = screens.first else { return [] }
        func converted(_ frame: CGRect) -> WindowFrame {
            .init(x: frame.minX, y: primary.frame.maxY - frame.maxY, width: frame.width, height: frame.height)
        }
        // Primary first, others by relative location. No display UUIDs or serials.
        let ordered = [primary] + screens.dropFirst().sorted { a, b in
            a.frame.minX == b.frame.minX ? a.frame.minY > b.frame.minY : a.frame.minX < b.frame.minX
        }
        return ordered.map { .init(frame: converted($0.frame), visibleFrame: converted($0.visibleFrame)) }
    }
}
#endif
