import AppKit
import SwiftUI

struct TaskDragSourceView: NSViewRepresentable {
    let taskID: UUID
    let title: String
    let tint: NSColor
    let font: NSFont
    let previewWidth: CGFloat
    let onClick: () -> Void
    let onDragBegan: () -> Void
    let onDragEnded: () -> Void

    func makeNSView(context: Context) -> TaskDragSourceNSView {
        let view = TaskDragSourceNSView()
        update(view)
        return view
    }

    func updateNSView(_ nsView: TaskDragSourceNSView, context: Context) {
        update(nsView)
    }

    private func update(_ view: TaskDragSourceNSView) {
        view.taskID = taskID
        view.title = title
        view.tint = tint
        view.font = font
        view.previewWidth = previewWidth
        view.onClick = onClick
        view.onDragBegan = onDragBegan
        view.onDragEnded = onDragEnded
    }
}

@MainActor
final class TaskDragSourceNSView: NSView, NSDraggingSource {
    var taskID = UUID()
    var title = ""
    var tint = NSColor.controlAccentColor
    var font = NSFont.systemFont(ofSize: 13.5, weight: .medium)
    var previewWidth: CGFloat = 220
    var onClick: () -> Void = {}
    var onDragBegan: () -> Void = {}
    var onDragEnded: () -> Void = {}

    private var initialMouseLocation: NSPoint?
    private var isDraggingTask = false

    override var acceptsFirstResponder: Bool { true }

    override func mouseDown(with event: NSEvent) {
        initialMouseLocation = convert(event.locationInWindow, from: nil)
        isDraggingTask = false
    }

    override func mouseDragged(with event: NSEvent) {
        guard !isDraggingTask, let initialMouseLocation else { return }
        let currentLocation = convert(event.locationInWindow, from: nil)
        let distance = hypot(
            currentLocation.x - initialMouseLocation.x,
            currentLocation.y - initialMouseLocation.y
        )
        guard distance >= 3 else { return }

        isDraggingTask = true
        onDragBegan()

        let pasteboardItem = NSPasteboardItem()
        pasteboardItem.setString(taskID.uuidString, forType: .string)
        let draggingItem = NSDraggingItem(pasteboardWriter: pasteboardItem)
        let imageSize = NSSize(
            width: max(previewWidth, 220),
            height: max(bounds.height, 34)
        )
        draggingItem.setDraggingFrame(
            NSRect(
                x: bounds.midX - imageSize.width / 2,
                y: bounds.midY - imageSize.height / 2,
                width: imageSize.width,
                height: imageSize.height
            ),
            contents: makePreviewImage(size: imageSize)
        )

        let session = beginDraggingSession(with: [draggingItem], event: event, source: self)
        session.draggingFormation = NSDraggingFormation.none
        session.animatesToStartingPositionsOnCancelOrFail = false
    }

    override func mouseUp(with event: NSEvent) {
        if !isDraggingTask {
            onClick()
        }
        initialMouseLocation = nil
    }

    func draggingSession(
        _ session: NSDraggingSession,
        sourceOperationMaskFor context: NSDraggingContext
    ) -> NSDragOperation {
        .move
    }

    func draggingSession(
        _ session: NSDraggingSession,
        endedAt screenPoint: NSPoint,
        operation: NSDragOperation
    ) {
        session.animatesToStartingPositionsOnCancelOrFail = false
        isDraggingTask = false
        initialMouseLocation = nil
        onDragEnded()
    }

    private func makePreviewImage(size: NSSize) -> NSImage {
        let image = NSImage(size: size)
        image.lockFocus()
        defer { image.unlockFocus() }

        let cardRect = NSRect(origin: .zero, size: size).insetBy(dx: 1.5, dy: 1.5)
        let card = NSBezierPath(roundedRect: cardRect, xRadius: 9, yRadius: 9)
        NSColor.windowBackgroundColor.withAlphaComponent(0.96).setFill()
        card.fill()
        tint.withAlphaComponent(0.95).setStroke()
        card.lineWidth = 2
        card.stroke()

        let circleRect = NSRect(x: 13, y: size.height / 2 - 7, width: 14, height: 14)
        let circle = NSBezierPath(ovalIn: circleRect)
        tint.setStroke()
        circle.lineWidth = 1.7
        circle.stroke()

        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byTruncatingTail
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: paragraph
        ]
        NSString(string: title).draw(
            in: NSRect(x: 37, y: size.height / 2 - 9, width: size.width - 50, height: 19),
            withAttributes: attributes
        )

        return image
    }
}
