import AppKit
import SwiftUI

extension NSPasteboard.PasteboardType {
    static let makeTaskID = Self("dev.orhun.MakeTask.task-id")
}

/// One stable native destination covers both rows and the space between them.
/// Per-row destinations can be obscured by the native drag source or move away
/// from the pointer while SwiftUI animates a reorder.
struct TaskDropDestinationView: NSViewRepresentable {
    let draggedTaskID: UUID?
    let onHover: (UUID, CGPoint) -> Void
    let onDrop: () -> Void

    func makeNSView(context: Context) -> TaskDropDestinationNSView {
        let view = TaskDropDestinationNSView()
        updateNSView(view, context: context)
        return view
    }

    func updateNSView(_ view: TaskDropDestinationNSView, context: Context) {
        view.draggedTaskID = draggedTaskID
        view.onHover = onHover
        view.onDrop = onDrop
    }
}

@MainActor
final class TaskDropDestinationNSView: NSView {
    var draggedTaskID: UUID?
    var onHover: (UUID, CGPoint) -> Void = { _, _ in }
    var onDrop: () -> Void = {}
    private var lastScrollTime: TimeInterval = 0

    override var isFlipped: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerForDraggedTypes([.makeTaskID])
        setAccessibilityElement(false)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func hitTest(_ point: NSPoint) -> NSView? {
        // Ordinary clicks, title editing, context menus and scrolling pass through.
        draggedTaskID == nil ? nil : super.hitTest(point)
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        updateDrag(sender)
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        updateDrag(sender)
    }

    override func wantsPeriodicDraggingUpdates() -> Bool { true }

    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        acceptedTaskID(sender) != nil
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard updateDrag(sender) == .move else { return false }
        onDrop()
        return true
    }

    private func acceptedTaskID(_ sender: NSDraggingInfo) -> UUID? {
        guard sender.draggingSource is TaskDragSourceNSView,
              let id = draggedTaskID,
              sender.draggingPasteboard.string(forType: .makeTaskID) == id.uuidString else { return nil }
        return id
    }

    private func updateDrag(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard let id = acceptedTaskID(sender) else { return [] }
        let point = convert(sender.draggingLocation, from: nil)
        guard bounds.contains(point) else { return [] }
        onHover(id, point)
        scrollNearEdge(point)
        return .move
    }

    private func scrollNearEdge(_ point: CGPoint) {
        let now = ProcessInfo.processInfo.systemUptime
        guard now - lastScrollTime >= 1.0 / 30 else { return }
        let margin: CGFloat = min(28, bounds.height / 4)
        let delta: CGFloat = point.y < margin ? -8 : (point.y > bounds.height - margin ? 8 : 0)
        guard delta != 0, let scrollView = containingScrollView(),
              let document = scrollView.documentView else { return }
        let clip = scrollView.contentView
        let maxY = max(0, document.bounds.height - clip.bounds.height)
        let nextY = min(max(clip.bounds.minY + delta, 0), maxY)
        guard nextY != clip.bounds.minY else { return }
        lastScrollTime = now
        clip.scroll(to: NSPoint(x: clip.bounds.minX, y: nextY))
        scrollView.reflectScrolledClipView(clip)
    }

    private func containingScrollView() -> NSScrollView? {
        // The overlay and SwiftUI's NSScrollView are siblings within the hosting tree.
        let center = convert(NSPoint(x: bounds.midX, y: bounds.midY), to: nil)
        func find(in view: NSView) -> NSScrollView? {
            if let scroll = view as? NSScrollView,
               scroll.convert(scroll.bounds, to: nil).contains(center) { return scroll }
            for child in view.subviews where child !== self {
                if let found = find(in: child) { return found }
            }
            return nil
        }
        var ancestor = superview
        while let view = ancestor {
            if let scroll = find(in: view) { return scroll }
            ancestor = view.superview
        }
        return nil
    }
}
