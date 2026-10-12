import Foundation
import Combine
import ZEUVEStorage

@MainActor public final class ScrollDirectionService: ObservableObject, QuickUtilityService {
    public let id = QuickUtilityID.scroll
    public static let settingsKey = "quickUtilities.scroll.options.v1"
    @Published public private(set) var state: QuickUtilityState = .disabled { didSet { stateDidChange?(state) } }
    @Published public private(set) var options = ScrollDirectionOptions()
    @Published public private(set) var settingsError: String?
    @Published public private(set) var otherInputFiltersDetected = false
    public var stateDidChange: (@MainActor (QuickUtilityState) -> Void)?
    private let settings: SettingsRepository?
    private let broker: any InputEventTapControlling
    private var loadFailure: String?

    public init(settings: SettingsRepository?, broker: any InputEventTapControlling) {
        self.settings = settings; self.broker = broker
        do {
            guard let settings else { throw QuickUtilityError.failure("El almacenamiento local no está disponible.") }
            options = try settings.value(forKey: Self.settingsKey, as: ScrollDirectionOptions.self) ?? .init()
            try options.validate()
        } catch { loadFailure = error.localizedDescription; settingsError = error.localizedDescription; state = .failed(error.localizedDescription) }
        broker.setFailureHandler(for: id) { [weak self] error in self?.state = error.state }
    }
    public func start() async throws {
        guard state != .active else { return }
        state = .activating
        do {
            if let loadFailure { throw QuickUtilityError.failure(loadFailure) }
            try options.validate(); try Task.checkCancellation()
            try await broker.startScroll(options)
            if Task.isCancelled { try await broker.stopScroll(); throw CancellationError() }
            otherInputFiltersDetected = broker.otherInputFiltersDetected == true
            state = .active
        } catch { state = (error as? QuickUtilityError)?.state ?? .failed(error.localizedDescription); throw error }
    }
    public func stop() async throws {
        guard state != .disabled else { return }
        state = .deactivating
        do { try await broker.stopScroll(); state = .disabled }
        catch { state = (error as? QuickUtilityError)?.state ?? .failed(error.localizedDescription); throw error }
    }
    public func updateOptions(_ value: ScrollDirectionOptions) async throws {
        do {
            try value.validate()
            guard let settings else { throw QuickUtilityError.failure("El almacenamiento local no está disponible.") }
            try settings.set(value, forKey: Self.settingsKey)
            options = value; loadFailure = nil; settingsError = nil
            if state == .active {
                do { try await broker.startScroll(value) }
                catch { state = (error as? QuickUtilityError)?.state ?? .failed(error.localizedDescription); throw error }
            }
        } catch { settingsError = error.localizedDescription; throw error }
    }
    public func restoreDefaultSettings() async throws {
        try await stop()
        try await updateOptions(.init())
    }
}

@MainActor public final class AdditionalMouseButtonsService: ObservableObject, QuickUtilityService {
    public let id = QuickUtilityID.mouseButtons
    public static let settingsKey = "quickUtilities.mouseButtons.options.v1"
    @Published public private(set) var state: QuickUtilityState = .disabled { didSet { stateDidChange?(state) } }
    @Published public private(set) var options = AdditionalMouseButtonsOptions()
    @Published public private(set) var settingsError: String?
    @Published public private(set) var otherInputFiltersDetected = false
    @Published public private(set) var isCapturing = false
    @Published public private(set) var lastCapturedButton: Int?
    public var stateDidChange: (@MainActor (QuickUtilityState) -> Void)?
    private let settings: SettingsRepository?
    private let broker: any InputEventTapControlling
    private var loadFailure: String?
    private var captureTimeout: Task<Void, Never>?

    public init(settings: SettingsRepository?, broker: any InputEventTapControlling) {
        self.settings = settings; self.broker = broker
        do {
            guard let settings else { throw QuickUtilityError.failure("El almacenamiento local no está disponible.") }
            options = try settings.value(forKey: Self.settingsKey, as: AdditionalMouseButtonsOptions.self) ?? .init()
            try options.validate()
        } catch { loadFailure = error.localizedDescription; settingsError = error.localizedDescription; state = .failed(error.localizedDescription) }
        broker.setFailureHandler(for: id) { [weak self] error in
            self?.captureTimeout?.cancel(); self?.captureTimeout = nil; self?.isCapturing = false; self?.state = error.state
        }
    }
    public func start() async throws {
        guard state != .active else { return }
        state = .activating
        do {
            if let loadFailure { throw QuickUtilityError.failure(loadFailure) }
            try options.validate()
            guard !options.assignments.isEmpty else { throw QuickUtilityError.unavailable("Asigna primero un atajo a un botón adicional.") }
            try Task.checkCancellation()
            try await broker.startButtons(options)
            if Task.isCancelled { try await broker.stopButtons(); throw CancellationError() }
            otherInputFiltersDetected = broker.otherInputFiltersDetected == true
            state = .active
        } catch { state = (error as? QuickUtilityError)?.state ?? .failed(error.localizedDescription); throw error }
    }
    public func stop() async throws {
        guard state != .disabled || isCapturing else { return }
        captureTimeout?.cancel(); captureTimeout = nil; isCapturing = false
        state = .deactivating
        do { try await broker.stopButtons(); state = .disabled }
        catch { state = (error as? QuickUtilityError)?.state ?? .failed(error.localizedDescription); throw error }
    }
    public func updateOptions(_ value: AdditionalMouseButtonsOptions) async throws {
        do {
            try value.validate()
            guard let settings else { throw QuickUtilityError.failure("El almacenamiento local no está disponible.") }
            try settings.set(value, forKey: Self.settingsKey)
            options = value; loadFailure = nil; settingsError = nil
            if state == .active {
                if value.assignments.isEmpty { try await broker.stopButtons(); state = .unavailable("Asigna primero un atajo a un botón adicional.") }
                else {
                    do { try await broker.startButtons(value) }
                    catch { state = (error as? QuickUtilityError)?.state ?? .failed(error.localizedDescription); throw error }
                }
            }
        } catch { settingsError = error.localizedDescription; throw error }
    }
    public func assign(_ shortcut: MouseButtonShortcut?, to button: Int) async throws {
        var updated = options
        updated.assignments[button] = shortcut
        try await updateOptions(updated)
    }
    public func captureButton() async throws {
        try await cancelCapture()
        lastCapturedButton = nil
        do {
            isCapturing = true
            try await broker.captureNextButton { [weak self] button in
                guard let self else { return }
                self.captureTimeout?.cancel(); self.captureTimeout = nil
                self.lastCapturedButton = button; self.isCapturing = false
            }
            captureTimeout = Task { @MainActor [weak self] in
                do { try await Task.sleep(for: .seconds(15)); try await self?.cancelCapture() }
                catch is CancellationError { }
                catch { self?.settingsError = error.localizedDescription }
            }
        } catch { isCapturing = false; settingsError = error.localizedDescription; throw error }
    }
    public func cancelCapture() async throws {
        captureTimeout?.cancel(); captureTimeout = nil
        guard isCapturing else { return }
        isCapturing = false
        try await broker.cancelButtonCapture()
    }
    public func restoreDefaultSettings() async throws {
        try await stop()
        try await updateOptions(.init())
    }
}
