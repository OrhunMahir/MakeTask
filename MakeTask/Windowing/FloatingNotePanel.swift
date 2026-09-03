import AppKit

final class FloatingNotePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

enum NoteWindowMetrics {
    static let minimumWidth: CGFloat = 260
    static let defaultWidth: CGFloat = 320
    static let defaultHeight: CGFloat = 360
    static let headerHeight: CGFloat = 46
    static let collapsedHeaderHeight: CGFloat = 48
    static let collapsedMinimumWidth: CGFloat = 176
    static let collapsedMaximumWidth: CGFloat = 280
    static let cornerRadius: CGFloat = 14
}
