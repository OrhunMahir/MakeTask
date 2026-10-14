import AppKit
import SwiftUI

struct TaskDragSourceView: NSViewRepresentable {
    let taskID: UUID
    let title: String
    let tint: NSColor
    let font: NSFont
    let isCompleted: Bool
    let isInProgress: Bool
    let onClick: () -> Void
    let onDragBegan: () -> Void
    let onDragEnded: (Bool) -> Void

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
        view.isCompleted = isCompleted
        view.isInProgress = isInProgress
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
    var isCompleted = false
    var isInProgress = false
    var onClick: () -> Void = {}
    var onDragBegan: () -> Void = {}
    var onDragEnded: (Bool) -> Void = { _ in }

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
        pasteboardItem.setString(taskID.uuidString, forType: .makeTaskID)
        let draggingItem = NSDraggingItem(pasteboardWriter: pasteboardItem)
        let imageSize = NSSize(
            width: bounds.width + 73, // Checkbox, spacing and reserved delete button.
            height: max(bounds.height + 10, 30)
        )
        draggingItem.setDraggingFrame(
            NSRect(
                x: -36, // Align the title with its position in the original row.
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
        context == .withinApplication ? .move : []
    }

    func draggingSession(
        _ session: NSDraggingSession,
        endedAt screenPoint: NSPoint,
        operation: NSDragOperation
    ) {
        session.animatesToStartingPositionsOnCancelOrFail = false
        isDraggingTask = false
        initialMouseLocation = nil
        onDragEnded(operation == .move)
    }

    private func makePreviewImage(size: NSSize) -> NSImage {
        let image = NSImage(size: size)
        image.lockFocus()
        defer { image.unlockFocus() }

        let cardRect = NSRect(origin: .zero, size: size).insetBy(dx: 1.5, dy: 1.5)
        let card = NSBezierPath(roundedRect: cardRect, xRadius: 9, yRadius: 9)
        NSColor.windowBackgroundColor.withAlphaComponent(0.96).setFill()
        card.fill()
        tint.withAlphaComponent(0.35).setStroke()
        card.lineWidth = 1
        card.stroke()

        let symbolName = isCompleted ? "checkmark.circle.fill" : (isInProgress ? "circle.lefthalf.filled" : "circle")
        let symbol = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)?
            .withSymbolConfiguration(.init(pointSize: 15, weight: .medium))?
            .withSymbolConfiguration(.init(paletteColors: [isCompleted || isInProgress ? tint : .secondaryLabelColor]))
        symbol?.draw(in: NSRect(x: 12, y: size.height / 2 - 8, width: 16, height: 16))

        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byWordWrapping
        var attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: paragraph
        ]
        if isCompleted { attributes[.strikethroughStyle] = NSUnderlineStyle.single.rawValue }
        NSString(string: title).draw(
            in: NSRect(x: 36, y: 5, width: size.width - 73, height: size.height - 10),
            withAttributes: attributes
        )

        return image
    }
}
