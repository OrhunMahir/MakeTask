import AppKit
import SwiftUI

/// Keeps borderless note movement confined to a deliberate part of the header.
struct WindowDragArea: NSViewRepresentable {
    var onMouseDown: (() -> Void)? = nil
    let onDoubleClick: () -> Void

    func makeNSView(context: Context) -> DragAreaView {
        let view = DragAreaView()
        view.onMouseDown = onMouseDown
        view.onDoubleClick = onDoubleClick
        return view
    }

    func updateNSView(_ nsView: DragAreaView, context: Context) {
        nsView.onMouseDown = onMouseDown
        nsView.onDoubleClick = onDoubleClick
    }
}

final class DragAreaView: NSView {
    var onMouseDown: (() -> Void)?
    var onDoubleClick: (() -> Void)?

    override var acceptsFirstResponder: Bool { false }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func mouseDown(with event: NSEvent) {
        onMouseDown?()
        window?.makeFirstResponder(window?.contentView)
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
