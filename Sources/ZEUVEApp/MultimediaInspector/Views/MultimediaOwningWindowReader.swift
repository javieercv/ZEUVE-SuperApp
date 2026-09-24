import AppKit
import SwiftUI

@MainActor
final class MultimediaOwningWindowReference: ObservableObject {
    weak var window: NSWindow?
    @Published private(set) var isAvailable = false

    func update(_ window: NSWindow?) {
        guard self.window !== window else { return }
        self.window = window
        isAvailable = window != nil
    }
}

struct MultimediaOwningWindowReader: NSViewRepresentable {
    let onChange: @MainActor (NSWindow?) -> Void

    func makeNSView(context: Context) -> WindowObservingView {
        let view = WindowObservingView()
        view.onChange = onChange
        return view
    }

    func updateNSView(_ nsView: WindowObservingView, context: Context) {
        nsView.onChange = onChange
        nsView.publishWindow()
    }

    final class WindowObservingView: NSView {
        var onChange: (@MainActor (NSWindow?) -> Void)?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            publishWindow()
        }

        @MainActor
        func publishWindow() {
            onChange?(window)
        }
    }
}
