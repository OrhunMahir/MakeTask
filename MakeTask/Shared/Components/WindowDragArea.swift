import AppKit
import SwiftUI

/// Keeps borderless note movement confined to a deliberate part of the header.
struct WindowDragArea: NSViewRepresentable {
    let onDoubleClick: () -> Void

    func makeNSView(context: Context) -> DragAreaView {
        let view = DragAreaView()
        view.onDoubleClick = onDoubleClick
        return view
    }

    func updateNSView(_ nsView: DragAreaView, context: Context) {
        nsView.onDoubleClick = onDoubleClick
    }
}

final class DragAreaView: NSView {
    var onDoubleClick: (() -> Void)?

    override var acceptsFirstResponder: Bool { false }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func mouseDown(with event: NSEvent) {
        if event.clickCount == 2 {
            onDoubleClick?()
            return
        }
        window?.performDrag(with: event)
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .openHand)
    }
}
