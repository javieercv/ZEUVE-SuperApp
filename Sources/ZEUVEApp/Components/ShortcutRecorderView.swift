import SwiftUI
import AppKit
import ZEUVECore

struct ShortcutRecorderView: View {
    let shortcut: KeyboardShortcutDescriptor?
    let onChange: (KeyboardShortcutDescriptor?) -> Void
    @State private var isRecording = false
    @State private var monitor: Any?

    var body: some View {
        HStack(spacing: 8) {
            Button(isRecording ? "Pulsa el nuevo atajo…" : (shortcut?.displayName ?? "Sin atajo")) {
                isRecording ? stopRecording() : startRecording()
            }
            .frame(minWidth: 150)
            if shortcut != nil { Button("Quitar") { onChange(nil) }.buttonStyle(.borderless) }
            if isRecording { Button("Cancelar") { stopRecording() }.buttonStyle(.borderless) }
        }
        .onDisappear { stopRecording() }
    }

    private func startRecording() {
        stopRecording(); isRecording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard isRecording else { return event }
            if event.keyCode == 53 { stopRecording(); return nil }
            guard let chars = event.charactersIgnoringModifiers, let scalar = chars.unicodeScalars.first else { return nil }
            let key = String(Character(scalar))
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            let descriptor = KeyboardShortcutDescriptor(key: key, command: flags.contains(.command), option: flags.contains(.option), control: flags.contains(.control), shift: flags.contains(.shift))
            onChange(descriptor); stopRecording(); return nil
        }
    }

    private func stopRecording() {
        if let monitor { NSEvent.removeMonitor(monitor); self.monitor = nil }
        isRecording = false
    }
}
