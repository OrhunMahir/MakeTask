import AppKit

final class FloatingNotePanel: NSPanel {
    var taskInputEnabled = true
    var onHeaderMouseDown: (() -> Void)?

    override func sendEvent(_ event: NSEvent) {
        if event.type == .leftMouseDown {
            prepareForHeaderInteraction(at: event.locationInWindow)
        }
        super.sendEvent(event)
    }

    func prepareForHeaderInteraction(at point: NSPoint) {
        let height = taskInputEnabled ? NoteWindowMetrics.headerHeight : NoteWindowMetrics.collapsedHeaderHeight
        let headerBottom = frame.height - height
        guard point.y >= headerBottom else { return }
        onHeaderMouseDown?()
        // Preserve the caret only when clicking inside the title editor itself.
        let responderFrame = (firstResponder as? NSView).map { $0.convert($0.bounds, to: nil) }
        if responderFrame.map({ $0.minY < headerBottom || !$0.contains(point) }) ?? true {
            makeFirstResponder(contentView)
        }
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

enum NoteWindowMetrics {
    static let minimumWidth: CGFloat = 260
    static let defaultWidth: CGFloat = 320
    static let defaultHeight: CGFloat = 360
    static let headerHeight: CGFloat = 46
    static let collapsedHeaderHeight: CGFloat = 34
    static let cornerRadius: CGFloat = 14
}
