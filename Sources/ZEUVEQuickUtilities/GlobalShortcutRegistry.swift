import Foundation
#if os(macOS)
import Carbon
import AppKit
#endif

public struct GlobalShortcut: Codable, Hashable, Sendable {
    public var keyCode: UInt32
    public var command: Bool
    public var option: Bool
    public var control: Bool
    public var shift: Bool
    public init(keyCode: UInt32, command: Bool = false, option: Bool = false, control: Bool = false, shift: Bool = false) {
        self.keyCode = keyCode; self.command = command; self.option = option; self.control = control; self.shift = shift
    }
    public var modifiers: UInt32 {
        (command ? 256 : 0) | (option ? 2048 : 0) | (control ? 4096 : 0) | (shift ? 512 : 0)
    }
    public var displayName: String {
        let names: [UInt32: String] = [48: "Tab", 36: "Intro", 49: "Espacio", 53: "Esc", 123: "←", 124: "→", 125: "↓", 126: "↑", 103: "F11"]
        return (control ? "⌃" : "") + (option ? "⌥" : "") + (shift ? "⇧" : "") + (command ? "⌘" : "") + (names[keyCode] ?? "Tecla \(keyCode)")
    }
    public func validate() throws {
        guard keyCode < 128, command || option || control else { throw QuickUtilityError.failure("El atajo debe incluir ⌘, ⌥ o ⌃ y una tecla compatible.") }
        let reserved: Set<UInt32> = [0, 6, 7, 8, 9, 12, 13, 4, 46, 43, 48]
        if command && !option && !control && reserved.contains(keyCode) {
            throw QuickUtilityError.failure("Esta combinación está reservada por macOS o ZEUVE.")
        }
    }
}

@MainActor public final class GlobalShortcutRegistry {
    public var navigationShortcuts: [GlobalShortcut] = []
    private var actions: [UInt32: @MainActor () -> Void] = [:]
    private var assigned: [String: GlobalShortcut] = [:]
    private var serial: UInt32 = 0
    #if os(macOS)
    private var registrations: [String: EventHotKeyRef] = [:]
    private var identifiers: [String: UInt32] = [:]
    private var handler: EventHandlerRef?
    #endif
    public init() {}
    public func conflict(for shortcut: GlobalShortcut) -> String? {
        assigned.first { $0.value == shortcut }?.key
    }
    public func register(id: String, shortcut: GlobalShortcut, action: @escaping @MainActor () -> Void) throws {
        try shortcut.validate()
        guard !navigationShortcuts.contains(shortcut), !assigned.contains(where: { $0.key != id && $0.value == shortcut }) else {
            throw QuickUtilityError.failure("El atajo ya está asignado a otra función de ZEUVE.")
        }
        #if os(macOS)
        var system: Unmanaged<CFArray>?
        if CopySymbolicHotKeys(&system) == noErr, let values = system?.takeRetainedValue() as? [[String: Any]] {
            for value in values where (value[kHISymbolicHotKeyEnabled as String] as? Bool) == true {
                if (value[kHISymbolicHotKeyCode as String] as? NSNumber)?.uint32Value == shortcut.keyCode,
                   (value[kHISymbolicHotKeyModifiers as String] as? NSNumber)?.uint32Value == shortcut.modifiers {
                    throw QuickUtilityError.failure("La combinación está ocupada por un atajo del sistema.")
                }
            }
        }
        if assigned[id] == shortcut, let number = identifiers[id] { actions[number] = action; return }
        if handler == nil {
            var type = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
            let result = InstallEventHandler(GetApplicationEventTarget(), { _, event, context in
                guard let event, let context else { return OSStatus(eventNotHandledErr) }
                var key = EventHotKeyID()
                let result = GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &key)
                guard result == noErr, key.signature == 0x5A455556 else { return OSStatus(eventNotHandledErr) }
                let owner = Unmanaged<GlobalShortcutRegistry>.fromOpaque(context).takeUnretainedValue()
                MainActor.assumeIsolated { owner.actions[key.id]?() }
                return noErr
            }, 1, &type, Unmanaged.passUnretained(self).toOpaque(), &handler)
            guard result == noErr else { throw QuickUtilityError.failure("No se pudo instalar el registro de atajos (\(result)).") }
        }
        serial += 1
        var ref: EventHotKeyRef?
        let result = RegisterEventHotKey(shortcut.keyCode, shortcut.modifiers, .init(signature: 0x5A455556, id: serial), GetApplicationEventTarget(), OptionBits(kEventHotKeyExclusive), &ref)
        guard result == noErr, let ref else {
            removeHandlerIfEmpty()
            throw QuickUtilityError.failure("No se pudo registrar el atajo; puede estar ocupado (\(result)).")
        }
        if let previous = registrations.removeValue(forKey: id) { UnregisterEventHotKey(previous) }
        if let previousID = identifiers.removeValue(forKey: id) { actions[previousID] = nil }
        registrations[id] = ref; identifiers[id] = serial; actions[serial] = action; assigned[id] = shortcut
        #else
        throw QuickUtilityError.unavailable("Los atajos globales requieren macOS.")
        #endif
    }
    public func unregister(id: String) {
        #if os(macOS)
        if let ref = registrations.removeValue(forKey: id) { UnregisterEventHotKey(ref) }
        if let number = identifiers.removeValue(forKey: id) { actions[number] = nil }
        #endif
        assigned[id] = nil
        #if os(macOS)
        removeHandlerIfEmpty()
        #endif
    }
    public func unregisterAll() { for id in Array(assigned.keys) { unregister(id: id) } }
    #if os(macOS)
    private func removeHandlerIfEmpty() {
        if registrations.isEmpty, let handler { RemoveEventHandler(handler); self.handler = nil }
    }
    public static func keyCode(for character: String) -> UInt32? {
        guard let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
              let pointer = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else { return nil }
        let data = Unmanaged<CFData>.fromOpaque(pointer).takeUnretainedValue()
        let layout = UnsafeRawPointer(CFDataGetBytePtr(data)).assumingMemoryBound(to: UCKeyboardLayout.self)
        for key in UInt16(0)..<128 {
            var dead: UInt32 = 0, count = 0
            var chars = [UniChar](repeating: 0, count: 8)
            let result = UCKeyTranslate(layout, key, UInt16(kUCKeyActionDisplay), 0, UInt32(LMGetKbdType()), OptionBits(kUCKeyTranslateNoDeadKeysBit), &dead, chars.count, &count, &chars)
            if result == noErr, String(utf16CodeUnits: chars, count: count).lowercased() == character.lowercased() { return UInt32(key) }
        }
        return nil
    }
    #endif
}
