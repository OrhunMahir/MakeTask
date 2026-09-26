#if DEBUG
import AppKit
import SwiftUI

/// Measures the actual SwiftUI title bounds in native-panel regression tests.
/// A background view has no influence on the title's proposed size.
struct NoteTitleLayoutProbe: NSViewRepresentable {
    private final class ProbeView: NSView {
        override func hitTest(_ point: NSPoint) -> NSView? { nil }
    }

    func makeNSView(context: Context) -> NSView {
        let view = ProbeView()
        view.identifier = NSUserInterfaceItemIdentifier("note.title-layout")
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}
#endif
